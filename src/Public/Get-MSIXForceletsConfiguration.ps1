function Get-MSIXForceletsConfiguration {
<#
.SYNOPSIS
    Returns the current MSIXForcelets module configuration.

.DESCRIPTION
    Returns a copy of the module-wide configuration hashtable.
    Use Set-MSIXForceletsConfiguration to change values.

    Configuration keys and their defaults:

    PSFProcessEntryLauncher   ($true)
        Add ".*_PsfLauncher.*" named process entry to the processes section.

    PSFProcessEntryFtaCom     ($true)
        Add ".*_PsfFtaCom.*" named process entry for the shell extension /
        file type association COM surrogate process.

    PSFProcessEntryPowershell ($true)
        Add "^[Pp]ower[Ss]hell.*" named process entry for PowerShell wrapper scripts.

    PSFDefaultArchitecture       ('Auto')
        Default PE architecture used by Add-MSXIXPSFShim when -PSFArchitektur is
        not specified. Values: Auto | x64 | x86.

    PSFTimManganDebugLevel       (2)
        debugLevel value written into config.json when Tim Mangan PSF is active.
        Supported range: 0-5.

    CopyVCRuntime                ($true)
        Copy VC++ Runtime DLLs from the local Windows installation when
        downloading a PSF framework (Update-MSIXMicrosoftPSF,
        Update-MSIXTMPSF).

    KeepTempFolder               ($false)
        Keep the temporary MSIX extraction folder after Close-MSIXPackage.
        Useful for debugging package contents.

.EXAMPLE
    Get-MSIXForceletsConfiguration

.EXAMPLE
    (Get-MSIXForceletsConfiguration).PSFDefaultArchitecture

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param()

    # Return a shallow copy so the caller cannot accidentally mutate module state
    $copy = [ordered]@{}
    foreach ($key in $Script:MSIXForceletsConfig.Keys) {
        $copy[$key] = $Script:MSIXForceletsConfig[$key]
    }
    [PSCustomObject]$copy
}
