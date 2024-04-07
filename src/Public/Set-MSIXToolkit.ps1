
function Set-MSIXToolkit {
    <#
    .SYNOPSIS
    Sets up the MSIX Toolkit by creating aliases for MakeAppx and signtool.
    
    .DESCRIPTION
    The Set-MSIXToolkit function sets up the MSIX Toolkit by creating aliases for MakeAppx and signtool executables. 
    If the MSIX Toolkit is not found in the specified path, a warning message is displayed.
    
    .PARAMETER None
    This function does not accept any parameters.
    
    .EXAMPLE
    Set-MSIXToolkit
    This example sets up the MSIX Toolkit by creating aliases for MakeAppx and signtool.
    #>
    
        [CmdletBinding()]
        param()  
        
        if (-not (Test-Path $Script:MSIXToolkitPath )) {
    
            Write-Warning "MSIX Toolkit not exist in $($Script:MSIXToolkitPath) - please Download" 
        }
        else {
    
            Write-Verbose "Assign Alias" 
            if (!(get-alias makeappx -ErrorAction SilentlyContinue)) {
                Write-Verbose "Create alias MakeAppx" 
                New-Alias -Name MakeAppx -value (Join-Path $Script:MSIXToolkitPath -childPath "makeappx.exe") -Scope Script
            }
        
    
            if (!(get-alias signtool -ErrorAction SilentlyContinue)) {
                $apath = (Join-Path $Script:MSIXToolkitPath -childPath "signtool.exe")
                Write-Verbose "Create alias signtool to $apath" 
                New-Alias -Name signtool -Value $apath -Scope Script #Global
            }
        }
    
    }
    