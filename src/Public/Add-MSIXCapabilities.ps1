
function Add-MSIXCapabilities {
    <#
    .SYNOPSIS
    Adds MSIX capabilities to a package.
    
    .DESCRIPTION
    The Add-MSIXCapabilities function is used to add MSIX capabilities to a package. This function modifies the package manifest to include the specified capabilities.
    
    .PARAMETER PackagePath
    The path to the MSIX package.
    
    .PARAMETER Capabilities
    An array of capabilities to be added to the package.
    
    .EXAMPLE
    Add-MSIXCapabilities -PackagePath "<PATH TO EXPANDED FOLDER>" -Capabilities "internetClient", "privateNetworkClientServer"
    Adds the "internetClient" and "privateNetworkClientServer" capabilities to the specified MSIX package.
    
    .INPUTS
    None.
    
    .OUTPUTS
    None.
    
    .NOTES
    Author: Andreas Nick
    Date: 01/10/2022
    https://www.nick-it.de
    
    #>
    
    
        param(    
            [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
            [System.IO.DirectoryInfo] $MSIXFolder,
            [ValidateSet("runFullTrust", "allowElevation", "internetClient", "internetClientServer", "privateNetworkClientServer", "allJoyn", "codeGeneration",
                "enterpriseAuthentication", "videosLibrary", "musicLibrary", "contacts", "appointments", "blockedChatMessages", "picturesLibrary",
                "userAccountInformation", "removableStorage", "phoneCall", "voipCall", "chat", "sharedUserCertificates", "objects3D", "phoneCallHistoryPublic",
                "spatialPerception", "remoteSystem", "backgroundMediaPlayback", "userNotificationListener", "offlineMapsManagement", "userDataTasks",
                "graphicsCapture", "globalMediaControl", "gazeInput", "recordedCallsFolder", "systemManagement", "lowLevelDevices", "accessoryManager",
                "documentsLibrary", "location", "microphone", "webcam", "radios", "unvirtualizedResources", IgnoreCase = $false)]
            [string[]] $Capabilities
        )
    
        begin {
    <#
    $MSIXCapability = @("runFullTrust", "allowElevation", "internetClient", "internetClientServer", "privateNetworkClientServer", "allJoyn", "codeGeneration",
    "enterpriseAuthentication", "videosLibrary", "musicLibrary", "contacts", "appointments", "blockedChatMessages", "picturesLibrary",
    "userAccountInformation", "removableStorage", "phoneCall", "voipCall", "chat", "sharedUserCertificates", "objects3D", "phoneCallHistoryPublic",
    "spatialPerception", "remoteSystem", "backgroundMediaPlayback", "userNotificationListener", "offlineMapsManagement", "userDataTasks",
    "graphicsCapture", "globalMediaControl", "gazeInput", "recordedCallsFolder", "systemManagement", "lowLevelDevices", "accessoryManager",
    "documentsLibrary", "location", "microphone", "webcam", "radios")
    #>
            $CapabilityNamespace = @{
                "internetClient"             = "Capability"
                "internetClientServer"       = "Capability"
                "privateNetworkClientServer" = "Capability"
                "allJoyn"                    = "Capability"
                "codeGeneration"             = "Capability"
                "enterpriseAuthentication"   = "uap:Capability"
                "videosLibrary"              = "uap:Capability"
                "musicLibrary"               = "uap:Capability"
                "contacts"                   = "uap:Capability"
                "appointments"               = "uap:Capability"
                "blockedChatMessages"        = "uap:Capability"
                "picturesLibrary"            = "uap:Capability"
                "userAccountInformation"     = "uap:Capability"
                "removableStorage"           = "uap:Capability"
                "phoneCall"                  = "uap:Capability"
                "voipCall"                   = "uap:Capability"
                "chat"                       = "uap:Capability"
                "sharedUserCertificates"     = "uap:Capability"
                "objects3D"                  = "uap:Capability"
                "phoneCallHistoryPublic"     = "uap2:Capability"
                "spatialPerception"          = "uap2:Capability"
                "remoteSystem"               = "uap3:Capability"
                "backgroundMediaPlayback"    = "uap3:Capability"
                "userNotificationListener"   = "uap3:Capability"
                "offlineMapsManagement"      = "uap4:Capability"
                "userDataTasks"              = "uap4:Capability"
                "graphicsCapture"            = "uap6:Capability"
                "globalMediaControl"         = "uap7:Capability"
                "gazeInput"                  = "uap7:Capability"
                "recordedCallsFolder"        = "mobile:Capability"
                "systemManagement"           = "iot:Capability"
                "lowLevelDevices"            = "iot:Capability"
                "accessoryManager"           = "rescap:Capability"
                "documentsLibrary"           = "rescap:Capability"
                "runFullTrust"               = "rescap:Capability"
                "allowElevation"             = "rescap:Capability"
                "location"                   = "DeviceCapability"
                "microphone"                 = "DeviceCapability"
                "webcam"                     = "DeviceCapability"
                "radios"                     = "DeviceCapability"
                "unvirtualizedResources"     = "rescap:Capability" #Allow disable VFS und vReg 
    
            }
    
        }
    
        process {
            <#
          <Capabilities>
            <rescap:Capability Name="runFullTrust" />
            <rescap:Capability Name="allowElevation" />
          </Capabilities>       
          #>
            if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
                Write-Verbose "[ERROR] The MSIX temporary folder not exist - skip adding Capabilities"
            }
            else {
    
                $manifest = New-Object xml
                $manifest.Load((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
                   
    
    
                $nsmgr = New-Object System.Xml.XmlNamespaceManager $manifest.NameTable
                $AppXNamespaces.GetEnumerator() | ForEach-Object {
                    $nsmgr.AddNamespace($_.key, $_.value)
                }
                $changed = $false
                foreach($cap in  $Capabilities){
                    
                    $namespace = $AppXNamespaces["ns"]
                    
                    if($CapabilityNamespace[$cap] -match '(?<space>.*):(?<name>.*)'){
                        $namespace = $AppXNamespaces[$Matches.space.Trim()]
                    }
                    #Element exist?
                    #$manifest.SelectSingleNode("//ns:Capabilities/rescap:Capability[@Name='runFullTrust']", $nsmgr)
    
                    $capNode = $manifest.SelectSingleNode($("//ns:Capabilities/" + $CapabilityNamespace[$cap] + '[@Name=' + "'" + $cap  +"'" +']'), $nsmgr)
                    if($capNode){
                        Write-Verbose "[INFORMATION] Element $cap already exist - skip element"
                    } else{
                        Write-Verbose "[INFORMATION] Add element $cap to the capabilities"
                        $CapsNode = $manifest.SelectSingleNode("//ns:Capabilities", $nsmgr)
                        $celem = $manifest.CreateElement($CapabilityNamespace[$cap], $namespace)
                        $celem.SetAttribute("Name", $cap)
                        $CapsNode.AppendChild($celem )
                        $changed = $true
                    }
                }
                if($changed){
                    $manifest.PreserveWhitespace = $false
                    $manifest.Save((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
                }
         
            }
        }
    }