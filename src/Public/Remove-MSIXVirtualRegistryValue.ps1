function Remove-MSIXVirtualRegistryValue {
<#
.SYNOPSIS
    Removes a value from a key in an MSIX registry hive file (Registry.dat / User.dat).

.DESCRIPTION
    Loads the hive file given by -HiveFilePath with RegLoadAppKey and deletes -ValueName from
    -KeyPath (relative to the hive root: 'REGISTRY\MACHINE\SOFTWARE\...' in Registry.dat,
    'Software\...' in User.dat whose root is HKCU). A missing key or value is not an error - the
    call is idempotent.

.EXAMPLE
    Remove-MSIXVirtualRegistryValue -HiveFilePath "$pkg\Registry.dat" -KeyPath 'REGISTRY\MACHINE\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown' -ValueName 'bEnableProtectedModeAppContainer'

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

        [Parameter(Mandatory = $true)]
        [string]$ValueName
    )

    # Check read-only first: a missing key or value needs no write access, so the idempotent case
    # also works without elevation (package hives usually allow writing only when elevated).
    $hKey = [IntPtr]::Zero
    $result = [Win32Apis]::RegLoadAppKey($HiveFilePath, [ref]$hKey, 0x20019, 0, 0)   # KEY_READ
    if ($result -ne 0) {
        throw "Failed to load hive '$HiveFilePath' (Win32 error $(Format-MSIXWin32Error $result))."
    }
    $present = $true
    try {
        $subKeyHandle = [IntPtr]::Zero
        $result = [Win32Apis]::RegOpenKeyEx($hKey, $KeyPath, 0, 0x20019, [ref]$subKeyHandle)
        if ($result -eq 2) {
            $present = $false
        }
        elseif ($result -eq 0) {
            $subKey = [Microsoft.Win32.RegistryKey]::FromHandle((New-Object Microsoft.Win32.SafeHandles.SafeRegistryHandle $subKeyHandle, $true))
            try { $present = $subKey.GetValueNames() -contains $ValueName } finally { $subKey.Dispose() }
        }
    }
    finally {
        $null = [Win32Apis]::RegCloseKey($hKey)
    }
    if (-not $present) {
        Write-Verbose "Value '$KeyPath\$ValueName' not present in '$HiveFilePath' - nothing to remove."
        return
    }

    if (-not $PSCmdlet.ShouldProcess("$HiveFilePath : $KeyPath\$ValueName", 'Remove value')) { return }

    $hKey = [IntPtr]::Zero
    $result = [Win32Apis]::RegLoadAppKey($HiveFilePath, [ref]$hKey, 0xF003F, 0, 0)   # KEY_ALL_ACCESS
    if ($result -ne 0) {
        $hint = ''
        if ($result -eq 5) { $hint = ' Writing to package hives usually requires an elevated PowerShell.' }
        throw "Failed to load hive '$HiveFilePath' (Win32 error $(Format-MSIXWin32Error $result)).$hint"
    }

    try {
        $subKeyHandle = [IntPtr]::Zero
        $result = [Win32Apis]::RegOpenKeyEx($hKey, $KeyPath, 0, 0xF003F, [ref]$subKeyHandle)
        if ($result -eq 2) {
            Write-Verbose "Key '$KeyPath' not present in '$HiveFilePath' - nothing to remove."
            return
        }
        if ($result -ne 0) {
            throw "Failed to open key '$KeyPath' in hive '$HiveFilePath' (Win32 error $(Format-MSIXWin32Error $result))."
        }

        try {
            $result = [Win32Apis]::RegDeleteValue($subKeyHandle, $ValueName)
            if ($result -eq 2) {
                Write-Verbose "Value '$ValueName' not present in '$KeyPath' - nothing to remove."
            }
            elseif ($result -ne 0) {
                throw "Failed to delete value '$ValueName' from '$KeyPath' in hive '$HiveFilePath' (Win32 error $(Format-MSIXWin32Error $result))."
            }
            else {
                Write-Verbose "Removed value '$KeyPath\$ValueName' from '$HiveFilePath'."
            }
        }
        finally {
            $null = [Win32Apis]::RegCloseKey($subKeyHandle)
        }
    }
    finally {
        $null = [Win32Apis]::RegCloseKey($hKey)
    }
}
