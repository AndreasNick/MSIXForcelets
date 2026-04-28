function Get-MSIXVirtualRegistryKeysAndValues {
<#
.SYNOPSIS
Retrieves the virtual registry keys and values for an MSIX package.

.DESCRIPTION
This function retrieves the virtual registry keys and values associated with an MSIX package. It can be used to inspect the virtual registry settings of an MSIX package.

.PARAMETER PackageName
The name of the MSIX package.

.PARAMETER RegistryPath
The path to the registry key to retrieve the virtual keys and values from.
Get-MSIXVirtualRegistryKeysAndValues -HiveFilePath "$env:userprofile\Desktop\Registry.dat" -KeyPath "REGISTRY\MACHINE\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown" -Verbose
Get-MSIXVirtualRegistryKeysAndValues -HiveFilePath "$env:userprofile\Desktop\Registry.dat" -KeyPath "REGISTRY\MACHINE\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown\cDefaultExecMenuItems" -Verbose
Get-MSIXVirtualRegistryKeysAndValues -HiveFilePath "$env:userprofile\Desktop\Registry.dat" -KeyPath "REGISTRY\MACHINE\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown\cDefaultFindAttachmentPerms" -Verbose
Get-MSIXVirtualRegistryKeysAndValues -HiveFilePath "$env:userprofile\Desktop\Registry.dat" -KeyPath "REGISTRY\MACHINE\SOFTWARE"

.EXAMPLE


This example retrieves the virtual registry keys and values for the "MyApp.msix" package under the "HKCU\Software\MyApp" registry path.
.NOTES
# Work with user rights!
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
    $result = [Win32Apis]::RegLoadAppKey($HiveFilePath, [ref]$hKey, 0x20019, 0, 0)
    if ($result -ne 0) {
        throw "Failed to load hive file with error code: $result"
    }

    try {
        $subKeyHandle = [IntPtr]::Zero
        $result = [Win32Apis]::RegOpenKeyEx($hKey, $KeyPath, 0, 0x20019, [ref]$subKeyHandle)
        if ($result -ne 0) {
            throw "Failed to open subkey with error code: $result"
        }

        try {
            # Enumerate values
            $index = 0
            $properties = @()
            while ($true) {
                $valueName = New-Object Text.StringBuilder 1024
                $valueData = New-Object Byte[] 4096
                $valueDataLength = 4096
                $valueType = [uint32]0
                $valueNameLength = $valueName.Capacity

                $result = [Win32Apis]::RegEnumValue($subKeyHandle, $index, $valueName, [ref]$valueNameLength, [IntPtr]::Zero, [ref]$valueType, $valueData, [ref]$valueDataLength)

                if ($result -eq 234) {  # ERROR_MORE_DATA
                    continue
                } elseif ($result -eq 0) {
                    $data = [System.Text.Encoding]::Unicode.GetString($valueData, 0, $valueDataLength - 2)  # -2 to remove trailing null
                    $properties += [pscustomobject]@{
                        Type = 'Value'
                        Name = $valueName.ToString()
                        Data = $data
                        ValueType = [Microsoft.Win32.RegistryValueKind]$valueType
                    }
                } elseif ($result -eq 259) {  # ERROR_NO_MORE_ITEMS
                    break
                } else {
                    throw "Failed to enumerate values with error code: $result"
                }
                $index++
            }

            # Enumerate subkeys
           $index = 0
      while ($true) {
        $subKeyName = New-Object Text.StringBuilder 1024
        $subKeyNameLength = $subKeyName.Capacity
        $fileTime = New-Object Win32Apis+FILETIME  # Neue Instanz von FILETIME
        $result = [Win32Apis]::RegEnumKeyEx($subKeyHandle, $index, $subKeyName, [ref]$subKeyNameLength, [IntPtr]::Zero, $null, [ref]0, [ref]$fileTime)

        if ($result -eq 234) {  # ERROR_MORE_DATA
          continue
        } elseif ($result -eq 0) {
          $properties += [pscustomobject]@{
            Type = 'Key'
            Name = $subKeyName.ToString()
            Data = $null
            ValueType = $null
          }
        } elseif ($result -eq 259) {  # ERROR_NO_MORE_ITEMS
          break
        } else {
          throw "Failed to enumerate keys with error code: $result"
        }
        $index++
      }

            # Output all properties and subkeys
            $properties | ForEach-Object { Write-Output $_ }
        } finally {
            $resVal = [Win32Apis]::RegCloseKey($subKeyHandle) 
        }
    } finally {
        $resVal = [Win32Apis]::RegCloseKey($hKey) 
    }
}

<#
    function Get-RegistryKeyValuesWork {
    [CmdletBinding()]
    param (
    [Parameter(Mandatory = $true)]
    [string]$HiveFilePath,

    [Parameter(Mandatory = $true)]
    [string]$KeyPath
    )

    $hKey = [IntPtr]::Zero
    $result = [Win32Apis]::RegLoadAppKey($HiveFilePath, [ref]$hKey, 0x20019, 0, 0)
    if ($result -ne 0) {
    throw "Failed to load hive file with error code: $result"
    }

    try {
    $subKeyHandle = [IntPtr]::Zero
        $result = [Win32Apis]::RegOpenKeyEx($hKey, $KeyPath, 0, 0x20019, [ref]$subKeyHandle)
        if ($result -ne 0) {
          if($result -eq 2){
            Write-verbose "key not found"
          }
          if($result -eq 32){
            Write-verbose "structure is in use"
          }
      
            throw "Failed to open subkey with error code: $result"
            
        }

        try {
            $index = 0
            $valueName = New-Object Text.StringBuilder 256
            $valueData = New-Object Byte[] 256
            $valueType = [uint32]0

            while ($true) {
                $valueNameLength = $valueName.Capacity
                $valueDataLength = $valueData.Length
                $result = [Win32Apis]::RegEnumValue($subKeyHandle, $index, $valueName, [ref]$valueNameLength, [IntPtr]::Zero, [ref]$valueType, $valueData, [ref]$valueDataLength)

                if ($result -eq 234) {  # ERROR_MORE_DATA
                    $valueName.Capacity = $valueNameLength + 1
                    $valueData = New-Object Byte[] ($valueDataLength + 1)
                    continue
                } elseif ($result -eq 0) {
                    $data = [System.Text.Encoding]::Unicode.GetString($valueData, 0, $valueDataLength - 2)  # -2 to remove trailing null
                    $name = $valueName.ToString()
                    $type = [Microsoft.Win32.RegistryValueKind]$valueType
                    Write-Output "$name = $data (Type: $type)"
                } elseif ($result -eq 259) {  # ERROR_NO_MORE_ITEMS
                    break
                } else {
                    throw "Failed to enumerate values with error code: $result"
                }
                
                $index++
                $valueName.Length = 0
            }
        } finally {
            [Win32Apis]::RegCloseKey($subKeyHandle)
        }
    } finally {
        [Win32Apis]::RegCloseKey($hKey)
    }
    }
#>
