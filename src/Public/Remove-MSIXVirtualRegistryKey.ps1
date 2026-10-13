function Remove-MSIXVirtualRegistryKey {
<#
.SYNOPSIS
    Removes a key from an MSIX registry hive file (Registry.dat / User.dat).

.DESCRIPTION
    Loads the hive file given by -HiveFilePath with RegLoadAppKey and deletes -KeyPath (relative to
    the hive root: 'REGISTRY\MACHINE\SOFTWARE\...' in Registry.dat, 'Software\...' in User.dat whose
    root is HKCU). Without -Recurse only a
    key without subkeys can be removed (RegDeleteKeyEx); with -Recurse the key and all its subkeys
    are deleted (RegDeleteTree). A missing key is not an error - the call is idempotent.

.EXAMPLE
    Remove-MSIXVirtualRegistryKey -HiveFilePath "$pkg\Registry.dat" -KeyPath 'REGISTRY\MACHINE\SOFTWARE\Microsoft\.NETFramework' -Recurse

.NOTES
    RegLoadAppKey works on the hive file directly (no reg load). The keys in package hives usually
    allow writing only from an elevated PowerShell; reading - and a removal with nothing to remove -
    works without.
    https://www.nick-it.de
    Andreas Nick, 2024
#>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$HiveFilePath,

        [Parameter(Mandatory = $true)]
        [string]$KeyPath,

        [switch]$Recurse
    )

    # Check read-only first: a missing key needs no write access, so the idempotent case also works
    # without elevation (package hives usually allow writing only from an elevated PowerShell).
    $hKey = [IntPtr]::Zero
    $result = [Win32Apis]::RegLoadAppKey($HiveFilePath, [ref]$hKey, 0x20019, 0, 0)   # KEY_READ
    if ($result -ne 0) {
        throw "Failed to load hive '$HiveFilePath' (Win32 error $(Format-MSIXWin32Error $result))."
    }
    try {
        $subKeyHandle = [IntPtr]::Zero
        $result = [Win32Apis]::RegOpenKeyEx($hKey, $KeyPath, 0, 0x20019, [ref]$subKeyHandle)
        if ($result -eq 0) { $null = [Win32Apis]::RegCloseKey($subKeyHandle) }
    }
    finally {
        $null = [Win32Apis]::RegCloseKey($hKey)
    }
    if ($result -eq 2) {
        Write-Verbose "Key '$KeyPath' not present in '$HiveFilePath' - nothing to remove."
        return
    }

    if (-not $PSCmdlet.ShouldProcess("$HiveFilePath : $KeyPath", 'Remove key')) { return }

    $hKey = [IntPtr]::Zero
    $result = [Win32Apis]::RegLoadAppKey($HiveFilePath, [ref]$hKey, 0xF003F, 0, 0)   # KEY_ALL_ACCESS
    if ($result -ne 0) {
        $hint = ''
        if ($result -eq 5) { $hint = ' Writing to package hives usually requires an elevated PowerShell.' }
        throw "Failed to load hive '$HiveFilePath' (Win32 error $(Format-MSIXWin32Error $result)).$hint"
    }

    try {
        if ($Recurse) {
            $result = [Win32Apis]::RegDeleteTree($hKey, $KeyPath)
        }
        else {
            # samDesired only selects the WOW64 view (KEY_WOW64_32KEY/64KEY) - not used for app hives.
            $result = [Win32Apis]::RegDeleteKeyEx($hKey, $KeyPath, 0, 0)
        }

        if ($result -eq 2) {
            Write-Verbose "Key '$KeyPath' not present in '$HiveFilePath' - nothing to remove."
        }
        elseif ($result -ne 0) {
            $hint = ''
            if ($result -eq 5 -and -not $Recurse) { $hint = ' Use -Recurse if the key has subkeys.' }
            throw "Failed to delete key '$KeyPath' in hive '$HiveFilePath' (Win32 error $(Format-MSIXWin32Error $result)).$hint"
        }
        else {
            Write-Verbose "Removed key '$KeyPath' from '$HiveFilePath'."
        }
    }
    finally {
        $null = [Win32Apis]::RegCloseKey($hKey)
    }
}
