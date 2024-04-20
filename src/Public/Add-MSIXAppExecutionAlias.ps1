
function Add-MSIXAppExecutionAlias {
<#
.SYNOPSIS
Adds an App Execution Alias to an MSIX application.

.DESCRIPTION
The Add-MSIXAppExecutionAlias function adds an App Execution Alias to an MSIX application by modifying the AppxManifest.xml file.

.PARAMETER MSIXFolder
The path to the folder containing the expanded MSIX package.

.PARAMETER MISXAppID
The ID of the MSIX application.

.PARAMETER CommandlineAlias
The command line alias to be added.

.EXAMPLE
Add-MSIXAppExecutionAlias -MSIXFolder "C:\MyApp" -MISXAppID "MyAppID" -CommandlineAlias "myapp"
This example adds the command line alias "myapp" to the MSIX application with the ID "MyAppID" located in the "C:\MyApp" folder.
.NOTES
Author: Andreas Nick
Date: 01/10/2022
https://www.nick-it.de
#>

    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)] 
        [Alias('Id')] 
        [String] $MISXAppID,
        [Parameter(Mandatory = $true)]
        [String] $CommandlineAlias 
    )

    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            Write-Verbose "[ERROR] The MSIX temporary folder does not exist - skipping adding AppExecutionAlias"
        }
        else {
        
            $manifest = New-Object xml
            $manifest.Load("$MSIXFolder\AppxManifest.xml")
            $manifest = New-Object xml
            $nsmgr = New-Object System.Xml.XmlNamespaceManager $manifest.NameTable
            $AppXNamespaces.GetEnumerator() | ForEach-Object {
                $nsmgr.AddNamespace($_.key, $_.value)
            }

            $manifest.Load((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
            $appNode = $manifest.SelectSingleNode("//ns:Package/ns:Applications/ns:Application[@Id=" + "'" + $MISXAppID + "']", $nsmgr)
            if (-not $appNode) {
                Write-Verbose "[ERROR] Application does not exist - skipping adding AppExecutionAlias"
            }
            else {
                if (-not $appNode.extensions) {
                    #Create Extensions node
                    $ext = $manifest.CreateElement("Extensions", $AppXNamespaces['ns'])
                    $appNode.AppendChild($ext)
                }
                
                $aliasNode = $manifest.SelectSingleNode("//ns:Application[@Id=" + "'" + $MISXAppID + "']/ns:Extensions//uap3:Extension[@Category='windows.appExecutionAlias']", $nsmgr)
                if (-not $aliasNode) {
                    Write-Verbose "[INFORMATION] Trying to create ExecutionAlias $CommandlineAlias for: $MISXAppID"
                    #Create Alias Node
                    $extensionsNode = $manifest.SelectSingleNode("//ns:Application[@Id=" + "'" + $MISXAppID + "']/ns:Extensions", $nsmgr)
                    $extensionNode = $manifest.CreateElement("uap3:Extension", $AppXNamespaces['uap3'])
                    $extensionsNode.AppendChild($extensionNode)
                    $extensionNode.SetAttribute("Category", "windows.appExecutionAlias")
                    $aliasNode = $manifest.CreateElement("uap3:AppExecutionAlias", $AppXNamespaces['uap3'])
                    $extensionNode.AppendChild($aliasNode)
                    $executionAliasNode = $manifest.CreateElement("desktop:ExecutionAlias", $AppXNamespaces['desktop'])
                    $executionAliasNode.SetAttribute("Alias", $CommandlineAlias)
                    $aliasNode.AppendChild($executionAliasNode)
                }
                else {
                    Write-Verbose "[WARNING] An alias Node $CommandlineAlias already exists for $MISXAppID - skipping"
                }
            }
            $manifest.PreserveWhitespace = $false
            $manifest.Save((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
        }
    }
}
