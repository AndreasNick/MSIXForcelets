
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




