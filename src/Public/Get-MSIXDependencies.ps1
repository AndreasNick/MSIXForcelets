function Get-MSIXDependencies {
<#
.SYNOPSIS
    Lists the PackageDependency entries declared in an expanded MSIX package's manifest.

.DESCRIPTION
    Reads the <Dependencies> section of AppxManifest.xml and returns one object
    per <PackageDependency> (framework dependency). The mandatory
    <TargetDeviceFamily> entry is intentionally NOT returned - it is not a
    removable framework reference.

    MSIX Packaging Tool captures often add framework dependencies that were
    present on the build machine but are unnecessary (or missing) on the target
    (e.g. Microsoft.WindowsAppRuntime.* pulled in by a co-installed component).
    A missing framework dependency makes Windows refuse to launch every app in
    the package. Pipe the results into Remove-MSIXDependencies to strip ones
    that are not actually needed.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder containing AppxManifest.xml.

.EXAMPLE
    Get-MSIXDependencies -MSIXFolder "C:\MSIXTemp\SSMS22"

.EXAMPLE
    Get-MSIXDependencies -MSIXFolder $pkg | Format-Table Name, MinVersion

.EXAMPLE
    # Remove a specific framework dependency
    Get-MSIXDependencies -MSIXFolder $pkg |
        Where-Object Name -like 'Microsoft.WindowsAppRuntime*' |
        Remove-MSIXDependencies

.OUTPUTS
    PSCustomObject with: Name, MinVersion, Publisher, MSIXFolderPath. The Name
    and MSIXFolderPath properties bind to Remove-MSIXDependencies via
    ValueFromPipelineByPropertyName.

.NOTES
    https://www.nick-it.de
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
