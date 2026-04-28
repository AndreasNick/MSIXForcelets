Import-Module D:\Development\GithubProjekte\MSIXForcelets\src\MSIXForcelets.psm1 -Force

Set-MSIXActivePSFFramework -Framework 'TimManganPSF\2026-2-22_release'

$msixSource = "$env:USERPROFILE\Desktop\WinRar_notStart_7.20.1.0_x64.msix"

# Fixed package written to Desktop
$msixOutput = "$env:USERPROFILE\Desktop\WinRar_notStart_7.20.1.0_x64_fixed.msix"

# Signing certificate
$certSubject = 'CN=CoolIT'

Add-MSIXFixWinRARModernShell `
    -MsixFile       $msixSource `
    -OutputFilePath $msixOutput `
    -Subject        $certSubject `
    -Version        '7.20.1.6' `
    -Verbose `
    -Force 

# Sign the fixed package
$Secpass = 'mypass' | ConvertTo-SecureString -Force -AsPlainText
Set-MSIXSignature -PfxCert "$env:USERPROFILE\Desktop\NewSelfSigningCert.pfx" -CertPassword $Secpass -MSIXFile $msixOutput
