function Get-MSIXApplications {
<#
.SYNOPSIS
    Retrieves the Application entries from an expanded MSIX package's manifest.

.DESCRIPTION
    Reads AppxManifest.xml from the specified expanded MSIX package folder and
    returns one object per Application entry, exposing Id, Executable, EntryPoint
    and the source folder. Designed to feed Set-MSIXApplicationVisualElements,
    Add-MSIXPSFShim and similar cmdlets via the pipeline.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder containing AppxManifest.xml.

.EXAMPLE
    Get-MSIXApplications -MSIXFolder "C:\MSIXTemp\App"

.EXAMPLE
    # Pipe into a manifest mutator
    Get-MSIXApplications -MSIXFolder $folder |
        Set-MSIXApplicationVisualElements -AssetId 'MyApp'

.OUTPUTS
    PSCustomObject with properties: Id, Executable, EntryPoint, MSIXFolderPath,
    UAP11WorkingDirectory, UAP11Parameters, Autostart, AutostartTaskId, AutostartDisplayName.
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

        $appxManifest = New-Object System.Xml.XmlDocument
        $appxManifest.Load($manifestPath)

        $nsmgr = New-Object System.Xml.XmlNamespaceManager($appxManifest.NameTable)
        $AppXNamespaces.GetEnumerator() | ForEach-Object { $null = $nsmgr.AddNamespace($_.Key, $_.Value) }
        $uap11Uri = $AppXNamespaces['uap11']

        $result = @()
        foreach ($app in $appxManifest.SelectNodes('//ns:Package/ns:Applications/ns:Application', $nsmgr)) {
            Write-Verbose "Found application $($app.GetAttribute('Id'))"

            $wd  = $app.GetAttribute('CurrentDirectoryPath', $uap11Uri)
            $par = $app.GetAttribute('Parameters', $uap11Uri)

            $startNode = $app.SelectSingleNode("ns:Extensions/desktop:Extension[@Category='windows.startupTask']/desktop:StartupTask", $nsmgr)

            $result += [PSCustomObject]@{
                Id                   = $app.GetAttribute('Id')
                Executable           = $app.GetAttribute('Executable')
                EntryPoint           = $app.GetAttribute('EntryPoint')
                MSIXFolderPath       = $MSIXFolder.FullName
                UAP11WorkingDirectory = if ($wd)  { $wd }  else { $null }
                UAP11Parameters       = if ($par) { $par } else { $null }
                Autostart            = ($null -ne $startNode -and $startNode.GetAttribute('Enabled') -eq 'true')
                AutostartTaskId      = if ($null -ne $startNode) { $startNode.GetAttribute('TaskId') } else { $null }
                AutostartDisplayName = if ($null -ne $startNode) { $startNode.GetAttribute('DisplayName') } else { $null }
            }
        }
        return $result
    }
}
