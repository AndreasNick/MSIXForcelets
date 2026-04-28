Import-Module D:\Development\GithubProjekte\MSIXForcelets\src\MSIXForcelets.psm1 -Force -Verbose

$msixSource = "$env:USERPROFILE\Desktop\GimpImVFS_3.2.2.0_x64.msix"

$msixOutput = "$env:USERPROFILE\Desktop\GimpImVFS_3.2.2.0_x64_fixed.msix"

$certSubject    = 'CN=CoolIT'

Add-msixFixGimp `
    -MsixFile       $msixSource `
    -OutputFilePath $msixOutput `
    -Subject        $certSubject `
     -Force

# Sign the fixed package
$Secpass = 'mypass' | ConvertTo-SecureString -Force -AsPlainText
Set-MSIXSignature -PfxCert "$env:USERPROFILE\Desktop\NewSelfSigningCert.pfx" -CertPassword  $Secpass -MSIXFile $msixOutput 
