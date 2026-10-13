function Format-MSIXWin32Error {
<#
.SYNOPSIS
    Formats a Win32 error code as "<code> = <system message>", e.g. "5 = Access is denied".
#>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [int] $Code
    )

    '{0} = {1}' -f $Code, (New-Object System.ComponentModel.Win32Exception $Code).Message
}
