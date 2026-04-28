function Update-MSIXTooling {
<#
.SYNOPSIS
    Downloads and installs the latest MSIX packaging tools.

.DESCRIPTION
    Downloads two sets of tools into the module's Libs folder:

      1. MSIX Core (msixmgr.exe)
         Source: https://github.com/microsoft/msix-packaging
         Target: Libs\MSIXCore\

      2. Windows SDK Packaging Tools (makeappx.exe, signtool.exe)
         Source: https://github.com/microsoft/MSIX-Toolkit
         Target: Libs\MSIXPackaging\

    Each tool is only downloaded when missing or a newer release is available.
    Use -SkipCore or -SkipPackaging to download only one of the two.

.PARAMETER Force
    Suppresses all confirmation prompts.

.PARAMETER SkipCore
    Skip downloading MSIX Core (msixmgr.exe).

.PARAMETER SkipPackaging
    Skip downloading the Windows SDK Packaging Tools (makeappx, signtool).

.EXAMPLE
    Update-MSIXTooling

.EXAMPLE
    Update-MSIXTooling -Force

.EXAMPLE
    Update-MSIXTooling -SkipCore

.NOTES
    MSIX Core source    : https://github.com/microsoft/msix-packaging
    MSIX Toolkit source : https://github.com/microsoft/MSIX-Toolkit
    Andreas Nick, 2026
#>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Switch] $Force,
        [Switch] $SkipCore,
        [Switch] $SkipPackaging
    )

    # --- MSIX Core (msixmgr.exe) ---
    if (-not $SkipCore) {
        $msixCoreDir  = $Script:MSIXCorePath
        $msixmgrPath  = Join-Path $msixCoreDir "x64\msixmgr.exe"
        $versionFile  = Join-Path $msixCoreDir "version.txt"
        $releasesUrl  = "https://api.github.com/repos/microsoft/msix-packaging/releases"

        $installedVersion = $null
        if (Test-Path $versionFile) {
            $installedVersion = (Get-Content $versionFile -Raw).Trim()
        }

        Write-Verbose "Querying GitHub for latest MSIX Core release..."
        try {
            $response      = Invoke-WebRequest -Uri $releasesUrl -UseBasicParsing -Headers @{ 'User-Agent' = 'MSIXForcelets' }
            $releases      = $response.Content | ConvertFrom-Json
            $latestRelease = $releases | Where-Object { $_.tag_name -like 'MSIX-Core-*' } | Select-Object -First 1
        }
        catch {
            Write-Error "Could not query GitHub for MSIX Core releases: $_"
            $latestRelease = $null
        }

        if ($null -ne $latestRelease) {
            $latestTag     = $latestRelease.tag_name
            $msixmgrExists = Test-Path $msixmgrPath

            if ($msixmgrExists -and $installedVersion -eq $latestTag) {
                Write-Host "MSIX Core is up to date ($latestTag)." -ForegroundColor Green
            }
            else {
                if ($msixmgrExists) {
                    Write-Host "MSIX Core update available: $installedVersion -> $latestTag"
                }
                else {
                    Write-Host "MSIX Core not installed. Latest version: $latestTag"
                }

                $proceed = $Force -or $PSCmdlet.ShouldContinue(
                    "Download and install MSIX Core $latestTag from GitHub?", "Install MSIX Core")

                if ($proceed) {
                    $downloadUrl = "https://github.com/microsoft/msix-packaging/releases/download/$latestTag/msixmgr.zip"
                    $tempZip     = Join-Path $env:TEMP ("msixmgr_" + [System.Guid]::NewGuid().ToString('N') + ".zip")
                    $tempExtract = Join-Path $env:TEMP ("msixmgr_" + [System.Guid]::NewGuid().ToString('N'))
                    try {
                        Write-Verbose "Downloading $downloadUrl..."
                        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing
                        [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempExtract)
                        if (-not (Test-Path $msixCoreDir)) {
                            New-Item -Path $msixCoreDir -ItemType Directory -Force | Out-Null
                        }
                        Copy-Item -Path (Join-Path $tempExtract "*") -Destination $msixCoreDir -Recurse -Force
                        Set-Content -Path $versionFile -Value $latestTag -Encoding UTF8
                        Write-Host "MSIX Core $latestTag installed to $msixCoreDir" -ForegroundColor Green
                        if (Get-Alias msixmgr -ErrorAction SilentlyContinue) {
                            Remove-Item -Path Alias:msixmgr -Force
                        }
                        New-Alias -Name msixmgr -Value $msixmgrPath -Scope Script
                    }
                    catch {
                        Write-Error "Failed to download MSIX Core: $_"
                    }
                    finally {
                        if (Test-Path $tempZip)     { Remove-Item $tempZip     -Force -ErrorAction SilentlyContinue }
                        if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
                    }
                }
            }
        }
    }

    # --- MSIX Toolkit: makeappx.exe + signtool.exe ---
    if (-not $SkipPackaging) {
        # $Script:MSIXPackagingPath = ..\Libs\MSIXPackaging\WindowsSDK\11\10.0.22000.0\x64
        # Four levels up reaches MSIXPackaging
        $toolkitRoot = Split-Path $Script:MSIXPackagingPath -Parent |
                       Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
        $versionFile = Join-Path $toolkitRoot "version.txt"
        $releasesUrl = "https://api.github.com/repos/microsoft/MSIX-Toolkit/releases"

        $installedVersion = $null
        if (Test-Path $versionFile) {
            $installedVersion = (Get-Content $versionFile -Raw).Trim()
        }

        Write-Verbose "Querying GitHub for latest MSIX Toolkit release..."
        try {
            $response      = Invoke-WebRequest -Uri $releasesUrl -UseBasicParsing -Headers @{ 'User-Agent' = 'MSIXForcelets' }
            $releases      = $response.Content | ConvertFrom-Json
            $latestRelease = $releases | Select-Object -First 1
        }
        catch {
            Write-Error "Could not query GitHub for MSIX Toolkit releases: $_"
            $latestRelease = $null
        }

        if ($null -ne $latestRelease) {
            $latestTag      = $latestRelease.tag_name
            $makeappxExists = Test-Path (Join-Path $Script:MSIXPackagingPath 'makeappx.exe')

            if ($makeappxExists -and $installedVersion -eq $latestTag) {
                Write-Host "MSIX Toolkit is up to date ($latestTag)." -ForegroundColor Green
            }
            else {
                if ($makeappxExists) {
                    Write-Host "MSIX Toolkit update available: $installedVersion -> $latestTag"
                }
                else {
                    Write-Host "MSIX Toolkit not installed. Latest version: $latestTag"
                }

                $proceed = $Force -or $PSCmdlet.ShouldContinue(
                    "Download and install MSIX Toolkit $latestTag from GitHub?", "Install MSIX Toolkit")

                if ($proceed) {
                    # Source archive URL — the toolkit has no separate binary release asset
                    $downloadUrl = "https://github.com/microsoft/MSIX-Toolkit/archive/refs/tags/$($latestTag).zip"
                    $tempZip     = Join-Path $env:TEMP ("MSIXToolkit_" + [System.Guid]::NewGuid().ToString('N') + ".zip")
                    $tempExtract = Join-Path $env:TEMP ("MSIXToolkit_" + [System.Guid]::NewGuid().ToString('N'))
                    try {
                        Write-Verbose "Downloading $downloadUrl..."
                        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing
                        [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempExtract)

                        # Source archive unpacks to MSIX-Toolkit-{version}\ (no leading 'v')
                        $innerFolder = Join-Path $tempExtract ("MSIX-Toolkit-" + $latestTag.TrimStart('v'))
                        if (-not (Test-Path $innerFolder)) {
                            # Fallback: first subfolder inside the extract dir
                            $innerFolder = (Get-ChildItem $tempExtract -Directory | Select-Object -First 1).FullName
                        }

                        if (-not (Test-Path $toolkitRoot)) {
                            New-Item -Path $toolkitRoot -ItemType Directory -Force | Out-Null
                        }

                        # Copy only the needed subfolders and the license file
                        foreach ($item in @('Scripts', 'WindowsSDK', 'LICENSE')) {
                            $src = Join-Path $innerFolder $item
                            if (Test-Path $src) {
                                Copy-Item -Path $src -Destination $toolkitRoot -Recurse -Force
                            }
                            else {
                                Write-Verbose "Item not found in archive: $item"
                            }
                        }

                        Set-Content -Path $versionFile -Value $latestTag -Encoding UTF8
                        Write-Host "MSIX Toolkit $latestTag installed to $toolkitRoot" -ForegroundColor Green

                        # Refresh aliases for the current session
                        $makeappxExe = Join-Path $Script:MSIXPackagingPath 'makeappx.exe'
                        if (Test-Path $makeappxExe) {
                            if (Get-Alias makeappx -ErrorAction SilentlyContinue) { Remove-Item Alias:makeappx -Force }
                            if (Get-Alias signtool -ErrorAction SilentlyContinue) { Remove-Item Alias:signtool -Force }
                            New-Alias -Name makeappx -Value $makeappxExe -Scope Global
                            New-Alias -Name signtool -Value (Join-Path $Script:MSIXPackagingPath 'signtool.exe') -Scope Global
                        }
                        else {
                            Write-Warning "makeappx.exe not found at expected path after extraction: $($Script:MSIXPackagingPath)"
                        }
                    }
                    catch {
                        Write-Error "Failed to download MSIX Toolkit: $_"
                    }
                    finally {
                        if (Test-Path $tempZip)     { Remove-Item $tempZip     -Force -ErrorAction SilentlyContinue }
                        if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
                    }
                }
            }
        }
    }
}
