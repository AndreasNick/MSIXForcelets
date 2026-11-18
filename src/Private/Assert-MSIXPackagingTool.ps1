function Assert-MSIXPackagingTool {
<#
.SYNOPSIS
    Throws a clear error when makeappx.exe is missing from the tooling folder.

.DESCRIPTION
    Without the Windows SDK packaging tools the bare MakeAppx call fails with "not recognized as the
    name of a cmdlet", which does not tell the user that the tooling is missing or how to get it.
#>
    [CmdletBinding()]
    param()

    if (-not (Test-Path (Join-Path $Script:MSIXPackagingPath 'makeappx.exe'))) {
        throw ("Windows SDK packaging tools (makeappx.exe) not found in '$($Script:MSIXPackagingPath)'. " +
            'Run Install-MSIXForceletsAllRequirements.')
    }
}
