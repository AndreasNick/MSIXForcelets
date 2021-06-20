#$ScriptPath = (Get-Location).Path
$ScriptPath = $PSScriptRoot
#$Script:PSFVersion = "2.0"
$Script:PSFVersion = "Beta"
$Script:MSIXPSFURL = "https://github.com/microsoft/MSIX-PackageSupportFramework/releases/download/v2.0/PSFBinaries.zip"
$Script:MSIXPSFFilename = "PSFBinaries.zip"


#Version 1.4
$Script:MSIXToolkitURL = "https://github.com/microsoft/MSIX-Toolkit/releases/download/1.4/MSIX-Toolkit.x64.zip"
$Script:MSIXToolkitFilename = "MSIX-Toolkit.x64_1.4.zip"

#Namespaces
$AppXNamespaces = [ordered]@{

    "ns" =  "http://schemas.microsoft.com/appx/manifest/foundation/windows10"
    "uap" = "http://schemas.microsoft.com/appx/manifest/uap/windows10" 
    "uap2" = "http://schemas.microsoft.com/appx/manifest/uap/windows10/2"
    "uap3" = "http://schemas.microsoft.com/appx/manifest/uap/windows10/3"
    "uap4" = "http://schemas.microsoft.com/appx/manifest/uap/windows10/4"
    "uap5" = "http://schemas.microsoft.com/appx/manifest/uap/windows10/6"
    "uap7" = "http://schemas.microsoft.com/appx/manifest/uap/windows10/7"
    "uap10" = "http://schemas.microsoft.com/appx/manifest/uap/windows10/7"
    "mobile" = "http://schemas.microsoft.com/appx/manifest/mobile/windows10"
    "iot" = "http://schemas.microsoft.com/appx/manifest/iot/windows10"
    "desktop" = "http://schemas.microsoft.com/appx/manifest/desktop/windows10"
    "rescap" = "http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
}


# Found here https://stackoverflow.com/questions/25709398/set-location-of-special-folders-with-powershell
$Script:SystemKnownFolders = [ordered] @{
    'AddNewPrograms'        = 'de61d971-5ebc-4f02-a3a9-6c82895e5c04';
    'AdminTools'            = '724EF170-A42D-4FEF-9F26-B60E846FBA4F';
    'AppUpdates'            = 'a305ce99-f527-492b-8b1a-7e76fa98d6e4';
    'CDBurning'             = '9E52AB10-F80D-49DF-ACB8-4330F5687855';
    'ChangeRemovePrograms'  = 'df7266ac-9274-4867-8d55-3bd661de872d';
    'CommonAdminTools'      = 'D0384E7D-BAC3-4797-8F14-CBA229B392B5';
    'CommonOEMLinks'        = 'C1BAE2D0-10DF-4334-BEDD-7AA20B227A9D';
    'CommonPrograms'        = '0139D44E-6AFE-49F2-8690-3DAFCAE6FFB8';
    'CommonStartMenu'       = 'A4115719-D62E-491D-AA7C-E74B8BE3B067';
    'CommonStartup'         = '82A5EA35-D9CD-47C5-9629-E15D2F714E6E';
    'CommonTemplates'       = 'B94237E7-57AC-4347-9151-B08C6C32D1F7';
    'ComputerFolder'        = '0AC0837C-BBF8-452A-850D-79D08E667CA7';
    'ConflictFolder'        = '4bfefb45-347d-4006-a5be-ac0cb0567192';
    'ConnectionsFolder'     = '6F0CD92B-2E97-45D1-88FF-B0D186B8DEDD';
    'Contacts'              = '56784854-C6CB-462b-8169-88E350ACB882';
    'ControlPanelFolder'    = '82A74AEB-AEB4-465C-A014-D097EE346D63';
    'Cookies'               = '2B0F765D-C0E9-4171-908E-08A611B84FF6';
    'Desktop'               = 'B4BFCC3A-DB2C-424C-B029-7FE99A87C641';
    'Documents'             = 'FDD39AD0-238F-46AF-ADB4-6C85480369C7';
    'Downloads'             = '374DE290-123F-4565-9164-39C4925E467B';
    'Favorites'             = '1777F761-68AD-4D8A-87BD-30B759FA33DD';
    'Fonts'                 = 'FD228CB7-AE11-4AE3-864C-16F3910AB8FE';
    'Games'                 = 'CAC52C1A-B53D-4edc-92D7-6B2E8AC19434';
    'GameTasks'             = '054FAE61-4DD8-4787-80B6-090220C4B700';
    'History'               = 'D9DC8A3B-B784-432E-A781-5A1130A75963';
    'InternetCache'         = '352481E8-33BE-4251-BA85-6007CAEDCF9D';
    'InternetFolder'        = '4D9F7874-4E0C-4904-967B-40B0D20C3E4B';
    'Links'                 = 'bfb9d5e0-c6a9-404c-b2b2-ae6db6af4968';
    'LocalAppData'          = 'F1B32785-6FBA-4FCF-9D55-7B8E7F157091';
    'LocalAppDataLow'       = 'A520A1A4-1780-4FF6-BD18-167343C5AF16';
    'LocalizedResourcesDir' = '2A00375E-224C-49DE-B8D1-440DF7EF3DDC';
    'Music'                 = '4BD8D571-6D19-48D3-BE97-422220080E43';
    'NetHood'               = 'C5ABBF53-E17F-4121-8900-86626FC2C973';
    'NetworkFolder'         = 'D20BEEC4-5CA8-4905-AE3B-BF251EA09B53';
    'OriginalImages'        = '2C36C0AA-5812-4b87-BFD0-4CD0DFB19B39';
    'PhotoAlbums'           = '69D2CF90-FC33-4FB7-9A0C-EBB0F0FCB43C';
    'Pictures'              = '33E28130-4E1E-4676-835A-98395C3BC3BB';
    'Playlists'             = 'DE92C1C7-837F-4F69-A3BB-86E631204A23';
    'PrintersFolder'        = '76FC4E2D-D6AD-4519-A663-37BD56068185';
    'PrintHood'             = '9274BD8D-CFD1-41C3-B35E-B13F55A758F4';
    'Profile'               = '5E6C858F-0E22-4760-9AFE-EA3317B67173';
    'ProgramData'           = '62AB5D82-FDC1-4DC3-A9DD-070D1D495D97';
    'ProgramFiles'          = '905e63b6-c1bf-494e-b29c-65b732d3d21a';
    'ProgramFilesX64'       = '6D809377-6AF0-444b-8957-A3773F02200E';
    'ProgramFilesX86'       = '7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E';
    'ProgramFilesCommon'    = 'F7F1ED05-9F6D-47A2-AAAE-29D317C6F066';
    'ProgramFilesCommonX64' = '6365D5A7-0F0D-45E5-87F6-0DA56B6A4F7D';
    'ProgramFilesCommonX86' = 'DE974D24-D9C6-4D3E-BF91-F4455120B917';
    'Programs'              = 'A77F5D77-2E2B-44C3-A6A2-ABA601054A51';
    'Public'                = 'DFDF76A2-C82A-4D63-906A-5644AC457385';
    'PublicDesktop'         = 'C4AA340D-F20F-4863-AFEF-F87EF2E6BA25';
    'PublicDocuments'       = 'ED4824AF-DCE4-45A8-81E2-FC7965083634';
    'PublicDownloads'       = '3D644C9B-1FB8-4f30-9B45-F670235F79C0';
    'PublicGameTasks'       = 'DEBF2536-E1A8-4c59-B6A2-414586476AEA';
    'PublicMusic'           = '3214FAB5-9757-4298-BB61-92A9DEAA44FF';
    'PublicPictures'        = 'B6EBFB86-6907-413C-9AF7-4FC2ABF07CC5';
    'PublicVideos'          = '2400183A-6185-49FB-A2D8-4A392A602BA3';
    'QuickLaunch'           = '52a4f021-7b75-48a9-9f6b-4b87a210bc8f';
    'Recent'                = 'AE50C081-EBD2-438A-8655-8A092E34987A';
    'RecycleBinFolder'      = 'B7534046-3ECB-4C18-BE4E-64CD4CB7D6AC';
    'ResourceDir'           = '8AD10C31-2ADB-4296-A8F7-E4701232C972';
    'RoamingAppData'        = '3EB685DB-65F9-4CF6-A03A-E3EF65729F3D';
    'SampleMusic'           = 'B250C668-F57D-4EE1-A63C-290EE7D1AA1F';
    'SamplePictures'        = 'C4900540-2379-4C75-844B-64E6FAF8716B';
    'SamplePlaylists'       = '15CA69B3-30EE-49C1-ACE1-6B5EC372AFB5';
    'SampleVideos'          = '859EAD94-2E85-48AD-A71A-0969CB56A6CD';
    'SavedGames'            = '4C5C32FF-BB9D-43b0-B5B4-2D72E54EAAA4';
    'SavedSearches'         = '7d1d3a04-debb-4115-95cf-2f29da2920da';
    'SEARCH_CSC'            = 'ee32e446-31ca-4aba-814f-a5ebd2fd6d5e';
    'SEARCH_MAPI'           = '98ec0e18-2098-4d44-8644-66979315a281';
    'SearchHome'            = '190337d1-b8ca-4121-a639-6d472d16972a';
    'SendTo'                = '8983036C-27C0-404B-8F08-102D10DCFD74';
    'SidebarDefaultParts'   = '7B396E54-9EC5-4300-BE0A-2482EBAE1A26';
    'SidebarParts'          = 'A75D362E-50FC-4fb7-AC2C-A8BEAA314493';
    'StartMenu'             = '625B53C3-AB48-4EC1-BA1F-A1EF4146FC19';
    'Startup'               = 'B97D20BB-F46A-4C97-BA10-5E3608430854';
    'SyncManagerFolder'     = '43668BF8-C14E-49B2-97C9-747784D784B7';
    'SyncResultsFolder'     = '289a9a43-be44-4057-a41b-587a76d7e7f9';
    'SyncSetupFolder'       = '0F214138-B1D3-4a90-BBA9-27CBC0C5389A';
    'System'                = '1AC14E77-02E7-4E5D-B744-2EB1AE5198B7';
    'SystemX86'             = 'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27';
    'Templates'             = 'A63293E8-664E-48DB-A079-DF759E0509F7';
    'TreeProperties'        = '5b3749ad-b49f-49c1-83eb-15370fbd4882';
    'UserProfiles'          = '0762D272-C50A-4BB0-A382-697DCD729B80';
    'UsersFiles'            = 'f3ce0f7c-4901-4acc-8648-d5d44b04ef8f';
    'Videos'                = '18989B1D-99B5-455B-841C-AB7C74E4DDFC';
    'Windows'               = 'F38BF404-1D43-42F2-9305-67DE0B28FC23';
}

function Get-MSIXToolkit {
    [CmdletBinding()]
    param()  

    #Version 1.4
    #$MSIXToolkitURL = "https://github.com/microsoft/MSIX-Toolkit/releases/download/1.4/MSIX-Toolkit.x64.zip"
    #$MSIXToolkitFilename = "MSIX-Toolkit.x64_1.4.zip"
    if (-not (Test-Path (Join-Path $ScriptPath -childPath "MSIX-Toolkit"))) { New-Item (Join-Path $ScriptPath -childPath "MSIX-Toolkit" ) -ItemType Directory }
    
    if (-Not (Test-Path (Join-Path $ScriptPath -childPath "MSIX-Toolkit\$MSIXToolkitFilename"))) {
        Write-Verbose "Download MSIX-Toolkit 64 Bit to MSIX-Toolkit\$MSIXToolkitFilename"
        Invoke-WebRequest -Uri $MSIXToolkitURL -OutFile  (Join-Path $ScriptPath -childPath "MSIX-Toolkit\$MSIXToolkitFilename")
        Expand-Archive -LiteralPath  (Join-Path $ScriptPath -childPath "MSIX-Toolkit\$MSIXToolkitFilename") -DestinationPath   (Join-Path $ScriptPath -childPath "MSIX-Toolkit")
    }
    else {
        Write-Verbose "MSIX Toolkit already exist - skip download" 

    }

    Write-Verbose "Assign Alias" 
    if (!(get-alias makeappx -ErrorAction SilentlyContinue)) {
        Write-Verbose "Create alias MakeAppx" 
        New-Alias -Name MakeAppx -value (Join-Path $ScriptPath -childPath "MSIX-Toolkit\MSIX-Toolkit.x64\makeappx.exe") -Scope Script
        
    }
    if (!(get-alias signtool -ErrorAction SilentlyContinue)) {
        $apath = (Join-Path $ScriptPath -childPath "MSIX-Toolkit\MSIX-Toolkit.x64\signtool.exe")
        Write-Verbose "Create alias signtool to $apath" 
        New-Alias -Name signtool -Value $apath -Scope Script #Global
        
    }
}

function Get-MSIXPSF {
    [CmdletBinding()]
    param (
        
    )
    if ($PSFVersion -ne "Beta") {
        if (-not (Test-Path (Join-Path $ScriptPath -childPath "MSIXPSF"))) { New-Item (Join-Path $ScriptPath -childPath "MSIXPSF" ) -ItemType Directory }
        if (-not (Test-Path (Join-Path $ScriptPath -childPath "MSIXPSF\$PSFVersion"))) { New-Item (Join-Path $ScriptPath -childPath "MSIXPSF\$PSFVersion" ) -ItemType Directory }
        if (-Not (Test-Path (Join-Path $ScriptPath -childPath "MSIXPSF\$PSFVersion\$MSIXPSFFilename"))) {
            Write-Verbose "Download MSIX Package Support Framework to XMSIXPSF\$PSFVersion\$MSIXPSFFilename"
            Invoke-WebRequest -Uri   $MSIXPSFURL -OutFile  (Join-Path $ScriptPath -childPath "MSIXPSF\$PSFVersion\$MSIXPSFFilename")
            Expand-Archive -LiteralPath (Join-Path $ScriptPath -childPath "MSIXPSF\$PSFVersion\$MSIXPSFFilename") -DestinationPath  (Join-Path $ScriptPath -childPath "MSIXPSF\$PSFVersion")
        }
        else {
            Write-Verbose "MSIX PSF in $PSFVersion already exist - skip download" 
        }
    } else {
        Write-Verbose "Beta Version skip Download" 
    }
}

  

<#
function Expand-MSIXPackage {
    param (
        [System.IO.FileInfo] $MSIXFilePath,
        $TempFolder = "$ENV:Temp\MSIXTempFolder",
        [Bool] $ClearTempFolder = $True
    )

    if (!(Test-Path $TempFolder )) {
        if ($ClearTempFolder) {
            Remove-Item  -Path $TempFolder  -Recurse -Confirm:$False
        }

        New-Item -Path$TempFolder -ItemType Directory
    }

    makeappx unpack -p $MSIXFilePath -d $TempFolder 

}
#>

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

function Add-MSIXCapabilities {
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


function Add-DisableVREGOrRegistryWrite {
    <#
    .SYNOPSIS
    Disables  VFS and VREG in einem MSIX / APPX package
    
    .DESCRIPTION
    Disables  VFS and VREG in einem MSIX / APPX package.
    >>> ATTENTION <<< - the package cannot be opened with the Packaging Tool afterwards. It does not 
    seem to know the namespace "desktop6" yet. An installation is only possible via the PoweerShell "Add-AppXPackage".
    
    .PARAMETER MSIXFolder
    The unzipped MSIX folder
    
    .PARAMETER DisableFileSystemWriteVirtualization
    desktop6:FileSystemWriteVirtualization
    Indicates whether virtualization for the file system is enabled for your desktop application. 
    If disabled, other apps can read or write the same file system entries as your application.
    
    .PARAMETER DisableRegistryWriteVirtualization
    desktop6:RegistryWriteVirtualization
    Indicates whether virtualization for the registry is enabled for your desktop application. 
    If disabled, other apps can read or write the same registry entries as your application
    
    .EXAMPLE
    Add-MSIXCapabilities -MSIXFolder $Package  -Capabilities unvirtualizedResources 
    Add-DisableVREGOrRegistryWrite -MSIXFolder $Package -DisableFileSystemWriteVirtualization -DisableRegistryWriteVirtualization
    
    .NOTES
    The idea is from this blog
    https://www.advancedinstaller.com/msix-disable-registry-file-redirection.html

    #>
    param(    
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Switch] $DisableFileSystemWriteVirtualization,
        [Switch] $DisableRegistryWriteVirtualization
    )

    process {
        <#
            <Properties>
            <desktop6:FileSystemWriteVirtualization>disabled</desktop6:FileSystemWriteVirtualization>
            <desktop6:RegistryWriteVirtualization>disabled</desktop6:RegistryWriteVirtualization>
            </Properties>
            #>
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            Write-Verbose "[ERROR] The MSIX temporary folder not exist - skip disableVREGOrRegistryWrite"
        }
        else {
            if ($DisableFileSystemWriteVirtualization -or $DisableRegistryWriteVirtualization) {
                $manifest = New-Object xml
                $manifest.Load((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
                
                $nsmgr = New-Object System.Xml.XmlNamespaceManager $manifest.NameTable
                $AppXNamespaces.GetEnumerator() | ForEach-Object {
                    $nsmgr.AddNamespace($_.key, $_.value)
                }
                $nsmgr.AddNamespace("desktop6", "http://schemas.microsoft.com/appx/manifest/desktop/windows10/6")

                $properties = $manifest.SelectSingleNode("//ns:Package/ns:Properties", $nsmgr)
                if ($DisableFileSystemWriteVirtualization) {
                    if ($null -eq $manifest.SelectSingleNode("//ns:Package/ns:Properties/desktop6:FileSystemWriteVirtualization", $nsmgr)) {
                        $disFSW = $manifest.CreateElement("desktop6:FileSystemWriteVirtualization", "http://schemas.microsoft.com/appx/manifest/desktop/windows10/6")
                        $disFSW.InnerText = "disabled"
                        $properties.AppendChild($disFSW)
                    }
                    else {
                        Write-Verbose "[INFORMATION] desktop6:FileSystemWriteVirtualization already exist"
                    }
                }
                if ($DisableRegistryWriteVirtualization) {
                    if ($null -eq $manifest.SelectSingleNode("//ns:Package/ns:Properties/desktop6:RegistryWriteVirtualization", $nsmgr)) {
                        $disvreg = $manifest.CreateElement("desktop6:RegistryWriteVirtualization", "http://schemas.microsoft.com/appx/manifest/desktop/windows10/6")
                        $disvreg.InnerText = "disabled"
                        $properties.AppendChild($disvreg)
                    }
                    else {
                        Write-Verbose "[INFORMATION] desktop6:RegistryWriteVirtualization already exist"
                    }
                }
                $manifest.PreserveWhitespace = $false
                $manifest.Save((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
            }
            else {
                Write-Verbose "[INFORMATION] DisableFileSystemWriteVirtualization or DisableRegistryWriteVirtualization are not set - skip"
            }
        }
    }
}


#https://techcommunity.microsoft.com/t5/msix-deployment/msix-packaging-gimp/m-p/859797
# Search order in a msix package
function Add-MSIXloaderSearchPathOverride {
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



#From https://stackoverflow.com/questions/37024568/applying-xsl-to-xml-with-powershell-exception-calling-transform
function Convert-MSIXPSFXML2JSON {
    [CmdletBinding()]
    param ([Parameter(Mandatory = $true)] [String] $xml, 
        [Parameter(Mandatory = $true)] [String] $xsl, 
        [Parameter(Mandatory = $true)] [String] $output
    )

    if (-not $xml -or -not $xsl -or -not $output) {
        Write-Host "& .\xslt.ps1 [-xml] xml-input [-xsl] xsl-input [-output] transform-output"
        return $false
    }

    Try {
        $xslt_settings = New-Object System.Xml.Xsl.XsltSettings;
        $XmlUrlResolver = New-Object System.Xml.XmlUrlResolver;
        $xslt_settings.EnableScript = 1;
        $xslt = New-Object System.Xml.Xsl.XslCompiledTransform;
        $xslt.Load($xsl, $xslt_settings, $XmlUrlResolver);
        $xslt.Transform($xml, $output);
    }

    Catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host  'Error' $ErrorMessage':'$FailedItem':' $_.Exception;
        return $false
    }
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
function Open-MSIXPackage {
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
        [Switch] $Force
    )
     
    process {
        if (-not (Test-Path $MsixFile )) {
            Write-Warning "the  file $($MsixFile.FullName) not exist"
        }

        if (-not (Test-Path $MSIXFolder)) {
            Write-Verbose "Force status: $($Force) creating folder $($MSIXFolder.FullName)"
            New-Item $MSIXFolder -ItemType Directory -force:$Force | Out-Null
        }

        MakeAppx unpack -p $($MsixFile.FullName) -d $($MSIXFolder.FullName) | Out-Default
        if ($lastexitcode -ne 0) {

            Write-Error "ERROR: MSIX Cannot open Package"
            Return $Null
        }

        return $MSIXFolder
    }
}

function Close-MSIXPackage {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            #ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [System.IO.FileInfo] $MSIXFile,
        [Switch] $KeepMSIXFolder
    )

    process {
        if (-not (Test-Path $MSIXFolder)) {
            Write-Error "The MSIX temporary folder not exist"
            return $null
        }
        else {
            #Create config.json
            Convert-MSIXPSFXML2JSON -xml (Join-Path $MSIXFolder -ChildPath "config.json.xml") -xsl (Join-Path $ScriptPath -ChildPath "Data\Format.xsl") -output (Join-Path $MSIXFolder -ChildPath "config.json")
            
            MakeAppx pack -p $MsixFile.FullName -d  $MSIXFolder.FullName 
            #-l 
            if ($lastexitcode -ne 0) {
                Write-Error "ERROR: MSIX Cannot close Package"
                return $null
            }
            else {
                if (-Not $KeepMSIXFolder) {
                    Remove-Item $MSIXFolder -Recurse -Confirm:$false
                }
            }
            
        }
    }
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
function Set-MSIXSignature {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.FileInfo] $MSIXFile,
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo] $PfxCert,
        [Parameter(Mandatory = $true)]
        [securestring] $CertPassword,
        [ValidateSet('http://timestamp.entrust.net/TSS/RFC3161sha2TS', 'http://time.certum.pl', 'http://timestamp.comodoca.com?td=sha256', 'http://timestamp.apple.com/ts01', 'http://zeitstempel.dfn.de')]
        $TimeStampServer = 'http://timestamp.entrust.net/TSS/RFC3161sha2TS',
        [switch] $force
    )
    

    process {
        #/v          Print verbose success and status messages. This may also provideslightly more information on error.
        #/fd         Specifies the file digest algorithm to use for creating filesignatures. (Default is SHA1)
        #/f <file>   Specify the signing cert in a file. If this file is a PFX with a password, the password may be supplied with the "/p" option.
        #            If the file does not contain private keys, use the "/csp" and "/kc" options to specify the CSP and container name of the private key.
        #/a          Select the best signing cert automatically. 
        
        $addParams = ""
        if ($force) {
            if (Test-Signature -MSIXFile $MSIXFile) {
                signtool remove $MSIXFile.FullName
            }
        }

        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CertPassword)
        $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        
        #signtool sign /v /fd SHA256 /a /f 'C:\temp\zertifikate\NIT-Signatur-2020-08-17.pfx' /tr 'http://timestamp.entrust.net/TSS/RFC3161sha2TS' /p 'C' "C:\Users\Andreas\Desktop\WinZinsen.msix"

        signtool sign /v /fd SHA256 /a /f $PfxCert /tr $TimeStampServer /p $UnsecurePassword $MSIXFile.Fullname  
        if ($lastexitcode -ne 0) {
            Write-Error "ERROR: MSIX Cannot sign package $($MSIXFile)"
            return $false
        }
        else {
            return $true
        }
        
    }

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


<#
.SYNOPSIS
    Modifies the AppXManifest with the given publisher certificate
.DESCRIPTION
    Long description
.EXAMPLE
    Example of how to use this cmdlet
.EXAMPLE
    Another example of how to use this cmdlet
#>
function Set-MSIXPublisher {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            #ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [String] $PublisherSubject = "CN=CoolIT"
    )

    process {
        if (-not (Test-Path $MSIXFolder)) {
            Write-Error "The MSIX temporary folder not exist"
            return $null
        }
        else {
            $xml = New-Object xml
            $xml.Load((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
            if ($null -ne $xml) {
                $xml.Package.Identity.Publisher = $PublisherSubject
                $xml.Save((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
            }
            Else {
                Write-Error "Cannod load AppXManifest.xml"
            }
        }
    }
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
function Add-MSIXPsfFrameworkFiles {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            #ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [ValidateSet('64Bit', '32Bit', '64And32Bit')]
        [String] $PSFArchitektur = '64And32Bit',
        [switch] $IncludePSFMonitor
    )
    
    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            Write-Error "The MSIX temporary folder not exist"
            return $null
        }
        else {
            $PsfBBasePath = (Join-Path $ScriptPath -childPath "MSIXPSF\$PSFVersion\Bin")
            if (($PSFArchitektur -eq '64And32Bit') -or ($PSFArchitektur -eq '64Bit')) {
                Copy-Item "$PsfBBasePath\*64*" -Destination $MSIXFolder -Verbose:$verbose | Out-Null
            }
            if (($PSFArchitektur -eq '64And32Bit') -or ($PSFArchitektur -eq '32Bit')) {
                Copy-Item "$PsfBBasePath\*32*" -Destination $MSIXFolder -Verbose:$verbose | Out-Null
            }

            Copy-Item "$PsfBBasePath\StartingScriptWrapper.ps1" -Destination $MSIXFolder | Out-Null

            if ($IncludePSFMonitor) {
                Copy-Item "$PsfBBasePath\PSFMonitor\*" -Destination $MSIXFolder -Recurse | Out-Null
            }
        } 
    }
}

function Remove-PSFMonitorFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            #ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder  
    )
    Begin {
        $MSFMonitorFiles = @("Dia2Lib.dll",
            "DynamicLibraryFixup32.dll",
            "DynamicLibraryFixup64.dll",
            "KernelTraceControl.dll",
            "KernelTraceControl.Win61.dll",
            "Microsoft.Diagnostics.FastSerialization.dll",
            "Microsoft.Diagnostics.Tracing.TraceEvent.dll",
            "msdia140.dll",
            "OSExtensions.dll",
            "PsfMonitor.exe",
            "PsfMonitorX64.exe",
            "PsfMonitorX86.exe")
    }    

    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            Write-Error "The MSIX temporary folder not exist"
            return $null
        }
        else {
            Foreach ($file in $MSFMonitorFiles) {
                if (Test-Path (Join-Path $MSIXFolder -ChildPath $file) ) {
                    Remove-Item  (Join-Path $MSIXFolder -ChildPath $file) 
                }
            }
            
        }
    }
}

function Remove-PSFFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            #ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder  
    )
    Begin {
        $MSFMonitorFiles = @("FileRedirectionFixup32.dll",
            "FileRedirectionFixup64.dll",
            "PsfLauncher32.exe",
            "PsfLauncher64.exe",
            "PsfRunDll32.exe",
            "PsfRunDll64.exe",
            "PsfRuntime32.dll",
            "PsfRuntime64.dll",
            "StartingScriptWrapper.ps1",
            "TraceFixup32.dll",
            "TraceFixup64.dll",
            "WaitForDebuggerFixup32.dll",
            "WaitForDebuggerFixup64.dll")
    }    

    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            Write-Error "The MSIX temporary folder not exist"
            return $null
        }
        else {
            Foreach ($file in $MSFMonitorFiles) {
                if (Test-Path (Join-Path $MSIXFolder -ChildPath $file) ) {
                    Remove-Item  (Join-Path $MSIXFolder -ChildPath $file) 
                }
            }
        }
    }
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
function Get-MSIXApplications {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            #ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder  
    )
    
    begin {
    }
    
    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            Write-Error "The MSIX temporary folder not exist"
            return $null
        }
        else {

            $AppxManigest = New-Object xml
            $AppxManigest.Load((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
            $result = @()
            foreach ($app in $AppxManigest.Package.Applications.Application) {
                Write-Verbose "Found application $($app.Id)"
                $AppObj = "" | Select-Object -Property Id, Executable, EntryPoint 
                $AppObj.Id = $app.Id
                $AppObj.Executable = $app.Executable
                $AppObj.EntryPoint = $app.EntryPoint
                $result += $AppObj
            }
            

            return $result

        } 
    }
    
    end {
    }
}

function Start-MSIXPSFMonitor{
    param(
        [ValidateSet('64', '32')]
        $Architektur = '64'
    )

    $Path = Join-Path -Path $ScriptPath -ChildPath $('MSIXPSF\' + $PSFVersion + '\bin\PSFMonitor')
    Start-Process $($Path + '\PsfMonitorx' + $Architektur + '.exe')
    
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
function Add-MSXIXPSFShim {
    [CmdletBinding()]
    [OutputType([int])]
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
        [String] $MISXAppID,
        [String] $WorkingDirectory = '',
        [String] $Arguments = '',
        [ValidateSet('64Bit', '32Bit', '64And32Bit')]
        [String] $PSFArchitektur = '32Bit'
    )
 
    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            Write-Error "The MSIX temporary folder not exist"
            return $null
        }
        else {
            Write-Verbose "Add PSF shim: $MISXAppID"
            $AppxManigest = New-Object xml
            $AppxManigest.Load((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
            
            $ns = New-Object System.Xml.XmlNamespaceManager $AppxManigest.NameTable 
            $ns.AddNamespace("ns", 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
            #$AppxManigest.SelectNodes("//Applications/Application ",$ns)            
            $node = $AppxManigest.SelectSingleNode($("//ns:Application[@Id=" + "'" + $MISXAppID + "']"), $ns)

            if ($null -eq $node) {
                Write-Warning "Application $MISXAppID not found"
            }
            else {
                #Change App In AppXManifest
                #Safe the exec Path
                $Executable = $node.Executable
                if ($PSFArchitektur -eq "64Bit") {
                    $node.Executable = "PsfLauncher64.exe"
                }
                else {
                    $node.Executable = "PsfLauncher32.exe"
                }
                #Change App in the Config.json template
                $conxml = New-Object xml
                
                if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "config.json.xml") )) {
                    $conxml = [xml] '<configuration><applications></applications></configuration>'
                }
                else {
                    #Load Config
                    $conxml.Load((Join-Path $MSIXFolder -ChildPath "config.json.xml"))
                }
                #Add Application
                $appnode = $conxml.SelectSingleNode('//application/id[text()' + "='" + $MISXAppID + "']")
                if ($null -eq $appnode) {
                    Write-Verbose "[Information] Add $MISXAppID to config.json.xml"
                    $approot = $conxml.SelectSingleNode('//applications')
                    $r = $conxml.CreateElement("application") 
                    $r.AppendChild($conxml.CreateElement("id")) | Out-Null
                    $r.AppendChild($conxml.CreateElement("executable")) | Out-Null
                    #
                    $r.AppendChild($conxml.CreateElement("workingDirectory")) | Out-Null
                    if ($WorkingDirectory -ne '') {
                        $r.workingDirectory = $WorkingDirectory
                    }
                    if ($Arguments -ne '') {
                        $r.AppendChild($conxml.CreateElement("arguments")) | Out-Null
                        $r.workingDirectory = $Arguments
                    }

                    $r.id = $MISXAppID
                    $r.executable = $($Executable -replace '\\', '/')
                    $approot.AppendChild($r) | Out-Null
                    #Save config
                    $conxml.PreserveWhiteSpace = $false
                    $conxml.Save((Join-Path $MSIXFolder -ChildPath "config.json.xml"))
                }
                $AppxManigest.Save((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
                # Create config.json
                #
            }
        }
    }
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
function Add-MSIXPSFMonitor {
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
        [Parameter(Mandatory = $true)]
        [ArgumentCompleter( { 'PsfMonitorX86.exe', 'PsfMonitorX64.exe', 'DebugView.exe', 'c:/Windows/System32/cmd.exe' })]
        $Executable, #"PsfMonitorX64.exe", "c:/windows/system32/cmd.exe", "DebugView.exe"...
        $Arguments = '', #"/g", "/c dir c:\\ /s"
        [switch] $Asadmin,
        [switch] $Monitorwait
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


                #<monitor>
                #<executable>PsfMonitor.exe</executable>
                #<arguments></arguments>
                #<asadmin>true</asadmin>
                #</monitor>

                $m = $conxml.CreateElement("monitor") 
                $m.AppendChild($conxml.CreateElement("executable")) | Out-Null
                $m.executable = $Executable

                if ($Arguments -ne '') {
                    $m.AppendChild($conxml.CreateElement("arguments")) | Out-Null
                    $m.arguments = $Arguments
                }
                if ($Asadmin) {
                    $m.AppendChild($conxml.CreateElement("asadmin")) | Out-Null
                    $m.asadmin = 'true'
                }
                if ($Monitorwait) {
                    $m.AppendChild($conxml.CreateElement("wait")) | Out-Null
                    $m.asadmin = 'wait'
                }
                $appNode.ParentNode.AppendChild($m)
                $conxml.PreserveWhiteSpace = $false
                $conxml.Save((Join-Path $MSIXFolder -ChildPath "config.json.xml"))
            }
        }
    }
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


function Add-MSIXPSFTracing {
    [CmdletBinding()]
    [OutputType([int])]
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
        [String] $Executable, #Process name as "Regex": "MSEDGE" od "MSEdge$", we don't need a path!
        [ValidateSet('printf', 'eventlog', 'outputDebugString')] #eventlog is for the psfmonitor
        [String] $TraceMethod = 'eventlog',
        [ValidateSet('always', 'ignoreSuccess', 'allFailures', 'unexpectedFailures', 'ignore')]
        [String] $TraceLevel = 'always',
        [switch] $IgnoreDllLoad,
        [ValidateSet('64Bit', '32Bit')]
        [String] $PSFArchitektur = '32Bit'
    )
    
    process {
    <#    
    <fixup>
        <dll>TraceFixup.dll</dll>
        <config>
            <traceMethod>eventLog</traceMethod>
            <traceLevels>
                <traceLevel level="default">allFailures</traceLevel>
            </traceLevels>
            <breakOn>
                <break level="fileSystem">unexpectedFailures</break>
            </breakOn>
        </config>
    </fixup>
    #>
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

            $fixupNode = $null
            if($PSFArchitektur -eq '32Bit') {
                $fixupNode = $conxml.SelectSingleNode('//fixups/fixup/dll[text()' + "='TraceFixup32.dll']")
            } else {
                $fixupNode = $conxml.SelectSingleNode('//fixups/fixup/dll[text()' + "='TraceFixup64.dll']")
            }

            if (-not $fixupNode) {
                #Create TraceNode
                Write-Verbose "[INFORMATION] Create fixup TraceFixup32.dll Element for node  $Executable"
                $fixup = $conxml.CreateElement("fixup")
                #$appNode.ParentNode.SelectNodes('fixups').AppendChild($fixup)  | Out-Null
                $dll = $conxml.CreateElement("dll")
                if($PSFArchitektur -eq '32Bit'){
                    $dll.InnerText = 'TraceFixup32.dll'
                } else {
                    $dll.InnerText = 'TraceFixup64.dll'
                }
               
                $fixup.AppendChild($dll)


                $Config = $conxml.CreateElement("config")
                $fixup.AppendChild($config)
          
                $rp = $conxml.CreateElement("traceMethod")
                $rp.InnerText = $TraceMethod
                $Config.AppendChild($rp)
                
                $tls = $conxml.CreateElement("traceLevels")
                $trl = $conxml.CreateElement("traceLevel")
                $trl.SetAttribute("level",'default') #here only default
                $trl.InnerText = $TraceLevel
                $tls.AppendChild($trl)
                $Config.AppendChild($tls)
                $appNode.ParentNode.SelectNodes('fixups').AppendChild( $fixup)  | Out-Null
            } #Get TraceNode
            else {
                #The node exist

            }
            $conxml.PreserveWhitespace = $false
             $conxml.Save((Join-Path $MSIXFolder -ChildPath "config.json.xml"))
        
        }
    }
}


    Get-MSIXToolkit -verbose
    Get-MSIXPSF -Verbose


