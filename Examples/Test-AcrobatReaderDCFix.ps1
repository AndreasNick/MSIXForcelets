# Start with F5 and not with F8 to prevent problems with $PSScriptRoot in Visual Studio Code or run in PowerShell ISE
# Andreas Nick '2023

if($PSScriptRoot -eq $null) {
    throw "Start with F5 and not with F8 to prevent problems with $PSScriptRoot in Visual Studio Code or run in PowerShell ISE"
    break
}

Import-Module "$PSScriptRoot\..\src\MSIXForcelets.psm1" -verbose -Force 
$msixFilePath = "$env:Userprofile\Desktop\AdobeAcrobatReaderDC-x86-Multi.msix"
$msixOutFilePath = "$env:Userprofile\Desktop\AdobeAcrobatReaderDC-x86-Multi_fixed.msix"


$CertPassword = 'mypass' | ConvertTo-SecureString -Force -AsPlainText
$CertPath = "$PSScriptRoot\..\test\NewSelfSigningCert.pfx" #Selfsigned Cert for example

#Get Subject from Cert
$Subject = (Get-PfxData -FilePath $CertPath -Password $CertPassword).EndEntityCertificates.subject

# Add the GIMP fix and a new subject
#Start-Transcript -Path $env:Userprofile\Desktop\Gimp-x64_fixed.log -Force
 Add-MSIXFixAcrobatReaderDC -MsixFile $msixFilePath  -OutputFilePath $msixOutFilePath -Subject $Subject -Force -Verbose 
#Stop-Transcript

# Sign the package
Set-MSIXSignature -MSIXFile $msixOutFilePath -PfxCert $CertPath -CertPassword $CertPassword 


