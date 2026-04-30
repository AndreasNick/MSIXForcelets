

function Remove-MSIXApplications {
<#
.SYNOPSIS
Removes an MSIX application from the AppxManifest.xml tn the specified MSIX folder.

.DESCRIPTION
The Remove-MSIXApplications function removes an MSIX application from the specified MSIX folder by modifying the AppxManifest.xml file.

.PARAMETER MSIXFolder
Specifies the expanded MSIX folder where the AppxManifest.xml file is located. This parameter is mandatory.

.PARAMETER MISXAppID
Specifies the ID of the MSIX application to be removed. This parameter is mandatory.

.EXAMPLE
Remove-MSIXApplications -MSIXFolder "C:\MSIXFolder" -MISXAppID "MyAppID"

This example removes the MSIX application with the ID "MyAppID" from the "C:\MSIXFolder" folder.

.INPUTS
None.

.OUTPUTS
None.

.NOTES

#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)] 
        [Alias('Id')] 
        [String] $MISXAppID
    )

    begin {
    }

    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            Write-Error "[ERROR] The MSIX temporary folder does not exist"
            return $null
        }
        else {

            Write-Verbose "[INFORMATION] Remove MSIX Application $MISXAppID"
            $AppxManigest = New-Object xml
            $AppxManigest.Load((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
        
            $ns = New-Object System.Xml.XmlNamespaceManager $AppxManigest.NameTable 
            $ns.AddNamespace("ns", 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
            $node = $AppxManigest.SelectSingleNode($("//ns:Application[@Id=" + "'" + $MISXAppID + "']"), $ns)
            if ($node) {
                $node.ParentNode.RemoveChild($node) | out-null

                #Save config
                $AppxManigest.PreserveWhiteSpace = $false
                $AppxManigest.Save((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
            }
            else {
                Write-Verbose "[INFORMATION] MSIX Application $MISXAppID not found"
            }
        }

    }
}
