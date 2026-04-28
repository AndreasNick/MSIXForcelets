function Set-MSIXVirtualRegistryKey {
<#
.SYNOPSIS
    Sets a virtual registry key for an MSIX package.

.DESCRIPTION
    This function sets a virtual registry key for an MSIX package. It should only be run with administrative privileges.

.PARAMETER KeyPath
    Specifies the path of the virtual registry key to set.

.PARAMETER ValueName
    Specifies the name of the value to set.

.PARAMETER ValueData
    Specifies the data to set for the value.

.EXAMPLE
    Set-MSIXVirtualRegistryKey -HiveFilePath "$env:userprofile\Desktop\Registry.dat" -KeyPath "REGISTRY\MACHINE\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown" -ValueName "bEnableProtectedModeAppContainer" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)

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
        [string]$ValueName,
  
        [Parameter(Mandatory = $true)]
        [string]$ValueData,
  
        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryValueKind]$ValueType
    )
  
    # Lädt die Hive-Datei
    $hKey = [IntPtr]::Zero
    $result = [Win32Apis]::RegLoadAppKey($HiveFilePath, [ref]$hKey, 0xF003F, 0, 0) # 0xF003F = Vollzugriff
    if ($result -ne 0) {
        throw "Failed to load hive file with error code: $result"
    }
      
    try {
        $subKeyHandle = [IntPtr]::Zero
        $disposition = 0
        # Erstelle oder öffne den angegebenen Schlüssel
        $result = [Win32Apis]::RegCreateKeyEx($hKey, $KeyPath, 0, $null, 0, 0xF003F, [IntPtr]::Zero, [ref]$subKeyHandle, [ref]$disposition)
        if ($result -ne 0) {
            throw "Failed to open or create subkey with error code: $result"
        }
  
        try {
            $data = $null
            switch ($ValueType) {
                {'String', 'ExpandString' -eq $_} {
                    $data = [System.Text.Encoding]::Unicode.GetBytes($ValueData + "`0")
                    break
                }
                'DWord' {
                    $data = [BitConverter]::GetBytes([int]$ValueData)
                    break
                }
                'QWord' {
                    $data = [BitConverter]::GetBytes([long]$ValueData)
                    break
                }
                Default {
                    throw "Unsupported ValueType: $ValueType"
                }
            }

            $result = [Win32Apis]::RegSetValueEx($subKeyHandle, $ValueName, 0, $ValueType, $data, $data.Length)
            if ($result -ne 0) {
                throw "Failed to set registry value with error code: $result"
            }
        }
        finally {
            $resVal = [Win32Apis]::RegCloseKey($subKeyHandle)
        }
    }
    finally {
        $resVal = [Win32Apis]::RegCloseKey($hKey)
    }
}