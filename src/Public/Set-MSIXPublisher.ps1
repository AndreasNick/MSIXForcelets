
function Set-MSIXPublisher {

    <#
.SYNOPSIS
Sets the publisher information for an MSIX package.

.DESCRIPTION
The Set-MSIXPublisher function is used to set the publisher information for an MSIX package. This information is used to verify the authenticity and integrity of the package.

.PARAMETER Publisher
Specifies the publisher name to be set for the MSIX package.

.PARAMETER PackagePath
Specifies the path to the MSIX package.

.EXAMPLE
Set-MSIXPublisher -Publisher "Contoso Inc." -PackagePath "C:\Path\To\Package.msix"

This example sets the publisher information for the MSIX package located at "C:\Path\To\Package.msix" to "Contoso Inc.".

.INPUTS
None.

.OUTPUTS
None.

.NOTES
https://www.nick-it.de
Andreas Nick, 2024

.LINK
https://docs.microsoft.com/en-us/powershell/module/msix/set-msixpublisher

#>
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            #ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [String] $PublisherSubject = "CN=CoolIT"
    )

    process {
        if (-not (Test-Path $MSIXFolder)) {
            Write-Error "The MSIX temporary folder not exist"
            throw "The MSIX temporary folder not exist"
        }
        else {
            $xml = New-Object xml
            $xml.Load((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
            if ($null -ne $xml) {
                $xml.Package.Identity.Publisher = $PublisherSubject
                $xml.Save((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
            }
            Else {
                Write-Error "Cannod load AppXManifest.xml"
                throw "Cannod load AppXManifest.xml"
            }
        }
    }
}
