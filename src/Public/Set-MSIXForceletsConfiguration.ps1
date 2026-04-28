function Set-MSIXForceletsConfiguration {
<#
.SYNOPSIS
    Changes one or more MSIXForcelets module configuration values.

.DESCRIPTION
    Updates the module-wide configuration that controls default behaviour across
    all MSIXForcelets functions.  Only the parameters you supply are changed;
    all others keep their current value.

    Run Get-MSIXForceletsConfiguration to see the full current state.

.PARAMETER PSFProcessEntryLauncher
    When $true (default), fixup functions add a ".*_PsfLauncher.*" named process
    entry to the PSF processes section.

.PARAMETER PSFProcessEntryFtaCom
    When $true (default), add a ".*_PsfFtaCom.*" named process entry for the
    shell extension / file type association COM surrogate.

.PARAMETER PSFProcessEntryPowershell
    When $true (default), add a "^[Pp]ower[Ss]hell.*" named process entry for
    PowerShell wrapper scripts.

.PARAMETER PSFDefaultArchitecture
    Default architecture for Add-MSXIXPSFShim when -PSFArchitektur is omitted.
    Valid values: Auto, x64, x86. Default: Auto.

.PARAMETER PSFTimManganDebugLevel
    debugLevel value written into config.json when Tim Mangan PSF is active.
    Range 0-5. Default: 2.

.PARAMETER CopyVCRuntime
    When $true (default), Update-MSIXMicrosoftPSF and Update-MSIXTMPSF
    copy VC++ Runtime DLLs from the local Windows installation.

.PARAMETER KeepTempFolder
    When $true, Close-MSIXPackage keeps the temporary extraction folder.
    Useful for inspecting package contents after repacking. Default: $false.

.EXAMPLE
    Set-MSIXForceletsConfiguration -PSFProcessEntryFtaCom $false

.EXAMPLE
    Set-MSIXForceletsConfiguration -PSFDefaultArchitecture x64 -PSFTimManganDebugLevel 0

.EXAMPLE
    Set-MSIXForceletsConfiguration -KeepTempFolder $true

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [System.Nullable[bool]] $PSFProcessEntryLauncher,
        [System.Nullable[bool]] $PSFProcessEntryFtaCom,
        [System.Nullable[bool]] $PSFProcessEntryPowershell,

        [ValidateSet('Auto', 'x64', 'x86')]
        [String] $PSFDefaultArchitecture,

        [ValidateRange(0, 5)]
        [System.Nullable[int]] $PSFTimManganDebugLevel,

        [System.Nullable[bool]] $CopyVCRuntime,
        [System.Nullable[bool]] $KeepTempFolder
    )

    if ($PSBoundParameters.ContainsKey('PSFProcessEntryLauncher')) {
        $Script:MSIXForceletsConfig.PSFProcessEntryLauncher = $PSFProcessEntryLauncher
    }
    if ($PSBoundParameters.ContainsKey('PSFProcessEntryFtaCom')) {
        $Script:MSIXForceletsConfig.PSFProcessEntryFtaCom = $PSFProcessEntryFtaCom
    }
    if ($PSBoundParameters.ContainsKey('PSFProcessEntryPowershell')) {
        $Script:MSIXForceletsConfig.PSFProcessEntryPowershell = $PSFProcessEntryPowershell
    }
    if ($PSBoundParameters.ContainsKey('PSFDefaultArchitecture')) {
        $Script:MSIXForceletsConfig.PSFDefaultArchitecture = $PSFDefaultArchitecture
    }
    if ($PSBoundParameters.ContainsKey('PSFTimManganDebugLevel')) {
        $Script:MSIXForceletsConfig.PSFTimManganDebugLevel = $PSFTimManganDebugLevel
    }
    if ($PSBoundParameters.ContainsKey('CopyVCRuntime')) {
        $Script:MSIXForceletsConfig.CopyVCRuntime = $CopyVCRuntime
    }
    if ($PSBoundParameters.ContainsKey('KeepTempFolder')) {
        $Script:MSIXForceletsConfig.KeepTempFolder = $KeepTempFolder
    }
}
