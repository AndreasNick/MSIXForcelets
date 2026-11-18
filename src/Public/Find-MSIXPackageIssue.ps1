function Find-MSIXPackageIssue {
<#
.SYNOPSIS
    Analyses an expanded MSIX package and lists likely problems with the Forcelets commands that address them.

.DESCRIPTION
    Read-only analysis of the package files, AppxManifest.xml and the registry hives (Registry.dat,
    User.dat, UserClasses.dat), following the package analysis of the MSIX Editor. Returns one object
    per finding (Severity, Category, Title, Detail, Recommendation, Command, AutoFix, Locations); use
    Export-Clixml or ConvertTo-Json to store them. With -FixScriptPath a fix script is written: AutoFix
    commands are active, everything that needs a decision is commented out. When a known application
    is detected, the script runs its Add-MSIXFix* function instead of the generic steps.
    InstalledLocationVirtualization is always proposed; the PSF only when a rule finds a reason for it,
    or with -ForcePSF (launcher, MFRFixup and RegLegacy defaults for every application).
    Commands refer to the package folder as $Package.

.EXAMPLE
    Find-MSIXPackageIssue -MSIXFolder $Package -FixScriptPath C:\Temp\Fix-MyApp.ps1 | Format-Table Severity, Title, AutoFix -Wrap
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [string] $FixScriptPath,

        # Adds the PSF with MFRFixup and RegLegacy defaults even when no rule asks for it.
        [switch] $ForcePSF
    )

    begin {
        $machine     = 'REGISTRY\MACHINE'
        $user        = 'REGISTRY\USER\[{AppVCurrentUserSID}]'
        $userClasses = 'REGISTRY\USER\[{AppVCurrentUserSID}]_CLASSES'

        # Stage orders the commands in the fix script: 0 known fix, 1 files, 2 manifest, 3 registry, 4 PSF.
        function Write-Finding {
            param(
                [string] $Severity, [string] $Category, [string] $Title, [string] $Detail, [string] $Recommendation,
                [string[]] $Command = @(), [bool] $AutoFix = $false, [string[]] $Locations = @(), [int] $Stage = 2
            )
            [PSCustomObject]@{
                Severity       = $Severity
                Category       = $Category
                Title          = $Title
                Detail         = $Detail
                Recommendation = $Recommendation
                Command        = $Command
                AutoFix        = $AutoFix
                Locations      = $Locations
                Stage          = $Stage
            }
        }

        function ConvertTo-Literal {
            param([string] $Text)
            "'" + $Text.Replace("'", "''") + "'"
        }

        # "[{ProgramFilesX64}]\Vendor\x.exe" -> "VFS\ProgramFilesX64\Vendor\x.exe"; $null for anything else.
        function Resolve-VfsToken {
            param([string] $Value)
            if (-not $Value) { return $null }
            $v = $Value.Trim().Trim('"').TrimEnd('\')
            if ($v -notmatch '^\[\{([^}\]]+)\}\]\\?(.*)$') { return $null }
            $folder = $Matches[1]
            $rest = $Matches[2]
            if (@($rest -split '\\') -contains '..') { return $null }
            if ($rest) { "VFS\$folder\$rest" } else { "VFS\$folder" }
        }

        # Splits '"C:\a b\x.exe" -arg' or 'x.exe -arg' into executable and arguments.
        function Split-CommandLine {
            param([string] $CommandLine)
            $s = $CommandLine.Trim()
            if ($s.StartsWith('"')) {
                $end = $s.IndexOf('"', 1)
                if ($end -lt 0) { return @($s.Trim('"'), '') }
                return @($s.Substring(1, $end - 1), $s.Substring($end + 1).Trim())
            }
            $exe = $s.IndexOf('.exe', [System.StringComparison]::OrdinalIgnoreCase)
            if ($exe -ge 0) { return @($s.Substring(0, $exe + 4), $s.Substring($exe + 4).Trim()) }
            $sp = $s.IndexOf(' ')
            if ($sp -lt 0) { return @($s, '') }
            @($s.Substring(0, $sp), $s.Substring($sp + 1).Trim())
        }

        # PE header data of a file: Kind (PE, Win16, Dos, None), Machine (x86, x64, arm64, ...) and the DLL
        # names of the import table (lower case). Reads only headers and the import directory.
        function Get-PEInfo {
            param([string] $Path)
            $info = [PSCustomObject]@{ Kind = 'None'; Machine = ''; Imports = @() }
            try {
                $stream = [System.IO.File]::OpenRead($Path)
            }
            catch {
                Write-Verbose "Cannot open '$Path': $($_.Exception.Message)"
                return $info
            }
            $names = New-Object System.Collections.Generic.List[string]
            try {
                $reader = New-Object System.IO.BinaryReader($stream)
                if ($stream.Length -lt 0x40 -or $reader.ReadUInt16() -ne 0x5A4D) { return $info }
                # MZ without a newer header is a DOS program; 'NE' marks a 16-bit Windows program.
                $info.Kind = 'Dos'
                $stream.Position = 0x3C
                $peOffset = $reader.ReadInt32()
                if ($peOffset -le 0 -or ($peOffset + 24) -gt $stream.Length) { return $info }
                $stream.Position = $peOffset
                $signature = $reader.ReadUInt32()
                if (($signature -band 0xFFFF) -eq 0x454E) { $info.Kind = 'Win16'; return $info }
                if ($signature -ne 0x4550) { return $info }
                $info.Kind = 'PE'
                $machineType = $reader.ReadUInt16()
                $info.Machine = switch ($machineType) { 0x14C { 'x86' } 0x8664 { 'x64' } 0xAA64 { 'arm64' } 0x1C4 { 'arm' } default { 'other' } }
                $sectionCount = $reader.ReadUInt16()
                $stream.Position = $peOffset + 20
                $optionalSize = $reader.ReadUInt16()
                $optionalStart = $peOffset + 24
                $stream.Position = $optionalStart
                $magic = $reader.ReadUInt16()
                $dataDirectories = if ($magic -eq 0x20B) { $optionalStart + 112 } else { $optionalStart + 96 }
                $stream.Position = $dataDirectories + 8
                $importRva = [long] $reader.ReadUInt32()
                if ($importRva -eq 0) { return $info }

                $sections = @()
                for ($i = 0; $i -lt $sectionCount; $i++) {
                    $stream.Position = $optionalStart + $optionalSize + 40 * $i + 8
                    $virtualSize = [long] $reader.ReadUInt32()
                    $virtualAddress = [long] $reader.ReadUInt32()
                    $rawSize = [long] $reader.ReadUInt32()
                    $rawPointer = [long] $reader.ReadUInt32()
                    $sections += , @($virtualAddress, [Math]::Max($virtualSize, $rawSize), $rawPointer)
                }
                $toOffset = {
                    param([long] $Rva)
                    foreach ($section in $sections) {
                        if ($Rva -ge $section[0] -and $Rva -lt ($section[0] + $section[1])) { return $Rva - $section[0] + $section[2] }
                    }
                    return -1
                }

                $descriptor = & $toOffset $importRva
                if ($descriptor -lt 0) { return $info }
                for ($n = 0; $n -lt 4096; $n++) {
                    $stream.Position = $descriptor + 20 * $n + 12
                    $nameRva = [long] $reader.ReadUInt32()
                    if ($nameRva -eq 0) { break }
                    $nameOffset = & $toOffset $nameRva
                    if ($nameOffset -lt 0 -or $nameOffset -ge $stream.Length) { continue }
                    $stream.Position = $nameOffset
                    $bytes = $reader.ReadBytes(256)
                    $end = [Array]::IndexOf($bytes, [byte] 0)
                    if ($end -lt 0) { $end = $bytes.Length }
                    $names.Add([System.Text.Encoding]::ASCII.GetString($bytes, 0, $end).ToLowerInvariant())
                }
            }
            catch {
                Write-Verbose "No import table read from '$Path': $($_.Exception.Message)"
            }
            finally {
                $stream.Dispose()
                $info.Imports = $names.ToArray()
            }
            $info
        }

        # Embedded application manifest of an executable: requested execution level and uiAccess.
        # The manifest resource is stored as plain text.
        function Get-ExeManifestInfo {
            param([string] $Path)
            $info = [PSCustomObject]@{ Level = ''; UiAccess = $false }
            $file = Get-Item -LiteralPath $Path
            if ($file.Length -gt 128MB) { return $info }
            $text = [System.Text.Encoding]::GetEncoding(28591).GetString([System.IO.File]::ReadAllBytes($Path))
            $element = [regex]::Match($text, '<requestedExecutionLevel[^>]*>')
            if ($element.Success) {
                $level = [regex]::Match($element.Value, 'level\s*=\s*["''](\w+)["'']')
                if ($level.Success) { $info.Level = $level.Groups[1].Value }
                $info.UiAccess = [regex]::IsMatch($element.Value, 'uiAccess\s*=\s*["'']true["'']', 'IgnoreCase')
            }
            $info
        }

        # Fix script line that copies a runtime DLL from this machine into VFS\SystemX64 / VFS\SystemX86.
        function Get-RuntimeCopyCommand {
            param([string] $Dll, [string] $Arch)
            $systemFolder = if ($Arch -eq 'x86') { 'SysWOW64' } else { 'System32' }
            $vfsFolder = if ($Arch -eq 'x86') { 'VFS\SystemX86' } else { 'VFS\SystemX64' }
            "`$src = Join-Path `$env:SystemRoot '$systemFolder\$Dll'; if (Test-Path -LiteralPath `$src) { `$dst = Join-Path `$Package '$vfsFolder'; `$null = New-Item -ItemType Directory -Path `$dst -Force; Copy-Item -LiteralPath `$src -Destination `$dst -Force } else { Write-Warning '$Dll ($Arch) is not on this machine - install the runtime or copy the file manually.' }"
        }

        # Opens a package hive read-only as RegistryKey (RegLoadAppKey, no administrative rights needed).
        function Open-PackageHive {
            param([string] $Path)
            if (-not (Test-Path -LiteralPath $Path)) { return $null }
            $handle = [IntPtr]::Zero
            $result = [Win32Apis]::RegLoadAppKey($Path, [ref] $handle, 0x20019, 0, 0)   # KEY_READ
            if ($result -ne 0) {
                throw "Failed to load hive '$Path' (Win32 error $(Format-MSIXWin32Error $result))."
            }
            [Microsoft.Win32.RegistryKey]::FromHandle((New-Object Microsoft.Win32.SafeHandles.SafeRegistryHandle($handle, $true)))
        }
    }

    process {
        $root = $MSIXFolder.FullName.TrimEnd('\')
        $manifestPath = Join-Path $root 'AppxManifest.xml'
        if (-not (Test-Path -LiteralPath $manifestPath)) {
            Write-Error "AppxManifest.xml not found in: $root"
            return
        }

        $manifestText = [System.IO.File]::ReadAllText($manifestPath)
        $manifest = New-Object System.Xml.XmlDocument
        $manifest.LoadXml($manifestText)
        $mentions = { param([string] $Text) $manifestText.IndexOf($Text, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 }

        $files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
                [PSCustomObject]@{ Path = $_.FullName.Substring($root.Length + 1); Name = $_.Name; FullName = $_.FullName; Length = $_.Length }
            })
        $shippedNames = @{}
        foreach ($f in $files) { $shippedNames[$f.Name.ToLowerInvariant()] = $true }

        $apps = @($manifest.SelectNodes("//*[local-name()='Application']") | Where-Object { $_.GetAttribute('Executable') } | ForEach-Object {
                [PSCustomObject]@{ Id = $_.GetAttribute('Id'); Executable = $_.GetAttribute('Executable') }
            })
        $primaryApp = $apps | Select-Object -First 1
        $hasPsf = (Test-Path -LiteralPath (Join-Path $root 'config.json.xml')) -or (Test-Path -LiteralPath (Join-Path $root 'config.json')) -or
            @($apps | Where-Object { $_.Executable -like '*PsfLauncher*' }).Count -gt 0
        $appTargets = @($apps | Where-Object { $_.Executable -notlike '*PsfLauncher*' -and (Test-Path -LiteralPath (Join-Path $root $_.Executable)) })
        # Win16 applications get their own launcher entry (OTVDM); the generic PSF block skips them.
        $win16RuntimeFolder = 'VFS\ProgramFilesX86\otvdm'
        $win16Apps = @($appTargets | Where-Object {
                $f = Join-Path $root $_.Executable
                (Get-Item -LiteralPath $f).Length -gt 0 -and (Get-PEInfo $f).Kind -eq 'Win16'
            })
        $appTargets = @($appTargets | Where-Object { $win16Apps -notcontains $_ })
        $appForExe = {
            param([string] $Exe)
            $match = @($apps | Where-Object { $_.Executable -eq $Exe }) | Select-Object -First 1
            if ($match) { $match } else { $primaryApp }
        }

        $hives = @{}
        $findings = New-Object System.Collections.Generic.List[object]
        foreach ($hiveName in 'Registry.dat', 'User.dat', 'UserClasses.dat') {
            try {
                $key = Open-PackageHive (Join-Path $root $hiveName)
                if ($null -ne $key) { $hives[$hiveName] = $key }
            }
            catch {
                $findings.Add((Write-Finding Error 'Analysis' "Hive '$hiveName' could not be read" $_.Exception.Message `
                            'Registry rules for this hive did not run; the package is NOT checked in this respect.' -Stage 9))
            }
        }

        # Registry roots as (hive, path below the hive root, readable prefix).
        $softwareRoots = @(
            @('Registry.dat', "$machine\SOFTWARE", 'HKLM\SOFTWARE'),
            @('Registry.dat', "$machine\SOFTWARE\WOW6432Node", 'HKLM\SOFTWARE\WOW6432Node'),
            @('Registry.dat', "$user\SOFTWARE", 'HKCU\SOFTWARE'),
            @('User.dat', 'Software', 'HKCU\Software')
        )
        $classRoots = @(
            @('Registry.dat', "$machine\SOFTWARE\Classes", 'HKLM\SOFTWARE\Classes'),
            @('Registry.dat', "$machine\SOFTWARE\WOW6432Node\Classes", 'HKLM\SOFTWARE\WOW6432Node\Classes'),
            @('Registry.dat', $userClasses, 'HKCU\Software\Classes'),
            @('Registry.dat', "$user\SOFTWARE\Classes", 'HKCU\SOFTWARE\Classes'),
            @('User.dat', 'Software\Classes', 'HKCU\Software\Classes'),
            @('UserClasses.dat', '', 'HKCU\Software\Classes')
        )
        $joinPath = { param([string] $Base, [string] $Child) if ($Base) { "$Base\$Child" } else { $Child } }

        # Every opened subkey is disposed at the end; an open handle keeps the hive file locked.
        $openedKeys = New-Object System.Collections.Generic.List[object]
        $openKey = {
            param([string] $Hive, [string] $Path)
            if (-not $hives.ContainsKey($Hive)) { return $null }
            if ($Path -eq '') { return $hives[$Hive] }
            $k = $hives[$Hive].OpenSubKey($Path)
            if ($null -ne $k) { $openedKeys.Add($k) }
            $k
        }
        # Short reads open and close their key immediately (class roots can hold thousands of keys).
        $subKeys = {
            param([string] $Hive, [string] $Path)
            if (-not $hives.ContainsKey($Hive)) { return @() }
            if ($Path -eq '') { return @($hives[$Hive].GetSubKeyNames()) }
            $k = $hives[$Hive].OpenSubKey($Path)
            if ($null -eq $k) { return @() }
            try { @($k.GetSubKeyNames()) } finally { $k.Dispose() }
        }
        $regValue = {
            param([string] $Hive, [string] $Path, [string] $Name)
            if (-not $hives.ContainsKey($Hive)) { return $null }
            if ($Path -eq '') { return $hives[$Hive].GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) }
            $k = $hives[$Hive].OpenSubKey($Path)
            if ($null -eq $k) { return $null }
            try { $k.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) } finally { $k.Dispose() }
        }
        $valueNames = {
            param([string] $Hive, [string] $Path)
            if (-not $hives.ContainsKey($Hive)) { return @() }
            if ($Path -eq '') { return @($hives[$Hive].GetValueNames()) }
            $k = $hives[$Hive].OpenSubKey($Path)
            if ($null -eq $k) { return @() }
            try { @($k.GetValueNames()) } finally { $k.Dispose() }
        }

        # PE data of all executables and DLLs (except the PSF), read once on first use.
        $peState = @{ Table = $null }
        $getPE = {
            if ($null -eq $peState.Table) {
                $table = @{}
                foreach ($f in $files) {
                    if ($f.Name -notmatch '\.(exe|dll)$' -or $f.Name -match '^Psf' -or $f.Name -match 'Fixup' -or $f.Length -eq 0) { continue }
                    $table[$f.Path] = Get-PEInfo $f.FullName
                }
                $peState.Table = $table
            }
            $peState.Table
        }

        # Squirrel layout: Update.exe next to app-<version> folders.
        $squirrel = $null
        foreach ($update in @($files | Where-Object { $_.Name -eq 'Update.exe' })) {
            $dir = Split-Path $update.Path -Parent
            $versions = @($files | Where-Object { (Split-Path (Split-Path $_.Path -Parent) -Parent) -eq $dir -and (Split-Path (Split-Path $_.Path -Parent) -Leaf) -match '^app-(\d+(\.\d+)*)' } |
                    ForEach-Object { Split-Path (Split-Path $_.Path -Parent) -Leaf } | Select-Object -Unique)
            if ($versions.Count -gt 0) {
                $latest = $versions | Sort-Object {
                    $v = ($_ -replace '^app-', '') -replace '[^\d.].*$', ''
                    if ($v -notmatch '\.') { $v += '.0' }
                    [version] $v
                } | Select-Object -Last 1
                $squirrel = [PSCustomObject]@{ Dir = $dir; Update = $update.Path; Latest = $(& $joinPath $dir $latest); Versions = $versions }
                break
            }
        }

        $rules = [ordered]@{}

        # ================================================================ known applications
        $rules['Known applications'] = {
            $known = @(
                @{ Pattern = '^WinRAR\.exe$'; Fix = 'Add-MSIXFixWinRAR'; App = 'WinRAR'; Note = 'For the Windows 11 modern context menu use Add-MSIXFixWinRARModernShell instead.' },
                @{ Pattern = '^notepad\+\+\.exe$'; Fix = 'Add-MSIXFixNotepadPlusPlus'; App = 'Notepad++'; Note = '' },
                @{ Pattern = '^soffice\.(exe|bin)$'; Fix = 'Add-MSIXFixLibreOffice'; App = 'LibreOffice'; Note = '' },
                @{ Pattern = '^AcroRd32\.exe$'; Fix = 'Add-MSIXFixAcrobatReaderDC'; App = 'Acrobat Reader DC'; Note = '' },
                @{ Pattern = '^gimp-\d[\d.]*\.exe$'; Fix = 'Add-MSIXFixGimp'; App = 'GIMP'; Note = '' },
                @{ Pattern = '^SumatraPDF\.exe$'; Fix = 'Add-MSIXFixSumatraPDF'; App = 'SumatraPDF'; Note = '' },
                @{ Pattern = '^Ssms\.exe$'; Fix = 'SSMS'; App = 'SQL Server Management Studio'; Note = '' }
            )
            # Only next to a manifest application: a bundled copy deeper in the package (e.g. the SumatraPDF
            # viewer inside RStudio) does not make the package that application.
            $appFolders = @($apps | ForEach-Object { Split-Path $_.Executable -Parent } | Select-Object -Unique)
            foreach ($k in $known) {
                $hit = @($files | Where-Object { $_.Name -match $k.Pattern -and $appFolders -contains (Split-Path $_.Path -Parent) }) | Select-Object -First 1
                if (-not $hit) { continue }
                $fix = $k.Fix
                if ($fix -eq 'SSMS') {
                    $major = 0
                    try { $major = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($hit.FullName).FileMajorPart } catch { Write-Verbose "No version info: $($hit.Path)" }
                    $fix = if ($major -ge 21) { 'Add-MSIXFixSSMS22' } else { 'Add-MSIXFixSSMS' }
                }
                $detail = ("The package contains $($hit.Path). $fix applies the tested fixes for this application. " + $k.Note).Trim()
                Write-Finding Info 'Known application' "$($k.App) detected: $fix is available" $detail `
                    "Run $fix on the .msix file instead of the generic steps." `
                    -Command @("$fix -MsixFile `$MsixFile -OutputFilePath `$OutputFile -Force") -AutoFix $true -Locations @($hit.Path) -Stage 0
            }
        }

        # ================================================================ package errors
        $rules['Empty executables'] = {
            $hits = @($files | Where-Object { $_.Name -match '\.(exe|dll)$' -and $_.Length -eq 0 } | ForEach-Object Path)
            if ($hits.Count -gt 0) {
                Write-Finding Error 'Package' 'Executables or DLLs with 0 bytes' `
                    'The files were not captured correctly; the application fails when it loads them.' `
                    'Capture the package again; this cannot be fixed in the package.' -Locations $hits -Stage 1
            }
        }
        $rules['16-bit executables'] = {
            $pe = & $getPE
            $win16 = @($pe.Keys | Where-Object { $_ -like '*.exe' -and $pe[$_].Kind -eq 'Win16' })
            if ($win16.Count -gt 0) {
                $cmd = @(
                    "if (`$Win16RuntimePath) { `$dst = Join-Path `$Package '$win16RuntimeFolder'; `$null = New-Item -ItemType Directory -Path `$dst -Force; Copy-Item -Path (Join-Path `$Win16RuntimePath '*') -Destination `$dst -Recurse -Force } else { Write-Warning 'No -Win16RuntimePath given: the 16-bit applications will not start.' }",
                    'Add-MSIXPsfFrameworkFiles -MSIXFolder $Package'
                )
                foreach ($app in $win16Apps) {
                    $dir = Split-Path $app.Executable -Parent
                    $cmd += "`$null = Add-MSIXPSFShim -MSIXFolder `$Package -MSIXAppID $(ConvertTo-Literal $app.Id) -PSFArchitektur x64 -LauncherExecutable '$win16RuntimeFolder\otvdm.exe' -Arguments $(ConvertTo-Literal (Split-Path $app.Executable -Leaf)) -WorkingDirectory $(ConvertTo-Literal $dir)"
                }
                Write-Finding Warning 'Runtime' '16-bit Windows (Win16) executables' `
                    '64-bit Windows has no 16-bit subsystem. OTVDM (winevdm, github.com/otya128/winevdm) runs Win16 programs and can be packaged with the application.' `
                    'Put OTVDM into the package and start the applications through it (fix script parameter -Win16RuntimePath = folder with otvdm.exe).' `
                    -Command $cmd -AutoFix ($win16Apps.Count -gt 0) -Locations $win16 -Stage 4
            }
            $dos = @($pe.Keys | Where-Object { $_ -like '*.exe' -and $pe[$_].Kind -eq 'Dos' })
            if ($dos.Count -gt 0) {
                Write-Finding Warning 'Runtime' 'DOS executables' `
                    '64-bit Windows cannot run DOS programs. An emulator such as DOSBox or vDos can be packaged with the application.' `
                    'Put the emulator into the package and start the program through it (Add-MSIXPSFShim -LauncherExecutable <emulator> -Arguments <program>).' -Locations $dos -Stage 4
            }
        }
        $rules['Missing files referenced by the manifest'] = {
            $missing = @()
            foreach ($node in @($manifest.SelectNodes("//*[@Executable]"))) {
                $exe = $node.GetAttribute('Executable')
                if ($exe -match '^\[\{|:|^%') { continue }
                if (-not (Test-Path -LiteralPath (Join-Path $root $exe))) { $missing += "$($node.LocalName) Executable=$exe" }
            }
            $imageAttributes = 'Square150x150Logo', 'Square44x44Logo', 'Wide310x150Logo', 'Square71x71Logo', 'Square310x310Logo', 'BadgeLogo', 'Image', 'Logo'
            $images = @()
            foreach ($node in @($manifest.SelectNodes("//*[@*]"))) {
                foreach ($attr in $imageAttributes) {
                    $v = $node.GetAttribute($attr)
                    if ($v -and $v -notmatch '^\[\{|:|^ms-') { $images += , @($node.LocalName, $attr, $v) }
                }
            }
            foreach ($logo in @($manifest.SelectNodes("//*[local-name()='Properties']/*[local-name()='Logo']"))) { $images += , @('Properties', 'Logo', $logo.InnerText) }
            foreach ($img in $images) {
                $rel = $img[2]
                if (Test-Path -LiteralPath (Join-Path $root $rel)) { continue }
                # Resource qualifiers: Logo.png is resolved to Logo.scale-100.png, Logo.targetsize-44.png ...
                $dir = Split-Path $rel -Parent
                $base = [System.IO.Path]::GetFileNameWithoutExtension($rel)
                $ext = [System.IO.Path]::GetExtension($rel)
                $qualified = @($files | Where-Object { (Split-Path $_.Path -Parent) -eq $dir -and $_.Name -like "$base.*$ext" })
                if ($qualified.Count -eq 0) { $missing += "$($img[0]) $($img[1])=$rel" }
            }
            if ($missing.Count -gt 0) {
                Write-Finding Error 'Package' 'Manifest references files that are not in the package' `
                    'Deployment or start fails, or the tiles stay empty.' `
                    'Add the files or correct the references (Set-MSIXApplication -Executable, New-MSIXAssetFrom for logos).' -Locations $missing -Stage 2
            }
        }
        $rules['Architecture and VFS folder'] = {
            $pe = & $getPE
            $hits = @()
            foreach ($path in @($appTargets | ForEach-Object Executable)) {
                if (-not $pe.ContainsKey($path)) { continue }
                if ($path -like 'VFS\ProgramFilesX64\*' -and $pe[$path].Machine -eq 'x86') { $hits += "$path (x86 in ProgramFilesX64)" }
                if ($path -like 'VFS\ProgramFilesX86\*' -and $pe[$path].Machine -eq 'x64') { $hits += "$path (x64 in ProgramFilesX86)" }
            }
            if ($hits.Count -gt 0) {
                Write-Finding Warning 'Package' 'Executables in the VFS folder of the other architecture' `
                    'The application sees a different Program Files folder than at installation; paths written to the registry or configuration may not match.' `
                    'Check the start; if it fails, capture the package again on a matching system.' -Locations $hits -Stage 1
            }
        }

        # ================================================================ files
        $rules['Installer and uninstaller files'] = {
            $hits = @($files | Where-Object { $_.Name -match '^(unins.*\.exe|uninstall.*\.exe|uninstaller.*|setup\.exe|install\.exe|_isres.*|autorun\.inf|setup\.msi)$' } | ForEach-Object Path)
            if ($hits.Count -gt 0) {
                Write-Finding Warning 'Files' 'Installer or uninstaller files in the package' `
                    'Windows removes MSIX packages itself; bundled uninstallers do nothing useful or damage the container.' `
                    'Delete the files (check first that the application does not start them itself).' `
                    -Command @($hits | ForEach-Object { "Remove-Item -LiteralPath (Join-Path `$Package $(ConvertTo-Literal $_)) -Force" }) -Locations $hits -Stage 1
            }
        }
        $rules['Updaters'] = {
            $hits = @($files | Where-Object {
                    $_.Name -notmatch '^(psf|msvc|vcruntime|api-ms-win-|msix)' -and
                    (-not $squirrel -or $_.Path -ne $squirrel.Update) -and
                    ($_.Name -match '(updater?\.exe$|updatesvc|sparkle|squirrel|googleupdate|edgeupdate|omaha|autoupdate|maintenanceservice)' -or
                    ($_.Path -like '*\Tasks\*' -and $_.Name -like '*.xml'))
                } | ForEach-Object Path)
            if ($hits.Count -gt 0) {
                Write-Finding Info 'Files' 'Auto-updater found' `
                    'An updater cannot update an MSIX package (package files are read-only).' `
                    'Delete the updater and distribute updates as new package versions; disable the update check in the application settings if possible.' `
                    -Command @($hits | ForEach-Object { "Remove-Item -LiteralPath (Join-Path `$Package $(ConvertTo-Literal $_)) -Force" }) -Locations $hits -Stage 1
            }
        }
        $rules['Desktop shortcuts'] = {
            $hits = @($files | Where-Object {
                    $_.Name -like '*.lnk' -and ($_.Path -like 'VFS\Common Desktop\*' -or $_.Path -like 'VFS\ThisPCDesktopFolder\*' -or $_.Path -like '*\Desktop\*')
                } | ForEach-Object Path)
            if ($hits.Count -gt 0) {
                $cmd = @($hits | ForEach-Object { "Remove-Item -LiteralPath (Join-Path `$Package $(ConvertTo-Literal $_)) -Force" })
                if ($primaryApp) { $cmd += "# Add-MSIXDesktop7Shortcut -MSIXFolder `$Package -AppId $(ConvertTo-Literal $primaryApp.Id) -Location '[{Desktop}]'" }
                Write-Finding Warning 'Files' 'Desktop shortcuts in the package' `
                    'Shortcuts in the VFS are not created on the desktop.' `
                    'Delete them; a desktop shortcut is added with Add-MSIXDesktop7Shortcut (per-user location).' `
                    -Command $cmd -AutoFix $true -Locations $hits -Stage 1
            }
        }
        $rules['URL shortcuts'] = {
            $hits = @($files | Where-Object { $_.Name -like '*.url' -and $_.Path -like 'VFS\*' } | ForEach-Object Path)
            if ($hits.Count -gt 0) {
                Write-Finding Info 'Files' 'Internet shortcuts (.url) in the package' `
                    'Internet shortcuts in the VFS do not appear in the Start menu.' `
                    'Remove them or offer the link inside the application.' -Locations $hits -Stage 1
            }
        }
        $rules['Nested packages and App Installer files'] = {
            $hits = @($files | Where-Object { $_.Name -match '\.(msix|appx|msixbundle|appxbundle)$' } | ForEach-Object Path)
            if ($hits.Count -gt 0) {
                Write-Finding Warning 'Files' 'Nested MSIX/APPX packages' `
                    'Packages inside the package are not installed. A sparse package often carries a shell extension (IExplorerCommand).' `
                    'Shell extension: merge it with Import-MSIXSparseShellExtension. Otherwise deploy it separately and declare it as a dependency.' `
                    -Command @($hits | ForEach-Object { "# Import-MSIXSparseShellExtension -MSIXFolder `$Package -SparsePackagePath $(ConvertTo-Literal $_)" }) -Locations $hits -Stage 2
            }
            $installer = @($files | Where-Object { $_.Name -like '*.appinstaller' } | ForEach-Object Path)
            if ($installer.Count -gt 0) {
                Write-Finding Info 'Files' 'App Installer file inside the package' `
                    'An .appinstaller file inside the package has no function; update settings belong next to the package.' `
                    'Delete it.' -Command @($installer | ForEach-Object { "Remove-Item -LiteralPath (Join-Path `$Package $(ConvertTo-Literal $_)) -Force" }) -AutoFix $true -Locations $installer -Stage 1
            }
        }
        $rules['Fonts'] = {
            $hits = @($files | Where-Object { $_.Name -match '\.(ttf|otf|ttc)$' } | ForEach-Object Path)
            if ($hits.Count -gt 0 -and -not (& $mentions 'windows.sharedFonts')) {
                $fontsFolder = @($hits | Where-Object { $_ -like 'VFS\Fonts\*' })
                Write-Finding Info 'Files' 'Fonts without SharedFonts extension' `
                    'Fonts in the package are only visible to the application.' `
                    'Declare the fonts with Add-MSIXSharedFonts (done automatically for VFS\Fonts, where the installer put them for all programs).' `
                    -Command @('Add-MSIXSharedFonts -MSIXFolderPath $Package') -AutoFix ($fontsFolder.Count -gt 0) -Locations $hits -Stage 2
            }
        }
        $rules['Certificates'] = {
            $hits = @($files | Where-Object { $_.Name -match '\.(cer|crt)$' } | ForEach-Object Path)
            if ($hits.Count -gt 0 -and -not (& $mentions 'windows.certificates')) {
                Write-Finding Info 'Files' 'Certificate files found' `
                    'Certificates in the package are not imported into a certificate store.' `
                    'Declare the extension windows.certificates in the manifest if the application needs them.' -Locations $hits
            }
        }
        $rules['Cleanup candidates'] = {
            $hits = @($files | Where-Object { $_.Path -like 'VFS\Windows\Installer\*' -or $_.Path -like 'VFS\Windows\Temp\*' -or $_.Name -match '\.(pdb|tmp)$' } | ForEach-Object Path)
            if ($hits.Count -gt 0) {
                Write-Finding Info 'Files' 'Installer caches, debug symbols or temporary files' `
                    'MSI caches, *.pdb and *.tmp files have no function in the container and enlarge the package.' `
                    'Remove them with Invoke-MSIXCleanup (keeps desktop7 shortcuts with -RemoveShortcutExtensions $false).' `
                    -Command @('Invoke-MSIXCleanup -MSIXFolder $Package -RemoveShortcutExtensions $false') -AutoFix $true -Locations @($hits | Select-Object -First 50) -Stage 1
            }
        }

        # ================================================================ runtimes
        $rules['Runtime DLLs (VC++, VB6)'] = {
            $pe = & $getPE
            $hasVcLibs = & $mentions 'Microsoft.VCLibs.140.00'
            $groups = @(
                @{ Name = 'Visual C++ 2015-2022'; Pattern = '^(vcruntime140(_1)?|msvcp140(_\w+)?|concrt140|vccorlib140|mfc140u?|vcomp140)\.dll$'; Copy = $true; SkipWithVcLibs = $true },
                @{ Name = 'Visual C++ 2010-2013'; Pattern = '^(msvcr1[012]0|msvcp1[012]0|mfc1[012]0u?|vcomp1[012]0)\.dll$'; Copy = $true; SkipWithVcLibs = $false },
                @{ Name = 'Visual Basic 6'; Pattern = '^msvbvm60\.dll$'; Copy = $true; SkipWithVcLibs = $false },
                @{ Name = 'Visual C++ 2005/2008 (side-by-side)'; Pattern = '^(msvcr[89]0|msvcp[89]0|mfc[89]0u?)\.dll$'; Copy = $false; SkipWithVcLibs = $false }
            )
            foreach ($g in $groups) {
                if ($g.SkipWithVcLibs -and $hasVcLibs) { continue }
                $needed = @{}
                $users = @()
                foreach ($path in $pe.Keys) {
                    $arch = $pe[$path].Machine
                    foreach ($dll in @($pe[$path].Imports | Where-Object { $_ -match $g.Pattern -and -not $shippedNames.ContainsKey($_) })) {
                        $needed["$dll|$arch"] = $true
                        $users += $path
                    }
                }
                if ($needed.Count -eq 0) { continue }
                $missing = @($needed.Keys | Sort-Object)
                $display = ($missing | ForEach-Object { $p = $_ -split '\|'; "$($p[0]) ($($p[1]))" }) -join ', '
                if ($g.Copy) {
                    $cmd = @($missing | ForEach-Object {
                            $p = $_ -split '\|'
                            if ($p[1] -in 'x86', 'x64') { Get-RuntimeCopyCommand -Dll $p[0] -Arch $p[1] }
                            else { "# $($p[0]) ($($p[1])): copy the matching DLL to VFS\SystemX64 manually" }
                        })
                    if ($g.SkipWithVcLibs) {
                        $cmd += '# Alternative to copying: declare the framework package Microsoft.VCLibs.140.00.UWPDesktop as PackageDependency in AppxManifest.xml (it must be installed on the target systems).'
                    }
                    Write-Finding Warning 'Runtime' "$($g.Name) runtime needed but not in the package" `
                        "Missing: $display. Without the runtime on the target system the application does not start." `
                        'Copy the runtime DLLs of the packaging machine to VFS\SystemX64 / VFS\SystemX86 (app-local deployment, no dependency needed).' `
                        -Command $cmd -AutoFix $true -Locations @($users | Select-Object -Unique | Select-Object -First 50) -Stage 1
                }
                else {
                    Write-Finding Warning 'Runtime' "$($g.Name) runtime needed but not in the package" `
                        "Missing: $display. These runtimes are side-by-side assemblies (WinSxS); copying the DLLs alone is not enough." `
                        'Install the matching Visual C++ Redistributable on the target systems, or add the DLLs together with their Microsoft.VC*.CRT manifest folder next to the executable.' `
                        -Locations @($users | Select-Object -Unique | Select-Object -First 50) -Stage 1
                }
            }
        }
        # An executable finds DLLs in its own folder and in VFS\System*. A DLL that exists only elsewhere in
        # the package is not found unless the application extends the search path itself. Only executables
        # are checked: plug-in DLLs import from their host process, which is already loaded.
        $rules['DLL search path'] = {
            $pe = & $getPE
            $dllPaths = @{}
            foreach ($f in @($files | Where-Object { $_.Name -like '*.dll' })) {
                $name = $f.Name.ToLowerInvariant()
                if (-not $dllPaths.ContainsKey($name)) { $dllPaths[$name] = @() }
                $dllPaths[$name] += $f.Path
            }
            $declared = @($manifest.SelectNodes("//*[local-name()='LoaderSearchPathEntry']") | ForEach-Object { $_.GetAttribute('FolderPath').TrimEnd('\') })
            $folders = @()
            $locations = @()
            foreach ($path in @($pe.Keys | Where-Object { $_ -like '*.exe' })) {
                $dir = Split-Path $path -Parent
                foreach ($dll in $pe[$path].Imports) {
                    $name = $dll.ToLowerInvariant()
                    if (-not $dllPaths.ContainsKey($name)) { continue }
                    $reachable = @($dllPaths[$name] | Where-Object {
                            $d = Split-Path $_ -Parent
                            $d -eq $dir -or $d -like 'VFS\System*' -or $declared -contains $d
                        })
                    if ($reachable.Count -gt 0) { continue }
                    $match = @($dllPaths[$name] | Where-Object { $pe.ContainsKey($_) -and $pe[$_].Machine -eq $pe[$path].Machine }) | Select-Object -First 1
                    if (-not $match) { continue }
                    $folder = Split-Path $match -Parent
                    if (-not $folder) { continue }
                    if ($folders -notcontains $folder) { $folders += $folder }
                    $locations += "$path -> $folder\$name"
                }
            }
            if ($folders.Count -gt 0) {
                Write-Finding Warning 'Runtime' 'Imported DLLs outside the search path' `
                    "Executables import DLLs that exist only in other folders of the package: $($folders -join ', '). Installed, the application finds them through PATH or its own setup; in the container the start can fail." `
                    'Declare the folders with Add-MSIXloaderSearchPathOverride (at most 5 folders; for more use Add-MSIXPSFDynamicLibraryFixup).' `
                    -Command @("Add-MSIXloaderSearchPathOverride -MSIXFolderPath `$Package -FolderPaths @($((($folders | Select-Object -First 5) | ForEach-Object { ConvertTo-Literal $_ }) -join ', '))") `
                    -AutoFix ($folders.Count -le 5) -Locations @($locations | Select-Object -First 50) -Stage 2
            }
        }
        $rules['.NET'] = {
            foreach ($cfg in @($files | Where-Object { $_.Name -like '*.runtimeconfig.json' })) {
                $dir = Split-Path $cfg.Path -Parent
                if (@($files | Where-Object { $_.Name -eq 'hostfxr.dll' -and (Split-Path $_.Path -Parent) -eq $dir }).Count -gt 0) { continue }
                $json = Get-Content -LiteralPath $cfg.FullName -Raw | ConvertFrom-Json
                $frameworks = @($json.runtimeOptions.framework) + @($json.runtimeOptions.frameworks) | Where-Object { $_ }
                $names = ($frameworks | ForEach-Object { "$($_.name) $($_.version)" }) -join ', '
                if (-not $names) { continue }
                Write-Finding Warning 'Runtime' '.NET application depends on an installed runtime' `
                    "$($cfg.Path) requires $names. Framework-dependent applications do not start without it." `
                    'Install the .NET runtime on the target systems, or publish the application self-contained.' -Locations @($cfg.Path) -Stage 1
            }
            $net35 = @($files | Where-Object { $_.Name -like '*.exe.config' } | Where-Object {
                    $t = Get-Content -LiteralPath $_.FullName -Raw
                    $t -match 'supportedRuntime\s+version\s*=\s*"v2\.0' -and $t -notmatch 'supportedRuntime\s+version\s*=\s*"v4\.'
                } | ForEach-Object Path)
            if ($net35.Count -gt 0) {
                Write-Finding Warning 'Runtime' '.NET Framework 3.5 needed' `
                    'The application only supports the .NET 2.0/3.5 runtime, which is an optional Windows feature.' `
                    'Enable the Windows feature NetFx3 on the target systems (Enable-WindowsOptionalFeature -Online -FeatureName NetFx3).' -Locations $net35 -Stage 1
            }
            $dotnet = @($files | Where-Object { $_.Name -eq 'hostfxr.dll' } | ForEach-Object Path)
            if ($dotnet.Count -gt 0) {
                Write-Finding Info 'Runtime' '.NET runtime in the package (self-contained)' 'Self-contained .NET application.' `
                    'No action; the runtime is only updated with new package versions.' -Locations $dotnet
            }
        }
        $rules['Other runtimes'] = {
            $java = @($files | Where-Object { $_.Path -like '*\bin\java.exe' } | ForEach-Object Path)
            if ($java.Count -gt 0) {
                Write-Finding Info 'Runtime' 'Bundled Java runtime' `
                    'A private JRE works, but it is only updated with new package versions.' `
                    'On conflicts with locally installed Java use the RegLegacy JavaBlocker remediation.' `
                    -Command @("# Add-MSIXPSFRegLegacyFixup -MSIXFolder `$Package -JavaBlocker -MajorVersion '<major>'") -Locations $java -Stage 4
            }
            $python = @($files | Where-Object { $_.Name -match '^python3\d*\.dll$' } | ForEach-Object Path)
            if ($python.Count -gt 0) {
                Write-Finding Info 'Runtime' 'Python runtime in the package' 'Embedded Python.' 'No action.' -Locations $python
            }
            $webView = @($files | Where-Object { $_.Name -in 'WebView2Loader.dll', 'Microsoft.Web.WebView2.Core.dll' } | ForEach-Object Path)
            if ($webView.Count -gt 0) {
                Write-Finding Info 'Runtime' 'Application uses WebView2' `
                    'The Evergreen WebView2 runtime is part of Windows 11; on Windows 10 it may be missing.' `
                    'Make sure the WebView2 runtime is installed on Windows 10 targets.' -Locations @($webView | Select-Object -First 5)
            }
            $electron = @($files | Where-Object { $_.Name -eq 'app.asar' -and $_.Path -like '*\resources\app.asar' } | ForEach-Object Path)
            if ($electron.Count -gt 0) {
                Write-Finding Info 'Runtime' 'Electron application' `
                    'Some Electron versions do not start in the container because of the Chromium sandbox. The package itself is not a sandbox for full-trust applications; switching the Chromium sandbox off lowers the protection.' `
                    'Only if the application does not start: pass --no-sandbox through the PSF launcher or set ELECTRON_DISABLE_SANDBOX=1 with EnvVarFixup.' `
                    -Command @(
                        '# Add-MSIXPsfFrameworkFiles -MSIXFolder $Package -EnvFixup',
                        "# Add-MSIXPSFEnvVarFixup -MSIXFolder `$Package -Name 'ELECTRON_DISABLE_SANDBOX' -Value '1'"
                    ) -Locations $electron -Stage 4
            }
        }

        # ================================================================ executables
        $rules['Embedded executable manifests'] = {
            $elevated = @()
            $uiAccess = @()
            foreach ($f in @($files | Where-Object { $_.Name -like '*.exe' -and $_.Name -notmatch '^Psf' -and $_.Length -gt 0 })) {
                $m = Get-ExeManifestInfo $f.FullName
                if ($m.Level -in 'requireAdministrator', 'highestAvailable') { $elevated += "$($f.Path) ($($m.Level))" }
                if ($m.UiAccess) { $uiAccess += $f.Path }
            }
            if ($elevated.Count -gt 0 -and @($manifest.SelectNodes("//*[local-name()='Capability' and @Name='allowElevation']")).Count -eq 0) {
                # Automatic only when an application entry point elevates; helper tools may never be started.
                $targetExes = @($appTargets | ForEach-Object Executable)
                $elevatedApps = @($elevated | Where-Object { $targetExes -contains ($_ -replace ' \(\w+\)$', '') })
                if ($elevatedApps.Count -gt 0) {
                    Write-Finding Warning 'Manifest' 'Applications request administrative rights' `
                        'Packaged applications may only elevate with the capability allowElevation (Windows 10 2004+); otherwise the start fails.' `
                        'Add the capability allowElevation, or change the application so that it runs without elevation.' `
                        -Command @("Add-MSIXCapabilities -MSIXFolder `$Package -Capabilities 'allowElevation'") -AutoFix $true -Locations $elevated -Stage 2
                }
                else {
                    Write-Finding Info 'Manifest' 'Helper executables request administrative rights' `
                        'Only helper programs elevate. If the application starts them, elevation needs the capability allowElevation.' `
                        'Add allowElevation only if the helper is used.' `
                        -Command @("# Add-MSIXCapabilities -MSIXFolder `$Package -Capabilities 'allowElevation'") -Locations $elevated -Stage 2
                }
            }
            if ($uiAccess.Count -gt 0) {
                Write-Finding Error 'Manifest' 'Executables request uiAccess' `
                    'uiAccess=true needs a signed binary in a secure location; this is not possible in an MSIX package.' `
                    'Replace the executable or remove uiAccess from its manifest (the vendor has to rebuild it).' -Locations $uiAccess -Stage 2
            }
        }
        $rules['Capabilities'] = {
            $pe = & $getPE
            if (@($manifest.SelectNodes("//*[local-name()='Capability' and @Name='runFullTrust']")).Count -eq 0) {
                $map = @{ 'internetClient' = @('wininet.dll', 'winhttp.dll', 'ws2_32.dll'); 'internetClientServer' = @('wsock32.dll'); 'privateNetworkClientServer' = @('fwpuclnt.dll') }
                foreach ($cap in $map.Keys) {
                    if (@($manifest.SelectNodes("//*[local-name()='Capability' and @Name='$cap']")).Count -gt 0) { continue }
                    $users = @($pe.Keys | Where-Object { @($pe[$_].Imports | Where-Object { $map[$cap] -contains $_ }).Count -gt 0 })
                    if ($users.Count -eq 0) { continue }
                    Write-Finding Warning 'Manifest' "Capability '$cap' needed" `
                        "Files import network APIs ($($map[$cap] -join ', ')) and the package is not full trust, so the capability is enforced." `
                        "Add the capability '$cap'." -Command @("Add-MSIXCapabilities -MSIXFolder `$Package -Capabilities '$cap'") -AutoFix $true -Locations @($users | Select-Object -First 20) -Stage 2
                }
            }
            $camera = @($pe.Keys | Where-Object { @($pe[$_].Imports | Where-Object { $_ -in 'avicap32.dll', 'mfsensorgroup.dll', 'mfreadwrite.dll' }).Count -gt 0 })
            if ($camera.Count -gt 0 -and -not (& $mentions 'webcam')) {
                Write-Finding Info 'Manifest' 'Application may use the camera or microphone' `
                    "Files import capture APIs (avicap32 / Media Foundation). Privacy settings can block packaged applications that do not declare the device capabilities." `
                    'If the camera or microphone does not work in the package, add the device capabilities webcam and microphone.' `
                    -Command @("# Add-MSIXCapabilities -MSIXFolder `$Package -Capabilities 'webcam', 'microphone'") -Locations @($camera | Select-Object -First 20) -Stage 2
            }
        }

        # ================================================================ other packaging tools
        $rules['Upper-case GUIDs'] = {
            # Build metadata (build:Metadata) is ignored; only attributes the system evaluates count.
            $guids = @($manifest.SelectNodes("//@*[not(ancestor::*[local-name()='Metadata'])]") |
                    ForEach-Object { [regex]::Matches($_.Value, '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}') } |
                    Where-Object { $_.Value -cmatch '[A-F]' } | ForEach-Object { $_.Value } | Select-Object -Unique)
            if ($guids.Count -gt 0) {
                Write-Finding Info 'Manifest' 'Upper-case GUIDs in the manifest' `
                    'Some packaging tools write GUIDs in upper case; tools and PSF configurations that compare GUIDs as text then miss them.' `
                    'Normalize the GUIDs to lower case.' `
                    -Command @("`$manifestFile = Join-Path `$Package 'AppxManifest.xml'; `$text = [System.IO.File]::ReadAllText(`$manifestFile); `$text = [regex]::Replace(`$text, '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}', [System.Text.RegularExpressions.MatchEvaluator] { param(`$m) `$m.Value.ToLowerInvariant() }, 'IgnoreCase'); [System.IO.File]::WriteAllText(`$manifestFile, `$text, (New-Object System.Text.UTF8Encoding(`$false)))") `
                    -AutoFix $true -Locations @($guids | Select-Object -First 20) -Stage 2
            }
        }
        $rules['Unused device-family namespaces'] = {
            $ns = @($manifest.DocumentElement.Attributes | Where-Object { $_.Name -like 'xmlns:*' -and $_.Value -match '/(iot|mobile)/' } | ForEach-Object { "$($_.Name)=$($_.Value)" })
            if ($ns.Count -gt 0) {
                Write-Finding Info 'Manifest' 'IoT or mobile namespaces in the manifest' `
                    'Desktop packages do not use them; some tools leave them behind. Elements from these namespaces can fail the deployment.' `
                    'Remove the namespace declarations and their prefixes from IgnorableNamespaces if no element uses them.' -Locations $ns -Stage 2
            }
        }
        $rules['PortableApps launcher'] = {
            foreach ($appInfo in @($files | Where-Object { $_.Path -like '*\App\AppInfo\appinfo.ini' })) {
                $base = Split-Path (Split-Path (Split-Path $appInfo.Path -Parent) -Parent) -Parent
                $real = $null
                $launcherFolder = & $joinPath $base 'App\AppInfo\Launcher'
                foreach ($ini in @($files | Where-Object { (Split-Path $_.Path -Parent) -eq $launcherFolder -and $_.Name -like '*.ini' })) {
                    $line = Get-Content -LiteralPath $ini.FullName | Where-Object { $_ -match '^\s*ProgramExecutable(64)?\s*=' } | Select-Object -First 1
                    if ($line) {
                        $candidate = & $joinPath $base ('App\' + ($line -replace '^\s*ProgramExecutable(64)?\s*=\s*', '').Trim())
                        if (Test-Path -LiteralPath (Join-Path $root $candidate)) { $real = $candidate; break }
                    }
                }
                $launcherApps = @($apps | Where-Object { (Split-Path $_.Executable -Parent) -eq $base -and $_.Executable -like '*Portable.exe' })
                $cmd = @()
                if ($real) {
                    foreach ($a in $launcherApps) { $cmd += "Set-MSIXApplication -MSIXFolderPath `$Package -AppId $(ConvertTo-Literal $a.Id) -Executable $(ConvertTo-Literal $real)" }
                }
                Write-Finding Warning 'Files' 'PortableApps launcher structure' `
                    "The PortableApps launcher in $base copies settings into its Data folder and starts the real program$(if ($real) { " ($real)" })." `
                    'Start the real program directly and redirect the writes with the PSF (MFRFixup).' `
                    -Command $cmd -AutoFix ($cmd.Count -gt 0) -Locations @($appInfo.Path) -Stage 2
            }
        }
        $rules['Squirrel installer layout'] = {
            if (-not $squirrel) { return }
            $exes = @($files | Where-Object { (Split-Path $_.Path -Parent) -eq $squirrel.Latest -and $_.Name -like '*.exe' -and $_.Name -notmatch '^(squirrel|Update|crashpad_handler|elevate)\.exe$' })
            $mainExe = $exes | Sort-Object Length -Descending | Select-Object -First 1
            $cmd = @("Remove-Item -LiteralPath (Join-Path `$Package $(ConvertTo-Literal $squirrel.Update)) -Force")
            if ($mainExe) {
                foreach ($a in @($apps | Where-Object { $_.Executable -eq $squirrel.Update -or ($_.Executable -like "$($squirrel.Dir)\app-*" -and (Split-Path $_.Executable -Parent) -ne $squirrel.Latest) })) {
                    $cmd = @("Set-MSIXApplication -MSIXFolderPath `$Package -AppId $(ConvertTo-Literal $a.Id) -Executable $(ConvertTo-Literal $mainExe.Path)") + $cmd
                }
            }
            $older = @($squirrel.Versions | Where-Object { (& $joinPath $squirrel.Dir $_) -ne $squirrel.Latest })
            foreach ($o in $older) { $cmd += "# Remove-Item -LiteralPath (Join-Path `$Package $(ConvertTo-Literal (& $joinPath $squirrel.Dir $o))) -Recurse -Force" }
            Write-Finding Warning 'Files' 'Squirrel installer layout (Update.exe, app-<version>)' `
                "Update.exe starts the newest app-<version> folder and tries to update it, which fails in the package. Newest version: $($squirrel.Latest)." `
                'Start the executable in the newest app-<version> folder directly and remove Update.exe.' `
                -Command $cmd -AutoFix ($null -ne $mainExe) -Locations @($squirrel.Update) -Stage 2
        }

        # ================================================================ PSF
        $psfCommands = {
            param([hashtable] $WorkingDirectories)
            $cmd = @('Add-MSIXPsfFrameworkFiles -MSIXFolder $Package -MFFixup -RegLegacyFixup')
            foreach ($app in $appTargets) {
                $line = "`$null = Add-MSIXPSFShim -MSIXFolder `$Package -MSIXAppID $(ConvertTo-Literal $app.Id)"
                if ($WorkingDirectories.ContainsKey($app.Id)) { $line += " -WorkingDirectory $(ConvertTo-Literal $WorkingDirectories[$app.Id])" }
                $cmd += $line
            }
            $cmd + @('Add-MSIXPSFMFRFixup -MSIXFolder $Package', 'Add-MSIXPSFDefaultRegLegacy -MSIXFolder $Package')
        }
        # Configuration files next to the executable hint at relative loading. Not counted: .NET files that are
        # loaded relative to the assembly (*.exe.config, *.deps.json, *.runtimeconfig.json, XML documentation
        # next to a DLL of the same name) and documents (license, readme ...). Apps with a uap11 working
        # directory are skipped.
        $workingDirectories = @{}
        foreach ($app in $appTargets) {
            $appNode = $manifest.SelectSingleNode("//*[local-name()='Application' and @Id='$($app.Id)']")
            if ($appNode -and @($appNode.Attributes | Where-Object { $_.LocalName -eq 'CurrentDirectoryPath' }).Count -gt 0) { continue }
            $dir = Split-Path $app.Executable -Parent
            if (-not $dir) { continue }
            $inFolder = @($files | Where-Object { (Split-Path $_.Path -Parent) -eq $dir })
            $dllNames = @{}
            foreach ($f in $inFolder) { if ($f.Name -like '*.dll') { $dllNames[[System.IO.Path]::GetFileNameWithoutExtension($f.Name).ToLowerInvariant()] = $true } }
            $configFiles = @($inFolder | Where-Object {
                    $_.Name -match '\.(ini|cfg|config|txt|dat|xml|json)$' -and
                    $_.Name -notmatch '\.(exe|dll)\.config$|\.(deps|runtimeconfig)\.json$|^(license|licence|readme|changelog|changes|copying|notice|eula|third.?party)' -and
                    -not ($_.Name -like '*.xml' -and $dllNames.ContainsKey([System.IO.Path]::GetFileNameWithoutExtension($_.Name).ToLowerInvariant()))
                })
            if ($configFiles.Count -gt 0) { $workingDirectories[$app.Id] = $dir }
        }
        $rules['Writes to the installation folder'] = {
            if ($hasPsf) { return }
            $hits = @()
            foreach ($dir in @($appTargets | ForEach-Object { Split-Path $_.Executable -Parent } | Select-Object -Unique)) {
                $hits += @($files | Where-Object { (Split-Path $_.Path -Parent) -eq $dir -and $_.Name -match '(\.(log|tmp|cache)$)|^(settings|user|state)\.' } | ForEach-Object Path)
            }
            if ($hits.Count -gt 0) {
                Write-Finding Warning 'PSF' 'Signs of writes to the installation folder' `
                    'Log, cache or settings files next to the executable suggest that the application writes into its installation folder, which is read-only in the container.' `
                    'Apply the PSF with MFRFixup (redirects the writes per user).' `
                    -Command (& $psfCommands $workingDirectories) -AutoFix $true -Locations $hits -Stage 4
            }
        }
        $rules['Working directory'] = {
            if ($hasPsf -or $workingDirectories.Count -eq 0) { return }
            $cmd = @(& $psfCommands $workingDirectories)
            foreach ($id in $workingDirectories.Keys) {
                $cmd += "# Windows 11 without PSF: Set-MSIXApplication -MSIXFolderPath `$Package -AppId $(ConvertTo-Literal $id) -UAP11WorkingDirectory $(ConvertTo-Literal $workingDirectories[$id])"
            }
            Write-Finding Warning 'PSF' 'Application probably expects its own working directory' `
                'MSIX starts applications with C:\Windows\System32 as working directory; applications that load configuration files relative to it do not find them.' `
                'Set the working directory with the PSF launcher (Add-MSIXPSFShim -WorkingDirectory) or, on Windows 11 only, uap11 (Set-MSIXApplication -UAP11WorkingDirectory).' `
                -Command $cmd -AutoFix $true -Locations @($workingDirectories.Values) -Stage 4
        }

        $rules['PSF on request'] = {
            if (-not $ForcePSF -or $hasPsf -or $appTargets.Count -eq 0) { return }
            Write-Finding Info 'PSF' 'PSF requested with -ForcePSF' `
                'The PSF is added without a specific finding: launcher for every application, MFRFixup and the RegLegacy defaults.' `
                'Test the package first without the PSF; keep it only if the application needs it.' `
                -Command (& $psfCommands $workingDirectories) -AutoFix $true -Locations @($appTargets | ForEach-Object Executable) -Stage 4
        }

        # ================================================================ manifest
        # Proposed for every package: harmless when the application never writes to its folder.
        $rules['Installed location virtualization'] = {
            if (& $mentions 'InstalledLocationVirtualization') { return }
            Write-Finding Info 'Manifest' 'No write virtualization for the installation folder' `
                'The installation folder is read-only in the container; an application that writes there fails or loses the data.' `
                'Declare InstalledLocationVirtualization (Windows 10 2004 or later): writes are redirected per user.' `
                -Command @('Add-MSIXInstalledLocationVirtualization -MSIXFolderPath $Package') -AutoFix $true -Locations @('AppxManifest.xml') -Stage 2
        }
        # MakeAppx creates AppxMetadata\CodeIntegrity.cat itself; only the manifest element enforces it.
        $rules['Package integrity'] = {
            if (@($manifest.SelectNodes("//*[local-name()='PackageIntegrity']")).Count -gt 0) {
                Write-Finding Warning 'Manifest' 'Package integrity enforcement (CodeIntegrity.cat)' `
                    'A modified and re-signed package with PackageIntegrity / CodeIntegrity.cat deploys, but the start fails with 0x80070057.' `
                    'Remove the package integrity before repacking.' `
                    -Command @('Remove-MSIXPackageIntegrity -MSIXFolderPath $Package') -AutoFix $true -Locations @('AppxManifest.xml') -Stage 2
            }
        }
        $rules['desktop7 shortcuts'] = {
            foreach ($s in @($manifest.SelectNodes("//*[local-name()='Shortcut']"))) {
                $file = $s.GetAttribute('File')
                if (-not $file) { continue }
                if ($file -match '^\[\{(Common )?Startup\}\]') {
                    Write-Finding Error 'Manifest' "desktop7 shortcut in the Startup folder: $file" `
                        '[{Startup}] and [{Common Startup}] are not valid desktop7 locations; deployment fails with 0x800700A1.' `
                        'Remove the shortcut; use a startup task (Set-MSIXApplication -Autostart) for autostart.' `
                        -Command @("Remove-MSIXDesktop7Shortcut -MSIXFolderPath `$Package -File $(ConvertTo-Literal $file)") -AutoFix $true -Locations @($file) -Stage 2
                }
                elseif ($file -like '`[{Common Programs}`]*') {
                    Write-Finding Info 'Manifest' "desktop7 shortcut in the all-users Start menu: $file" `
                        'Shortcuts in system locations show no icon; only per-user locations ([{Programs}], [{Desktop}]) do.' `
                        'Move the shortcut to the per-user Start menu with Repair-MSIXDesktop7Shortcut.' `
                        -Command @("Repair-MSIXDesktop7Shortcut -MSIXFolderPath `$Package -File $(ConvertTo-Literal $file)") -AutoFix $true -Locations @($file) -Stage 2
                }
            }
        }
        $rules['Declared services'] = {
            foreach ($svc in @(Get-MSIXServices -MSIXFolder $root)) {
                Write-Finding Warning 'Services' "Package declares the service '$($svc.ServiceName)'" `
                    "Start account: $($svc.StartAccount). Packaged services need Windows 10 2004 or later, administrative rights for installation and the capability packagedServices / localSystemServices." `
                    'Keep the service only if the application needs it; otherwise remove the declaration with Remove-MSIXServices.' `
                    -Command @('# Remove-MSIXServices -MSIXFolder $Package') -Locations @("Application $($svc.ApplicationId)") -Stage 2
            }
        }

        # ================================================================ registry
        $rules['Services in the registry'] = {
            foreach ($set in 'CurrentControlSet', 'ControlSet001') {
                $base = "$machine\SYSTEM\$set\Services"
                foreach ($name in (& $subKeys 'Registry.dat' $base)) {
                    $image = & $regValue 'Registry.dat' "$base\$name" 'ImagePath'
                    if (-not $image) { continue }
                    if ((& $mentions "Name=`"$name`"") -and (& $mentions 'windows.service')) { continue }
                    $start = & $regValue 'Registry.dat' "$base\$name" 'Start'
                    $startType = switch ($start) { 2 { 'auto' } 4 { 'disabled' } default { 'manual' } }
                    $account = [string](& $regValue 'Registry.dat' "$base\$name" 'ObjectName')
                    if (-not $account) { $account = 'LocalSystem' }
                    Write-Finding Warning 'Services' "Service '$name' only in the registry" `
                        "ImagePath: $image; start type: $startType; account: $account. Services in the package registry are not installed." `
                        'Declare it as desktop6:Extension windows.service (Windows 10 2004+, capability packagedServices / localSystemServices) or remove the keys if the application works without the service.' `
                        -Command @("# Remove-MSIXVirtualRegistryKey -HiveFilePath (Join-Path `$Package 'Registry.dat') -KeyPath $(ConvertTo-Literal "$base\$name") -Recurse   # elevated") `
                        -Locations @("HKLM\SYSTEM\$set\Services\$name") -Stage 3
                }
            }
        }
        $rules['Autostart (Run keys)'] = {
            $run = @()
            $runOnce = @()
            $convertible = @()
            foreach ($r in $softwareRoots) {
                foreach ($kind in 'Run', 'RunOnce') {
                    $path = "$($r[1])\Microsoft\Windows\CurrentVersion\$kind"
                    $key = & $openKey $r[0] $path
                    if ($null -eq $key) { continue }
                    foreach ($v in $key.GetValueNames()) {
                        $data = [string] $key.GetValue($v, '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                        $label = if ($v) { $v } else { '(Default)' }
                        $entry = "$($r[2])\Microsoft\Windows\CurrentVersion\$kind -> $label = $data"
                        if ($kind -eq 'RunOnce') { $runOnce += $entry; continue }
                        $run += $entry
                        $parts = @(Split-CommandLine $data)
                        $exe = Resolve-VfsToken $parts[0]
                        if ($exe -and (Test-Path -LiteralPath (Join-Path $root $exe))) { $convertible += $exe }
                    }
                }
            }
            if ($run.Count -gt 0 -and -not (& $mentions 'windows.startupTask')) {
                $cmd = @()
                if ($convertible.Count -gt 0) {
                    $app = & $appForExe $convertible[0]
                    if ($app) { $cmd += "Set-MSIXApplication -MSIXFolderPath `$Package -AppId $(ConvertTo-Literal $app.Id) -Autostart `$true -AutostartExecutable $(ConvertTo-Literal $convertible[0])" }
                }
                Write-Finding Info 'Registry' 'Autostart via Run keys' `
                    'Run entries in the package registry are not executed by Windows.' `
                    'Declare a startup task (Set-MSIXApplication -Autostart; the user can switch it off). One startup task per application.' `
                    -Command $cmd -AutoFix ($cmd.Count -gt 0) -Locations $run -Stage 2
            }
            if ($runOnce.Count -gt 0) {
                Write-Finding Info 'Registry' 'RunOnce entries' `
                    'RunOnce entries in the package registry are not executed and cannot be converted.' `
                    'Check whether the application needs the step (often a first-run setup); move it into a PSF start script if so.' -Locations $runOnce -Stage 3
            }
        }
        $rules['Uninstall keys'] = {
            $keys = @()
            $cmd = @()
            foreach ($r in $softwareRoots) {
                $path = "$($r[1])\Microsoft\Windows\CurrentVersion\Uninstall"
                foreach ($n in (& $subKeys $r[0] $path)) {
                    $keys += "$($r[2])\Microsoft\Windows\CurrentVersion\Uninstall\$n"
                    $cmd += "# Remove-MSIXVirtualRegistryKey -HiveFilePath (Join-Path `$Package $(ConvertTo-Literal $r[0])) -KeyPath $(ConvertTo-Literal "$path\$n") -Recurse   # elevated"
                }
            }
            if ($keys.Count -gt 0) {
                Write-Finding Warning 'Registry' 'Uninstall entries in the registry' `
                    'These entries are useless in an MSIX package and can point to uninstallers that do not work in the container.' `
                    'Delete the keys (writing to the package hives needs an elevated PowerShell).' -Command $cmd -Locations $keys -Stage 3
            }
        }
        $rules['App Paths'] = {
            $aliasCmd = @()
            $aliasLocations = @()
            $searchFolders = @()
            foreach ($r in $softwareRoots) {
                $path = "$($r[1])\Microsoft\Windows\CurrentVersion\App Paths"
                foreach ($alias in (& $subKeys $r[0] $path)) {
                    $target = Resolve-VfsToken ([string](& $regValue $r[0] "$path\$alias" ''))
                    if ($target -and (Test-Path -LiteralPath (Join-Path $root $target)) -and -not (& $mentions "Alias=`"$alias`"")) {
                        $app = & $appForExe $target
                        if ($app) {
                            $aliasCmd += "Add-MSIXAppExecutionAlias -MSIXFolder `$Package -MSIXAppID $(ConvertTo-Literal $app.Id) -CommandlineAlias $(ConvertTo-Literal $alias) -Executable $(ConvertTo-Literal $target)"
                            $aliasLocations += "$($r[2])\Microsoft\Windows\CurrentVersion\App Paths\$alias"
                        }
                    }
                    $searchPath = [string](& $regValue $r[0] "$path\$alias" 'Path')
                    foreach ($folder in @($searchPath -split ';' | Where-Object { $_ })) {
                        $resolved = Resolve-VfsToken $folder
                        if ($resolved -and (Test-Path -LiteralPath (Join-Path $root $resolved)) -and $searchFolders -notcontains $resolved) { $searchFolders += $resolved }
                    }
                }
            }
            if ($aliasCmd.Count -gt 0) {
                Write-Finding Info 'Registry' 'App Paths entries without execution alias' `
                    'App Paths in the package registry are not visible to Win+R or other programs; the executable cannot be started by name.' `
                    'Declare execution aliases (Add-MSIXAppExecutionAlias).' -Command $aliasCmd -AutoFix $true -Locations $aliasLocations -Stage 2
            }
            if ($searchFolders.Count -gt 0 -and -not (& $mentions 'loaderSearchPathOverride')) {
                Write-Finding Warning 'Registry' 'App Paths add DLL search folders' `
                    "The application expects DLLs from these folders: $($searchFolders -join ', '). App Paths do not apply in the package." `
                    'Declare the folders with Add-MSIXloaderSearchPathOverride (at most 5 folders).' `
                    -Command @("Add-MSIXloaderSearchPathOverride -MSIXFolderPath `$Package -FolderPaths @($((($searchFolders | Select-Object -First 5) | ForEach-Object { ConvertTo-Literal $_ }) -join ', '))") `
                    -AutoFix $true -Locations $searchFolders -Stage 2
            }
            # DLLs of the same name in several folders: the loader takes the first one it finds.
            $dupes = @($files | Where-Object { $_.Name -like '*.dll' -and $_.Path -notlike 'VFS\System*' } | Group-Object { $_.Name.ToLowerInvariant() } |
                    Where-Object { @($_.Group | ForEach-Object { Split-Path $_.Path -Parent } | Select-Object -Unique).Count -gt 1 } | ForEach-Object { $_.Name })
            if ($dupes.Count -gt 0) {
                Write-Finding Info 'Files' 'DLLs with the same name in several folders' `
                    "Which copy is loaded depends on the search order: $(($dupes | Select-Object -First 15) -join ', ')." `
                    'Only relevant if the application loads the wrong version; then fix the search order with Add-MSIXloaderSearchPathOverride or Add-MSIXPSFDynamicLibraryFixup.' `
                    -Locations @($dupes | Select-Object -First 30)
            }
        }
        $rules['Firewall rules'] = {
            foreach ($set in 'CurrentControlSet', 'ControlSet001') {
                $path = "$machine\SYSTEM\$set\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
                $key = & $openKey 'Registry.dat' $path
                if ($null -eq $key) { continue }
                foreach ($v in $key.GetValueNames()) {
                    $fields = @{}
                    foreach ($part in ([string] $key.GetValue($v)) -split '\|') {
                        $kv = $part -split '=', 2
                        if ($kv.Count -eq 2) { $fields[$kv[0]] = $kv[1] }
                    }
                    if ($fields['Action'] -ne 'Allow') { continue }
                    $exe = Resolve-VfsToken $fields['App']
                    if (-not $exe -or -not (Test-Path -LiteralPath (Join-Path $root $exe))) { continue }
                    if ((& $mentions 'windows.firewallRules') -and (& $mentions $exe)) { continue }
                    $protocol = switch ($fields['Protocol']) { '6' { 'TCP' } '17' { 'UDP' } default { '' } }
                    $port = $fields['LPort']
                    $direction = if ($fields['Dir'] -eq 'Out') { 'out' } else { 'in' }
                    $app = & $appForExe $exe
                    $line = "Add-MSIXFirewallRule -MSIXFolder `$Package -MSIXAppID $(ConvertTo-Literal $app.Id) -Executable $(ConvertTo-Literal $exe) -Direction $direction -IPProtocol $protocol -Port $port"
                    $auto = $protocol -and $port -match '^\d+$' -and $app
                    if (-not $auto) { $line = "# $line   # protocol/port '$($fields['Protocol'])/$port' needs a manual rule" }
                    Write-Finding Warning 'Registry' "Firewall rule '$($fields['Name'])' only in the registry" `
                        "Rule for $exe ($direction, protocol $($fields['Protocol']), local port $port). Firewall rules in the package registry are not applied." `
                        'Declare the rule in the manifest (Add-MSIXFirewallRule; installation then needs administrative rights).' `
                        -Command @($line) -AutoFix ([bool] $auto) -Locations @("HKLM\SYSTEM\$set\...\FirewallRules\$v") -Stage 2
                }
            }
        }
        $rules['File type associations'] = {
            $byProgId = @{}
            foreach ($r in $classRoots) {
                foreach ($ext in @((& $subKeys $r[0] $r[1]) | Where-Object { $_ -match '^\.[A-Za-z0-9_\-]+$' })) {
                    if (& $mentions ">$ext<") { continue }
                    $progId = [string](& $regValue $r[0] (& $joinPath $r[1] $ext) '')
                    $command = $null
                    if ($progId) { $command = [string](& $regValue $r[0] (& $joinPath $r[1] "$progId\shell\open\command") '') }
                    if (-not $command) { $command = [string](& $regValue $r[0] (& $joinPath $r[1] "$ext\shell\open\command") '') }
                    if (-not $command) { continue }
                    $parts = @(Split-CommandLine $command)
                    $exe = Resolve-VfsToken $parts[0]
                    if (-not $exe -or -not (Test-Path -LiteralPath (Join-Path $root $exe))) { continue }
                    $name = if ($progId) { $progId } else { $ext.TrimStart('.') }
                    $groupKey = "$name|$exe"
                    if (-not $byProgId.ContainsKey($groupKey)) { $byProgId[$groupKey] = New-Object System.Collections.Generic.List[string] }
                    if (-not $byProgId[$groupKey].Contains($ext.ToLowerInvariant())) { $byProgId[$groupKey].Add($ext.ToLowerInvariant()) }
                }
            }
            foreach ($groupKey in $byProgId.Keys) {
                $p = $groupKey -split '\|'
                $exe = $p[1]
                $app = & $appForExe $exe
                if (-not $app) { continue }
                $ftaName = ($p[0].ToLowerInvariant() -replace '[^a-z0-9._-]', '-').Trim('-')
                if ($ftaName.Length -gt 100) { $ftaName = $ftaName.Substring(0, 100) }
                $types = @($byProgId[$groupKey])
                Write-Finding Warning 'Registry' "File types $($types -join ', ') only in the registry" `
                    "ProgId $($p[0]) opens $exe. File type associations in the package registry are not registered with Windows." `
                    'Declare the file type association in the manifest (Add-MSIXFileTypeAssociation).' `
                    -Command @("Add-MSIXFileTypeAssociation -MSIXFolderPath `$Package -AppId $(ConvertTo-Literal $app.Id) -Name $(ConvertTo-Literal $ftaName) -FileType @($(($types | ForEach-Object { ConvertTo-Literal $_ }) -join ', '))") `
                    -AutoFix $true -Locations $types -Stage 2
            }
        }
        $rules['URL protocols'] = {
            foreach ($r in $classRoots) {
                foreach ($proto in @((& $subKeys $r[0] $r[1]) | Where-Object { $_ -notlike '.*' -and $_ -notmatch '^(CLSID|Interface|TypeLib|AppID|\*)$' })) {
                    if (@(& $valueNames $r[0] (& $joinPath $r[1] $proto)) -notcontains 'URL Protocol') { continue }
                    if ((& $mentions "Name=`"$proto`"") -and (& $mentions 'windows.protocol')) { continue }
                    $command = [string](& $regValue $r[0] (& $joinPath $r[1] "$proto\shell\open\command") '')
                    Write-Finding Warning 'Registry' "URL protocol '$($proto):' only in the registry" `
                        "Command: $command. Protocols in the package registry are not registered with Windows; links with '$($proto):' do not open the application." `
                        'Declare uap:Extension windows.protocol in the manifest.' -Locations @("$($r[2])\$proto") -Stage 3
                }
            }
        }
        $shellTargets = '*', 'Directory', 'Directory\Background', 'Folder', 'Drive', 'AllFilesystemObjects'
        $rules['Shell extensions'] = {
            foreach ($r in $classRoots) {
                foreach ($target in $shellTargets) {
                    foreach ($kind in 'ContextMenuHandlers', 'DragDropHandlers', 'PropertySheetHandlers', 'CopyHookHandlers') {
                        $path = & $joinPath $r[1] "$target\shellex\$kind"
                        foreach ($handler in (& $subKeys $r[0] $path)) {
                            $clsid = if ($handler -match '^\{[0-9a-fA-F-]{36}\}$') { $handler } else { [string](& $regValue $r[0] "$path\$handler" '') }
                            if (-not $clsid) { $clsid = $handler }
                            if (& $mentions $clsid.Trim('{', '}')) { continue }
                            Write-Finding Error 'Shell' "Explorer extension '$handler' ($target, $kind)" `
                                "CLSID $clsid. Classic shell extensions in the package registry are not loaded by Explorer." `
                                'Context menus: declare desktop9:Extension windows.fileExplorerClassicContextMenuHandler with com:SurrogateServer (Windows 11); WinRAR and Notepad++ have ready-made fixes, a bundled sparse package is merged with Import-MSIXSparseShellExtension. Property sheet and copy hook handlers have no MSIX equivalent.' `
                                -Locations @("$($r[2])\$target\shellex\$kind\$handler") -Stage 2
                        }
                    }
                }
            }
        }
        $rules['Shell verbs'] = {
            foreach ($r in $classRoots) {
                foreach ($target in $shellTargets) {
                    $path = & $joinPath $r[1] "$target\shell"
                    foreach ($verb in (& $subKeys $r[0] $path)) {
                        $command = & $regValue $r[0] "$path\$verb\command" ''
                        $explorerCommand = $null -ne (& $regValue $r[0] "$path\$verb" 'ExplorerCommandHandler')
                        if ($null -eq $command -and -not $explorerCommand) { continue }
                        if ((& $mentions "Verb Id=`"$verb`"") -or (& $mentions "Id=`"$verb`"")) { continue }
                        $severity = if ($explorerCommand) { 'Error' } else { 'Warning' }
                        $detail = if ($explorerCommand) { 'ExplorerCommandHandler - not loaded from the package registry.' } else { "Command: $command" }
                        Write-Finding $severity 'Shell' "Shell verb '$verb' for '$target'" $detail `
                            'Declare it as context menu in the manifest (desktop4:FileExplorerContextMenus or a desktop9 handler).' `
                            -Locations @("$($r[2])\$target\shell\$verb") -Stage 2
                    }
                }
            }
        }
        $rules['Preview, thumbnail, icon and property handlers'] = {
            $handlers = @(
                @('{8895b1c6-b41f-4c1c-a562-0d564250836f}', 'Preview handler', 'desktop2:DesktopPreviewHandler'),
                @('{e357fccd-a995-4576-b01f-234630154e96}', 'Thumbnail handler', 'uap:ThumbnailHandler or desktop2:ThumbnailHandler')
            )
            foreach ($r in $classRoots) {
                foreach ($ext in @((& $subKeys $r[0] $r[1]) | Where-Object { $_.StartsWith('.') })) {
                    foreach ($h in $handlers) {
                        $path = & $joinPath $r[1] "$ext\shellex\$($h[0])"
                        $clsid = [string](& $regValue $r[0] $path '')
                        if (-not $clsid -or (& $mentions $clsid.Trim('{', '}'))) { continue }
                        Write-Finding Warning 'Shell' "$($h[1]) for '$ext'" "Handler CLSID $clsid is only registered in the package registry." `
                            "Declare it in the file type association (windows.fileTypeAssociation) as $($h[2])." -Locations @("$($r[2])\$ext\shellex\$($h[0])") -Stage 2
                    }
                    $progId = [string](& $regValue $r[0] (& $joinPath $r[1] $ext) '')
                    if (-not $progId) { continue }
                    foreach ($kind in 'IconHandler', 'DropHandler') {
                        $clsid = [string](& $regValue $r[0] (& $joinPath $r[1] "$progId\shellex\$kind") '')
                        if (-not $clsid -or (& $mentions $clsid.Trim('{', '}'))) { continue }
                        Write-Finding Warning 'Shell' "$kind for '$ext' ($progId)" "Handler CLSID $clsid is only registered in the package registry." `
                            'Not supported by the MSIX file type association; Explorer shows the default icon / ignores drops.' -Locations @("$($r[2])\$progId\shellex\$kind") -Stage 2
                    }
                }
            }
            $props = "$machine\SOFTWARE\Microsoft\Windows\CurrentVersion\PropertySystem\PropertyHandlers"
            foreach ($ext in (& $subKeys 'Registry.dat' $props)) {
                $clsid = [string](& $regValue 'Registry.dat' "$props\$ext" '')
                if (-not $clsid -or (& $mentions $clsid.Trim('{', '}'))) { continue }
                Write-Finding Warning 'Shell' "Property handler for '$ext'" "Handler CLSID $clsid." `
                    'Declare it in the file type association as desktop2:DesktopPropertyHandler.' `
                    -Locations @("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PropertySystem\PropertyHandlers\$ext") -Stage 2
            }
        }
        $rules['COM servers'] = {
            $hits = @()
            foreach ($r in $classRoots) {
                $clsidRoot = & $joinPath $r[1] 'CLSID'
                foreach ($clsid in (& $subKeys $r[0] $clsidRoot)) {
                    if (& $mentions $clsid.Trim('{', '}')) { continue }
                    foreach ($server in 'InProcServer32', 'LocalServer32') {
                        $path = [string](& $regValue $r[0] "$clsidRoot\$clsid\$server" '')
                        if (-not $path) { continue }
                        $parts = @(Split-CommandLine $path)
                        $exe = Resolve-VfsToken $parts[0]
                        if ($exe -and (Test-Path -LiteralPath (Join-Path $root $exe))) { $hits += "$clsid ($server) -> $exe" }
                    }
                }
            }
            if ($hits.Count -gt 0) {
                Write-Finding Info 'COM' "$($hits.Count) COM class(es) of the package only in the registry" `
                    'Inside the application this works through the virtual registry. Other processes (Office add-ins, Explorer) do not see these COM servers.' `
                    'Only needed when other processes use the classes: declare com:Extension windows.comServer in the manifest.' -Locations $hits
            }
        }
        $rules['Short (8.3) paths in the registry'] = {
            if (-not $hives.ContainsKey('Registry.dat')) { return }
            $hits = @()
            $visited = 0
            $stack = New-Object System.Collections.Generic.Stack[string]
            foreach ($start in "$machine\SOFTWARE", $user) { $stack.Push($start) }
            while ($stack.Count -gt 0 -and $visited -lt 30000 -and $hits.Count -lt 30) {
                $path = $stack.Pop()
                $key = $hives['Registry.dat'].OpenSubKey($path)
                if ($null -eq $key) { continue }
                try {
                    $visited++
                    foreach ($v in $key.GetValueNames()) {
                        if ($key.GetValueKind($v) -notin 'String', 'ExpandString') { continue }
                        $data = [string] $key.GetValue($v, '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                        if ($data -match '\\[^\\~\s"]{1,6}~\d') { $hits += "$path -> $(if ($v) { $v } else { '(Default)' }) = $data" }
                    }
                    foreach ($sub in $key.GetSubKeyNames()) { $stack.Push("$path\$sub") }
                }
                finally {
                    $key.Dispose()
                }
            }
            if ($hits.Count -gt 0) {
                Write-Finding Warning 'Registry' 'Short (8.3) paths in the registry' `
                    'Short names like PROGRA~1 were generated on the packaging machine; in the package they usually do not exist and the paths fail.' `
                    'Replace them with the long paths (Set-MSIXVirtualRegistryKey, elevated) or capture the package again on a system without 8.3 names.' -Locations $hits -Stage 3
            }
        }

        try {
            foreach ($name in $rules.Keys) {
                Write-Verbose "Rule: $name"
                try {
                    foreach ($finding in @(& $rules[$name])) {
                        if ($null -ne $finding) { $findings.Add($finding) }
                    }
                }
                catch {
                    $findings.Add((Write-Finding Error 'Analysis' "Rule '$name' failed" $_.Exception.Message `
                                'The result of this rule is unknown; the package is NOT checked in this respect.' -Stage 9))
                }
            }
        }
        finally {
            foreach ($key in $openedKeys) { $key.Dispose() }
            foreach ($key in $hives.Values) { $key.Dispose() }
        }

        $severityOrder = @{ 'Error' = 0; 'Warning' = 1; 'Info' = 2 }
        $sorted = @($findings | Sort-Object @{ Expression = { $severityOrder[$_.Severity] } }, Category, Title)

        if ($FixScriptPath) {
            $identity = $manifest.SelectSingleNode("//*[local-name()='Identity']")
            $lines = New-Object System.Collections.Generic.List[string]
            $lines.Add('#Requires -Version 5.1')
            $lines.Add('<#')
            $lines.Add("    Fix script generated by Find-MSIXPackageIssue on $(Get-Date -Format 'yyyy-MM-dd HH:mm') for $($identity.GetAttribute('Name')) $($identity.GetAttribute('Version')).")
            $lines.Add('    Review it before running. Commented commands need a decision or manual work.')
            $lines.Add('    Runtime DLLs are copied from the machine that runs this script.')
            $lines.Add('#>')
            $lines.Add('param(')
            $lines.Add('    [Parameter(Mandatory = $true)] [string] $MsixFile,')
            $lines.Add('    [string] $OutputFile = ($MsixFile -replace ''\.msix$'', ''_fixed.msix''),')
            $lines.Add('    [string] $PfxFile,')
            if (@($sorted | Where-Object { $_.Title -like '16-bit Windows*' }).Count -gt 0) {
                $lines.Add('    [System.Security.SecureString] $PfxPassword,')
                $lines.Add('    # Folder with otvdm.exe (OTVDM / winevdm) for the 16-bit applications.')
                $lines.Add('    [string] $Win16RuntimePath')
            }
            else {
                $lines.Add('    [System.Security.SecureString] $PfxPassword')
            }
            $lines.Add(')')
            $lines.Add('$ErrorActionPreference = ''Stop''')
            $lines.Add('Import-Module MSIXForcelets')
            $lines.Add('')

            $knownFix = @($sorted | Where-Object { $_.Stage -eq 0 }) | Select-Object -First 1
            $emitted = @{}
            $writeFinding = {
                param($Finding, [bool] $Active)
                $lines.Add("# [$($Finding.Severity)] $($Finding.Title)")
                $lines.Add("#   $($Finding.Recommendation)")
                foreach ($c in $Finding.Command) {
                    if ($emitted.ContainsKey($c)) { continue }
                    $emitted[$c] = $true
                    if ($Active -and $Finding.AutoFix -and -not $c.StartsWith('#')) { $lines.Add($c) }
                    elseif ($c.StartsWith('#')) { $lines.Add($c) }
                    else { $lines.Add("# $c") }
                }
                $lines.Add('')
            }

            # Active commands first so that a commented duplicate never hides an active one.
            $ordered = @($sorted | Where-Object { $_.Stage -ne 0 } | Sort-Object Stage, @{ Expression = { -not $_.AutoFix } })
            if ($knownFix) {
                $lines.Add('# A ready-made fix for this application exists; it opens, fixes and repacks the package itself.')
                & $writeFinding $knownFix $true
                $lines.Add('# The generic findings below are listed for reference only.')
                $lines.Add('')
                foreach ($f in $ordered) { & $writeFinding $f $false }
            }
            else {
                $lines.Add('$Package = Open-MSIXPackage -MsixFile $MsixFile -Force')
                $lines.Add('')
                foreach ($f in $ordered) { & $writeFinding $f $true }
                $lines.Add('Close-MSIXPackage -MSIXFolder $Package -MSIXFile $OutputFile -Force')
            }
            $lines.Add('if ($PfxFile) {')
            $lines.Add('    Set-MSIXSignature -MSIXFile $OutputFile -PfxCert $PfxFile -CertPassword $PfxPassword')
            $lines.Add('}')

            # UTF-8 with BOM so that Windows PowerShell 5.1 reads non-ASCII paths correctly.
            [System.IO.File]::WriteAllLines($FixScriptPath, $lines, (New-Object System.Text.UTF8Encoding($true)))
            Write-Verbose "Fix script written: $FixScriptPath"
        }

        $sorted | Select-Object Severity, Category, Title, Detail, Recommendation, Command, AutoFix, Locations
    }
}
