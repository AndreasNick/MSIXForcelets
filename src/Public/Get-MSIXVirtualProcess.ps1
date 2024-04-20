<#
.SYNOPSIS
Retrieves information about virtual processes associated with MSIX packages.

.DESCRIPTION
The Get-MSIXVirtualProcess function retrieves information about virtual processes associated with MSIX packages installed in the specified directory.

.PARAMETER MSIXInstallPath
Optional: Specifies the directory where the MSIX packages are installed. The default value is "C:\Program Files\WindowsApps\".

.EXAMPLE
Get-MSIXVirtualProcess  # -MSIXInstallPath "C:\Program Files\WindowsApps\" #Default MSIX folder
This example retrieves information about virtual processes associated with MSIX packages installed in the default directory.

.OUTPUTS
System.Diagnostics.Process
The function returns a collection of Process objects representing the virtual processes associated with MSIX packages.

.NOTES
https://www.nick-it.de
Andreas Nick, 2024
#>
function Get-MSIXVirtualProcess {
    [CmdletBinding()]   

    Param(
        [Parameter(Position = 0)]
        [Alias("Path")]
        [string]$MSIXInstallPath = 'C:\Program Files\WindowsApps\',
        [switch]$ShowMicrosoftApps,
        [Switch]$OutputList
       
    )
    
    
    $MSIXAppList = Get-Process | Where-Object { $_.Path -like "$MSIXInstallPath*" -and (($_.Company -notlike "Microsoft Corporation") -or ($ShowMicrosoftApps -eq $true)) } | Select-Object -Property Name, StartTime, Description, Company, Product, Id, Path
        
    if ($OutputList) {
        $MSIXAppList | Format-List
    }
    else {
        $MSIXAppList | Format-Table
    }
}
