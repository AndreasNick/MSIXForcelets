#Requires -Version 5.1
# Test the dev source instead of the installed module:
#   Import-Module 'D:\Development\GithubProjekte\MSIXForcelets\src\MSIXForcelets.psd1' -Force
#Import-Module MSIXForcelets
Import-Module 'D:\Development\GithubProjekte\MSIXForcelets\src\MSIXForcelets.psd1' -Force


$CertPath           = "$env:USERPROFILE\Desktop\NewSelfSigningCert.pfx"
$CertPassword       = 'mypass' | ConvertTo-SecureString -Force -AsPlainText
$MSIXSource         = "$env:USERPROFILE\Desktop\MSIXPsfTestApp_1.0.1.0_x64__0cfjrh7p5ggd2.msix"
$MSIXOutputFilename = "$env:USERPROFILE\Desktop\MSIXPsfTestApp_1.0.1.0_x64__0cfjrh7p5ggd2_PSF_FRF.msix"
$WorkingDirectory   = ''   # optional literal path, e.g. 'VFS\ProgramFilesX64\MyApp'

# --- Unpack ------------------------------------------------------------------

# Subject from Cert!
$Subject = (Get-PfxData -FilePath $CertPath -Password $CertPassword).EndEntityCertificates.Subject
$Package = Open-MSIXPackage -MsixFile $MSIXSource -Force
Set-MSIXPublisher -MSIXFolder $Package -PublisherSubject $Subject
Write-Verbose "Expanded: $($Package.FullName)" -Verbose

Remove-MsixDesktop7Shortcut  -MSIXFolder $Package -Verbose
Remove-MSIXDependencies -DependencyPackageName 'Microsoft.WindowsAppRuntime*'  -MSIXFolder $Package -Verbose

# --- PSF shim + trace + monitor, repack, sign --------------------------------

$app = Get-MSIXApplications -MSIXFolder $Package | Select-Object -First 1

Add-MSIXPsfFrameworkFiles -MSIXFolder $Package -PSFArchitektur Both -TraceFixup -FRFixup -MFFixup #-IncludePSFMonitor -Verbose

Set-MSIXForceletsConfiguration -PSFDebugLevel '3=Debug basic'
Add-MSXIXPSFShim -MSIXFolder $Package -PSFArchitektur x64 -MISXAppID $app.Id -WorkingDirectory $WorkingDirectory -Verbose -Debug 

#Not needed!
MSIXForcelets\Add-MSIXPSFDefaultFRF -MSIXFolder $Package -Executable '.*' -PackageRelativeBase 'VFS\ProgramFilesX64\MSIXPsfTestApp' -Verbose

# MFRFixup - modern replacement for FileRedirectionFixup. Its presence detours the file APIs, so
# the fixup logs every file call to OutputDebugString at debugLevel >= 3 (DebugView). Don't combine
# MFR and FRF in production - pick one; here both are shown for comparison.
# Add-MSIXPSFMFRFixup -MSIXFolder $Package -Executable '.*' -Verbose

# Trace into the same '.*' catch-all (first-match-wins; '.*' is last, a per-exe entry would never hit).
#Add-MSIXPSFTracing    -MSIXFolder $Package -Executable '.*' -TraceMethod eventlog -TraceLevel allFailures -Verbose

# $appId = (Get-MSIXApplications -MSIXFolder $Package | Select-Object -First 1).Id
# Add-MSIXPSFMonitor   -MSIXFolder $Package -MISXAppID $appId -Asadmin -Verbose
# Add-MSIXCapabilities -MSIXFolder $Package -Capabilities 'runFullTrust', 'allowElevation' -Verbose

$Package | Close-MSIXPackage -MSIXFile $MSIXOutputFilename  -Verbose
Set-MSIXSignature -MSIXFile $MSIXOutputFilename -PfxCert $CertPath -CertPassword $CertPassword
