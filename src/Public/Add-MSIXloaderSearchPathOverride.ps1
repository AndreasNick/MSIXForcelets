function Add-MSIXloaderSearchPathOverride {
    <#
.SYNOPSIS
Adds a search path override to the LoaderSearchPathEntry element in the AppxManifest.xml file of an MSIX package.

.DESCRIPTION
The Add-MSIXloaderSearchPathOverride function adds a search path override to the LoaderSearchPathEntry element in the AppxManifest.xml file of an MSIX package. This allows the MSIX package to load dependencies from specified folder paths.

.PARAMETER MSIXFolderPath
Specifies the path to the folder containing the MSIX package.

.PARAMETER FolderPaths
Specifies an array of folder paths to be added as search paths in the LoaderSearchPathEntry element.

.EXAMPLE
Add-MSIXloaderSearchPathOverride -MSIXFolderPath "C:\MyMSIXPackage" -FolderPaths "libs", "plugins"

This example adds "libs" and "plugins" as search paths in the LoaderSearchPathEntry element of the AppxManifest.xml file located in the "C:\MyMSIXPackage" folder.

.EXAMPLE
Add-MSIXloaderSearchPathOverride -FolderPaths "Bin",'VFS\ProgramFilesX64\GIMP 3\bin','VFS\ProgramFilesX64\GIMP 2\bin' -MSIXFolderPath $MsixFolder

PROVEN WORKING EXAMPLE (GIMP): Use backslashes for VFS paths. Spaces in folder names
are written as-is (not URL-encoded). Multiple paths cover root-packaged and both
VFS variants (GIMP 2 and GIMP 3) in one call.

Author: Andreas Nick
Date: 01/10/2022
https://www.nick-it.de
#>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo] $MSIXFolderPath,
        [Parameter(Mandatory = $true)]
        [String[]] $FolderPaths,
        [Switch] $SaveManifestCopy
    )

    if (Test-Path "$MSIXFolderPath\AppxManifest.xml") {
    
        # Load existing manifest
        [xml]$manifest = Get-Content "$MSIXFolderPath\AppxManifest.xml"
    
        Add-MSIXManifestNamespace -Manifest $manifest -Prefixes 'uap6'

        # Create namespace manager
        $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
        $null = $nsmgr.AddNamespace("default", "http://schemas.microsoft.com/appx/manifest/foundation/windows10") 
        $null = $nsmgr.AddNamespace("uap6", "http://schemas.microsoft.com/appx/manifest/uap/windows10/6")
    
        # Check if LoaderSearchPathOverride exists
        if ($null -eq $manifest.SelectSingleNode("//uap6:LoaderSearchPathOverride", $nsmgr)) {
            
            $extensionsNode = $manifest.SelectSingleNode("//default:Package/default:Extensions", $nsmgr)
    
            if ($null -eq $extensionsNode) {
                # If Extensions node does not exist, create it
                $extensionsNode = $manifest.CreateElement("Extensions", $manifest.DocumentElement.NamespaceURI)

                # Insert the Extensions node before the Applications node (or at the right place in the hierarchy)
                $applicationsNode = $manifest.SelectSingleNode("//default:Package/default:Applications", $nsmgr)
                if ($null -ne $applicationsNode) {
                    [void]$manifest.DocumentElement.InsertAfter($extensionsNode, $applicationsNode)
                }
                else {
                    # In case Applications node is missing, just append Extensions at the root level
                    [void]$manifest.DocumentElement.AppendChild($extensionsNode)
                }
            }

            $extensionNode = $manifest.CreateElement("uap6:Extension", 'http://schemas.microsoft.com/appx/manifest/uap/windows10/6')
        
            # Set attributes and append nodes
            $categoryAttribute = $manifest.CreateAttribute("Category")
            $categoryAttribute.Value = 'windows.loaderSearchPathOverride'
            $null = $extensionNode.Attributes.Append($categoryAttribute)
        
            $loaderSearchPathOverrideNode = $manifest.CreateElement("uap6:LoaderSearchPathOverride", 'http://schemas.microsoft.com/appx/manifest/uap/windows10/6')
            foreach ($Item in $FolderPaths) {
                $entryNode = $manifest.CreateElement("uap6:LoaderSearchPathEntry", 'http://schemas.microsoft.com/appx/manifest/uap/windows10/6')
                $folderAttribute = $manifest.CreateAttribute("FolderPath")
                $folderAttribute.Value = ($Item -replace '/', '\')
                $null = $entryNode.Attributes.Append($folderAttribute)
                $null = $loaderSearchPathOverrideNode.AppendChild($entryNode)
            }
        
            # Append elements correctly
            $null = $extensionNode.AppendChild($loaderSearchPathOverrideNode)
            $null = $extensionsNode.AppendChild($extensionNode)
            #[void] $manifest.DocumentElement.AppendChild($extensionsNode)
        
            if ($SaveManifestCopy.IsPresent) {
                Write-Verbose "Creating backup of AppxManifest.xml"
                Rename-Item -Path "$MSIXFolderPath\AppxManifest.xml" -NewName "AppxManifest.xml.$(Get-Date -Format 'yyyymmdd-hhmmss')"
            }
        
            Write-Verbose "Saving modified AppxManifest.xml"
            $null = $manifest.Save("$MSIXFolderPath\AppxManifest.xml")
        }
        else {
            Write-Warning "Element Exists: Package.Extensions.Extension.LoaderSearchPathOverride.LoaderSearchPathEntry"
        }
    }
    else {
        Write-Warning "Cannot open path $($MSIXFolderPath)\AppxManifest.xml"
    }
}