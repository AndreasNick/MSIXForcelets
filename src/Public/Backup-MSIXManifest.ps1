
function Backup-MSIXManifest {
<#
.SYNOPSIS
    Backs up the AppxManifest.xml file in the specified MSIX folder.

.DESCRIPTION
    The Backup-MSIXManifest function is used to create a backup of the AppxManifest.xml file in the specified MSIX folder. 
    If the AppxManifest.xml file does not exist in the folder, an error is displayed.

.PARAMETER MSIXFolder
    Specifies the MSIX folder where the AppxManifest.xml file is located.
    
.PARAMETER BackupFilename
    Specifies the name of the backup file. If not provided, the backup file name will be generated using the current date and time.

.EXAMPLE
    Backup-MSIXManifest -MSIXFolder "C:\MyMSIXFolder" -BackupFilename "Backup_AppxManifest.xml"
    
    This example backs up the AppxManifest.xml file in the "C:\MyMSIXFolder" folder with the name "Backup_AppxManifest.xml".

#>
    [CmdletBinding()]
    #[OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            #ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [String] $BackupFilename = $((get-date -Format "yyyymmdd-MM-ss") + '_' + 'AppXManifest.xml')
    )
 
    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            #Write-Error "The MSIX temporary folder does not exist"
            throw "The MSIX temporary folder does not exist"
            #return $null
        }
        else {
            Copy-Item -Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") -Destination (Join-Path $MSIXFolder -ChildPath $BackupFilename)
        }
    }
}
