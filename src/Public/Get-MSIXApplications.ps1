function Get-MSIXApplications {
<#
.SYNOPSIS
    Retrieves the Application entries from an expanded MSIX package's manifest.

.DESCRIPTION
    Reads AppxManifest.xml from the specified expanded MSIX package folder and
    returns one object per Application entry, exposing Id, Executable, EntryPoint
    and the source folder. Designed to feed Set-MSIXApplicationVisualElements,
    Add-MSXIXPSFShim and similar cmdlets via the pipeline.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder containing AppxManifest.xml.

.EXAMPLE
    Get-MSIXApplications -MSIXFolder "C:\MSIXTemp\App"

.EXAMPLE
    # Pipe into a manifest mutator
    Get-MSIXApplications -MSIXFolder $folder |
        Set-MSIXApplicationVisualElements -AssetId 'MyApp'

.OUTPUTS
    PSCustomObject with properties: Id, Executable, EntryPoint, MSIXFolderPath.
    The MSIXFolderPath property is named so it binds to the MSIXFolderPath
    parameter of downstream cmdlets via ValueFromPipelineByPropertyName.

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder
    )

    process {
        $manifestPath = Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"
        if (-not (Test-Path $manifestPath)) {
            Write-Error "The MSIX folder does not contain AppxManifest.xml: $($MSIXFolder.FullName)"
            return
        }

        $appxManifest = New-Object xml
        $appxManifest.Load($manifestPath)

        $result = @()
        foreach ($app in $appxManifest.Package.Applications.Application) {
            Write-Verbose "Found application $($app.Id)"
            $result += [PSCustomObject]@{
                Id             = $app.Id
                Executable     = $app.Executable
                EntryPoint     = $app.EntryPoint
                MSIXFolderPath = $MSIXFolder.FullName
            }
        }
        return $result
    }
}
