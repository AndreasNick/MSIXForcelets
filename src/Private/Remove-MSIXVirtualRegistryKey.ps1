function Remove-MSIXVirtualRegistryKey {
    <#
.SYNOPSIS
Removes a virtual registry key from an MSIX package.

.DESCRIPTION
The Remove-MSIXVirtualRegistryKey function is used to remove a virtual registry key from an MSIX package. This function can be used to clean up virtual registry keys that are no longer needed.

.PARAMETER KeyPath
Specifies the path of the virtual registry key to be removed.

.PARAMETER PackagePath
Specifies the path of the MSIX package from which the virtual registry key should be removed.

.EXAMPLE
Remove-MSIXVirtualRegistryKey -HiveFilePath "$env:userprofile\Desktop\Registry.dat" -KeyPath "REGISTRY\MACHINE\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown" -Verbose
This example removes the virtual registry key "HKCU\Software\MyApp" from the MSIX package located at "C:\MyApp.msix".

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
        [string]$KeyPath
    )

    $hKey = [IntPtr]::Zero
    $result = [Win32Apis]::RegLoadAppKey($HiveFilePath, [ref]$hKey, 0xF003F, 0, 0)
    if ($result -ne 0) {
        throw "Failed to load hive file with error code: $result"
    }

    try {
        $result = [Win32Apis]::RegDeleteKeyEx($hKey, $KeyPath, 0xF003F, 0)
        if ($result -ne 0) {
            throw "Failed to delete key with error code: $result"
        }
        else {
            Write-Host "Key '$KeyPath' deleted successfully."
        }
    }
    finally {
        $resVal = [Win32Apis]::RegCloseKey($hKey)
    }
}