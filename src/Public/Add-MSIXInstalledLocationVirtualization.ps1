<#
.SYNOPSIS
Adds InstalledLocationVirtualization element to the AppxManifest.xml file in the specified MSIX folder path.

.DESCRIPTION
The Add-MSIXInstalledLocationVirtualization function modifies the AppxManifest.xml file located in the specified MSIX folder path by adding an InstalledLocationVirtualization element if it does not already exist. The function allows customization of the ModifiedItems, AddedItems, and DeletedItems attributes within the InstalledLocationVirtualization element.

.PARAMETER MSIXFolderPath
Specifies the path to the MSIX folder containing the AppxManifest.xml file. Defaults to "$ENV:Temp\MSIXTempFolder".

.PARAMETER ModifiedItems
Specifies the value for the ModifiedItems attribute within the InstalledLocationVirtualization element. Acceptable values are "keep" or "reset". Defaults to "keep".

.PARAMETER AddedItems
Specifies the value for the AddedItems attribute within the InstalledLocationVirtualization element. Acceptable values are "keep" or "reset". Defaults to "keep".

.PARAMETER DeletedItems
Specifies the value for the DeletedItems attribute within the InstalledLocationVirtualization element. Acceptable values are "keep" or "reset". Defaults to "keep".

.EXAMPLE
Add-MSIXInstalledLocationVirtualization -MSIXFolderPath "C:\MSIXFolder" -ModifiedItems "reset" -AddedItems "keep" -DeletedItems "reset"

This example modifies the AppxManifest.xml file in the "C:\MSIXFolder" directory, setting the ModifiedItems attribute to "reset", the AddedItems attribute to "keep", and the DeletedItems attribute to "reset".


.NOTES
https://learn.microsoft.com/en-us/uwp/schemas/appxpackage/uapmanifestschema/element-uap10-installedlocationvirtualization
Found in 
Author: Andreas Nick
Date: 01/10/2022
https://www.nick-it.de

#>
function Add-MSIXInstalledLocationVirtualization {
    [CmdletBinding()]
    Param(
        
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo] $MSIXFolderPath,
    
        [ValidateSet("keep", "reset")]
        [String] $ModifiedItems = "keep",
    
        [ValidateSet("keep", "reset")]
        [String] $AddedItems = "keep",
    
        [ValidateSet("keep", "reset")]
        [String] $DeletedItems = "keep",

        [Switch] $SaveManifestCopy
    )
  
    if (Test-Path "$MSIXFolderPath\AppxManifest.xml") {
        
        $manifest = New-Object xml
        $manifest.Load("$MSIXFolderPath\AppxManifest.xml")
        
        # Create and use the namespace manager
        $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
        $null = $nsmgr.AddNamespace("default", "http://schemas.microsoft.com/appx/manifest/foundation/windows10") 
        $null = $nsmgr.AddNamespace("uap10", "http://schemas.microsoft.com/appx/manifest/uap/windows10/10")
        
        if ($null -eq $manifest.SelectSingleNode("//uap10:InstalledLocationVirtualization", $nsmgr)) {
            
            <#
            # Ensure Extensions node exists
            $extensionsNode = $manifest.SelectSingleNode("//Extensions")
            if (-not $extensionsNode) {
                $extensionsNode = $manifest.CreateElement("Extensions", "http://schemas.microsoft.com/appx/manifest/foundation/windows10")
                $manifest.DocumentElement.AppendChild($extensionsNode)
            }
            #>
            $extensionsNode = $manifest.SelectSingleNode("//default:Package/default:Extensions", $nsmgr)
    
            if ($extensionsNode -eq $null) {
                # If Extensions node does not exist, create it
                $extensionsNode = $manifest.CreateElement("Extensions", $manifest.DocumentElement.NamespaceURI)
                
                # Insert the Extensions node before the Applications node (or at the right place in the hierarchy)
                $applicationsNode = $manifest.SelectSingleNode("//default:Package/default:Applications", $nsmgr)
                if ($applicationsNode -ne $null) {
                    [void]$manifest.DocumentElement.InsertAfter($extensionsNode, $applicationsNode)
                }
                else {
                    # In case Applications node is missing, just append Extensions at the root level
                    [void]$manifest.DocumentElement.AppendChild($extensionsNode)
                }
            }
            
            # Create Extension node
            $extensionElement = $manifest.CreateElement("uap10:Extension", 'http://schemas.microsoft.com/appx/manifest/uap/windows10/10')
            $null = $extensionsNode.AppendChild($extensionElement)

            # Attribut für die Extension
            $CategoryAttribute = $manifest.CreateAttribute("Category")
            $CategoryAttribute.Value = 'windows.installedLocationVirtualization'
            $null = $ExtensionElement.Attributes.Append($CategoryAttribute)
        
            # uap10:InstalledLocationVirtualization Element
            $InstalledLocationVirtualizationElement = $manifest.CreateElement("uap10:InstalledLocationVirtualization", 'http://schemas.microsoft.com/appx/manifest/uap/windows10/10')
            $null = $ExtensionElement.AppendChild($InstalledLocationVirtualizationElement)
        
            # uap10:UpdateActions Element
            $UpdateActionsElement = $manifest.CreateElement("uap10:UpdateActions", 'http://schemas.microsoft.com/appx/manifest/uap/windows10/10')
        
            # Attribute für UpdateActions
            $ModifiedItemsAttribute = $manifest.CreateAttribute("ModifiedItems")
            $ModifiedItemsAttribute.Value = $ModifiedItems
            $null = $UpdateActionsElement.Attributes.Append($ModifiedItemsAttribute)
        
            $AddedItemsAttribute = $manifest.CreateAttribute("AddedItems")
            $AddedItemsAttribute.Value = $AddedItems
            $null = $UpdateActionsElement.Attributes.Append($AddedItemsAttribute)
        
            $DeletedItemsAttribute = $manifest.CreateAttribute("DeletedItems")
            $DeletedItemsAttribute.Value = $DeletedItems
            $null = $UpdateActionsElement.Attributes.Append($DeletedItemsAttribute)
        
            $null = $InstalledLocationVirtualizationElement.AppendChild($UpdateActionsElement)
        
            #$manifest.Package.AppendChild($ExtensionsElement)

            if ($SaveManifestCopy.IsPresent) {
                Write-Verbose "Creating backup of AppxManifest.xml"
                Rename-Item -Path "$MSIXFolderPath\AppxManifest.xml" -NewName "AppxManifest.xml.$(Get-Date -Format 'yyyymmdd-hhmmss')"
            }

            # Save the modified AppxManifest.xml file
            $null = $manifest.Save("$MSIXFolderPath\AppxManifest.xml")
        }
        else {
            Write-Warning "Element Exist: Package.Extensions.Extension.InstalledLocationVirtualization"
        }
    }
    else {
        Write-Warning "Cannot open path: $($MSIXFolderPath)\AppxManifest.xml"
    }
}