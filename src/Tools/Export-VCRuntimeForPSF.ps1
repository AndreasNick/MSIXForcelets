<#
.SYNOPSIS
    Copies the VC++ runtime DLLs the PSF fixups need from this machine into a Desktop folder.

.DESCRIPTION
    The PSF fixup DLLs (FileRedirection, MFR, RegLegacy, DynamicLibrary, EnvVar) import
    msvcp140.dll / vcruntime140.dll (x64 also vcruntime140_1.dll). Tim Mangan's PSF does not ship
    them, so Update-MSIXTMPSF takes them from System32/SysWOW64 - which fails on a packaging
    machine without the VC++ Redistributable. This script collects them on a machine that has
    them, in the PSF folder layout (amd64\ = x64 from System32, win32\ = x86 from SysWOW64).
    Copy both folders into each PSF build folder afterwards, e.g.
    <Modules>\MSIXForcelets\Tooling\MSIXPSF\TimManganPSF\2026.10.13_release\
    msvcp140_1/_2 are not imported by the PSF but expected by Add-MSIXPsfFrameworkFiles, so
    they are collected as well.

.EXAMPLE
    & (Join-Path (Get-Module MSIXForcelets -ListAvailable | Select-Object -First 1).ModuleBase 'Tools\Export-VCRuntimeForPSF.ps1')

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
#>
[CmdletBinding()]
param(
    [string] $Destination = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'VCRuntime-PSF'),
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

# A 32-bit PowerShell on 64-bit Windows sees SysWOW64 behind "System32"; Sysnative is the real one.
$system64 = Join-Path $env:windir 'System32'
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $system64 = Join-Path $env:windir 'Sysnative'
}

$sets = @(
    @{ Folder = 'amd64'; Source = $system64;                         Machine = 0x8664
       Files  = @('msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') }
    @{ Folder = 'win32'; Source = (Join-Path $env:windir 'SysWOW64'); Machine = 0x014C
       Files  = @('msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll', 'vcruntime140.dll') }
)

# Reads the machine type from the PE header (0x8664 = x64, 0x014C = x86).
function Get-PEMachine([string] $Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
    return [BitConverter]::ToUInt16($bytes, $peOffset + 4)
}

if ((Test-Path -LiteralPath $Destination) -and -not $Force) {
    throw "Destination already exists: $Destination (use -Force to overwrite)."
}

$missing = 0
$report  = foreach ($set in $sets) {
    $targetDir = Join-Path $Destination $set.Folder
    $null = New-Item -ItemType Directory -Path $targetDir -Force
    foreach ($name in $set.Files) {
        $source = Join-Path $set.Source $name
        if (-not (Test-Path -LiteralPath $source)) {
            Write-Warning "Not found on this machine: $source"
            $missing++
            continue
        }
        $machine = Get-PEMachine $source
        if ($machine -ne $set.Machine) {
            Write-Warning ("Skipped {0}: wrong architecture (0x{1:X4}) for {2}\" -f $source, $machine, $set.Folder)
            $missing++
            continue
        }
        Copy-Item -LiteralPath $source -Destination $targetDir -Force
        $version = (Get-Item -LiteralPath $source).VersionInfo.FileVersion
        Write-Verbose "Copied $source -> $($set.Folder)\"
        [pscustomobject]@{ Folder = $set.Folder; File = $name; Version = $version }
    }
}

# Keep a record of where the files came from (version of the installed redistributable).
$info = Join-Path $Destination 'SOURCE.txt'
@(
    "VC++ runtime DLLs for the MSIX Package Support Framework"
    "Collected from: $env:COMPUTERNAME on $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    ''
    ($report | Format-Table -AutoSize | Out-String).TrimEnd()
) | Set-Content -LiteralPath $info -Encoding UTF8

$report | Format-Table -AutoSize
if ($missing -gt 0) {
    Write-Warning "$missing file(s) missing - install the VC++ Redistributable (x64 and x86) on this machine and run again."
}
Write-Output "Done: $Destination - copy amd64\ and win32\ into each PSF build folder (..._release and ..._debug)."
