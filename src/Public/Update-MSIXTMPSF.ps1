
function Update-MSIXTMPSF {
    <#
.SYNOPSIS
    Downloads and organises the latest Tim Mangan MSIX Package Support Framework release.

.DESCRIPTION
    Queries the GitHub releases for TimMangan/MSIX-PackageSupportFramework, downloads the
    latest ZipRelease asset, extracts the nested Debug and Release ZIP archives, and sorts
    every EXE and DLL into amd64\ or win32\ sub-folders based on their actual PE machine
    type (detected via Get-MSIXAppMachineType).

    The files are placed under:
        <module>\MSIXPSF\TimManganPSF\<release-name>\
            _debug\
                amd64\   <- x64 binaries
                win32\   <- x86 binaries
                         <- scripts / non-binary files
            _release\
                amd64\
                win32\

    The Visual C++ Runtime DLLs are not shipped by Tim Mangan. By default they are copied
    from the local Windows installation. A warning is issued for each file not found on the system.

.PARAMETER Force
    Skips all confirmation prompts and overwrites an existing version folder.

.PARAMETER CopyVCRuntime
    Copies the Visual C++ Runtime DLLs that Tim Mangan does not ship from the local Windows
    installation into the amd64\ and win32\ sub-folders:
        amd64\: msvcp140.dll, msvcp140_1.dll, msvcp140_2.dll, vcruntime140.dll, vcruntime140_1.dll  (from System32)
        win32\: msvcp140.dll, msvcp140_1.dll, msvcp140_2.dll, vcruntime140.dll                      (from SysWOW64)
    A warning is issued for each file not found on the local machine.
    When omitted, the module configuration value CopyVCRuntime is used (default: $true).
    Pass -CopyVCRuntime:$false to skip copying; a warning is still issued for each missing file.

.EXAMPLE
    Update-MSIXTMPSF

.EXAMPLE
    Update-MSIXTMPSF -Force -Verbose

.EXAMPLE
    Update-MSIXTMPSF -CopyVCRuntime:$false

.NOTES
    Source: https://github.com/TimMangan/MSIX-PackageSupportFramework
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Switch] $Force,
        [System.Nullable[bool]] $CopyVCRuntime
    )

    # Load ZIP support (required in PS 5.1 / .NET Framework 4.5+)
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    if ($PSBoundParameters.ContainsKey('CopyVCRuntime')) {
        $resolvedCopyVC = [bool]$CopyVCRuntime
    } else {
        $resolvedCopyVC = $Script:MSIXForceletsConfig.CopyVCRuntime
    }

    $releasesUrl      = "https://api.github.com/repos/TimMangan/MSIX-PackageSupportFramework/releases"
    $timManganPsfPath = Join-Path $Script:MSIXPSFPath "TimManganPSF"

    # --- Query GitHub for latest release that carries a ZipRelease asset ---
    Write-Verbose "Querying GitHub for latest Tim Mangan PSF release..."
    try {
        $response = Invoke-WebRequest -Uri $releasesUrl -UseBasicParsing `
            -Headers @{ 'User-Agent' = 'MSIXForcelets' }
        $releases = $response.Content | ConvertFrom-Json
    }
    catch {
        Write-Error "Could not query GitHub releases: $_"
        return
    }

    $latestRelease = $null
    $zipAsset      = $null
    foreach ($release in $releases) {
        $asset = $release.assets |
            Where-Object { $_.name -like "ZipRelease*.zip" } |
            Select-Object -First 1
        if ($null -ne $asset) {
            $latestRelease = $release
            $zipAsset      = $asset
            break
        }
    }

    if ($null -eq $latestRelease) {
        Write-Warning "No Tim Mangan PSF release with a ZipRelease*.zip asset was found on GitHub."
        return
    }

    $assetName   = $zipAsset.name
    $downloadUrl = $zipAsset.browser_download_url

    # Extract date string from asset name, e.g. "ZipRelease.zip-v2026-2-22.zip" -> "2026-2-22"
    if ($assetName -match '-v(\d{4}-\d{1,2}-\d{1,2})') {
        $dateStr = $Matches[1]
    }
    else {
        $dateStr = $latestRelease.tag_name -replace '^[vV]', ''
    }

    $debugPath   = Join-Path $timManganPsfPath "$($dateStr)_debug"
    $releasePath = Join-Path $timManganPsfPath "$($dateStr)_release"

    Write-Verbose "Latest release : $($latestRelease.tag_name)"
    Write-Verbose "Asset          : $assetName"
    Write-Verbose "Debug folder   : $debugPath"
    Write-Verbose "Release folder : $releasePath"

    # --- Skip if already downloaded ---
    if ((Test-Path $debugPath) -and (Test-Path $releasePath) -and -not $Force) {
        Write-Verbose "PSF version '$dateStr' is already present. Use -Force to re-download."
        return
    }

    if (-not $Force) {
        if (-not $PSCmdlet.ShouldContinue(
                "Download Tim Mangan PSF '$assetName' from GitHub?",
                "Download PSF")) {
            return
        }
    }

    # --- Download outer ZIP to %TEMP% ---
    $guid        = [System.Guid]::NewGuid().ToString('N')
    $tempZip     = Join-Path $env:TEMP ("TMPSFPSF_outer_$guid.zip")
    $tempExtract = Join-Path $env:TEMP ("TMPSFPSF_outer_$guid")

    try {
        Write-Verbose "Downloading $downloadUrl ..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing

        Write-Verbose "Extracting outer ZIP..."
        [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempExtract)

        # --- Locate the inner Debug / Release ZIPs ---
        $innerZips  = Get-ChildItem -Path $tempExtract -Filter "*.zip" -Recurse
        $debugZip   = $innerZips | Where-Object { $_.Name -imatch 'debug' }   | Select-Object -First 1
        $releaseZip = $innerZips | Where-Object { $_.Name -imatch 'release' -and $_.Name -inotmatch 'debug' } |
            Select-Object -First 1

        if ($null -eq $debugZip -and $null -eq $releaseZip) {
            Write-Warning ("Could not identify Debug or Release ZIPs inside '$assetName'. " +
                "Found: $($innerZips.Name -join ', ')")
            return
        }

        # Build a lookup table: label -> @{ Path; Zip }
        $buildTypeMap = [ordered]@{}
        if ($null -ne $debugZip)   { $buildTypeMap['debug']   = @{ Path = $debugPath;   Zip = $debugZip } }
        if ($null -ne $releaseZip) { $buildTypeMap['release'] = @{ Path = $releasePath; Zip = $releaseZip } }

        # -----------------------------------------------------------------------
        # File routing tables - derived from the known release structure of
        # TimManganPSF\amd64\ and TimManganPSF\win32\.
        # -----------------------------------------------------------------------

        # Files that exist only in amd64\ (x64-exclusive natives)
        $amd64OnlyFiles = @(
            'PsfMonitorx64.exe',
            'vcruntime140_1.dll'        # x86 edition missing from Tim's package
        )

        # Files that exist only in win32\ (x86-exclusive)
        $win32OnlyFiles = @(
            'KernelTraceControl.Win61.dll',
            'PsfMonitorx86.exe'
        )

        # Native PE files that Tim ships for BOTH architectures under the same filename.
        # Use Get-MSIXAppMachineType to route each copy to the correct sub-folder.
        #   amd64\: KernelTraceControl.dll (x64), msdia140.dll (x64), msvcp140.dll (x64),
        #           PsfMonitor.exe (x64), ucrtbased.dll (x64), vcruntime140.dll (x64)
        #   win32\: the same names but x86 builds
        $peDetectedBothFiles = @(
            'KernelTraceControl.dll',
            'msdia140.dll',
            'msvcp140.dll',
            'PsfMonitor.exe',
            'TraceReloggerLib.dll',
            'ucrtbased.dll',
            'vcruntime140.dll'
        )

        # AnyCPU .NET assemblies - PE header reports I386 but they are architecture-neutral.
        # Copy to BOTH amd64\ and win32\ so PsfMonitor works in either bitness.
        $copyBothFiles = @(
            'Microsoft.Diagnostics.FastSerialization.dll',
            'Microsoft.Diagnostics.Tracing.TraceEvent.dll',
            'OSExtensions.dll'
        )

        # PSF core files expected by Add-MSIXPsfFrameworkFiles
        $expectedRootFiles = @(
            'PsfLauncher32.exe',          'PsfLauncher64.exe',
            'PsfRunDll32.exe',            'PsfRunDll64.exe',
            'PsfRuntime32.dll',           'PsfRuntime64.dll',
            'DynamicLibraryFixup32.dll',  'DynamicLibraryFixup64.dll',
            'EnvVarFixup32.dll',          'EnvVarFixup64.dll',
            'FileRedirectionFixup32.dll', 'FileRedirectionFixup64.dll',
            'MFRFixup32.dll',             'MFRFixup64.dll',
            'RegLegacyFixups32.dll',      'RegLegacyFixups64.dll',
            'TraceFixup32.dll',           'TraceFixup64.dll',
            'StartingScriptWrapper.ps1',
            'StartMenuCmdScriptWrapper.ps1',
            'StartMenuShellLaunchWrapperScript.ps1'
        )
        # VCRuntime DLLs are NOT shipped by Tim - must be sourced from the local Windows installation
        $expectedAmd64Runtime = @('msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')
        $expectedWin32Runtime = @('msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll', 'vcruntime140.dll')

        foreach ($buildType in $buildTypeMap.Keys) {
            $entry     = $buildTypeMap[$buildType]
            $buildPath = $entry.Path
            $innerZip  = $entry.Zip
            $innerGuid = [System.Guid]::NewGuid().ToString('N')
            $innerTemp = Join-Path $env:TEMP "TMPSFPSF_inner_$innerGuid"

            Write-Verbose "Extracting $($innerZip.Name) -> $buildPath ..."
            [System.IO.Compression.ZipFile]::ExtractToDirectory($innerZip.FullName, $innerTemp)

            $amd64Path = Join-Path $buildPath "amd64"
            $win32Path = Join-Path $buildPath "win32"
            New-Item -Path $amd64Path -ItemType Directory -Force | Out-Null
            New-Item -Path $win32Path -ItemType Directory -Force | Out-Null

            # Route each extracted file to the correct destination:
            #   amd64OnlyFiles    → amd64\ only
            #   win32OnlyFiles    → win32\ only
            #   peDetectedBothFiles → amd64\ or win32\ via Get-MSIXAppMachineType
            #   copyBothFiles     → both amd64\ and win32\ (AnyCPU .NET assemblies)
            #   everything else   → build root (_debug\ or _release\)
            $allFiles = Get-ChildItem -Path $innerTemp -File -Recurse
            foreach ($file in $allFiles) {
                if ($amd64OnlyFiles -contains $file.Name) {
                    Copy-Item $file.FullName -Destination $amd64Path -Force
                }
                elseif ($win32OnlyFiles -contains $file.Name) {
                    Copy-Item $file.FullName -Destination $win32Path -Force
                }
                elseif ($peDetectedBothFiles -contains $file.Name) {
                    $arch = Get-MSIXAppMachineType -FilePathName $file
                    switch ($arch) {
                        'x64'  { Copy-Item $file.FullName -Destination $amd64Path -Force }
                        'I386' { Copy-Item $file.FullName -Destination $win32Path -Force }
                        default { Copy-Item $file.FullName -Destination $buildPath -Force }
                    }
                }
                elseif ($copyBothFiles -contains $file.Name) {
                    Copy-Item $file.FullName -Destination $amd64Path -Force
                    Copy-Item $file.FullName -Destination $win32Path -Force
                }
                else {
                    # PSF core binaries (PsfLauncher32/64, Fixup DLLs), scripts, Version.txt, etc.
                    Copy-Item $file.FullName -Destination $buildPath -Force
                }
            }

            # --- Warn about missing PSF core files (unexpected) ---
            $allExtractedNames = $allFiles | Select-Object -ExpandProperty Name
            foreach ($expected in $expectedRootFiles) {
                if ($allExtractedNames -notcontains $expected) {
                    Write-Warning "$buildType`: expected PSF file missing from package: $expected"
                }
            }

            # --- VCRuntime: copy from local Windows installation or warn if absent ---
            # msvcp140.dll, vcruntime140.dll, vcruntime140_1.dll are not shipped by Tim Mangan.
            $vcRuntimeSources = @{
                amd64 = @{ Dest = $amd64Path; Source = "$env:SystemRoot\System32"; Files = $expectedAmd64Runtime }
                win32 = @{ Dest = $win32Path; Source = "$env:SystemRoot\SysWOW64"; Files = $expectedWin32Runtime }
            }

            foreach ($archKey in $vcRuntimeSources.Keys) {
                $vcEntry = $vcRuntimeSources[$archKey]
                $present = Get-ChildItem -Path $vcEntry.Dest -File | Select-Object -ExpandProperty Name
                foreach ($vcFile in $vcEntry.Files) {
                    if ($present -notcontains $vcFile) {
                        $sourcePath = Join-Path $vcEntry.Source $vcFile
                        if ($resolvedCopyVC) {
                            if (Test-Path $sourcePath) {
                                Copy-Item $sourcePath -Destination $vcEntry.Dest -Force
                                Write-Verbose "Copied $vcFile -> $archKey\"
                            }
                            else {
                                Write-Warning "$vcFile not found on this system ($sourcePath). Install the Visual C++ Redistributable."
                            }
                        }
                        else {
                            Write-Warning "$vcFile is missing from $archKey\. Use -CopyVCRuntime or set CopyVCRuntime via Set-MSIXForceletsConfiguration."
                        }
                    }
                }
            }

            # --- Write SOURCE.txt and LICENSE.txt into the build folder ---
            @(
                "MSIX Package Support Framework by Tim Mangan",
                "=============================================",
                "",
                "Release   : $($latestRelease.tag_name)",
                "Build     : $buildType",
                "Asset     : $assetName",
                "Downloaded: $(Get-Date -Format 'yyyy-MM-dd')",
                "GitHub    : https://github.com/TimMangan/MSIX-PackageSupportFramework",
                "License   : MIT (see LICENSE.txt)",
                "",
                "Files in this folder were downloaded from the GitHub repository listed above",
                "and are subject to the MIT License.",
                "",
                "Downloaded by MSIXForcelets - https://www.nick-it.de"
            ) | Set-Content -Path (Join-Path $buildPath "SOURCE.txt") -Encoding UTF8

            try {
                $licenseUrl = "https://raw.githubusercontent.com/TimMangan/MSIX-PackageSupportFramework/master/LICENSE"
                Write-Verbose "Downloading LICENSE from $licenseUrl ..."
                Invoke-WebRequest -Uri $licenseUrl -OutFile (Join-Path $buildPath "LICENSE.txt") -UseBasicParsing
            }
            catch {
                Write-Warning "Could not download LICENSE file: $_"
            }

            Remove-Item $innerTemp -Recurse -Force -ErrorAction SilentlyContinue
        }

        "Tim Mangan PSF downloaded to: $timManganPsfPath ($($dateStr)_debug / $($dateStr)_release)"
    }
    catch {
        Write-Error "Failed to download or extract Tim Mangan PSF: $_"
        throw
    }
    finally {
        if (Test-Path $tempZip)     { Remove-Item $tempZip     -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
