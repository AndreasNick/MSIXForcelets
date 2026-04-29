function Add-MSIXApplication {
<#
.SYNOPSIS
    Adds an Application entry (with VisualElements) to an MSIX package's manifest.

.DESCRIPTION
    Inserts a single Application element into AppxManifest.xml. Defaults for Id
    and DisplayName are derived from the Executable filename when not specified.
    AssetId binds VisualElements logo paths to PNG files in the Assets folder
    (typically generated beforehand by New-MSIXAssetFrom). When AssetId is
    omitted, all logos fall back to Assets\StoreLogo.png.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder.

.PARAMETER Executable
    Package-relative path to the executable (.exe / .ps1 / .cmd / .vbs / .js).
    The file must already exist inside the package.

.PARAMETER Id
    Application Id. Defaults to a sanitised form of the executable's base name.

.PARAMETER DisplayName
    Display name shown in Start menu. Defaults to the executable's base name.

.PARAMETER AssetId
    Asset prefix used for VisualElements logo paths (Assets\<AssetId>-*.png).
    When empty, all logos use Assets\StoreLogo.png.

.PARAMETER Description
    Application description. Defaults to DisplayName.

.PARAMETER EntryPoint
    EntryPoint attribute. Defaults to Windows.FullTrustApplication.

.EXAMPLE
    Add-MSIXApplication -MSIXFolder $pkg -Executable 'NITMSIXEventlogTracer.ps1' `
        -DisplayName 'NIT Eventlog Tracer' -AssetId 'PSTracer'

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Executable,

        [string] $Id,
        [string] $DisplayName,
        [string] $AssetId,
        [string] $Description,
        [string] $EntryPoint = 'Windows.FullTrustApplication'
    )

    process {
        $manifestPath = Join-Path $MSIXFolder.FullName 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "AppxManifest.xml not found in: $($MSIXFolder.FullName)"
            return $null
        }

        $exeFull = Join-Path $MSIXFolder.FullName $Executable
        if (-not (Test-Path $exeFull)) {
            Write-Error "Executable not found in package: $Executable (looked in $exeFull)"
            return $null
        }

        # Defaults from executable base name
        $exeBase = [IO.Path]::GetFileNameWithoutExtension($Executable)
        if ([string]::IsNullOrEmpty($Id)) {
            # Sanitise to MSIX Application/@Id pattern: [A-Za-z][-A-Za-z0-9.]{0,62}
            $sanitised = ($exeBase -replace '[^A-Za-z0-9.\-]', '')
            $sanitised = $sanitised -replace '^[^A-Za-z]+', ''
            if ($sanitised.Length -eq 0) {
                Write-Error "Could not derive a valid Id from executable '$Executable'. Provide -Id explicitly."
                return $null
            }
            if ($sanitised.Length -gt 63) { $sanitised = $sanitised.Substring(0, 63) }
            $Id = $sanitised
            Write-Verbose "Derived Id: $Id"
        }
        if ([string]::IsNullOrEmpty($DisplayName)) {
            $DisplayName = $exeBase
            Write-Verbose "Derived DisplayName: $DisplayName"
        }
        if ([string]::IsNullOrEmpty($Description)) { $Description = $DisplayName }

        # Decide logo paths
        if ([string]::IsNullOrEmpty($AssetId)) {
            $logo150 = 'Assets\StoreLogo.png'
            $logo44  = 'Assets\StoreLogo.png'
            $logo71  = 'Assets\StoreLogo.png'
            $logo310 = 'Assets\StoreLogo.png'
            $wide310 = 'Assets\StoreLogo.png'
            Write-Verbose "AssetId not set - all logos use Assets\StoreLogo.png"
        }
        else {
            $logo150 = "Assets\$AssetId-Square150x150Logo.png"
            $logo44  = "Assets\$AssetId-Square44x44Logo.png"
            $logo71  = "Assets\$AssetId-Square71x71Logo.png"
            $logo310 = "Assets\$AssetId-Square310x310Logo.png"
            $wide310 = "Assets\$AssetId-Wide310x150Logo.png"
        }

        $xml = New-Object System.Xml.XmlDocument
        $xml.PreserveWhitespace = $false
        $xml.Load($manifestPath)

        $foundationNs = 'http://schemas.microsoft.com/appx/manifest/foundation/windows10'
        $uapNs        = 'http://schemas.microsoft.com/appx/manifest/uap/windows10'

        # Ensure xmlns:uap is declared on Package
        if (-not $xml.DocumentElement.HasAttribute('xmlns:uap')) {
            $xml.DocumentElement.SetAttribute('xmlns:uap', $uapNs)
            $ignorable = $xml.DocumentElement.GetAttribute('IgnorableNamespaces')
            if ($ignorable -notmatch '\buap\b') {
                $xml.DocumentElement.SetAttribute('IgnorableNamespaces', ($ignorable.TrimEnd() + ' uap').Trim())
            }
            Write-Verbose "Added uap namespace to manifest root"
        }

        $appsNode = $xml.SelectSingleNode("//*[local-name()='Applications']")
        if ($null -eq $appsNode) {
            $appsNode = $xml.CreateElement('Applications', $foundationNs)
            $null = $xml.DocumentElement.AppendChild($appsNode)
        }

        # Reject duplicate Id
        foreach ($existing in @($appsNode.SelectNodes("*[local-name()='Application']"))) {
            if ($existing.GetAttribute('Id') -eq $Id) {
                Write-Error "An Application with Id '$Id' already exists in the manifest."
                return $null
            }
        }

        $app = $xml.CreateElement('Application', $foundationNs)
        $app.SetAttribute('Id', $Id)
        $app.SetAttribute('Executable', $Executable)
        $app.SetAttribute('EntryPoint', $EntryPoint)

        $ve = $xml.CreateElement('uap:VisualElements', $uapNs)
        $ve.SetAttribute('BackgroundColor', 'transparent')
        $ve.SetAttribute('DisplayName', $DisplayName)
        $ve.SetAttribute('Square150x150Logo', $logo150)
        $ve.SetAttribute('Square44x44Logo',   $logo44)
        $ve.SetAttribute('Description',       $Description)

        $tile = $xml.CreateElement('uap:DefaultTile', $uapNs)
        $tile.SetAttribute('Wide310x150Logo',   $wide310)
        $tile.SetAttribute('Square310x310Logo', $logo310)
        $tile.SetAttribute('Square71x71Logo',   $logo71)
        $null = $ve.AppendChild($tile)

        $null = $app.AppendChild($ve)
        $null = $appsNode.AppendChild($app)

        $xml.Save($manifestPath)
        Write-Verbose "Added Application '$Id' (Executable=$Executable) to manifest"

        return [PSCustomObject]@{
            Id          = $Id
            DisplayName = $DisplayName
            Executable  = $Executable
            AssetId     = $AssetId
        }
    }
}
