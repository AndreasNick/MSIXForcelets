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
    Default architecture for Add-MSIXPSFShim when -PSFArchitektur is omitted.
    Valid values: Auto, x64, x86. Default: Auto.

.PARAMETER PSFDebugLevel
    debugLevel written into config.json (applies to PSF forks that support it). Pick a named level
    ('0=Disable' ... '20=Debug supermax'); only the leading number is written. Default: 2.

.PARAMETER PSFEnableReportError
    enableReportError in config.json. $false (default) suppresses PSF's error dialogs; $true shows
    them - useful for debugging. Written on the next Add-MSIXPSFShim.

.PARAMETER CopyVCRuntime
    When $true (default), Update-MSIXMicrosoftPSF and Update-MSIXTMPSF
    copy VC++ Runtime DLLs from the local Windows installation.

.PARAMETER KeepTempFolder
    When $true, Close-MSIXPackage keeps the temporary extraction folder.
    Useful for inspecting package contents after repacking. Default: $false.

.EXAMPLE
    Set-MSIXForceletsConfiguration -PSFProcessEntryFtaCom $false

.EXAMPLE
    Set-MSIXForceletsConfiguration -PSFDefaultArchitecture x64 -PSFDebugLevel '0=Disable'

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

        [ValidateSet(
            '0=Disable', '1=Exceptions only', '2=Start/Launch (default)',
            '3=Debug basic', '4=Debug intermediate', '9=Debug maximum',
            '20=Debug supermax (PSF internal)'
        )]
        [string] $PSFDebugLevel,

        [System.Nullable[bool]] $PSFEnableReportError,

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
    if ($PSBoundParameters.ContainsKey('PSFDebugLevel')) {
        # Store the numeric debugLevel, parsed from the 'N=Label' choice.
        $Script:MSIXForceletsConfig.PSFDebugLevel = [int]($PSFDebugLevel -split '=')[0]
    }
    if ($PSBoundParameters.ContainsKey('PSFEnableReportError')) {
        $Script:MSIXForceletsConfig.PSFEnableReportError = $PSFEnableReportError
    }
    if ($PSBoundParameters.ContainsKey('CopyVCRuntime')) {
        $Script:MSIXForceletsConfig.CopyVCRuntime = $CopyVCRuntime
    }
    if ($PSBoundParameters.ContainsKey('KeepTempFolder')) {
        $Script:MSIXForceletsConfig.KeepTempFolder = $KeepTempFolder
    }
}
