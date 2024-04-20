<#
.SYNOPSIS
Retrieves information about MSIX applications from a specified expanded MSIX package folder.

.DESCRIPTION
The Get-MSIXApplications function Retrieves information about MSIX applications inside the AppXManifest from a specified expanded MSIX package folder. It reads the AppxManifest.xml file in the folder and returns an array of objects containing the application ID, executable, and entry point.

.PARAMETER MSIXFolder
specified expanded MSIX package folder path where the MSIX AppXManifest.xml are located.

.EXAMPLE
Get-MSIXApplications -MSIXFolder "C:\MSIXApplications"
This example retrieves information about MSIX applications located in the "C:\MSIXApplications" folder.

.OUTPUTS

.NOTES
Author: Your Name
Date: Today's Date
#>

function Get-MSIXApplications {
    [CmdletBinding()]
    #[OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            #ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder  
    )
    
    begin {
    }
    
    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            Write-Error "The MSIX temporary folder does not exist"
            throw "The MSIX temporary folder does not exist"
            #return $null
        }
        else {

            $AppxManigest = New-Object xml
            $AppxManigest.Load((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
            $result = @()
            foreach ($app in $AppxManigest.Package.Applications.Application) {
                Write-Verbose "Found application $($app.Id)"
                $AppObj = "" | Select-Object -Property Id, Executable, EntryPoint 
                $AppObj.Id = $app.Id
                $AppObj.Executable = $app.Executable
                $AppObj.EntryPoint = $app.EntryPoint
                $result += $AppObj
            }
            return $result
        } 
    }
    end {
    }
}