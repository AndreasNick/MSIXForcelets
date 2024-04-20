
function Get-MSIXPackageVersion {
    <#
    .SYNOPSIS
        Retrieves the version of an MSIX package.
    
    .DESCRIPTION
        The Get-MSIXPackageVersion function retrieves the version of an MSIX package by parsing the AppxManifest.xml file.
    
    .PARAMETER MSIXFolder
        Specifies the path to the folder containing the MSIX package.
    
    .OUTPUTS
        [system.version]
        The version of the MSIX package.
    
    .EXAMPLE
        Get-MSIXPackageVersion -MSIXFolder "C:\Path\To\MSIXFolder"
    
        This example retrieves the version of the MSIX package located in the specified folder.
    
     .NOTES
        https://www.nick-it.de
        Andreas Nick, 2024
    #>
        [CmdletBinding()]
        [OutputType([int])]
        param(
            [Parameter(Mandatory = $true,
                ValueFromPipeline = $true,
                #ValueFromPipelineByPropertyName = $true,
                Position = 0)]
            [System.IO.DirectoryInfo] $MSIXFolder
        )
    
        process {
            if (-not (Test-Path $MSIXFolder)) {
                Write-Error "The MSIX temporary folder does not exist."
                return $null
            }
            else {
                $xml = New-Object xml
                $xml.Load((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
                if ($null -ne $xml) {
                    return [system.version] $xml.Package.Identity.Version
                }
                Else {
                    Write-Error "Cannot load AppXManifest.xml."
                    return $null
                }
            }
        }
    }