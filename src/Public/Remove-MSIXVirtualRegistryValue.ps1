function Remove-MSIXVirtualRegistryValue {
<#
.SYNOPSIS
Removes a value from a virtual registry key in an MSIX package.

.DESCRIPTION
The Remove-MSIXVirtualRegistryValue function removes a specified value from a virtual registry key in an MSIX package.
It loads the hive file, opens the subkey, and deletes the specified value.

.PARAMETER HiveFilePath
The path to the hive file of the MSIX package.

.PARAMETER KeyPath
The path to the virtual registry key.

.PARAMETER ValueName
The name of the value to be deleted.

.EXAMPLE
Remove-MSIXVirtualRegistryValue -HiveFilePath "$env:userprofile\Desktop\Registry.dat" -KeyPath "REGISTRY\MACHINE\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown"  -ValueName "bEnableProtectedModeAppContainer"
Removes the value named "Setting1" from the virtual registry key "HKCU\Software\MyApp" in the MSIX package located at "C:\Package.hiv".
Get-MSIXVirtualRegistryKeysAndValues -HiveFilePath "$env:userprofile\Desktop\Registry.dat" -KeyPath "REGISTRY\MACHINE\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown" -Verbose

.NOTES
Only run this function with administrative privileges.
https://www.nick-it.de
Andreas Nick, 2024
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$HiveFilePath,

        [Parameter(Mandatory = $true)]
        [string]$KeyPath,

        [Parameter(Mandatory = $true)]
        [string]$ValueName
    )

    $hKey = [IntPtr]::Zero
    $result = [Win32Apis]::RegLoadAppKey($HiveFilePath, [ref]$hKey, 0xF003F, 0, 0)
    if ($result -ne 0) {
        throw "Failed to load hive file with error code: $result"
    }

    try {
        $subKeyHandle = [IntPtr]::Zero
        $result = [Win32Apis]::RegOpenKeyEx($hKey, $KeyPath, 0, 0xF003F, [ref]$subKeyHandle)
        if ($result -ne 0) {
            throw "Failed to open subkey with error code: $result"
        }

        try {
            $result = [Win32Apis]::RegDeleteValue($subKeyHandle, $ValueName)
            if ($result -ne 0) {
                throw "Failed to delete value '$ValueName' with error code: $result"
            } else {
                Write-Host "Value '$ValueName' deleted successfully."
            }
        } finally {
            $resVal = [Win32Apis]::RegCloseKey($subKeyHandle)
        }
    } finally {
        $resVal =  [Win32Apis]::RegCloseKey($hKey)
    }
}
