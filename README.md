# MSIXForcelets
Additional PowerShell Commands for Microsoft MSIX

This is a working beta version. Included is also a newer version of the PFS framework, which we compiled ourselves. Use at your own risk.
> Analysis of MSIX packages
> Adding PSF fixes


## How does it work?
First the module must be imported. This can also be in the module memory, for example. I am also planning to store a version in the PowerShell gallery.

```powershell
#In the Script folder
Import-Module $($PSScriptRoot +'\MSIXForcelets')
Import-Module 'YOURPATH\'+'\MSIXForcelets') 
````

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
