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