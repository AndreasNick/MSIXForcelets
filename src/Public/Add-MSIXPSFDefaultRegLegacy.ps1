function Add-MSIXPSFDefaultRegLegacy {
<#
.SYNOPSIS
    Adds a standard RegLegacyFixups configuration to an MSIX package.

.DESCRIPTION
    Applies a comprehensive default RegLegacyFixups rule set by calling
    Add-MSIXPSFRegLegacyFixup with the following configuration:

    ModifyKeyAccess HKCU Full2MaxAllowed — full access -> MAXIMUM_ALLOWED
    ModifyKeyAccess HKCU RW2MaxAllowed   — read/write  -> MAXIMUM_ALLOWED
    ModifyKeyAccess HKLM Full2R          — full access -> read-only  (omitted with -AllowRedirectHKLMWrites)
    ModifyKeyAccess HKLM RW2R            — read/write  -> read-only  (omitted with -AllowRedirectHKLMWrites)
    FakeDelete      HKCU                 — suppress ACCESS_DENIED on key deletions

    The HKCU rules and FakeDelete are compatible with both Microsoft PSF and Tim Mangan PSF.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain config.json.xml).

.PARAMETER Executable
    Regex pattern for the process entry. Default: ".*" (all processes).

.PARAMETER AllowRedirectHKLMWrites
    When set, adds an HKLM2HKCU rule that redirects HKLM writes to virtual HKCU AND
    omits the two HKLM read-only ModifyKeyAccess rules (Full2R/RW2R). Those would
    downgrade HKLM key opens to read-only, and that downgraded access mask is reused
    for the redirected HKCU open — leaving the redirect target read-only and defeating
    the redirect. The two approaches are mutually exclusive: force HKLM read-only, OR
    redirect HKLM writes to HKCU. Requires Tim Mangan PSF — errors if Microsoft PSF is active.

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

        # The HKLM read-only downgrade (Full2R/RW2R) is MUTUALLY EXCLUSIVE with HKLM2HKCU
        # redirection, so it is only emitted when we are NOT redirecting HKLM writes.
        # Verified against the Tim Mangan RegLegacyFixups source: on a HKLM key OPEN,
        # RegFixupSam matches the HKLM rule against the ORIGINAL HKLM path and strips the
        # write bits (KEY_SET_VALUE/KEY_CREATE_SUB_KEY/KEY_WRITE). The resulting read-only
        # access mask is then reused for the redirected HKCU open (RegOpenKeyEx.cpp), so the
        # redirect target ends up opened read-only and writes still fail - which defeats the
        # whole point of HKLM2HKCU. (RegCreateKeyEx recomputes the mask on the HKCU path and is
        # unaffected, but apps usually OPEN existing keys to write values.)
        if (-not $AllowRedirectHKLMWrites) {
            Add-MSIXPSFRegLegacyFixup -MSIXFolder $MSIXFolder -Executable $Executable `
                -ModifyKeyAccess -Hive HKLM -Patterns @('.*') -Access Full2R

            Add-MSIXPSFRegLegacyFixup -MSIXFolder $MSIXFolder -Executable $Executable `
                -ModifyKeyAccess -Hive HKLM -Patterns @('.*') -Access RW2R
        }

        Add-MSIXPSFRegLegacyFixup -MSIXFolder $MSIXFolder -Executable $Executable `
            -FakeDelete -Hive HKCU -Patterns @('.*')

        if ($AllowRedirectHKLMWrites) {
            Add-MSIXPSFRegLegacyFixup -MSIXFolder $MSIXFolder -Executable $Executable `
                -HKLM2HKCU -Hive HKLM
        }
    }
}
