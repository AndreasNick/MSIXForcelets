

function Add-MSIXloaderSearchPathOverride {
    <#
    .SYNOPSIS
    Adds a search path override to the LoaderSearchPathEntry element in the AppxManifest.xml file of an MSIX package.
    
    .DESCRIPTION
    The Add-MSIXloaderSearchPathOverride function adds a search path override to the LoaderSearchPathEntry element in the AppxManifest.xml file of an MSIX package. This allows the MSIX package to load dependencies from specified folder paths.
    
    .PARAMETER MSIXFolderPath
    Specifies the path to the folder containing the MSIX package. The default value is "$ENV:Temp\MSIXTempFolder".
    
    .PARAMETER FolderPaths
    Specifies an array of folder paths to be added as search paths in the LoaderSearchPathEntry element. The folder paths should be specified in the format "folder1/subfolder1".
    
    .EXAMPLE
    Add-MSIXloaderSearchPathOverride -MSIXFolderPath "C:\MyMSIXPackage" -FolderPaths "libs", "plugins"
    
    This example adds "libs" and "plugins" as search paths in the LoaderSearchPathEntry element of the AppxManifest.xml file located in the "C:\MyMSIXPackage" folder.
    
    .NOTES
    - The function checks if the AppxManifest.xml file exists in the specified MSIX folder path before making any modifications.
    - If the LoaderSearchPathEntry element already exists in the AppxManifest.xml file, a warning message is displayed and no modifications are made.
    Found in https://techcommunity.microsoft.com/t5/msix-deployment/msix-packaging-gimp/m-p/859797
    Search order in a msix package
    
    Author: Andreas Nick
    Date: 01/10/2022
    https://www.nick-it.de
    #>
        Param(
            [System.IO.DirectoryInfo] $MSIXFolderPath = "$ENV:Temp\MSIXTempFolder",
            [String []] $FolderPaths #Syntax "folder1/subfolder1"
        )
    
        if (Test-Path "$MSIXFolderPath\AppxManifest.xml" ) {
            
            $manifest = New-Object xml
            $manifest.Load("$MSIXFolderPath\AppxManifest.xml")
            
            if ($Manifest.Package.Extensions.Extension.LoaderSearchPathOverride.LoaderSearchPathEntry -eq $null) {
                $nsmgr = New-Object System.Xml.XmlNamespaceManager $manifest.NameTable
                $Rootelement = $manifest.CreateNode("element", "Extensions" , "http://schemas.microsoft.com/appx/manifest/foundation/windows10")
                $element = $manifest.CreateElement("uap6:Extension", 'http://schemas.microsoft.com/appx/manifest/uap/windows10/6')#,$nsmgr)
                $Rootelement.AppendChild($element)
                $attribute = $manifest.CreateAttribute("Category")
                $attribute.Value = 'windows.loaderSearchPathOverride'
                $element.Attributes.Append($attribute)
                $element = $element.AppendChild($manifest.CreateElement("uap6:LoaderSearchPathOverride", 'http://schemas.microsoft.com/appx/manifest/uap/windows10/6'))
                foreach ( $Item in $FolderPaths) {
                    $e = $manifest.CreateElement("uap6:LoaderSearchPathEntry", 'http://schemas.microsoft.com/appx/manifest/uap/windows10/6')
                    $a = $manifest.CreateAttribute("FolderPath")
                    $a.Value = $($Item -replace '\\', '/')
                    $e.Attributes.Append($a)
                    $element.AppendChild($e)
                }
            
                $manifest.Package.AppendChild($Rootelement)
                
                Rename-Item -Path "$MSIXFolderPath\AppxManifest.xml" -NewName "AppxManifest.xml.$(Get-Date -Format 'yyyymmdd-hhmmss')"
                $manifest.Save("$MSIXFolderPath\AppxManifest.xml")
            }
            else {
                Write-Warning "Element Exist: Package.Extensions.Extension.LoaderSearchPathOverride.LoaderSearchPathEntry"
            }
        }
        else {
            Write-Warning "Cannot open path $($MSIXFolderPath)\AppxManifest.xml" 
        }
    }