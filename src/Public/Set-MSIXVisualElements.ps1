
function Set-MSIXVisualElements {
<#
.SYNOPSIS
Sets the visual elements of an MSIX application.

.DESCRIPTION
The Set-MSIXVisualElements function is used to update the visual elements of an MSIX application specified by the ApplicationId. It modifies the AppxManifest.xml file located in the MSIXFolder to reflect the changes.

.PARAMETER MSIXFolder
Specifies the folder path where the MSIX application is located.

.PARAMETER ApplicationId
Specifies the unique identifier of the MSIX application.

.PARAMETER Description
Specifies the description of the MSIX application.

.PARAMETER AppListEntry
Specifies the AppListEntry value of the MSIX application. Valid values are 'default' or 'none'.

.PARAMETER Square150x150Logo
Specifies the path to the Square150x150Logo image file.

.PARAMETER Square44x44Logo
Specifies the path to the Square44x44Logo image file.

.PARAMETER Wide310x150Logo
Specifies the path to the Wide310x150Logo image file.

.PARAMETER Square310x310Logo
Specifies the path to the Square310x310Logo image file.

.PARAMETER Square71x71Logo
Specifies the path to the Square71x71Logo image file.

.PARAMETER BackgroundColor
Specifies the background color of the MSIX application. Valid values are 'transparent', 'aliceBlue', 'antiqueWhite', 'aqua', 'aquamarine', 'azure', 'beige', 'bisque', 'black', 'blanchedAlmond', 'blue', or 'red'.

.PARAMETER DisplayName
Specifies the display name of the MSIX application.

.EXAMPLE
Set-MSIXVisualElements -MSIXFolder "C:\MyApp" -ApplicationId "MyApp" -Description "My App Description" -AppListEntry "default" -Square150x150Logo "C:\MyApp\Logo.png" -BackgroundColor "blue" -DisplayName "My App"
This example sets the visual elements of the MSIX application located in "C:\MyApp". It updates the description, AppListEntry, Square150x150Logo, background color, and display name.

.NOTES
This function requires the AppxManifest.xml file to be present in the specified MSIXFolder. If the file does not exist, an error will be thrown.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'CommonParameters')]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Parameter(Mandatory = $true)]
        [string] $ApplicationId,

        [string] $Description,
        [ValidateSet('default', 'none')]
        [string] $AppListEntry,
        [string] $Square150x150Logo,
        [string] $Square44x44Logo,
        [string] $Wide310x150Logo,
        [string] $Square310x310Logo,
        [string] $Square71x71Logo,
        [ArgumentCompleter( {'transparent', 'aliceBlue', 'antiqueWhite', 'aqua', 'aquamarine', 'azure', 'beige', 'bisque', 'black', 'blanchedAlmond', 'blue', 'red'})]
        [string] $BackgroundColor,
        [string] $DisplayName
        )
    process {

        $ManifestPath = Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"
        if (-not (Test-Path $ManifestPath) ) {
            Write-Error "The MSIX temporary folder not exist"
            throw "The MSIX temporary folder not exist"
        }

        # Load the XML manifest file
        $manifestXml = [xml](Get-Content -Path $ManifestPath)
        $ns = New-Object System.Xml.XmlNamespaceManager($manifestXml.NameTable)
        $ns.AddNamespace('uap', 'http://schemas.microsoft.com/appx/manifest/uap/windows10')
        $ns.AddNamespace('def', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')

        # Find the application node
        $appNode = $manifestXml.SelectSingleNode("//def:Application[@Id='$ApplicationId']", $ns) 
        if ($null -eq $appNode) {
            throw "Application with Id $ApplicationId not found in the manifest."
        }

        # Update the visual elements if parameters are provided
        $visualElements = $appNode.SelectSingleNode("uap:VisualElements", $ns) 
        if ($null -eq $visualElements) {
            throw "VisualElements not found for the application $ApplicationId."
        }

        # Überprüfen, ob ein Wert für $AppListEntry bereitgestellt wurde
        if ($null -ne $AppListEntry) {
            # Setze oder aktualisiere den Wert des AppListEntry-Attributs
            $visualElements.SetAttribute('AppListEntry', $null, $AppListEntry)
        } 
        # Untested ....
        if ($null -ne $Description) { $visualElements.SetAttribute('Description', $null, $Description) }
        if ($null -ne $AppListEntry) { $visualElements.SetAttribute('AppListEntry', $null, $AppListEntry) }
        if ($null -ne $Square150x150Logo) { $visualElements.SetAttribute('Square150x150Logo', $null, $Square150x150Logo) }
        if ($null -ne $Square44x44Logo) { $visualElements.SetAttribute('Square44x44Logo', $null, $Square44x44Logo) }
        if ($null -ne $BackgroundColor) { $visualElements.SetAttribute('BackgroundColor', $null, $BackgroundColor) }
        if ($null -ne $DisplayName) { $visualElements.SetAttribute('DisplayName', $null, $DisplayName) }

        $defaultTile = $visualElements.SelectSingleNode("uap:DefaultTile", $ns)
        if ($null -ne $Wide310x150Logo) { $defaultTile.SetAttribute('Wide310x150Logo', $null, $Wide310x150Logo) }
        if ($null -ne $Square310x310Logo) { $defaultTile.SetAttribute('Square310x310Logo', $null, $Square310x310Logo) }
        if ($null -ne $Square71x71Logo) { $defaultTile.SetAttribute('Square71x71Logo', $null, $Square71x71Logo) }

        
        # Save the updated manifest
        $manifestXml.Save($ManifestPath)

        Write-Verbose "Visual elements updated successfully for application $ApplicationId."
    }
}
