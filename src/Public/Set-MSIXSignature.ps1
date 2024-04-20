

function Set-MSIXSignature {
    
<#
.SYNOPSIS
    Sets the signature for an MSIX file.

.DESCRIPTION
    The Set-MSIXSignature function sets the signature for an MSIX file using either a PFX certificate or a certificate thumbprint. It also allows specifying a timestamp server for timestamping the signature.

.PARAMETER MSIXFile
    Specifies the MSIX file for which the signature needs to be set.

.PARAMETER PfxCert
    Specifies the PFX certificate file to be used for signing the MSIX file. This parameter is mandatory when using the PFX certificate.

.PARAMETER CertPassword
    Specifies the password for the PFX certificate. This parameter is mandatory when using the PFX certificate.

.PARAMETER CertThumbprint
    Specifies the thumbprint of the certificate to be used for signing the MSIX file. This parameter is mandatory when using the certificate thumbprint.

.PARAMETER TimeStampServer
    Specifies the timestamp server to be used for timestamping the signature. The default value is 'http://timestamp.entrust.net/TSS/RFC3161sha2TS'. Valid options are: 'http://timestamp.entrust.net/TSS/RFC3161sha2TS', 'http://time.certum.pl', 'http://timestamp.comodoca.com?td=sha256', 'http://timestamp.apple.com/ts01', 'http://zeitstempel.dfn.de'.

.PARAMETER Force
    Forces the signature to be set even if the MSIX file already has a signature.

.OUTPUTS
    true if the signature is set successfully; otherwise, false.

.EXAMPLE
    Set-MSIXSignature -MSIXFile 'C:\Path\To\MyApp.msix' -PfxCert 'C:\Path\To\Certificate.pfx' -CertPassword 'MyPassword' -TimeStampServer 'http://timestamp.comodoca.com?td=sha256'

    Sets the signature for the 'MyApp.msix' file using the 'Certificate.pfx' file and the specified timestamp server.

.EXAMPLE
    Set-MSIXSignature -MSIXFile 'C:\Path\To\MyApp.msix' -CertThumbprint '1234567890ABCDEF' -TimeStampServer 'http://time.certum.pl'

    Sets the signature for the 'MyApp.msix' file using the certificate with the specified thumbprint and the specified timestamp server.

.NOTES
 https://www.nick-it.de
        Andreas Nick, 2024

#>
    [CmdletBinding(DefaultParameterSetName = 'PFX')]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.FileInfo] $MSIXFile,

        [Parameter(Mandatory = $true, ParameterSetName = 'PFX')]
        [System.IO.FileInfo] $PfxCert,

        [Parameter(Mandatory = $true, ParameterSetName = 'PFX')]
        [securestring] $CertPassword,

        [Parameter(Mandatory = $true, ParameterSetName = 'Thumbprint')]
        [string] $CertThumbprint,

        [ValidateSet('http://timestamp.entrust.net/TSS/RFC3161sha2TS', 'http://time.certum.pl', 'http://timestamp.comodoca.com?td=sha256', 'http://timestamp.apple.com/ts01', 'http://zeitstempel.dfn.de')]
        $TimeStampServer = 'http://timestamp.entrust.net/TSS/RFC3161sha2TS',

        [switch] $force
    )
    process {
        # Your initial code and checks...
        $addParams = ""
        if ($force) {
            if (Test-Signature -MSIXFile $MSIXFile) {
                signtool remove $MSIXFile.FullName
            }
        }
        switch ($PSCmdlet.ParameterSetName) {
            'PFX' {
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CertPassword)
                $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                signtool sign /v /td SHA256 /fd SHA256 /a /f $PfxCert /tr $TimeStampServer /p $UnsecurePassword $MSIXFile.Fullname 
            }
            'Thumbprint' {
                signtool sign /v /td SHA256 /fd SHA256 /sha1 $CertThumbprint /tr $TimeStampServer $MSIXFile.Fullname 
            }
        }
        
        if ($lastexitcode -ne 0) {
            Write-Error "ERROR: MSIX Cannot sign package $($MSIXFile)"
            return $false
        }
        else {
            return $true
        }
    }
}


<#
function Set-MSIXSignature {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.FileInfo] $MSIXFile,
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo] $PfxCert,
        [Parameter(Mandatory = $true)]
        [securestring] $CertPassword,
        [ValidateSet('http://timestamp.entrust.net/TSS/RFC3161sha2TS', 'http://time.certum.pl', 'http://timestamp.comodoca.com?td=sha256', 'http://timestamp.apple.com/ts01', 'http://zeitstempel.dfn.de')]
        $TimeStampServer = 'http://timestamp.entrust.net/TSS/RFC3161sha2TS',
        [switch] $force
    )
    

    process {
        #/v          Print verbose success and status messages. This may also provideslightly more information on error.
        #/fd         Specifies the file digest algorithm to use for creating filesignatures. (Default is SHA1)
        #/f <file>   Specify the signing cert in a file. If this file is a PFX with a password, the password may be supplied with the "/p" option.
        #            If the file does not contain private keys, use the "/csp" and "/kc" options to specify the CSP and container name of the private key.
        #/a          Select the best signing cert automatically. 
        
        $addParams = ""
        if ($force) {
            if (Test-Signature -MSIXFile $MSIXFile) {
                signtool remove $MSIXFile.FullName
            }
        }

        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CertPassword)
        $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        
        #signtool sign /v /fd SHA256 /a /f 'C:\temp\zertifikate\NIT-Signatur-2020-08-17.pfx' /tr 'http://timestamp.entrust.net/TSS/RFC3161sha2TS' /p 'C' "C:\Users\Andreas\Desktop\WinZinsen.msix"

        signtool sign /v /td SHA256 /fd SHA256 /a /f $PfxCert /tr $TimeStampServer /p $UnsecurePassword $MSIXFile.Fullname  
        if ($lastexitcode -ne 0) {
            Write-Error "ERROR: MSIX Cannot sign package $($MSIXFile)"
            return $false
        }
        else {
            return $true
        }
        
    }

}
#>