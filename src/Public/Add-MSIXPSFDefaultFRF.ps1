function Add-MSIXPSFDefaultFRF {
<#
.SYNOPSIS
    Adds a standard FileRedirectionFixup configuration to an MSIX package.

.DESCRIPTION
    Applies a comprehensive default FileRedirectionFixup rule set by calling
    Add-MSIXPSFFileRedirectionFixup with the following configuration:

    packageRelative exclusions (not redirected):
      - Executable types: .exe .dll .tlb .ocx .com .fon .ttc .ttf .zip*
      - VFS\FONTS folder
    packageRelative catch-all (redirected):
      - Everything else under the package root
    knownFolders (redirected):
      - ProgramFilesX64, SystemX86, System (only when -SystemFolders is true)

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain config.json.xml).

.PARAMETER Executable
    Regex pattern for the process entry. Default: ".*" (all processes).

.PARAMETER SystemFolders
    When $true, redirects ProgramFilesX64, SystemX86 and System known folders.
    Default is $false because the packageRelative catch-all already covers
    system writes indirectly via MSIX VFS-mapping (writes to C:\Windows\System32
    are normalised to <pkg>\VFS\SystemX64\... by the runtime, then matched by
    the catch-all). Explicit knownFolder rules are mostly redundant for the
    default whole-package scope.

    However, when -PackageRelativeBase is set to a subfolder, the catch-all
    no longer covers system paths via VFS-mapping. In that case you usually
    want -SystemFolders:`$true to add explicit knownFolder rules - a warning
    is issued at runtime if you forget.

.PARAMETER PackageRelativeBase
    Optional base path inside the package for the binary-type-exclusion rule
    and the catch-all redirection rule. Default '' = applies to the whole
    package root (legacy behaviour). Set to a subfolder like
    'VFS\ProgramFilesX64\NickIT' to scope the catch-all to that app folder.
    Useful for isolating which writes really need redirection (lab tests of
    the VFS-mapping hypothesis). The FONTS exclusion and known-folder rules
    are NOT affected by this parameter.

.PARAMETER ExcludePersonalFolder
    When $true, adds isExclusion rules for the user's personal data folders
    so writes there bypass FRF and land in the real %USERPROFILE% instead of
    the package's writable container. Apps may resolve the same logical folder
    via different Windows APIs (legacy CSIDL vs. modern KNOWNFOLDERID), and
    MSIX maps each to a different VFS path - so multiple excludes per folder
    are needed to cover all routes:
      VFS\Personal              - Documents (legacy CSIDL_PERSONAL)
      VFS\Profile\Documents     - Documents (modern fallback)
      VFS\Profile\Pictures      - Pictures
      VFS\Profile\Music         - Music
      VFS\Profile\Videos        - Videos
      VFS\Profile\Downloads     - Downloads
      VFS\Profile\Desktop       - Desktop (legacy CSIDL_DESKTOPDIRECTORY)
      VFS\ThisPCDesktopFolder   - Desktop (Win10+ KNOWNFOLDERID)
    Off by default - turn on when the app is supposed to produce files the
    user can find later via Explorer (would otherwise disappear on uninstall).

.EXAMPLE
    Add-MSIXPSFDefaultFRF -MSIXFolder "C:\MSIXTemp\WinRAR"

.EXAMPLE
    Add-MSIXPSFDefaultFRF -MSIXFolder "C:\MSIXTemp\Lab" -SystemFolders:$false

.EXAMPLE
    # Office-style app: keep Documents writes in the real user profile
    Add-MSIXPSFDefaultFRF -MSIXFolder "C:\MSIXTemp\App" -ExcludePersonalFolder:$true

.NOTES
    Hintergrund / Stolpersteine zu FRF (Hypothesen, VFS-Pfad-Inkonsistenzen, Best Practices)
    sind in Test\InternalDocs\MSIX-Grundlagen-KB.md unter "File Redirection Fixup (FRF)"
    dokumentiert (Buchkandidat-Material).

    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [String] $Executable = '.*',

        [String] $PackageRelativeBase = '',

        [bool] $SystemFolders         = $false,
        [bool] $ExcludePersonalFolder = $false
    )

    process {
        # Validate MSIXFolder
        if (-not (Test-Path $MSIXFolder.FullName -PathType Container)) {
            Write-Error "MSIXFolder not found: $($MSIXFolder.FullName)"
            return
        }
        if (-not (Test-Path (Join-Path $MSIXFolder.FullName 'AppxManifest.xml'))) {
            Write-Warning "AppxManifest.xml not found in '$($MSIXFolder.FullName)'. Is this a valid expanded MSIX package?"
        }

        # Validate Executable is a compilable regex
        try {
            $null = [System.Text.RegularExpressions.Regex]::new($Executable)
        }
        catch {
            Write-Error "-Executable '$Executable' is not a valid regular expression: $_"
            return
        }

        # When the catch-all is scoped to a subfolder, the VFS-mapping side effect
        # that catches system writes via the whole-package catch-all no longer
        # applies. Warn the user if they didn't explicitly opt into SystemFolders.
        if ($PackageRelativeBase -ne '' -and -not $PSBoundParameters.ContainsKey('SystemFolders')) {
            Write-Warning ("PackageRelativeBase='$PackageRelativeBase' scopes the catch-all to that subfolder. " +
                'Writes to system paths (System32, ProgramFiles, ...) are no longer redirected via ' +
                'VFS-mapping side-effects. If the app writes to system folders, consider ' +
                "-SystemFolders:`$true to add explicit knownFolder rules.")
        }

        # Exclusion: executable and binary file types must not be redirected
        Add-MSIXPSFFileRedirectionFixup -MSIXFolder $MSIXFolder -Executable $Executable `
            -PackageRelative -Base $PackageRelativeBase `
            -Patterns @(
                '.*\\.[eE][xX][eE]$', '.*\\.[dD][lL][lL]$', '.*\\.[tT][lL][bB]$',
                '.*\\.[oO][cC][xX]$', '.*\\.[cC][oO][mM]$', '.*\\.[fF][oO][nN]$',
                '.*\\.[tT][tT][cC]$', '.*\\.[tT][tT][fF]$', '.*\\.[zZ][iI][pP].*'
            ) -IsExclusion

        # Exclusion: VFS\FONTS is managed by the OS font subsystem
        Add-MSIXPSFFileRedirectionFixup -MSIXFolder $MSIXFolder -Executable $Executable `
            -PackageRelative -Base 'VFS\FONTS' -Patterns @('.*') -IsExclusion

        # Optional exclusion: keep user's personal data folders in the real profile.
        # MSIX VFS naming is wildly inconsistent across legacy CSIDL paths and the
        # newer KNOWNFOLDERID names. Apps that fall back from one API to the other
        # (common in .NET libraries) hit different VFS paths sequentially, so we
        # exclude both routes per logical folder.
        if ($ExcludePersonalFolder) {
            $personalFolders = @(
                'VFS\Personal',             # Documents (legacy CSIDL_PERSONAL)
                'VFS\Profile\Documents',    # Documents (modern fallback)
                'VFS\Profile\Pictures',
                'VFS\Profile\Music',
                'VFS\Profile\Videos',
                'VFS\Profile\Downloads',
                'VFS\Profile\Desktop',      # Desktop (legacy CSIDL_DESKTOPDIRECTORY)
                'VFS\ThisPCDesktopFolder'   # Desktop (Win10+ KNOWNFOLDERID)
            )
            foreach ($pf in $personalFolders) {
                Add-MSIXPSFFileRedirectionFixup -MSIXFolder $MSIXFolder -Executable $Executable `
                    -PackageRelative -Base $pf -Patterns @('.*') -IsExclusion
            }
        }

        # Redirect everything else under the package root (or, if -PackageRelativeBase
        # is set, only under that subfolder of the package).
        Add-MSIXPSFFileRedirectionFixup -MSIXFolder $MSIXFolder -Executable $Executable `
            -PackageRelative -Base $PackageRelativeBase -Patterns @('.*')

        if ($SystemFolders) {
            Add-MSIXPSFFileRedirectionFixup -MSIXFolder $MSIXFolder -Executable $Executable `
                -KnownFolder 'ProgramFilesX64' -Base '' -Patterns @('.*')

            Add-MSIXPSFFileRedirectionFixup -MSIXFolder $MSIXFolder -Executable $Executable `
                -KnownFolder 'SystemX86' -Base '' -Patterns @('.*')

            Add-MSIXPSFFileRedirectionFixup -MSIXFolder $MSIXFolder -Executable $Executable `
                -KnownFolder 'System' -Base '' -Patterns @('.*')
        }
    }
}
