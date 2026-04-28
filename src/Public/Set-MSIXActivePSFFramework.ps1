
function Set-MSIXActivePSFFramework {
    <#
    .SYNOPSIS
    Sets the active PSF (Package Support Framework) used by all PSF cmdlets.

    .DESCRIPTION
    Discovers all PSF installations under the module MSIXPSF folder by searching for
    directories that contain PsfLauncher64.exe or PsfLauncher32.exe. Sets the module-scope
    variable $Script:PsfBasePath so that Add-MSIXPsfFrameworkFiles and related cmdlets
    automatically use the correct files.

    Discovered options include:
      - MicrosoftPSF                       (Microsoft official PSF)
      - TimManganPSF                       (Tim Mangan PSF root with existing files)
      - TimManganPSF\2026-2-22_release     (specific downloaded release build)
      - TimManganPSF\2026-2-22_debug       (specific downloaded debug build)

    Use -List to display all available installations without changing the active one.
    Tab-completion on -Framework enumerates valid options automatically.

    .PARAMETER Framework
    Relative path under the MSIXPSF folder identifying the PSF to activate.
    Examples: "MicrosoftPSF", "TimManganPSF", "TimManganPSF\2026-2-22_release"

    .PARAMETER List
    Lists all discovered PSF installations with their full paths. Does not change
    the active framework.

    .EXAMPLE
    Set-MSIXActivePSFFramework -Framework MicrosoftPSF

    .EXAMPLE
    Set-MSIXActivePSFFramework -Framework "TimManganPSF\2026-2-22_release"

    .EXAMPLE
    Set-MSIXActivePSFFramework -List

    .NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
    #>
    [CmdletBinding(DefaultParameterSetName = 'Set')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Set', Position = 0)]
        [ArgumentCompleter({
            param($cmd, $param, $word, $ast, $fakeBound)
            # Access the module-private variable from within the module scope
            $module  = Get-Module MSIXForcelets
            if ($null -eq $module) { return }
            $psfRoot = & $module { $Script:MSIXPSFPath }
            if (-not (Test-Path $psfRoot)) { return }

            $options = @()
            foreach ($dir in (Get-ChildItem $psfRoot -Directory -ErrorAction SilentlyContinue)) {
                $hasLauncher = (Test-Path (Join-Path $dir.FullName 'PsfLauncher64.exe')) -or
                               (Test-Path (Join-Path $dir.FullName 'PsfLauncher32.exe'))
                if ($hasLauncher) {
                    $options += $dir.Name
                }
                # One level deeper (e.g. TimManganPSF\2026-2-22_release)
                foreach ($sub in (Get-ChildItem $dir.FullName -Directory -ErrorAction SilentlyContinue)) {
                    $subHas = (Test-Path (Join-Path $sub.FullName 'PsfLauncher64.exe')) -or
                              (Test-Path (Join-Path $sub.FullName 'PsfLauncher32.exe'))
                    if ($subHas) {
                        $options += "$($dir.Name)\$($sub.Name)"
                    }
                }
            }
            # Quote options that contain a backslash so PowerShell handles them correctly
            $options |
                Where-Object { $_ -like "$word*" } |
                ForEach-Object { if ($_ -match '\\') { "'$_'" } else { $_ } }
        })]
        [string] $Framework,

        [Parameter(Mandatory = $true, ParameterSetName = 'List')]
        [Switch] $List
    )

    $psfRoot = $Script:MSIXPSFPath

    if (-not (Test-Path $psfRoot)) {
        Write-Error "MSIXPSF folder not found: $psfRoot"
        return
    }

    # Discover all valid PSF installations (top-level and one sublevel)
    $discovered = @()
    foreach ($dir in (Get-ChildItem $psfRoot -Directory -ErrorAction SilentlyContinue)) {
        $hasLauncher = (Test-Path (Join-Path $dir.FullName 'PsfLauncher64.exe')) -or
                       (Test-Path (Join-Path $dir.FullName 'PsfLauncher32.exe'))
        if ($hasLauncher) {
            $discovered += [PSCustomObject]@{
                Name = $dir.Name
                Path = $dir.FullName
            }
        }
        foreach ($sub in (Get-ChildItem $dir.FullName -Directory -ErrorAction SilentlyContinue)) {
            $subHas = (Test-Path (Join-Path $sub.FullName 'PsfLauncher64.exe')) -or
                      (Test-Path (Join-Path $sub.FullName 'PsfLauncher32.exe'))
            if ($subHas) {
                $discovered += [PSCustomObject]@{
                    Name = "$($dir.Name)\$($sub.Name)"
                    Path = $sub.FullName
                }
            }
        }
    }

    # -List: display available installations and return
    if ($PSCmdlet.ParameterSetName -eq 'List') {
        if ($discovered.Count -eq 0) {
            Write-Warning "No PSF installations found under $psfRoot"
            return
        }
        $active = $Script:PsfBasePath
        $discovered | ForEach-Object {
            $marker = if ($_.Path -eq $active) { '*' } else { ' ' }
            [PSCustomObject]@{
                Active = $marker
                Name   = $_.Name
                Path   = $_.Path
            }
        } | Format-Table -AutoSize
        return
    }

    # -Framework: find and activate the selected installation
    $selected = $discovered | Where-Object { $_.Name -eq $Framework } | Select-Object -First 1

    if ($null -eq $selected) {
        $availableNames = $discovered | Select-Object -ExpandProperty Name
        Write-Error ("PSF '$Framework' not found. Available options:`n" +
            ($availableNames | ForEach-Object { "  $_" } | Out-String).TrimEnd() +
            "`nUse Set-MSIXActivePSFFramework -List for details.")
        return
    }

    $Script:PSFVersion  = $Framework
    $Script:PsfBasePath = $selected.Path

    Write-Host "Active PSF : $Framework" -ForegroundColor Green
    Write-Host "Path       : $($Script:PsfBasePath)" -ForegroundColor Green

    # Warn if expected structure is incomplete
    $missingWarnings = @()
    if (-not (Test-Path (Join-Path $Script:PsfBasePath 'amd64'))) {
        $missingWarnings += "amd64\ subfolder (needed for x64 VCRuntime files)"
    }
    if (-not (Test-Path (Join-Path $Script:PsfBasePath 'win32'))) {
        $missingWarnings += "win32\ subfolder (needed for x86 VCRuntime files)"
    }
    foreach ($w in $missingWarnings) {
        Write-Warning "PSF installation is missing: $w"
    }
}
