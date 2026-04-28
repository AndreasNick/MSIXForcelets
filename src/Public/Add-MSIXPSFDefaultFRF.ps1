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
      - RoamingAppData, ProgramFilesX64, SystemX86, System

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain config.json.xml).

.PARAMETER Executable
    Regex pattern for the process entry. Default: ".*" (all processes).

.EXAMPLE
    Add-MSIXPSFDefaultFRF -MSIXFolder "C:\MSIXTemp\WinRAR"

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [String] $Executable = '.*'
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

        # Exclusion: executable and binary file types must not be redirected
        Add-MSIXPSFFileRedirectionFixup -MSIXFolder $MSIXFolder -Executable $Executable `
            -PackageRelative -Base '' `
            -Patterns @(
                '.*\\.[eE][xX][eE]$', '.*\\.[dD][lL][lL]$', '.*\\.[tT][lL][bB]$',
                '.*\\.[oO][cC][xX]$', '.*\\.[cC][oO][mM]$', '.*\\.[fF][oO][nN]$',
                '.*\\.[tT][tT][cC]$', '.*\\.[tT][tT][fF]$', '.*\\.[zZ][iI][pP].*'
            ) -IsExclusion

        # Exclusion: VFS\FONTS is managed by the OS font subsystem
        Add-MSIXPSFFileRedirectionFixup -MSIXFolder $MSIXFolder -Executable $Executable `
            -PackageRelative -Base 'VFS\FONTS' -Patterns @('.*') -IsExclusion

        # Redirect everything else under the package root
        Add-MSIXPSFFileRedirectionFixup -MSIXFolder $MSIXFolder -Executable $Executable `
            -PackageRelative -Base '' -Patterns @('.*')

        # Redirect known system and user folders
        Add-MSIXPSFFileRedirectionFixup -MSIXFolder $MSIXFolder -Executable $Executable `
            -KnownFolder 'RoamingAppData' -Base '' -Patterns @('.*')

        Add-MSIXPSFFileRedirectionFixup -MSIXFolder $MSIXFolder -Executable $Executable `
            -KnownFolder 'ProgramFilesX64' -Base '' -Patterns @('.*')

        Add-MSIXPSFFileRedirectionFixup -MSIXFolder $MSIXFolder -Executable $Executable `
            -KnownFolder 'SystemX86' -Base '' -Patterns @('.*')

        Add-MSIXPSFFileRedirectionFixup -MSIXFolder $MSIXFolder -Executable $Executable `
            -KnownFolder 'System' -Base '' -Patterns @('.*')
    }
}
