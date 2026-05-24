function New-MSIXSelfSigningCert {
<#
.SYNOPSIS
    Creates a self-signed code-signing certificate and exports it as .pfx and .cer.

.DESCRIPTION
    Lab helper: creates an RSA-2048 code-signing cert, exports a password-protected
    .pfx (with private key) and a .cer (public only), then removes it from the
    store unless -KeepInStore is set. Returns an object with Thumbprint, PfxPath,
    CerPath and Password for direct use with Set-MSIXSignature.

.EXAMPLE
    $c = New-MSIXSelfSigningCert -Subject 'CN=CoolIT'
    Set-MSIXSignature -MSIXFile $msix -PfxCert $c.PfxPath -CertPassword (ConvertTo-SecureString $c.Password -AsPlainText -Force)

.NOTES
    Andreas Nick, 2019-2026
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string] $Subject      = 'CN=CoolIT',
        [string] $Password     = 'mypass',
        [System.IO.DirectoryInfo] $OutputFolder = "$env:USERPROFILE\Desktop",
        [string] $FileName     = 'NewSelfSigningCert',
        [switch] $KeepInStore
    )

    $cert = New-SelfSignedCertificate -Subject $Subject -KeyAlgorithm RSA -KeyLength 2048 `
        -Type CodeSigningCert -CertStoreLocation 'Cert:\CurrentUser\My'

    $pfxPath = Join-Path $OutputFolder.FullName ($FileName + '.pfx')
    $cerPath = Join-Path $OutputFolder.FullName ($FileName + '.cer')
    $securePwd = ConvertTo-SecureString $Password -AsPlainText -Force

    $null = Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $securePwd
    $null = Export-Certificate    -Cert $cert -FilePath $cerPath -Type CERT

    if (-not $KeepInStore) {
        Remove-Item ('Cert:\CurrentUser\My\' + $cert.Thumbprint)
    }

    [PSCustomObject]@{
        Thumbprint = $cert.Thumbprint
        Subject    = $Subject
        PfxPath    = $pfxPath
        CerPath    = $cerPath
        Password   = $Password
        InStore    = [bool]$KeepInStore
    }
}
