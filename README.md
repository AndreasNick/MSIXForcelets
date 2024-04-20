# MSIXForcelets
Additional PowerShell Commands for Microsoft MSIX
This is a working beta version. Included is also a newer version of the PFS framework, which we compiled ourselves. Use at your own risk.
currently this is not a real module but only a working version, but it is fully functional and is already used by and for packaging. Until the completion is still missing some

## Function
> Analysis of MSIX packages
> Adding PSF fixes

## How does it work?
First the module must be imported. This can also be in the module memory, for example. I am also planning to store a version in the PowerShell gallery.

```powershell
#In the Script folder
Import-Module "MSIXForcelets.psm1" -verbose -Force 

````
## Test MSIXForcelets (for Infos)

```powershell
#Import-Module $PSScriptRoot\..\MSIXForcelets.ps1
Import-Module "<PathTo>\MSIXForcelets.psm1" -verbose -Force 

Get-AppXManifestInfo \\Server\autosequencer\MSIXPackages\Blender-x64-2.91.2.msix
<#
Name                  : Blender-x64
DisplayName           : Blender-x64-2.91.2
Publisher             : CN=Nick Informationstechnik GmbH, O=Nick Informationstechnik GmbH, STREET=Dribusch 2, L=Hannover, S=Niedersachsen, PostalCode=30539, C=DE    
ProcessorArchitecture : x64
Version               : 2.91.2.0
Description           :
ConfigPath            : \\192.168.10.153\autosequencer\MSIXPackages\Blender-x64-2.91.2\Blender-x64-2.91.2.msix
UncompressedSize      : 552922446
MaxfileSize           : 165234632
MaxfilePath           : Blender%20Foundation/Blender%202.91/blender.exe
FileCount             : 4118
Applications          : {@{Id=Blender; Executable=Blender Foundation\Blender 2.91\blender.exe; VisualElements=}}
#>
````

## Test MSIX Packaging
Import-Module <PATH>\MSIXPackaging.ps1
## Some Examples
```powershell
#Header
#Password for signing
$CertPassword = 'MyPass' | ConvertTo-SecureString -Force -AsPlainText
#File to open
$msixOpen = "$env:Userprofile\Desktop\MSIX\msix-testapp-VFS.msix"
#Output
$msixOutput = "C:\Users\Andreas\Desktop\msix-testapp-VFS.msix" #Output File
#Signing Subject
$Subject = 'CN=Nick Informationstechnik GmbH'

#Open a Package
$Package = Open-MSIXPackage -MsixFile $msixOpen -Force

#Set a Publusher
Set-MSIXPublisher -MSIXFolder $Package -PublisherSubject $Subject

#Backup AppXManifest
Backup-MSIXManifest -MSIXFolder $Package 

#Add Framework files
Add-MSIXPsfFrameworkFiles -MSIXFolder $Package -PSFArchitektur 64Bit #-IncludePSFMonitor -Verbose 

# Add PSF Shim
Get-MSIXApplications -MSIXFolder $Package | Add-MSXIXPSFShim -MSIXFolder $Package -PSFArchitektur 64Bit 
# Add file redirection
Add-MSIXPSFFileRedirectionFixup -MSIXFolder $Package -Executable '.*' -PackageRelative -Patterns @('.*\\.[eE][xX][eE]$', '.*\\.[dD][lL][lL]$', '.*\\.[tT][lL][bB]$', '.*\\.[cC][oO][mM]$')  -RedirectTargetBase 'c:\\temp\\' -IsExclusion -Verbose

Add-MSIXPSFFileRedirectionFixup -MSIXFolder $Package -Executable '.*' -PackageRelative -Patterns  ".*\\.txt" -Verbose

#Other Example
# Allow Textfiles
Add-MSIXPSFFileRedirectionFixup -MSIXFolder $Package -Executable 'msix-testapp$' -PackageRelative -Patterns '.*\\.txt' -Base 'VFS\\ProgramFilesX64\\myApp\\' 

#Redirect to drive "G"
Add-MSIXPSFFileRedirectionFixup -MSIXFolder $Package -Executable '.*' -KnownFolder 'ProgramFilesX64'  -Patterns '.*' -redirectTargetBase 'g:\\temp2\\' -UseGUID

#Add Tracing
Add-MSIXPSFTracing -MSIXFolder $Package -Executable "msix-testapp$" -PSFArchitektur 64Bit -TraceMethod outputDebugString -TraceLevel unexpectedFailures -Verbose


#Disable VSFWrite and VREG
Add-MSIXCapabilities -MSIXFolder $Package  -Capabilities unvirtualizedResources 
Add-DisableVREGOrRegistryWrite -MSIXFolder $Package -DisableFileSystemWriteVirtualization -DisableRegistryWriteVirtualization

#Close a Package
$package | Close-MSIXPackage -MSIXFile $msixOutput  -KeepMSIXFolder

#Sign Package
Set-MSIXSignature -MSIXFile $msixOutput -PfxCert "C:\temp\zertifikate\NIT-Signatur-2020-08-17.pfx" -CertPassword $CertPassword 

#Start Monitor
Start-MSIXPSFMonitor

````
