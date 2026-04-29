function New-MSIXPackage {
<#
.SYNOPSIS
    Creates an empty MSIX skeleton folder from the bundled template.

.DESCRIPTION
    Copies the MSIXTemplate (empty Registry.dat / User.dat / UserClasses.dat /
    Resources.pri / Assets / AppxManifest.xml) into a fresh folder and fills the
    manifest placeholders. Returns the created folder so it can be piped into
    Add-MSIXApplication, New-MSIXAssetFrom, Add-MSIXPsfFrameworkFiles, etc.

.PARAMETER OutputFolder
    Destination folder for the skeleton.

.PARAMETER Name
    Identity Name (e.g. 'MyApp'). Must match [A-Za-z][-A-Za-z0-9.]*.

.PARAMETER Publisher
    Publisher subject (e.g. 'CN=Contoso').

.PARAMETER Version
    Package version, four-part (e.g. '1.0.0.0').

.PARAMETER DisplayName
    Display name shown in Settings. Defaults to Name.

.PARAMETER PublisherDisplayName
    Friendly publisher name. Defaults to the CN= part of Publisher.

.PARAMETER Description
    Package description. Defaults to DisplayName.

.PARAMETER ProcessorArchitecture
    x64 (default), x86, or neutral.

.PARAMETER Force
    Overwrites OutputFolder if it already exists.

.EXAMPLE
    $pkg = New-MSIXPackage -OutputFolder C:\Temp\MyApp -Name 'MyApp' `
        -Publisher 'CN=Contoso' -Version '1.0.0.0'

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    [OutputType([System.IO.DirectoryInfo])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [System.IO.DirectoryInfo] $OutputFolder,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Za-z][-A-Za-z0-9.]*$')]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^CN=')]
        [string] $Publisher,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\d+\.\d+\.\d+\.\d+$')]
        [string] $Version,

        [string] $DisplayName,
        [string] $PublisherDisplayName,
        [string] $Description,

        [ValidateSet('x64', 'x86', 'neutral')]
        [string] $ProcessorArchitecture = 'x64',

        [switch] $Force
    )

    process {
        $templateRoot = Join-Path $Script:ScriptPath 'Libs\MSIXTemplate'
        if (-not (Test-Path $templateRoot)) {
            Write-Error "MSIX template folder not found: $templateRoot"
            return $null
        }

        if (Test-Path $OutputFolder.FullName) {
            if (-not $Force) {
                Write-Error "OutputFolder already exists: $($OutputFolder.FullName). Use -Force to overwrite."
                return $null
            }
            Write-Verbose "Removing existing OutputFolder: $($OutputFolder.FullName)"
            Remove-Item $OutputFolder.FullName -Recurse -Force -ErrorAction Stop
        }

        Write-Verbose "Creating skeleton folder: $($OutputFolder.FullName)"
        New-Item -ItemType Directory -Path $OutputFolder.FullName -Force | Out-Null

        Copy-Item -Path (Join-Path $templateRoot '*') -Destination $OutputFolder.FullName -Recurse -Force
        Write-Verbose "Copied template files from: $templateRoot"

        # Apply defaults derived from required parameters
        if ([string]::IsNullOrEmpty($DisplayName)) { $DisplayName = $Name }
        if ([string]::IsNullOrEmpty($Description)) { $Description = $DisplayName }
        if ([string]::IsNullOrEmpty($PublisherDisplayName)) {
            $cnMatch = [regex]::Match($Publisher, 'CN=([^,]+)')
            $PublisherDisplayName = if ($cnMatch.Success) { $cnMatch.Groups[1].Value.Trim() } else { $Name }
        }

        $manifestPath = Join-Path $OutputFolder.FullName 'AppxManifest.xml'
        $manifest = Get-Content $manifestPath -Raw
        $manifest = $manifest.
            Replace('{{Name}}',                  $Name).
            Replace('{{Publisher}}',             $Publisher).
            Replace('{{Version}}',               $Version).
            Replace('{{ProcessorArchitecture}}', $ProcessorArchitecture).
            Replace('{{DisplayName}}',           $DisplayName).
            Replace('{{PublisherDisplayName}}',  $PublisherDisplayName).
            Replace('{{Description}}',           $Description)
        Set-Content -Path $manifestPath -Value $manifest -Encoding UTF8 -NoNewline
        Write-Verbose "Manifest finalised: $manifestPath"

        return Get-Item $OutputFolder.FullName
    }
}
