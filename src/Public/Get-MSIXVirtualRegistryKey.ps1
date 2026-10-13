function Get-MSIXVirtualRegistryKey {
<#
.SYNOPSIS
    Lists the values and subkeys of a key in an MSIX registry hive file (Registry.dat / User.dat).

.DESCRIPTION
    Loads the hive file given by -HiveFilePath with RegLoadAppKey and returns one object per value
    (Type 'Value') and per subkey (Type 'Key') of -KeyPath (relative to the hive root:
    'REGISTRY\MACHINE\SOFTWARE\...' in Registry.dat, 'Software\...' in User.dat whose root is HKCU).
    Value data is decoded by its registry type:
    String/ExpandString -> string, MultiString -> string[], DWord -> UInt32, QWord -> UInt64,
    anything else -> byte[].

.EXAMPLE
    Get-MSIXVirtualRegistryKey -HiveFilePath "$pkg\Registry.dat" -KeyPath 'REGISTRY\MACHINE\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown'

.NOTES
    RegLoadAppKey works on the hive file directly (no reg load). Reading needs no administrative
    rights.
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
    $result = [Win32Apis]::RegLoadAppKey($HiveFilePath, [ref]$hKey, 0x20019, 0, 0)   # KEY_READ
    if ($result -ne 0) {
        throw "Failed to load hive '$HiveFilePath' (Win32 error $(Format-MSIXWin32Error $result))."
    }

    try {
        $subKeyHandle = [IntPtr]::Zero
        $result = [Win32Apis]::RegOpenKeyEx($hKey, $KeyPath, 0, 0x20019, [ref]$subKeyHandle)
        if ($result -ne 0) {
            throw "Failed to open key '$KeyPath' in hive '$HiveFilePath' (Win32 error $(Format-MSIXWin32Error $result))."
        }

        try {
            # --- Values ---
            # ERROR_MORE_DATA (234): retry the same index with larger buffers. lpcbData then holds the
            # required data size; value names can be up to 16383 characters.
            $nameCapacity = 1024
            $dataCapacity = 4096
            $index   = 0
            $retries = 0
            while ($true) {
                $valueName       = New-Object System.Text.StringBuilder $nameCapacity
                $valueNameLength = [uint32]$nameCapacity
                $valueData       = New-Object byte[] $dataCapacity
                $valueDataLength = [uint32]$dataCapacity
                $valueType       = [uint32]0
                $result = [Win32Apis]::RegEnumValue($subKeyHandle, [uint32]$index, $valueName, [ref]$valueNameLength,
                    [IntPtr]::Zero, [ref]$valueType, $valueData, [ref]$valueDataLength)

                if ($result -eq 234) {   # ERROR_MORE_DATA
                    if (++$retries -gt 5) {
                        throw "Value #$index of '$KeyPath' in hive '$HiveFilePath' does not fit into $dataCapacity bytes."
                    }
                    $nameCapacity = 16384
                    $dataCapacity = [Math]::Max([int]$valueDataLength, $dataCapacity * 2)
                    continue
                }
                if ($result -eq 259) { break }   # ERROR_NO_MORE_ITEMS
                if ($result -ne 0) {
                    throw "Failed to enumerate the values of '$KeyPath' in hive '$HiveFilePath' (Win32 error $(Format-MSIXWin32Error $result))."
                }

                $length = [int]$valueDataLength
                $kind   = [Microsoft.Win32.RegistryValueKind]$valueType
                switch ($kind) {
                    { $_ -in 'String', 'ExpandString' } {
                        $data = [System.Text.Encoding]::Unicode.GetString($valueData, 0, $length).TrimEnd([char]0)
                    }
                    'MultiString' {
                        $text = [System.Text.Encoding]::Unicode.GetString($valueData, 0, $length).TrimEnd([char]0)
                        if ($text) { $data = [string[]]($text -split "`0") } else { $data = [string[]]@() }
                    }
                    'DWord' {
                        if ($length -ge 4) { $data = [BitConverter]::ToUInt32($valueData, 0) } else { $data = $null }
                    }
                    'QWord' {
                        if ($length -ge 8) { $data = [BitConverter]::ToUInt64($valueData, 0) } else { $data = $null }
                    }
                    default {
                        $data = New-Object byte[] $length
                        [Array]::Copy($valueData, $data, $length)
                    }
                }

                [pscustomobject]@{
                    Type      = 'Value'
                    Name      = $valueName.ToString()
                    Data      = $data
                    ValueType = $kind
                }
                $index++
                $retries = 0
            }

            # --- Subkeys ---
            $nameCapacity = 1024
            $index   = 0
            $retries = 0
            while ($true) {
                $subKeyName       = New-Object System.Text.StringBuilder $nameCapacity
                $subKeyNameLength = [uint32]$nameCapacity
                $classLength      = [uint32]0
                $fileTime         = New-Object Win32Apis+FILETIME
                $result = [Win32Apis]::RegEnumKeyEx($subKeyHandle, [uint32]$index, $subKeyName, [ref]$subKeyNameLength,
                    [IntPtr]::Zero, $null, [ref]$classLength, [ref]$fileTime)

                if ($result -eq 234) {   # ERROR_MORE_DATA
                    if (++$retries -gt 5) {
                        throw "Subkey #$index of '$KeyPath' in hive '$HiveFilePath' has a name longer than $nameCapacity characters."
                    }
                    $nameCapacity *= 2
                    continue
                }
                if ($result -eq 259) { break }   # ERROR_NO_MORE_ITEMS
                if ($result -ne 0) {
                    throw "Failed to enumerate the subkeys of '$KeyPath' in hive '$HiveFilePath' (Win32 error $(Format-MSIXWin32Error $result))."
                }

                [pscustomobject]@{
                    Type      = 'Key'
                    Name      = $subKeyName.ToString()
                    Data      = $null
                    ValueType = $null
                }
                $index++
                $retries = 0
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
