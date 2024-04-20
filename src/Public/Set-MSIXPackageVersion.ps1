
function Set-MSIXPackageVersion {
    <#
    .SYNOPSIS
    Sets the version of an MSIX package by updating the AppxManifest.xml file.
    
    .DESCRIPTION
    The Set-MSIXPackageVersion function sets the version of an MSIX package by updating the AppxManifest.xml file located in the specified MSIX folder. It takes a mandatory parameter, $MSIXFolder, which represents the path to the MSIX folder. It also takes an optional parameter, $MSVersion, which represents the version to set. If not provided, the default version is "1.0.0.0".
    
    .PARAMETER MSIXFolder
    Specifies the path to the MSIX folder.
    
    .PARAMETER MSVersion
    Specifies the version to set for the MSIX package. If not provided, the default version is "1.0.0.0".
    
    .OUTPUTS
      
    .EXAMPLE
    Set-MSIXPackageVersion -MSIXFolder "C:\MSIXFolder" -MSVersion "2.0.0.0"
    Sets the version of the MSIX package located in "C:\MSIXFolder" to "2.0.0.0".
    .NOTES
    https://www.nick-it.de
    Andreas Nick, 2024
    #>
     
        [CmdletBinding()]
        #[OutputType([int])]
        param(
            [Parameter(Mandatory = $true,
                ValueFromPipeline = $true,
                #ValueFromPipelineByPropertyName = $true,
                Position = 0)]
            [System.IO.DirectoryInfo] $MSIXFolder,
            [version] $MSVersion = "1.0.0.0"
        )
    
        process {
            if (-not (Test-Path $MSIXFolder)) {
                Write-Error "The MSIX temporary folder does not exist."
                throw "The MSIX temporary folder does not exist."
            }
            else {
                $xml = New-Object xml
                $xml.Load((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
                if ($null -ne $xml) {
                    $xml.Package.Identity.Version=  $MSVersion.ToString()
                    $xml.Save((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
                }
                Else {
                    Write-Error "Cannot load AppXManifest.xml."
                }
            }
        }
    }