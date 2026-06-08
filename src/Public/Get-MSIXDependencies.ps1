function Get-MSIXDependencies {
<#
.SYNOPSIS
    Lists PackageDependency entries in an MSIX manifest (TargetDeviceFamily excluded).
.PARAMETER MSIXFolder
    Expanded MSIX package folder (contains AppxManifest.xml).
.EXAMPLE
    Get-MSIXDependencies -MSIXFolder $pkg | Format-Table Name, MinVersion
.NOTES
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder
    )

    process {
        $manifestPath = Join-Path $MSIXFolder.FullName 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "The MSIX folder does not contain AppxManifest.xml: $($MSIXFolder.FullName)"
            return
        }

        $manifest = New-Object System.Xml.XmlDocument
        $manifest.Load($manifestPath)

        $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
        $null = $nsmgr.AddNamespace('default', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')

        $deps = $manifest.SelectNodes('//default:Package/default:Dependencies/default:PackageDependency', $nsmgr)
        foreach ($dep in $deps) {
            Write-Verbose "Found PackageDependency '$($dep.GetAttribute('Name'))'"
            [PSCustomObject]@{
                Name           = $dep.GetAttribute('Name')
                MinVersion     = $dep.GetAttribute('MinVersion')
                Publisher      = $dep.GetAttribute('Publisher')
                MSIXFolderPath = $MSIXFolder.FullName
            }
        }
    }
}
