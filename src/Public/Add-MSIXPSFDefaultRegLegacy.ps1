function Add-MSIXPSFDefaultRegLegacy {
<#
.SYNOPSIS
    Adds a standard RegLegacyFixups configuration to an MSIX package.

.DESCRIPTION
    Applies a comprehensive default RegLegacyFixups rule set by calling
    Add-MSIXPSFRegLegacyFixup with the following configuration:

    ModifyKeyAccess HKCU Full2MaxAllowed — full access -> MAXIMUM_ALLOWED
    ModifyKeyAccess HKCU RW2MaxAllowed   — read/write  -> MAXIMUM_ALLOWED
    ModifyKeyAccess HKLM Full2R          — full access -> read-only
    ModifyKeyAccess HKLM RW2R            — read/write  -> read-only
    FakeDelete      HKCU                 — suppress ACCESS_DENIED on key deletions

    All five rules are compatible with both Microsoft PSF and Tim Mangan PSF.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain config.json.xml).

.PARAMETER Executable
    Regex pattern for the process entry. Default: ".*" (all processes).

.PARAMETER AllowRedirectHKLMWrites
    When set, also adds an HKLM2HKCU rule that redirects HKLM writes to virtual
    HKCU. Requires Tim Mangan PSF — the call will error if Microsoft PSF is active.

.EXAMPLE
    Add-MSIXPSFDefaultRegLegacy -MSIXFolder "C:\MSIXTemp\MyApp"

.EXAMPLE
    Add-MSIXPSFDefaultRegLegacy -MSIXFolder "C:\MSIXTemp\MyApp" -AllowRedirectHKLMWrites

.NOTES
    Microsoft PSF: https://github.com/microsoft/MSIX-PackageSupportFramework/tree/main/fixups/RegLegacyFixups
    Tim Mangan PSF: https://github.com/TimMangan/MSIX-PackageSupportFramework/wiki/Fixup:-RegLegacyFixup
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [String] $Executable = '.*',

        [Switch] $AllowRedirectHKLMWrites
    )

    process {
        Add-MSIXPSFRegLegacyFixup -MSIXFolder $MSIXFolder -Executable $Executable `
            -ModifyKeyAccess -Hive HKCU -Patterns @('.*') -Access Full2MaxAllowed

        Add-MSIXPSFRegLegacyFixup -MSIXFolder $MSIXFolder -Executable $Executable `
            -ModifyKeyAccess -Hive HKCU -Patterns @('.*') -Access RW2MaxAllowed

        Add-MSIXPSFRegLegacyFixup -MSIXFolder $MSIXFolder -Executable $Executable `
            -ModifyKeyAccess -Hive HKLM -Patterns @('.*') -Access Full2R

        Add-MSIXPSFRegLegacyFixup -MSIXFolder $MSIXFolder -Executable $Executable `
            -ModifyKeyAccess -Hive HKLM -Patterns @('.*') -Access RW2R

        Add-MSIXPSFRegLegacyFixup -MSIXFolder $MSIXFolder -Executable $Executable `
            -FakeDelete -Hive HKCU -Patterns @('.*')

        if ($AllowRedirectHKLMWrites) {
            Add-MSIXPSFRegLegacyFixup -MSIXFolder $MSIXFolder -Executable $Executable `
                -HKLM2HKCU -Hive HKLM
        }
    }
}
