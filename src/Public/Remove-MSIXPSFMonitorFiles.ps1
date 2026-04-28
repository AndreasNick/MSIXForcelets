

function Remove-MSIXPSFMonitorFiles {
<#
.SYNOPSIS
Removes PSFMonitor files from the specified MSIX folder.

.DESCRIPTION
The Remove-PSFMonitorFiles function removes PSFMonitor files from the specified MSIX folder. It searches for the specified PSFMonitor files in the MSIX folder and its subdirectories, and deletes them.

.PARAMETER MSIXFolder
Specifies the MSIX folder from which to remove the PSFMonitor files.

.EXAMPLE
Remove-PSFMonitorFiles -MSIXFolder "C:\Path\To\MSIXFolder"
Removes PSFMonitor files from the specified MSIX folder "C:\Path\To\MSIXFolder".

.INPUTS
[System.IO.DirectoryInfo]
Accepts a DirectoryInfo object representing the MSIX folder.

.OUTPUTS
None. The function does not return any output.

.NOTES
Author: Your Name
Date: Current Date

.LINK
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            #ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder  
    )
    Begin {
       
        $PSFMonitorFiles = @("Dia2Lib.dll",
            "DynamicLibraryFixup32.dll",
            "DynamicLibraryFixup64.dll",
            "KernelTraceControl.dll",
            "KernelTraceControl.Win61.dll",
            "Microsoft.Diagnostics.FastSerialization.dll",
            "Microsoft.Diagnostics.Tracing.TraceEvent.dll",
            "msdia140.dll",
            "OSExtensions.dll",
            "PsfMonitor.exe",
            "PsfMonitorX64.exe",
            "PsfMonitorX86.exe")
    }    

    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            Write-Error "The MSIX temporary folder does not exist"
            return $null
        }

        foreach ($file in (Get-ChildItem $MSIXFolder -Recurse -Include $PSFMonitorFiles)) {
            Write-Verbose "Remove PSFMonitor File $($file.FullName)"
            Remove-Item $file.FullName
        }            
        
    }
}