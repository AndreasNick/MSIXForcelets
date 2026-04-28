function Update-MSIXMicrosoftPSF {
<#
.SYNOPSIS
    Downloads and organises the latest Microsoft MSIX Package Support Framework from NuGet.

.DESCRIPTION
    Queries the NuGet v3 API for the latest version of the Microsoft.PackageSupportFramework
    package, downloads the .nupkg (which is a ZIP archive), and sorts all EXE and DLL files
    into the correct sub-folders, matching the same layout used by Update-MSIXTMPSF.

    Files are placed under:
        <module>\MSIXPSF\MicrosoftPSF\<version>\
            amd64\   <- x64-specific binaries
            win32\   <- x86-specific binaries
                     <- shared binaries (32/64 suffix pairs) and scripts

    If StartingScriptWrapper.ps1 is not included in the NuGet package it is copied from the
    module's Libs folder (src\Libs\StartingScriptWrapper.ps1).

    SOURCE.txt and LICENSE.txt are written into each version folder on download.

    The Visual C++ Runtime DLLs are not included in the NuGet package. By default they are
    copied from the local Windows installation. A warning is issued for each file not found.

.PARAMETER Force
    Skips confirmation prompts and overwrites an existing version folder.

.PARAMETER CopyVCRuntime
    Copies the Visual C++ Runtime DLLs from the local Windows installation into amd64\ and win32\:
        amd64\: msvcp140.dll, msvcp140_1.dll, msvcp140_2.dll, vcruntime140.dll, vcruntime140_1.dll  (from System32)
        win32\: msvcp140.dll, msvcp140_1.dll, msvcp140_2.dll, vcruntime140.dll                      (from SysWOW64)
    A warning is issued for each file not found on the local machine.
    When omitted, the module configuration value CopyVCRuntime is used (default: $true).
    Pass -CopyVCRuntime:$false to skip copying; a warning is still issued for each missing file.

.EXAMPLE
    Update-MSIXMicrosoftPSF

.EXAMPLE
    Update-MSIXMicrosoftPSF -Force -Verbose

.EXAMPLE
    Update-MSIXMicrosoftPSF -CopyVCRuntime:$false

.NOTES
    NuGet source : https://www.nuget.org/packages/Microsoft.PackageSupportFramework
    GitHub source: https://github.com/microsoft/MSIX-PackageSupportFramework
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Switch] $Force,
        [System.Nullable[bool]] $CopyVCRuntime
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    if ($PSBoundParameters.ContainsKey('CopyVCRuntime')) {
        $resolvedCopyVC = [bool]$CopyVCRuntime
    } else {
        $resolvedCopyVC = $Script:MSIXForceletsConfig.CopyVCRuntime
    }

    $nugetBaseUrl     = $Script:MicrosoftPSFNuGetUrl
    $microsoftPsfPath = Join-Path $Script:MSIXPSFPath "MicrosoftPSF"
    $libsPath         = Join-Path $Script:ScriptPath "Libs"

    # --- Query NuGet v3 for the latest version ---
    Write-Verbose "Querying NuGet for latest Microsoft PSF version..."
    try {
        $indexResponse = Invoke-WebRequest -Uri "$nugetBaseUrl/index.json" -UseBasicParsing `
            -Headers @{ 'User-Agent' = 'MSIXForcelets' }
        $versionList   = ($indexResponse.Content | ConvertFrom-Json).versions
    }
    catch {
        Write-Error "Could not query NuGet index: $_"
        return
    }

    if ($null -eq $versionList -or $versionList.Count -eq 0) {
        Write-Error "NuGet returned an empty version list for Microsoft.PackageSupportFramework."
        return
    }

    $latestVersion = $versionList[-1]
    $downloadUrl   = "$nugetBaseUrl/$latestVersion/microsoft.packagesupportframework.$latestVersion.nupkg"
    $versionPath   = Join-Path $microsoftPsfPath $latestVersion

    Write-Verbose "Latest version : $latestVersion"
    Write-Verbose "Download URL   : $downloadUrl"
    Write-Verbose "Target folder  : $versionPath"

    # --- Skip if already present ---
    if ((Test-Path $versionPath) -and -not $Force) {
        Write-Verbose "Microsoft PSF version '$latestVersion' is already present. Use -Force to re-download."
        return
    }

    if (-not $Force) {
        if (-not $PSCmdlet.ShouldContinue(
                "Download Microsoft PSF $latestVersion from NuGet?",
                "Download PSF")) {
            return
        }
    }

    # --- Download .nupkg to %TEMP% ---
    $guid        = [System.Guid]::NewGuid().ToString('N')
    $tempZip     = Join-Path $env:TEMP "MSPsf_$guid.nupkg"
    $tempExtract = Join-Path $env:TEMP "MSPsf_$guid"

    try {
        Write-Verbose "Downloading $downloadUrl ..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing

        Write-Verbose "Extracting NuGet package..."
        [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempExtract)

        # -----------------------------------------------------------------------
        # File routing tables - derived from the known MicrosoftPSF\OLD structure.
        # -----------------------------------------------------------------------

        # Files that belong exclusively in amd64\
        $amd64OnlyFiles = @(
            'PsfMonitorx64.exe',
            'vcruntime140_1.dll'
        )

        # Files that belong exclusively in win32\
        $win32OnlyFiles = @(
            'KernelTraceControl.Win61.dll',
            'PsfMonitorx86.exe'
        )

        # PE binaries shipped for both architectures under the same filename.
        # Get-MSIXAppMachineType determines whether each copy goes to amd64\ or win32\.
        $peDetectedBothFiles = @(
            'KernelTraceControl.dll',
            'msdia140.dll',
            'msvcp140.dll',
            'PsfMonitor.exe',
            'TraceReloggerLib.dll',
            'ucrtbased.dll',
            'vcruntime140.dll'
        )

        # AnyCPU .NET assemblies - copy to both amd64\ and win32\
        $copyBothFiles = @(
            'Microsoft.Diagnostics.FastSerialization.dll',
            'Microsoft.Diagnostics.Tracing.TraceEvent.dll',
            'OSExtensions.dll'
        )

        # Ignore NuGet metadata and C++ SDK files (headers, linker libs, build targets, package signature)
        $ignoreExtensions = @('.nuspec', '.psmdcp', '.rels', '.xml', '.h', '.lib', '.targets', '.p7s')

        $amd64Path = Join-Path $versionPath "amd64"
        $win32Path = Join-Path $versionPath "win32"
        New-Item -Path $amd64Path -ItemType Directory -Force | Out-Null
        New-Item -Path $win32Path -ItemType Directory -Force | Out-Null

        $allFiles = Get-ChildItem -Path $tempExtract -File -Recurse | Where-Object {
            $ignoreExtensions -notcontains $_.Extension
        }

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
                    default { Copy-Item $file.FullName -Destination $versionPath -Force }
                }
            }
            elseif ($copyBothFiles -contains $file.Name) {
                Copy-Item $file.FullName -Destination $amd64Path -Force
                Copy-Item $file.FullName -Destination $win32Path -Force
            }
            else {
                # PSF core binaries (PsfLauncher32/64, Fixup DLLs, scripts, etc.)
                Copy-Item $file.FullName -Destination $versionPath -Force
            }
        }

        # --- VCRuntime: copy from local Windows installation or warn if absent ---
        # msvcp140.dll, vcruntime140.dll, vcruntime140_1.dll are not included in the NuGet package.
        $vcRuntimeSources = @{
            amd64 = @{
                Dest   = $amd64Path
                Source = "$env:SystemRoot\System32"
                Files  = @('msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')
            }
            win32 = @{
                Dest   = $win32Path
                Source = "$env:SystemRoot\SysWOW64"
                Files  = @('msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll', 'vcruntime140.dll')
            }
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

        # --- Copy StartingScriptWrapper.ps1 from Libs if not already present ---
        $startingScript    = Join-Path $versionPath "StartingScriptWrapper.ps1"
        $startingScriptLib = Join-Path $libsPath "StartingScriptWrapper.ps1"

        if (-not (Test-Path $startingScript)) {
            if (Test-Path $startingScriptLib) {
                Copy-Item $startingScriptLib -Destination $versionPath -Force
                Write-Verbose "Copied StartingScriptWrapper.ps1 from Libs."
            }
            else {
                Write-Warning "StartingScriptWrapper.ps1 not found in the NuGet package or in $libsPath."
            }
        }

        # --- Write SOURCE.txt and LICENSE.txt into the version folder ---
        @(
            "Microsoft MSIX Package Support Framework",
            "========================================",
            "",
            "Version   : $latestVersion",
            "Downloaded: $(Get-Date -Format 'yyyy-MM-dd')",
            "NuGet     : $downloadUrl",
            "GitHub    : https://github.com/microsoft/MSIX-PackageSupportFramework",
            "License   : MIT (see LICENSE.txt)",
            "",
            "Files in this folder were downloaded from NuGet and are subject to the MIT License.",
            "",
            "Downloaded by MSIXForcelets - https://www.nick-it.de"
        ) | Set-Content -Path (Join-Path $versionPath "SOURCE.txt") -Encoding UTF8

        try {
            $licenseUrl = "https://raw.githubusercontent.com/microsoft/MSIX-PackageSupportFramework/main/LICENSE"
            Write-Verbose "Downloading LICENSE from $licenseUrl ..."
            Invoke-WebRequest -Uri $licenseUrl -OutFile (Join-Path $versionPath "LICENSE.txt") -UseBasicParsing
        }
        catch {
            Write-Warning "Could not download LICENSE file: $_"
        }

        "Microsoft PSF $latestVersion downloaded to: $versionPath"
    }
    catch {
        Write-Error "Failed to download or extract Microsoft PSF: $_"
        throw
    }
    finally {
        if (Test-Path $tempZip)     { Remove-Item $tempZip     -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
