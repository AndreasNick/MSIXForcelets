function Set-MSIXVirtualRegistryKey {
<#
.SYNOPSIS
    Sets a value in an MSIX registry hive file (Registry.dat / User.dat) and creates the key if needed.

.DESCRIPTION
    Loads the hive file given by -HiveFilePath with RegLoadAppKey, creates -KeyPath (relative to the
    hive root: 'REGISTRY\MACHINE\SOFTWARE\...' in Registry.dat, 'Software\...' in User.dat whose root
    is HKCU) when it does not exist yet and writes the value -ValueName. -ValueData depends on -ValueType:
      String / ExpandString  text
      MultiString            string array (a single string is accepted as well)
      DWord / QWord          number, decimal or hex string ('0xFFFFFFFF'); negative numbers are
                             stored as two's complement, like reg.exe does
      Binary                 byte array, or a hex string ('01 02 FF', '01,02,FF' or '0102FF')

.EXAMPLE
    Set-MSIXVirtualRegistryKey -HiveFilePath "$pkg\Registry.dat" -KeyPath 'REGISTRY\MACHINE\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown' -ValueName 'bEnableProtectedModeAppContainer' -ValueData 1 -ValueType DWord

.NOTES
    RegLoadAppKey works on the hive file directly (no reg load). The keys in package hives usually
    allow writing only from an elevated PowerShell; reading works without.
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
        [string]$ValueName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [object]$ValueData,

        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryValueKind]$ValueType
    )

    # Converts DWord/QWord input into its little-endian bytes ($Size = 4 or 8).
    $toIntegerBytes = {
        param($Value, [int]$Size)
        $text = ([string]$Value).Trim()
        try {
            if ($text -match '^0[xX]([0-9a-fA-F]{1,16})$') {
                $number = [decimal][Convert]::ToUInt64($Matches[1], 16)
            }
            else {
                $number = [decimal]::Parse($text, [System.Globalization.NumberStyles]::Integer,
                    [System.Globalization.CultureInfo]::InvariantCulture)
            }
        }
        catch {
            throw "ValueData '$Value' is not a valid $ValueType number."
        }
        if ($Size -eq 4) {
            if ($number -lt [int32]::MinValue -or $number -gt [uint32]::MaxValue) {
                throw "ValueData '$Value' is out of range for a DWord (-2147483648 .. 0xFFFFFFFF)."
            }
            if ($number -lt 0) { return [BitConverter]::GetBytes([int32]$number) }
            return [BitConverter]::GetBytes([uint32]$number)
        }
        if ($number -lt [int64]::MinValue -or $number -gt [uint64]::MaxValue) {
            throw "ValueData '$Value' is out of range for a QWord."
        }
        if ($number -lt 0) { return [BitConverter]::GetBytes([int64]$number) }
        return [BitConverter]::GetBytes([uint64]$number)
    }

    switch ($ValueType) {
        { $_ -in 'String', 'ExpandString' } {
            $data = [System.Text.Encoding]::Unicode.GetBytes([string]$ValueData + [char]0)
        }
        'MultiString' {
            # Every string is null-terminated, the list ends with one more null character.
            $text = (@($ValueData) | ForEach-Object { [string]$_ + [char]0 }) -join ''
            $data = [System.Text.Encoding]::Unicode.GetBytes($text + [char]0)
        }
        'DWord' {
            $data = [byte[]](& $toIntegerBytes $ValueData 4)
        }
        'QWord' {
            $data = [byte[]](& $toIntegerBytes $ValueData 8)
        }
        'Binary' {
            if ($ValueData -is [byte[]]) {
                $data = $ValueData
            }
            elseif ($ValueData -is [array]) {
                $data = [byte[]]$ValueData
            }
            else {
                $hex = ([string]$ValueData) -replace '^0[xX]', '' -replace '[\s,\-]', ''
                if ($hex.Length % 2 -ne 0 -or $hex -notmatch '^[0-9a-fA-F]*$') {
                    throw "ValueData '$ValueData' is not a valid hex string for a Binary value."
                }
                $data = New-Object byte[] ($hex.Length / 2)
                for ($i = 0; $i -lt $data.Length; $i++) {
                    $data[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16)
                }
            }
        }
        default {
            throw "Unsupported ValueType '$ValueType' (supported: String, ExpandString, MultiString, DWord, QWord, Binary)."
        }
    }

    if (-not $PSCmdlet.ShouldProcess("$HiveFilePath : $KeyPath\$ValueName", "Set $ValueType value")) { return }

    $hKey = [IntPtr]::Zero
    $result = [Win32Apis]::RegLoadAppKey($HiveFilePath, [ref]$hKey, 0xF003F, 0, 0)   # KEY_ALL_ACCESS
    if ($result -ne 0) {
        $hint = ''
        if ($result -eq 5) { $hint = ' Writing to package hives usually requires an elevated PowerShell.' }
        throw "Failed to load hive '$HiveFilePath' (Win32 error $(Format-MSIXWin32Error $result)).$hint"
    }

    try {
        $subKeyHandle = [IntPtr]::Zero
        $disposition  = [uint32]0
        $result = [Win32Apis]::RegCreateKeyEx($hKey, $KeyPath, 0, $null, 0, 0xF003F, [IntPtr]::Zero, [ref]$subKeyHandle, [ref]$disposition)
        if ($result -ne 0) {
            throw "Failed to open or create key '$KeyPath' in hive '$HiveFilePath' (Win32 error $(Format-MSIXWin32Error $result))."
        }

        try {
            $result = [Win32Apis]::RegSetValueEx($subKeyHandle, $ValueName, 0, $ValueType, $data, $data.Length)
            if ($result -ne 0) {
                throw "Failed to set value '$ValueName' in '$KeyPath' of hive '$HiveFilePath' (Win32 error $(Format-MSIXWin32Error $result))."
            }
            Write-Verbose "Set '$KeyPath\$ValueName' ($ValueType) in '$HiveFilePath'."
        }
        finally {
            $null = [Win32Apis]::RegCloseKey($subKeyHandle)
        }
    }
    finally {
        $null = [Win32Apis]::RegCloseKey($hKey)
    }
}
