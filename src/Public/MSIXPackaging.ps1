
function Get-MSIXPSFFrameworkPath {
    $Script:MSIXPSFPath
}

function Get-MSIXToolkitPath {
    $Script:MSIXToolkitPath
}

  

function New-MSIXPackage {
    param (
        [String] $MSIXFileNamePath,
        $TempFolder = "$ENV:Temp\MSIXTempFolder"
    )

    if (!(Test-Path $TempFolder )) {
        Write-Error "Packagefolder $TempFolder not exist" 

    }
    else {
        makeappx pack /d $TempFolder /p $MSIXFileNamePath
    }
}

<<<<<<< HEAD


#
#Start the msix application over the commandline
#

function Add-MSIXAppExecutionAlias {
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
            Write-Verbose "[ERROR] The MSIX temporary folder not exist - skip addming AppExecutionAlias"
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
                Write-Verbose "[ERROR] Application not exist - skip addming AppExecutionAlias"
            }
            else {
                if (-not $appNode.extensions) {
                    #Create Extensions node
                    $ext = $manifest.CreateElement("Extensions", $AppXNamespaces['ns'])
                    $appNode.AppendChild($ext)
                }
                
                $aliasNode = $manifest.SelectSingleNode("//ns:Application[@Id=" + "'" + $MISXAppID + "']/ns:Extensions//uap3:Extension[@Category='windows.appExecutionAlias']", $nsmgr)
                if (-not $aliasNode) {
                    Write-Verbose "[INFORMATION] Tray to create ExecutionAlias $CommandlineAlias for: $MISXAppID"
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
                    Write-Verbose "[WARNING] An alias Node $CommandlineAlias exist for $MISXAppID - skip"
                }
            }
            $manifest.PreserveWhitespace = $false
            $manifest.Save((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
        }
    }
}

#
# 
# ###############>>>>>>>>>>>>>>>>> ToDo <<<<<<<<<<<<<<<<<<<
# 
# 

function Add-MSIXFirewallRule
{
<#
    <Extensions>
    <desktop2:Extension Category="windows.firewallRules">
      <desktop2:FirewallRules Executable="sample.exe">
        <desktop2:Rule Direction="in" IPProtocol="TCP" LocalPortMax="4810" LocalPortMin="4810" Profile="all"/>
      </desktop2:FirewallRules>
    </desktop2:Extension>
    </Extensions>
#>
}





# From https://stackoverflow.com/questions/42636510/convert-multiple-xmls-to-json-list
# Use 
#   [xml]$var = Get-Content file.xml
# Convert to JSON with 
#   $var | ConvertFrom-XML | ConvertTo-JSON -Depth 3

# Helper function that converts a *simple* XML document to a nested hashtable
# with ordered keys.
function ConvertFrom-Xml {
    param([parameter(Mandatory, ValueFromPipeline)] [System.Xml.XmlNode] $node)
    process {
        if ($node.DocumentElement) { $node = $node.DocumentElement }
        $oht = [ordered] @{}
        $name = $node.Name
        if ($node.FirstChild -is [system.xml.xmltext]) {
            $oht.$name = $node.FirstChild.InnerText
        }
        else {
            $oht.$name = New-Object System.Collections.ArrayList 
            foreach ($child in $node.ChildNodes) {
                $null = $oht.$name.Add((ConvertFrom-Xml $child))
            }
        }
        $oht
    }
}







function Open-MSIXPackage {
    <#
.SYNOPSIS
Opens an MSIX package and unpacks its contents to a specified folder.

.DESCRIPTION
The Open-MSIXPackage function opens an MSIX package and unpacks its contents to a specified folder. It supports various options such as encryption, decryption, validation, and verbose output.

.PARAMETER MsixFile
Specifies the MSIX package file to be opened. This parameter is mandatory.

.PARAMETER MSIXFolder
Specifies the folder where the contents of the MSIX package will be unpacked. If not specified, a temporary folder will be created.

.PARAMETER ClearOutputFolder
Specifies whether to clear the output folder before unpacking the MSIX package. By default, the existing files in the output folder will not be cleared.

.PARAMETER Force
Specifies whether to force the creation of the output folder if it does not exist. By default, the output folder will be created only if it does not exist.

.EXAMPLE
$MSIXExpandedFolder = Open-MSIXPackage -MsixFile "C:\Path\To\Package.msix" -MSIXFolder "C:\Output\Folder" -ClearOutputFolder -Force
This example opens the specified MSIX package and unpacks its contents to the specified output folder. It clears the output folder before unpacking and forces the creation of the output folder if it does not exist.
.NOTES
Author: Andreas Nick
https://www.nick-it.de
#>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.FileInfo]
        $MsixFile,
        [System.IO.DirectoryInfo] $MSIXFolder = ($env:Temp + "\MSIX_TEMP_" + [system.guid]::NewGuid().ToString()),
        [bool] $ClearOutputFolder = $false,
        [Switch] $Force
    )
     
    process {
        if (-not (Test-Path $MsixFile )) {
            Write-Warning "the  file $($MsixFile.FullName) not exist"
        }

        if ((Test-Path $MSIXFolder) -and $ClearOutputFolder) {
            #Check there is an AppxManifest
            if (Test-Path (Join-Path -Path $MSIXFolder -ChildPath AppxManifest.xml)) {
                Remove-Item -Path $MSIXFolder -Recurse -Force
            }
        }

        if (-not (Test-Path $MSIXFolder)) {
            Write-Verbose "Force status: $($Force) creating folder $($MSIXFolder.FullName)"
            New-Item $MSIXFolder -ItemType Directory -force:$Force | Out-Null
        }

        <#
        Options:
        --------
            /pfn: Unpacks all files to a subdirectory under the specified output path,
                named after the package full name.
            /nv, /noValidation: Skips validation that ensures the package will be
                installable on Windows. The validation include: existence of files
                referenced in manifest, ContentGroupMap correctness, and additional
                manifest validation on Protocols and FileTypeAssociation. By default,
                all semantic validation is performed.
            /kf: Use this option to encrypt or decrypt the package or bundle using a
                key file. This option cannot be combined with /kt.
            /kt: Use this option to encrypt or decrypt the package or bundle using the
                global test key. This option cannot be combined with /kf.
            /nd: Skips decryption when unpacking an encrypted package or bundle.
            /o, /overwrite: Forces the output to overwrite any existing files with the
                same name. By default, the user is asked whether to overwrite existing
                files with the same name. You can't use this option with /no.
            /no, /noOverwrite: Prevents the output from overwriting any existing files
                with the same name. By default, the user is asked whether to overwrite
                existing files with the same name. You can't use this option with /o.
            /v, /verbose: Enables verbose output of messages to the console.
          
        #>      
        MakeAppx unpack -o -p $($MsixFile.FullName) -d $($MSIXFolder.FullName) | Out-Default
        if ($lastexitcode -ne 0) {

            Write-Error "ERROR: MSIX Cannot open Package"
            Return $Null
        }

        return $MSIXFolder
    }
=======


#
# 
# ###############>>>>>>>>>>>>>>>>> ToDo <<<<<<<<<<<<<<<<<<<
# 
# 

function Add-MSIXFirewallRule
{
<#
    <Extensions>
    <desktop2:Extension Category="windows.firewallRules">
      <desktop2:FirewallRules Executable="sample.exe">
        <desktop2:Rule Direction="in" IPProtocol="TCP" LocalPortMax="4810" LocalPortMin="4810" Profile="all"/>
      </desktop2:FirewallRules>
    </desktop2:Extension>
    </Extensions>
#>
>>>>>>> e62f2928578ea05159492fe447f94c528234072b
}



<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    Example of how to use this cmdlet
.EXAMPLE
    Another example of how to use this cmdlet
#>
function Test-Signature {
<<<<<<< HEAD
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.FileInfo] $MSIXFile
    )
    
    process {
        (Get-AuthenticodeSignature $MSIXFile.FullName).Status -eq "NotSigned"    
    }
    
    end {
    }
}





function Get-MSIXApplications {
=======
>>>>>>> e62f2928578ea05159492fe447f94c528234072b
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.FileInfo] $MSIXFile
    )
    
    process {
        (Get-AuthenticodeSignature $MSIXFile.FullName).Status -eq "NotSigned"    
    }
    
    end {
    }
}





function Start-MSIXPSFMonitor{
    param(
        [ValidateSet('64', '32')]
        $Architektur = '64'
    )

    #$Path = Join-Path -Path $ScriptPath -ChildPath $($Script:PsfBBasePath + '\PSFMonitor')
    Start-Process $($Script:PsfBBasePath + '\PsfMonitorx' + $Architektur + '.exe')
    
}


function Remove-MSIXApplications {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            #ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)] 
        [Alias('Id')] 
        [String] $MISXAppID
    )

    begin {
    }

    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            Write-Error "[ERROR] The MSIX temporary folder not exist"
            return $null
        }
        else {

            Write-Verbose "[INFORMATION] Remove MSIX Application $MISXAppID"
            $AppxManigest = New-Object xml
            $AppxManigest.Load((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
        
            $ns = New-Object System.Xml.XmlNamespaceManager $AppxManigest.NameTable 
            $ns.AddNamespace("ns", 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
            $node = $AppxManigest.SelectSingleNode($("//ns:Application[@Id=" + "'" + $MISXAppID + "']"), $ns)
            if ($node) {
                $node.ParentNode.RemoveChild($node) | out-null

                #Save config
                $AppxManigest.PreserveWhiteSpace = $false
                $AppxManigest.Save((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
            }
            else {
                Write-Verbose "[INFORMATION] Remove MSIX Application $MISXAppID"
            }
        }

    }
}


function Backup-MSIXManifest {

    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            #ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [String] $BackupFilename = $((get-date -Format "yyyymmdd-MM-ss") + '_' + 'AppXManifest.xml')
    )
 
    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            Write-Error "The MSIX temporary folder not exist"
            return $null
        }
        else {
            Copy-Item -Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") -Destination (Join-Path $MSIXFolder -ChildPath $BackupFilename)
        }
    }
}


#Formatet output over a filestream
# From: https://stackoverflow.com/questions/39267485/formatting-xml-from-powershell/39271782
function Format-XML {
    [CmdletBinding()]
    Param ([Parameter(ValueFromPipeline = $true, Mandatory = $true)][xml] $xmldoc)
    #$xmldoc = New-Object -TypeName System.Xml.XmlDocument
    #$xmldoc.LoadXml($xmlcontent)
    $sw = New-Object System.IO.StringWriter
    $writer = New-Object System.Xml.XmlTextwriter($sw)
    $writer.Formatting = [System.XML.Formatting]::Indented
    $xmldoc.WriteContentTo($writer)
    $sw.ToString()
}

function Add-MSIXPSFPowerShellScript {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)] 
        [Alias('Id')] 
        [String] $MISXAppID,
        [Parameter(Mandatory = $true, ParameterSetName = 'StartScript')]
        [switch] $StartScript,
        [Parameter(Mandatory = $true, ParameterSetName = 'EndScript')]
        [switch] $EndScript,
        [Parameter(Mandatory = $true)]
        [ArgumentCompleter( { 'Startscript.ps1', 'Endscript.ps1' })]
        [String]$ScriptPath, 
        [ArgumentCompleter( { '%MsixWritablePackageRoot%\\VFS\LocalAppData\\Vendor' })]
        [String] $ScriptArguments, 
        [ArgumentCompleter( { '-ExecutionPolicy Bypass' })]
        [String] $ScriptExecutionMode,
        [switch] $StopOnScriptError,
        [switch] $RunOnce,
        [switch] $ShowWindow,
        [Parameter(ParameterSetName = 'StartScript')]
        [switch] $WaitForScriptToFinish,
        [Parameter(ParameterSetName = 'StartScript')]
        [int] $ScriptTimeout = -1
    )

    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "config.json.xml") )) {
            Write-Warning "[ERROR] The MSIX config.json.xml not exist"
            return $null
        }
        else {
            $conxml = New-Object xml
            $conxml.Load((Join-Path $MSIXFolder -ChildPath "config.json.xml"))
            $appNode = $conxml.SelectSingleNode('//application/id[text()' + "='" + $MISXAppID + "']")
            

            if ($null -eq $appNode) {
                Write-Warning "[ERROR] The application not exist in MSIX config.json.xml - skip"
                return $null
            }
            else {
                <#
                "stopOnScriptError": false,
                "scriptExecutionMode": "-ExecutionPolicy Bypass",
                "startScript":
                {
                  "waitForScriptToFinish": true,
                  "timeout": 30000,
                  "runOnce": true,
                  "showWindow": false,
                  "scriptPath": "PackageStartScript.ps1",
                  "waitForScriptToFinish": true
                  "scriptArguments": "%MsixWritablePackageRoot%\\VFS\LocalAppData\\Vendor",
                },
                "endScript":
                {
                  "scriptPath": "\\server\scriptshare\\RunMeAfter.ps1",
                  "scriptArguments": "ThisIsMe.txt"
                }
                #>
                $m = $null

                if ($ScriptExecutionMode -ne "") {
                    $em = $conxml.SelectSingleNode('//application/id[text()' + "='" + $MISXAppID + "']/../scriptExecutionMode")
                    if ($em) {
                        $em.InnerText = $ScriptExecutionMode
                    }
                    else {
                        $em = $conxml.CreateElement("scriptExecutionMode") 
                        
                        $appNode.ParentNode.AppendChild($em)
                        $em.InnerText = $ScriptExecutionMode
                        $appNode.ParentNode.AppendChild($em)
                    }
                }
                if ($StopOnScriptError.IsPresent) {
                    $em = $conxml.SelectSingleNode('//application/id[text()' + "='" + $MISXAppID + "']/../stopOnScriptError")
                    if ($em) {
                        $em.InnerText = $StopOnScriptError.ToString().ToLower()
                    }
                    else {
                        $em = $conxml.CreateElement("stopOnScriptError") 
                        $em.InnerText = $StopOnScriptError.ToString().ToLower()
                        $appNode.ParentNode.AppendChild($em)
                    }
                }
                else {
                    $em = $conxml.SelectSingleNode('//application/id[text()' + "='" + $MISXAppID + "']/../stopOnScriptError")
                    if ($em) {
                        Write-Verbose "[INFORMATION] Remove stopOnScriptError node for $MISXAppID"
                        $em.ParentNode.RemoveChild($em)
                    }
                }

                if ($StartScript.IsPresent) {
                    if ($conxml.SelectSingleNode('//application/id[text()' + "='" + $MISXAppID + "']/../startScript")) {
                        Write-Warning "[WARNING] A start script for $MISXAppID already exist. Please remove it first"
                    }
                    else {
                        $m = $conxml.CreateElement("startScript") 
                    }
                }

                if ($EndScript.IsPresent) {
                    if ($conxml.SelectSingleNode('//application/id[text()' + "='" + $MISXAppID + "']/../endScript")) {
                        Write-Warning "[WARNING] A end script for $MISXAppID already exist. Please remove it first"
                    }
                    else {
                        $m = $conxml.CreateElement("endScript") 
                    }
                }

                if ($m) {
                    if ($ScriptTimeout -ge 0) {
                        $to = $conxml.CreateElement("timeout")
                        $to.InnerText = $ScriptTimeout
                        $m.AppendChild($to) | Out-Null
                    }

                    if ($WaitForScriptToFinish.IsPresent) {
                        $wa = $conxml.CreateElement("waitForScriptToFinish")
                        $wa.InnerText = $WaitForScriptToFinish.ToString().ToLower()
                        $m.AppendChild($wa) | Out-Null
                    }

                    if ($ShowWindow.IsPresent) {
                        $sw = $conxml.CreateElement("showWindow")
                        $sw.InnerText = $ShowWindow.ToString().ToLower()
                        $m.AppendChild($sw) | Out-Null
                    }

                    if ($RunOnce.IsPresent) {
                        $sw = $conxml.CreateElement("runOnce")
                        $sw.InnerText = $RunOnce.ToString().ToLower()
                        $m.AppendChild($sw) | Out-Null
                    }

                    if ($ScriptArguments -ne "") {
                        $sw = $conxml.CreateElement("scriptArguments")
                        $sw.InnerText = $ScriptArguments
                        $m.AppendChild($sw) | Out-Null
                    }   

                    $sp = $conxml.CreateElement("scriptPath")
                    $sp.InnerText = $ScriptPath
                    $m.AppendChild($sp) | Out-Null

                    $appNode.ParentNode.AppendChild($m)
                    $conxml.PreserveWhiteSpace = $false
                    $conxml.Save((Join-Path $MSIXFolder -ChildPath "config.json.xml"))
                }
            }
        }
    }
}

function Copy-ToMSIXPackage {

    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 2)]
        [string] $Path,
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 3)]
        [ArgumentCompleter( { 'VFS\LocalAppData\Vendor\MyScript.ps1', 'MyScript.ps1' })]
        [string] $DestinaltionRootRelative,
        [switch] $Force
    )

    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "config.json.xml") )) {
            Write-Warning "[ERROR] The MSIX config.json.xml not exist. Cannot copy file $Path"
            return $null
        }
        else {
            Copy-Item -Path $Path -Destination (Join-Path $MSIXFolder -ChildPath  $DestinaltionRootRelative) -Force:$Force
        }

    }
}



function Add-MSIXPSFFileRedirectionFixup {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 1)] 
        [String] $Executable, #Process name as "Regex": "MSEDGE" od "MSEdge$", we don't need a path!
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 3, ParameterSetName = 'KnownFolders')]
        [ArgumentCompleter( { $SystemKnownFolders.Keys })]
        [string] $KnownFolder,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 3, ParameterSetName = 'PackageRelative')]
        [switch] $PackageRelative,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 3, ParameterSetName = 'PackageDriveRelative')]
        [switch] $PackageDriveRelative,
        [Parameter(ParameterSetName = 'PackageRelative')]
        [Parameter(ParameterSetName = 'PackageDriveRelative')]
        [Parameter(ParameterSetName = 'KnownFolders')]
        [ArgumentCompleter( { 'Contoso\\config', 'VFS\\ProgramFilesX86\\this\\config' })]
        [string] $Base = "",
        [Parameter(ParameterSetName = 'PackageRelative')]
        [Parameter(ParameterSetName = 'PackageDriveRelative')]
        [Parameter(ParameterSetName = 'KnownFolders')]
        [ArgumentCompleter( { "'.*\\.txt'", "'.*\\.log'", "'.*\\.ini'", "'.*'", "@('.*\\.[eE][xX][eE]$', '.*\\.[dD][lL][lL]$', '.*\\.[tT][lL][bB]$', '.*\\.[cC][oO][mM]$')" })]
        [String[]] $Patterns,
        [Parameter(ParameterSetName = 'PackageRelative')]
        [Parameter(ParameterSetName = 'PackageDriveRelative')]
        [Parameter(ParameterSetName = 'KnownFolders')]
        [ArgumentCompleter( { "'H:'", "'H:\\MyApp\\'", "'g:\\temp\\'" })]
        [string] $RedirectTargetBase, #Optional "H:\"
        [Parameter(ParameterSetName = 'PackageRelative')]
        [Parameter(ParameterSetName = 'PackageDriveRelative')]
        [Parameter(ParameterSetName = 'KnownFolders')]
        [switch] $IsExclusion,
        [Parameter(ParameterSetName = 'PackageRelative')]
        [Parameter(ParameterSetName = 'PackageDriveRelative')]
        [Parameter(ParameterSetName = 'KnownFolders')]
        [switch] $IsReadOnly,
        [Parameter(ParameterSetName = 'KnownFolders')]
        [switch] $UseGUID
    )

    #<processes>
    #<process>
    #<executable>PsfLauncher.*</executable>
    #</process>
    #<process>
    #<executable>.*</executable>
    #<fixups>

    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "config.json.xml") )) {
            Write-Warning "[ERROR] The MSIX config.json.xml not exist"
            return $null
        }
        else {
            $conxml = New-Object xml
            $conxml.Load((Join-Path $MSIXFolder -ChildPath "config.json.xml"))
            if (-not $conxml.SelectSingleNode('//processes')) {
                Write-Verbose "[INFORMATION] Create processes node"
                $processes = $conxml.CreateElement("processes")
                $conxml.configuration.AppendChild($processes) | Out-Null
            }

            $appNode = $conxml.SelectSingleNode('//processes/process/executable[text()' + "='" + $Executable + "']")
            if (-not $appNode) {
                #Create Executable node
                Write-Verbose "[INFORMATION] Processs node for $Executable not exist create the process node"
                [System.Xml.XmlElement] $proc = $conxml.CreateElement("process")
                $exec = $conxml.CreateElement("executable")
                $exec.InnerText = $Executable
                $proc.AppendChild($exec) | Out-Null
                ($conxml.SelectSingleNode('//processes')).AppendChild($proc) | Out-Null
            } 
            $appNode = $conxml.SelectSingleNode('//processes/process/executable[text()' + "='" + $Executable + "']")
            if (-not $appNode.ParentNode.fixups) {
                Write-Verbose "[INFORMATION] Create Fixup Element for node  $Executable"
                $fixups = $conxml.CreateElement("fixups")
                $appNode.ParentNode.AppendChild($fixups)  | Out-Null
            }

            $fixupNode = $conxml.SelectSingleNode('//fixups/fixup/dll[text()' + "='FileRedirectionFixup.dll']")
            if (-not $fixupNode) {
                Write-Verbose "[INFORMATION] Create fixup FileRedirectionFixup.dll Element for node  $Executable"
                $fixup = $conxml.CreateElement("fixup")
                #$appNode.ParentNode.SelectNodes('fixups').AppendChild($fixup)  | Out-Null
                $dll = $conxml.CreateElement("dll")
                $dll.InnerText = 'FileRedirectionFixup.dll'
                $fixup.AppendChild($dll)
                $Config = $conxml.CreateElement("config")
                $fixup.AppendChild($config)

                $rp = $conxml.CreateElement("redirectedPaths")
                $Config.AppendChild($rp)
                $appNode.ParentNode.SelectNodes('fixups').AppendChild( $fixup)  | Out-Null
            }

            $elementPathConfig = $conxml.CreateElement("pathConfig")
            $elementBase = $conxml.CreateElement("base")
            if ($Base) {
                $elementBase.InnerText = $Base
            }
            $elementPatterns = $conxml.CreateElement("patterns")

            foreach ($pat in $Patterns) {
                $elementPat = $conxml.CreateElement("pattern")
                $elementPat.InnerText = $pat
                $elementPatterns.AppendChild($elementPat) | Out-Null
            }

            #Exist or empty 
           
            #$relativeNode = $conxml.SelectSingleNode('//packageRelative/pathConfig/base[text()' + "='" + $Base + "']|//packageRelative/pathConfig/base[not(text())]")
            #$relativeNode = $conxml.SelectSingleNode('//packageRelative/pathConfig/base[text()' + "='" + $Base + "']
            # More then one entry are allowed!
  
            if ($PackageRelative) {
                Write-Verbose "[INFORMATION] Create node packageRelative "
                #<pathConfig>
                #<base/>
                #<patterns>
                #<pattern>.*\\.txt</pattern>
                #<pattern>Tèƨƭ.*</pattern>
                #</patterns>
                #</pathConfig>
                Write-Verbose "[INFORMATION] Create PackageRelative element for node  $Executable"
                $fixupNode = $conxml.SelectSingleNode('//fixups/fixup/dll[text()' + "='FileRedirectionFixup.dll']")

                #$elementPackageRelative =  $conxml.SelectSingleNode('//config/redirectedPaths/packageRelative')
                #if(-not $elementPackageRelative) {
                $elementPackageRelative = $conxml.CreateElement("packageRelative")
                #}
                $elementPackageRelative.AppendChild($elementPathConfig) | Out-Null

                    
                $elementPathConfig.AppendChild($elementBase) | Out-Null
                $elementPathConfig.AppendChild($elementPatterns) | Out-Null


                if ($IsExclusion) {
                    $elementisExclusion = $conxml.CreateElement("isExclusion")
                    $elementisExclusion.InnerText = "true"
                    $elementPathConfig.AppendChild($elementisExclusion) | Out-Null
                }
                if ($IsReadOnly) {
                    $elementisReadOnly = $conxml.CreateElement("isReadOnly")
                    $elementisReadOnly.InnerText = "true"
                    $elementPathConfig.AppendChild($elementisReadOnly) | Out-Null
                }

                if ($RedirectTargetBase) {
                    $elementisRedirectTargetBase = $conxml.CreateElement("redirectTargetBase")
                    $elementisRedirectTargetBase.InnerText = $RedirectTargetBase
                    $elementPathConfig.AppendChild($elementisRedirectTargetBase) | Out-Null
                }


                $fixupNode.ParentNode.SelectNodes('config/redirectedPaths').AppendChild($elementPackageRelative) | Out-Null
            }
  
            if ($PackageDriveRelative) {
                #<pathConfig>
                #<base/>
                #<patterns>
                #<pattern>.*\\.txt</pattern>
                #<pattern>Tèƨƭ.*</pattern>
                #</patterns>
                #</pathConfig>
                Write-Verbose "[INFORMATION] Create packageDriveRelative element for node  $Executable"
                $fixupNode = $conxml.SelectSingleNode('//fixups/fixup/dll[text()' + "='FileRedirectionFixup.dll']")

                #$elementPackageRelative =  $conxml.SelectSingleNode('//config/redirectedPaths/packageRelative')
                #if(-not $elementPackageRelative) {
                $elementPackageDriveRelative = $conxml.CreateElement("packageDriveRelative")
                #}
                $elementPackageDriveRelative.AppendChild($elementPathConfig) | Out-Null

                    
                $elementPathConfig.AppendChild($elementBase) | Out-Null
                $elementPathConfig.AppendChild($elementPatterns) | Out-Null


                if ($IsExclusion) {
                    $elementisExclusion = $conxml.CreateElement("isExclusion")
                    $elementisExclusion.InnerText = "true"
                    $elementPathConfig.AppendChild($elementisExclusion) | Out-Null
                }
                if ($IsReadOnly) {
                    $elementisReadOnly = $conxml.CreateElement("isReadOnly")
                    $elementisReadOnly.InnerText = "true"
                    $elementPathConfig.AppendChild($elementisReadOnly) | Out-Null
                }

                if ($RedirectTargetBase) {
                    $elementisRedirectTargetBase = $conxml.CreateElement("redirectTargetBase")
                    $elementisRedirectTargetBase.InnerText = $RedirectTargetBase
                    $elementPathConfig.AppendChild($elementisRedirectTargetBase) | Out-Null
                }


                $fixupNode.ParentNode.SelectNodes('config/redirectedPaths').AppendChild($elementPackageDriveRelative) | Out-Null
            }

            if ($KnownFolder) {
                <#
                <knownFolders>
                <knownFolder>
                    <id>ProgramFilesX64</id>
                    <relativePaths>
                        <relativePath>
                            <base>Contoso\\config</base>
                            <patterns>
                                <pattern>.*</pattern>
                            </patterns>
                        </relativePath>
                    </relativePaths>
                </knownFolder>
                </knownFolders>
                #>
                Write-Verbose "[INFORMATION] Create knownFoldere element for node  $Executable"
                $fixupNode = $conxml.SelectSingleNode('//fixups/fixup/dll[text()' + "='FileRedirectionFixup.dll']")

                $knownFoldersElement = $conxml.SelectSingleNode('//config/redirectedPaths/knownFolders')
                
                if(-not($knownFoldersElement)){
                    $knownFoldersElement = $conxml.CreateElement("knownFolders")
                    $null = $fixupNode.ParentNode.SelectNodes('//config/redirectedPaths').AppendChild($knownFoldersElement ) 
                }


               

                #Exist known Folder Element?
                $relativePathsElement = $null
                if($UseGUID){
                  $relativePathsElement = $conxml.SelectSingleNode('//config/redirectedPaths/knownFolders/knownFolder/id[text()="{' +  $SystemKnownFolders[$KnownFolder] + '}"]/../relativePaths')
                } else {
                  $relativePathsElement = $conxml.SelectSingleNode('//config/redirectedPaths/knownFolders/knownFolder/id[text()="' + $KnownFolder + '"]/../relativePaths')
                }
                
                
                if (-not $relativePathsElement) {
                    #Create KnownFolder Element
                    $knownFolderElement = $conxml.CreateElement("knownFolder")
                    $idElement = $conxml.CreateElement("id")
                    #
                    if($UseGUID){
                        $idElement.InnerText = $('{' +  $SystemKnownFolders[$KnownFolder] + '}')
                    } else {
                        $idElement.InnerText = $KnownFolder
                    }
                    $knownFolderElement.AppendChild($idElement) | Out-Null
                    $relativePathsElement = $conxml.CreateElement("relativePaths")
                    $knownFolderElement.AppendChild($relativePathsElement) | Out-Null
                    $knownFoldersElement.AppendChild($knownFolderElement) | Out-Null
                }

                $relativePathElement = $conxml.CreateElement("relativePath")
                #Array!
                $relativePathsElement.AppendChild($relativePathElement) | Out-Null

                $relativePathElement.AppendChild($elementBase) | Out-Null
                $relativePathElement.AppendChild($elementPatterns) | Out-Null


                if ($IsExclusion) {
                    $elementisExclusion = $conxml.CreateElement("isExclusion")
                    $elementisExclusion.InnerText = "true"
                    $relativePathElement.AppendChild($elementisExclusion) | Out-Null
                }
                if ($IsReadOnly) {
                    $elementisReadOnly = $conxml.CreateElement("isReadOnly")
                    $elementisReadOnly.InnerText = "true"
                    $relativePathElement.AppendChild($elementisReadOnly) | Out-Null
                }

                if ($RedirectTargetBase) {
                    $elementisRedirectTargetBase = $conxml.CreateElement("redirectTargetBase")
                    $elementisRedirectTargetBase.InnerText = $RedirectTargetBase
                    $relativePathElement.AppendChild($elementisRedirectTargetBase) | Out-Null
                }


                #$fixupNode.ParentNode.SelectNodes('config/redirectedPaths').AppendChild($elementPackageDriveRelative) | Out-Null
            }


            $conxml.PreserveWhiteSpace = $false
            $conxml.Save((Join-Path $MSIXFolder -ChildPath "config.json.xml"))
        }
    }
}


function Set-MSIXPSFFileRedirectionFixup {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)] 
        [String] $Executable #Process name as "Regex": "MSEDGE" od "MSEdge$", we don't need a path!
    )
}


function Get-MSIXFixup {
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [xml] $XmlDoc
    )

    #<fixup>
    #<dll>TraceFixup64.dll</dll>
    #<config>
    #<traceMethod>eventLog</traceMethod>
    #<traceLevels>
    #<default>always</default>
    #</traceLevels>
    #</config>
    #</fixup>

    $fragment = $xmlDoc.CreateDocumentFragment()
    # Noch ein fehler. Das muss so ausschauen
    #<traceLevel level="default">always</traceLevel>
    #$fragment.InnerXml = '<fixup><dll>TraceFixup64.dll</dll><config><traceMethod>eventLog</traceMethod><traceLevels><traceLevel level="default">allFailures</traceLevel></traceLevels></config></fixup>'
    $fragment.InnerXml = '<fixup><dll>TraceFixup64.dll</dll><config><traceMethod>outputDebugString</traceMethod><traceLevels><traceLevel level="default">allFailures</traceLevel><traceLevel level="filesystem">always</traceLevel></traceLevels></config></fixup>'
    #$fragment.InnerXml = '<fixup><dll>TraceFixup64.dll</dll><config><traceMethod>eventLog</traceMethod><traceLevels></traceLevels></config></fixup>'
    #$xmlDoc.AppendChild($fragment)
    return $fragment
    
}




