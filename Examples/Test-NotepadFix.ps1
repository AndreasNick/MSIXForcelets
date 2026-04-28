#Requires -Version 5.1
Import-Module D:\Development\GithubProjekte\MSIXForcelets\src\MSIXForcelets.psm1 -Force

Set-MSIXActivePSFFramework -Framework 'TimManganPSF\2026-2-22_release'

# --- Configuration -----------------------------------------------------------

$msixSource  = "$env:USERPROFILE\Desktop\NotepadPlusPlus-x64-8.9.4.msix"
$msixOutput  = "$env:USERPROFILE\Desktop\NotepadPlusPlus-x64-8.9.4_fixed.msix"
$certSubject = 'CN=CoolIT'

# -----------------------------------------------------------------------------

Add-MSIXFixNotepadPlusPlus `
    -MsixFile       $msixSource `
    -OutputFilePath $msixOutput `
    -Subject        $certSubject `
    -Verbose `
    -Force

$secpass = 'mypass' | ConvertTo-SecureString -Force -AsPlainText
Set-MSIXSignature -PfxCert "$env:USERPROFILE\Desktop\NewSelfSigningCert.pfx" -CertPassword $secpass -MSIXFile $msixOutput
