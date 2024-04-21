# root path
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
$Script:MSIXToolkitPath = "$PSScriptRoot\MSIX-Toolkit\WindowsSDK\11\10.0.22000.0\x64"
$Script:MSIXPSFPath = "$PSScriptRoot\MSIXPSF"
$Script:ScriptPath = $PSScriptRoot

#Info
$PSFVersions = @("MicrosoftPSF", "TimManganPSF")

#$Script:MSIXPSFURL = "https://github.com/microsoft/MSIX-PackageSupportFramework/releases/download/v2.0/PSFBinaries.zip"
#$Script:MSIXPSFFilename = "PSFBinaries.zip"
#Version 1.4
#$Script:MSIXToolkitURL = "https://github.com/microsoft/MSIX-Toolkit/releases/download/1.4/MSIX-Toolkit.x64.zip"
#$Script:MSIXToolkitFilename = "MSIX-Toolkit.x64_1.4.zip"

#Namespaces
$AppXNamespaces = [ordered]@{
    "ns" =  "http://schemas.microsoft.com/appx/manifest/foundation/windows10"
    "uap" = "http://schemas.microsoft.com/appx/manifest/uap/windows10" 
    "uap2" = "http://schemas.microsoft.com/appx/manifest/uap/windows10/2"
    "uap3" = "http://schemas.microsoft.com/appx/manifest/uap/windows10/3"
    "uap4" = "http://schemas.microsoft.com/appx/manifest/uap/windows10/4"
    "uap5" = "http://schemas.microsoft.com/appx/manifest/uap/windows10/6"
    "uap6"= "http://schemas.microsoft.com/appx/manifest/uap/windows10/6"
    "uap7" = "http://schemas.microsoft.com/appx/manifest/uap/windows10/7"
    "uap10" = "http://schemas.microsoft.com/appx/manifest/uap/windows10/7"
    "mobile" = "http://schemas.microsoft.com/appx/manifest/mobile/windows10"
    "iot" = "http://schemas.microsoft.com/appx/manifest/iot/windows10"
    "desktop" = "http://schemas.microsoft.com/appx/manifest/desktop/windows10"
    "desktop6" = "http://schemas.microsoft.com/appx/manifest/desktop/windows10/6"   
    "desktop7" = "http://schemas.microsoft.com/appx/manifest/desktop/windows10/7"
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

#
# define some return types 
#

$AppxManifestInfo = "Name, DisplayName, Publisher, ProcessorArchitecture, Version, Description, ConfigPath, UncompressedSize, MaxfileSize, MaxfilePath, FileCount, Applications"
$AppxManifestInfo = @($AppxManifestInfo.replace("`n", "").replace("`r", "").replace(" ", "").split(',') )
Remove-TypeData -TypeName 'AppxManifestInfo' -ea SilentlyContinue

$AppxManifestConfig = @{
  MemberType = 'NoteProperty'
  TypeName   = 'AppxManifestInfo'
  Value      = $null
}

foreach ($item in $AppxManifestInfo) {
  Update-TypeData @AppxManifestConfig -MemberName $item -force
}

#Icon Extractor return Format
$IconInfo = @("Target", "Base64Image", "ImageType")

$IconConfig = @{
  MemberType = 'NoteProperty'
  TypeName   = 'MSIXIconObject'
  Value      = $null
}
foreach ($item in $IconInfo) {
  Update-TypeData @IconConfig -MemberName $item -force
}

# For direct registry.dat file operations
$RawRegFileCode = @"
using System;
using System.Text;
using System.Runtime.InteropServices;
using Microsoft.Win32; 

public static class Win32Apis {

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int RegLoadAppKey(string lpFile, out IntPtr phkResult, int samDesired, int dwOptions, int Reserved);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int RegOpenKeyEx(IntPtr hKey, string subKey, uint options, int samDesired, out IntPtr phkResult);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern int RegCloseKey(IntPtr hKey);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int RegQueryInfoKey(
        IntPtr hKey, 
        StringBuilder lpClass, 
        ref uint lpcbClass, 
        IntPtr lpReserved, 
        out uint lpcSubKeys, 
        out uint lpcbMaxSubKeyLen, 
        out uint lpcbMaxClassLen, 
        out uint lpcValues, 
        out uint lpcbMaxValueNameLen, 
        out uint lpcbMaxValueLen, 
        out uint lpcbSecurityDescriptor, 
        out FILETIME lpLastWriteTime);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int RegEnumKeyEx(
        IntPtr hKey, 
        uint index, 
        StringBuilder lpName, 
        ref uint lpcbName, 
        IntPtr lpReserved, 
        StringBuilder lpClass, 
        ref uint lpcbClass, 
        out FILETIME lpftLastWriteTime);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int RegQueryValueEx(
        IntPtr hKey,
        string lpValueName,
        int lpReserved,
        out uint lpType,
        [Out] byte[] lpData,
        ref uint lpcbData);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int RegEnumValue(
        IntPtr hKey,
        uint dwIndex,
        StringBuilder lpValueName,
        ref uint lpcbValueName,
        IntPtr lpReserved,
        out uint lpType,
        byte[] lpData,
        ref uint lpcbData);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int RegCreateKeyEx(
        IntPtr hKey,
        string lpSubKey,
        uint Reserved,
        string lpClass,
        uint dwOptions,
        uint samDesired,
        IntPtr lpSecurityAttributes,
        out IntPtr phkResult,
        out uint lpdwDisposition);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern int RegSetValueEx(
        IntPtr hKey,
        string lpValueName,
        int Reserved,
        RegistryValueKind dwType,
        byte[] lpData,
        int cbData);

  [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int RegDeleteKeyEx(
        IntPtr hKey,
        string lpSubKey,
        uint samDesired,
        uint Reserved);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int RegDeleteValue(
        IntPtr hKey,
        string lpValueName);

    [StructLayout(LayoutKind.Sequential)]
    public struct FILETIME {
        public uint dwLowDateTime;
        public uint dwHighDateTime;
    }
}
"@;

Add-Type -TypeDefinition $RawRegFileCode -Language CSharp


#
# load Assembly binaries
#
Add-Type -AssemblyName System.IO
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# stop ansi colours in ps7.2+

if ($PSVersionTable.PSVersion -ge [version]'7.2.0') {
    #$PSStyle.OutputRendering = 'PlainText'
}


# load private functions
Get-ChildItem "$($root)/Private/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

#List of existing Functions
$sysfuncs = Get-ChildItem Function:

# load public functions
Get-ChildItem "$($root)/Public/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

# get functions from memory and compare to existing to find new functions added
$funcs = Get-ChildItem Function: | Where-Object { $sysfuncs -notcontains $_ }

# export the module's public functions
Export-ModuleMember -Function ($funcs.Name)

Write-Host "===============================" -ForegroundColor Green
Write-Host "loaded MSIXForcelets" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green
Write-Host "Use default Toolkit Path $($MSIXToolkitPath)"  -ForegroundColor Green
Write-Host "Use default PSF Path $($MSIXPSFPath)" -ForegroundColor Green
Write-Host "(c) 2020-2024 Andreas Nick" -ForegroundColor Green
Write-Host "Use at your own risk without any guarantee or warranty1" -ForegroundColor Red

#Set Default PSF
Set-MSIXActivePSFFramework -version "MicrosoftPSF"
Set-MSIXToolkit 

