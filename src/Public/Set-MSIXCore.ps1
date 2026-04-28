function Set-MSIXCore {
<#
.SYNOPSIS
    Registers the msixmgr.exe alias for the current session.

.DESCRIPTION
    Locates msixmgr.exe inside the module's Data\MSIXCore\x64 folder and
    creates a script-scoped alias named 'msixmgr'. If the binary is not
    found a warning is written and the user is directed to run
    Update-MSIXForcelets.

.EXAMPLE
    Set-MSIXCore

.NOTES
    Called automatically when the module is imported.
    Andreas Nick, 2024
#>

    [CmdletBinding()]
    param()

    $Script:MSIXMgrPath = Join-Path $Script:MSIXCorePath "x64\msixmgr.exe"

    if (-not (Test-Path $Script:MSIXMgrPath)) {
        Write-Warning "msixmgr.exe not found at '$Script:MSIXMgrPath'. Run Update-MSIXTooling to download MSIX Core."
        return
    }

    if (-not (Get-Alias msixmgr -ErrorAction SilentlyContinue)) {
        New-Alias -Name msixmgr -Value $Script:MSIXMgrPath -Scope Script
    }

    Write-Verbose "msixmgr alias set to $Script:MSIXMgrPath"
}
