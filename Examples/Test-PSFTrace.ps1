#Requires -Version 5.1
$ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module "$ScriptRoot\..\src\MSIXForcelets.psm1" -Force -Verbose

# --- Configuration -----------------------------------------------------------

$CertPath           = "$ScriptRoot\NewSelfSigningCert.pfx"
$CertPassword       = 'mypass' | ConvertTo-SecureString -Force -AsPlainText
$MSIXSource         = "$env:USERPROFILE\Desktop\FreeOrion_5.0.1.0_x64__5g7qmyvpqtbge.msix"
$MSIXOutputFilename = "$env:USERPROFILE\Desktop\FreeOrion_5.0.1.0_x64_NewFile.msix"

# FreeOrion requires a working directory pointing to its install location.
$WorkingDirectory   = 'C:/Program Files (x86)/FreeOrion'

# -----------------------------------------------------------------------------

break

# --- Open package and align publisher ----------------------------------------

$Subject = (Get-PfxData -FilePath $CertPath -Password $CertPassword).EndEntityCertificates.Subject
$Package = Open-MSIXPackage -MsixFile $MSIXSource -Force

Set-MSIXPublisher  -MSIXFolder $Package -PublisherSubject $Subject
Get-MSIXPackageVersion -MSIXFolder $Package

break

# --- Apply PSF (TraceFixup + Monitor) ----------------------------------------

Set-MSIXActivePSFFramework -Framework 'TimManganPSF\2026-2-22_release'
Add-MSIXPsfFrameworkFiles  -MSIXFolder $Package -PSFArchitektur 64And32Bit `
                            -TraceFixup -IncludePSFMonitor -Verbose

# To remove the monitor files again:
# Remove-MSIXPSFMonitorFiles -MSIXFolder $Package -Verbose

Backup-MSIXManifest -MSIXFolder $Package

$apps = Get-MSIXApplications -MSIXFolder $Package

foreach ($app in $apps) {
    Set-MSIXApplicationVisualElements -MSIXFolderPath $Package -Id $app.Id -AppListEntry 'default'

    $exe = Join-Path -Path $Package -ChildPath $app.Executable
    $arch = if ((Get-MSIXAppExeArchitectureType $exe) -eq 'I386') { '32Bit' } else { '64Bit' }
    Add-MSXIXPSFShim -MSIXFolder $Package -PSFArchitektur $arch -MISXAppID $app.Id `
                     -WorkingDirectory $WorkingDirectory -Verbose
}

Add-MSIXPSFTracing -MSIXFolder $Package -Executable 'FreeOrion' `
                   -PSFArchitektur 32Bit -TraceMethod outputDebugString `
                   -TraceLevel allFailures -Verbose

break

# --- Pack and sign -----------------------------------------------------------

$Package | Close-MSIXPackage -MSIXFile $MSIXOutputFilename -KeepMSIXFolder -Verbose
Set-MSIXSignature -MSIXFile $MSIXOutputFilename -PfxCert $CertPath -CertPassword $CertPassword

break

# --- Reinstall ---------------------------------------------------------------

Get-AppPackage FreeOrion* | Remove-AppPackage
