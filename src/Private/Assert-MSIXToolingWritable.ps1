function Assert-MSIXToolingWritable {
<#
.SYNOPSIS
    Throws a clear error when the tooling folder cannot be written.

.DESCRIPTION
    For an AllUsers installation the tooling folder lies under Program Files
    (...\Modules\MSIXForcelets\Tooling), which a non-elevated session cannot write to. Called by the
    cmdlets that download or copy tooling so the user gets a hint instead of a bare "access denied"
    halfway through a download.
#>
    [CmdletBinding()]
    param()

    if ($WhatIfPreference) { return }

    if ($Script:ToolingPath.StartsWith($env:ProgramFiles, [System.StringComparison]::OrdinalIgnoreCase)) {
        $hint = 'This is an AllUsers installation - run the command from an elevated PowerShell.'
    }
    else {
        $hint = 'Check the folder permissions or set $env:MSIXFORCELETS_TOOLING to a writable folder.'
    }

    try {
        if (-not (Test-Path $Script:ToolingPath)) {
            New-Item -ItemType Directory -Path $Script:ToolingPath -Force -ErrorAction Stop | Out-Null
        }
        $probe = Join-Path $Script:ToolingPath ([System.IO.Path]::GetRandomFileName())
        [System.IO.File]::WriteAllText($probe, '')
        Remove-Item -Path $probe -Force -ErrorAction Stop
    }
    catch {
        throw "Tooling folder '$($Script:ToolingPath)' is not writable. $hint"
    }
}
