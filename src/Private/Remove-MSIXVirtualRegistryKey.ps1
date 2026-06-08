function Remove-MSIXVirtualRegistryKey {
<#
.SYNOPSIS
    Removes a virtual registry key from an MSIX hive file (Registry.dat / User.dat).
.PARAMETER HiveFilePath
    Path to the hive file, e.g. "$pkg\Registry.dat".
.PARAMETER KeyPath
    Key path relative to the hive root, e.g.
    'REGISTRY\MACHINE\SOFTWARE\Microsoft\.NETFramework'.
.PARAMETER Recurse
    Delete the key AND all its subkeys (RegDeleteTree). Without it only an empty
    leaf key is removed (RegDeleteKeyEx).
.EXAMPLE
    Remove-MSIXVirtualRegistryKey -HiveFilePath "$pkg\Registry.dat" `
        -KeyPath 'REGISTRY\MACHINE\SOFTWARE\Microsoft\.NETFramework' -Recurse
.NOTES
    RegLoadAppKey needs write access to the hive (may require elevation).
    https://www.nick-it.de
    Andreas Nick, 2024
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$HiveFilePath,

        [Parameter(Mandatory = $true)]
        [string]$KeyPath,

        [switch]$Recurse
    )

    $hKey = [IntPtr]::Zero
    $result = [Win32Apis]::RegLoadAppKey($HiveFilePath, [ref]$hKey, 0xF003F, 0, 0)
    if ($result -ne 0) {
        throw "Failed to load hive '$HiveFilePath' (error $result; 5 = access denied, may need elevation)."
    }

    try {
        if ($Recurse) {
            $result = [Win32Apis]::RegDeleteTree($hKey, $KeyPath)
        }
        else {
            $result = [Win32Apis]::RegDeleteKeyEx($hKey, $KeyPath, 0xF003F, 0)
        }

        if ($result -eq 2) {
            Write-Verbose "Key '$KeyPath' not present - nothing to remove."
        }
        elseif ($result -ne 0) {
            throw "Failed to delete key '$KeyPath' (error $result)."
        }
        else {
            Write-Verbose "Removed virtual registry key '$KeyPath'."
        }
    }
    finally {
        $null = [Win32Apis]::RegCloseKey($hKey)
    }
}
