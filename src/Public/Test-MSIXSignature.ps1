function Test-MSIXSignature {
<#
.SYNOPSIS
    Tests whether an MSIX file has a valid Authenticode signature.

.DESCRIPTION
    Returns $true if the MSIX file carries a valid Authenticode signature,
    $false otherwise (not signed, signature invalid, or file not found).

.PARAMETER MSIXFile
    Path to the MSIX file to check.

.EXAMPLE
    Test-MSIXSignature -MSIXFile "C:\Packages\MyApp.msix"

.EXAMPLE
    if (Test-MSIXSignature -MSIXFile $file) { Write-Host "Already signed" }

.OUTPUTS
    [bool]

.NOTES
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.FileInfo] $MSIXFile
    )

    process {
        if (-not (Test-Path $MSIXFile.FullName)) {
            Write-Error "MSIX file not found: $($MSIXFile.FullName)"
            return $false
        }

        $sig = Get-AuthenticodeSignature -FilePath $MSIXFile.FullName
        return ($sig.Status -eq [System.Management.Automation.SignatureStatus]::Valid)
    }
}
