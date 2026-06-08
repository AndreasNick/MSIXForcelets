# Stage MSIXForcelets for a PowerShell Gallery publish.
#
# Copies src\ to out\MSIXForcelets\, EXCLUDING the large binary download trees that
# Update-MSIXTooling / Update-MSIXTMPSF / Update-MSIXMicrosoftPSF fetch on demand at
# runtime (MSIXPSF, Libs\MSIXPackaging, Libs\MSIXCore). Includes the repo LICENSE in
# the staged module folder. Validates the manifest, imports the staged module and
# verifies the exported function count, and optionally runs PSScriptAnalyzer.
#
# This script does NOT publish - that is a manual step at the end (requires your
# NuGet API key from powershellgallery.com).

[CmdletBinding()]
param(
    [string] $StageRoot  = (Join-Path $env:Temp 'MSIXForcelets_publish'),
    [switch] $SkipAnalyzer
)

$ErrorActionPreference = 'Stop'
$RepoRoot   = $PSScriptRoot
$ModuleName = 'MSIXForcelets'
$Src        = Join-Path $RepoRoot 'src'
$Out        = Join-Path $StageRoot $ModuleName

# Folders inside src\ that must NOT be uploaded (fetched on demand at runtime).
$excludePrefixes = @(
    (Join-Path $Src 'MSIXPSF'),
    (Join-Path $Src 'Libs\MSIXPackaging'),
    (Join-Path $Src 'Libs\MSIXCore')
)

# --- 1. Clean stage --------------------------------------------------------------
if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
$null = New-Item -ItemType Directory -Path $Out -Force
Write-Verbose "Staging into: $Out" -Verbose

# --- 2. Copy src\ -> out\MSIXForcelets\, skipping the binary trees ---------------
$srcLen = $Src.Length + 1
$copied = 0
Get-ChildItem $Src -Recurse -File | Where-Object {
    $full = $_.FullName
    -not ($excludePrefixes | Where-Object { $full -like "$_\*" })
} | ForEach-Object {
    $rel    = $_.FullName.Substring($srcLen)
    $target = Join-Path $Out $rel
    $tdir   = Split-Path $target -Parent
    if (-not (Test-Path $tdir)) { $null = New-Item -ItemType Directory -Path $tdir -Force }
    Copy-Item $_.FullName $target -Force
    $copied++
}
Write-Verbose "Copied files: $copied" -Verbose

# --- 3. Ship LICENSE next to the manifest ----------------------------------------
$license = Join-Path $RepoRoot 'LICENSE'
if (Test-Path $license) {
    Copy-Item $license (Join-Path $Out 'LICENSE') -Force
    Write-Verbose "Included LICENSE." -Verbose
} else {
    Write-Warning "LICENSE not found at $license."
}

# --- 4. Manifest validation -------------------------------------------------------
$psd1 = Join-Path $Out ($ModuleName + '.psd1')
$manifest = Test-ModuleManifest -Path $psd1 -ErrorAction Stop
Write-Verbose ("Manifest OK: {0} v{1}" -f $manifest.Name, $manifest.Version) -Verbose

# --- 5. Import + export-count cross-check ----------------------------------------
Import-Module $Out -Force
$publicNames   = (Get-ChildItem (Join-Path $Src 'Public') -Filter *.ps1).BaseName
$exportedNames = (Get-Command -Module $ModuleName).Name
Write-Verbose ("Exported: {0}  /  Public/*.ps1: {1}" -f $exportedNames.Count, $publicNames.Count) -Verbose
$notExported = @($publicNames | Where-Object { $_ -notin $exportedNames })
if ($notExported.Count) {
    Write-Verbose "Public functions NOT in FunctionsToExport (intentional?):" -Verbose
    $notExported | ForEach-Object { Write-Verbose "  - $_" -Verbose }
}

# --- 6. PSScriptAnalyzer (optional) ----------------------------------------------
if (-not $SkipAnalyzer) {
    if (Get-Module -ListAvailable PSScriptAnalyzer) {
        $issues = Invoke-ScriptAnalyzer -Path $Out -Recurse -Severity Warning, Error
        if ($issues) {
            Write-Warning ("PSScriptAnalyzer reported {0} issue(s) - review before publish." -f $issues.Count)
            $issues | Group-Object Severity | ForEach-Object {
                Write-Verbose ("  {0}: {1}" -f $_.Name, $_.Count) -Verbose
            }
        } else {
            Write-Verbose "PSScriptAnalyzer: no warnings/errors." -Verbose
        }
    } else {
        Write-Warning "PSScriptAnalyzer not installed - skipping (Install-Module PSScriptAnalyzer)."
    }
}

# --- 7. Done ---------------------------------------------------------------------
Write-Output ""
Write-Output ("Staged package: {0}" -f $Out)
Write-Output "Next step (manual, requires your NuGet API key from powershellgallery.com):"
Write-Output ("  Publish-Module -Path '{0}' -NuGetApiKey '<your-key>'" -f $Out)
