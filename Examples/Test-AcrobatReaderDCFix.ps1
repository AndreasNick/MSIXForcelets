Import-Module D:\Development\GithubProjekte\MSIXForcelets\src\MSIXForcelets.psm1 -Force -Verbose

# Source MSIX — Adobe Acrobat Reader DC

# $msixSource  = "$env:USERPROFILE\Desktop\AdobeAcrobatReaderDC-x86-English-26.001.21411.msix"
# $msixSource = "$env:USERPROFILE\\Desktop\AdobeAcrobatReaderDC-x86-Multi-26.001.21411.msix"
# $msixSource = "$env:USERPROFILE\Desktop\AdobeAcrobatReaderDC-x64-English-26.001.21411.msix"
$msixSource = "$env:USERPROFILE\Desktop\AdobeAcrobatReaderDC-x86-German-26.001.21411.msix"

# Fixed package written to Desktop
# $msixOutput  = "$env:USERPROFILE\Desktop\AdobeAcrobatReaderDC-x86-English-26.001.21411_fixed.msix"
# $msixOutput  = "$env:USERPROFILE\Desktop\AdobeAcrobatReaderDC-x86-Multi-26.001.21411_fixed.msix"
# $msixOutput  = "$env:USERPROFILE\Desktop\AdobeAcrobatReaderDC-x64-English-26.001.21411_fixed.msix"
$msixOutput  = "$env:USERPROFILE\Desktop\AdobeAcrobatReaderDC-x86-German-26.001.21411_fixed.msix" 


# Signing certificate on the USB signing stick
$certThumbprint = 'fb2385268890b2f3771e84b8f1ebc11c5df610ad'
$certSubject    = 'CN=Nick Informationstechnik GmbH, O=Nick Informationstechnik GmbH, L=Hannover, S=Niedersachsen, C=DE'

# Apply the Acrobat Reader DC PSF fix.
# -Subject triggers Set-MSIXPublisher internally so the publisher in
# AppxManifest.xml matches the signing certificate.
# MSIXFolder defaults to a unique path under %TEMP% — no cleanup needed.
Add-MSIXFixAcrobatReaderDC `
    -MsixFile       $msixSource `
    -OutputFilePath $msixOutput `
    -Subject        $certSubject `
    -Force `
    -Verbose

# Sign the fixed package with the hardware signing stick (USB token must be inserted).
Set-MSIXSignature `
    -MSIXFile       $msixOutput `
    -CertThumbprint $certThumbprint `
    -Verbose
