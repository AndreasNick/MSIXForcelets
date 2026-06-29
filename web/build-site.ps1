<#
.SYNOPSIS
    Generates the static cmdlet reference page (cmdlets.html) from the live module.
.DESCRIPTION
    Imports MSIXForcelets, reads every exported function and its comment-based
    synopsis, groups the cmdlets into categories and emits a dark-themed, static,
    SEO-friendly HTML page. Each cmdlet gets a stable anchor (#cmdlet-name) and a
    version-pinned link to its source on GitHub.

    Re-run this on every release (pass -Ref v1.2.3) so the docs match the shipped version.
.PARAMETER RepoBase
    GitHub repository base URL.
.PARAMETER Ref
    Git ref the source links point at (branch or tag, e.g. 'v1.0.0'). Verified against the
    remote: if the ref is not found on GitHub (e.g. a tag that was not pushed), the script
    warns and falls back to 'master' so the generated source links never 404.
.PARAMETER OutFile
    Output HTML path. Defaults to cmdlets.html next to this script.
.NOTES
    Andreas Nick, 2026 - https://www.nick-it.de
#>
[CmdletBinding()]
param(
    [string] $RepoBase = 'https://github.com/AndreasNick/MSIXForcelets',
    [string] $Ref      = 'master',
    [string] $OutFile  = (Join-Path $PSScriptRoot 'cmdlets.html')
)

# Make sure the chosen ref actually exists on the remote, otherwise the generated source links
# would 404 (classic case: a version tag that was generated against but never pushed). When the
# ref cannot be confirmed on the remote, fall back to 'master', which always resolves.
if ($Ref -ne 'master') {
    $verified  = $false
    $reachable = $true
    try {
        $remoteHit = git ls-remote $RepoBase "refs/tags/$Ref" "refs/heads/$Ref" 2>$null
        if ($LASTEXITCODE -ne 0) { $reachable = $false }
        elseif (-not [string]::IsNullOrWhiteSpace($remoteHit)) { $verified = $true }
    }
    catch { $reachable = $false }

    if ($verified) {
        Write-Verbose "Ref '$Ref' verified on $RepoBase."
    }
    elseif (-not $reachable) {
        Write-Warning "Could not verify ref '$Ref' on $RepoBase (git/network). Using it as given - check the source links if the ref is not pushed."
    }
    else {
        Write-Warning "Ref '$Ref' not found on $RepoBase - source links would 404. Falling back to 'master'. Push the tag first (git push origin $Ref) for version-pinned links."
        $Ref = 'master'
    }
}

$moduleRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $moduleRoot 'src\MSIXForcelets.psm1') -Force *> $null

# --- Category map (display order). Unmapped cmdlets fall into 'Other'. --------
$categories = [ordered]@{
    'Open, build, sign &amp; validate' = @(
        'Open-MSIXPackage','Close-MSIXPackage','New-MSIXPackage','Backup-MSIXManifest',
        'Copy-ToMSIXPackage','Set-MSIXPublisher','Set-MSIXSignature','Test-MSIXSignature',
        'Get-MSIXPackageVersion','Set-MSIXPackageVersion','Test-MSIXManifest','New-MSIXSelfSigningCert')
    'Pre-built application fixes' = @(
        'Add-MSIXFixAcrobatReaderDC','Add-MSIXFixGimp','Add-MSIXFixLibreOffice',
        'Add-MSIXFixNotepadPlusPlus','Add-MSIXFixSSMS','Add-MSIXFixWinRAR','Add-MSIXFixWinRARModernShell')
    'Package Support Framework (PSF)' = @(
        'Set-MSIXActivePSFFramework','Get-MSIXPSFFrameworkPath','Add-MSIXPsfFrameworkFiles',
        'Add-MSIXPSFShim','Add-MSIXPSFMFRFixup','Add-MSIXPSFRegLegacyFixup','Add-MSIXPSFDefaultRegLegacy',
        'Add-MSIXPSFDefaultFRF','Add-MSIXPSFFileRedirectionFixup','Add-MSIXPSFDynamicLibraryFixup',
        'Add-MSIXPSFEnvVarFixup','Add-MSIXPSFFtaCom','Add-MSIXPSFTracing','Add-MSIXPSFMonitor',
        'Add-MSIXPSFPowerShellScript','Remove-MSIXPsfFiles','Remove-MSIXPSFMonitorFiles')
    'Applications, services &amp; dependencies' = @(
        'Add-MSIXApplication','Get-MSIXApplications','Set-MSIXApplication','Remove-MSIXApplications','New-MSIXApplicationVariant',
        'Add-MSIXAppExecutionAlias','Get-MSIXServices','Remove-MSIXServices','Get-MSIXDependencies','Remove-MSIXDependencies')
    'Shortcuts, shell &amp; context menus' = @(
        'Add-MSIXDesktop7Shortcut','Get-MSIXDesktop7Shortcut','Remove-MSIXDesktop7Shortcut','Repair-MSIXDesktop7Shortcut',
        'Add-MSIXFileTypeAssociation','Get-MSIXFileTypeAssociation','Set-MSIXFileTypeAssociation','Remove-MSIXFileTypeAssociation',
        'Convert-MSIXClassicContextMenuToVerbs','Remove-MSIXClassicShellExtension','Import-MSIXSparseShellExtension')
    'Capabilities, virtualization &amp; registry' = @(
        'Add-MSIXCapabilities','Add-MSIXFlexibleVirtualization','Add-MSIXDisableWriteVirtualization',
        'Add-MSIXInstalledLocationVirtualization','Add-MSIXloaderSearchPathOverride','Add-MSIXRegAccessFix',
        'Remove-MSIXPackageIntegrity','Add-MSIXFirewallRule','Add-MSIXSharedContainer','Add-MSIXSharedFonts')
    'Assets &amp; visual elements' = @(
        'New-MSIXAssetFrom','Set-MSIXApplicationVisualElements','Set-MSIXApplicationIcon')
    'App Attach &amp; deployment' = @(
        'New-MSIXAppAttachImage','New-MSIXDynamicAppAttachDisk','Invoke-MSIXCreateImage',
        'New-MSIXAppInstallerConfiguration','New-MSIXPortalPage')
    'Diagnostics &amp; inspection' = @(
        'Start-MSIXTracing','Stop-MSIXTracing','Wait-MSIXTracing','Get-MSIXVirtualProcess',
        'Get-MSIXAppMachineType','Get-MSIXAppExeDetailInfo','Get-AppXManifestInfo','Invoke-MSIXCleanup','Find-MSIXFonts')
    'Setup, tooling &amp; configuration' = @(
        'Install-MSIXForceletsAllRequirements',
        'Update-MSIXTooling','Update-MSIXMicrosoftPSF','Update-MSIXTMPSF','Set-MSIXCore',
        'Get-MSIXForceletsConfiguration','Set-MSIXForceletsConfiguration')
}

# Descriptions for cmdlets whose comment-based .SYNOPSIS is empty.
$overrides = @{
    'Add-MSIXFirewallRule'             = 'Adds a Windows Firewall rule (windows.firewallRules) for a packaged executable.'
    'Add-MSIXFixSSMS'                  = 'Pre-built fix for SQL Server Management Studio (SSMS) MSIX packages.'
    'Add-MSIXPSFFileRedirectionFixup'  = 'Adds a FileRedirectionFixup entry (package-relative or known-folder paths) to the PSF config.'
    'Add-MSIXPSFPowerShellScript'      = 'Configures PSF start/end PowerShell scripts for a packaged application.'
    'Copy-ToMSIXPackage'               = 'Copies files into an expanded MSIX package at a package-root-relative path.'
    'Get-MSIXPSFFrameworkPath'         = 'Returns the path of the currently active PSF framework.'
    'Invoke-MSIXCreateImage'           = 'Creates an App Attach image (VHD/VHDX/CIM) from an MSIX via msixmgr.'
    'New-MSIXAppInstallerConfiguration'= 'Generates an .appinstaller configuration for auto-update deployment.'
    'New-MSIXAssetFrom'                = 'Generates MSIX asset PNGs (tile/logo icons) from an exe, dll, ico or png source.'
    'New-MSIXSelfSigningCert'          = 'Creates a self-signed code-signing certificate (PFX) for test-signing MSIX packages.'
}

# --- Gather live data --------------------------------------------------------
$cmds = Get-Command -Module MSIXForcelets -CommandType Function
$info = @{}
foreach ($c in $cmds) {
    $help = Get-Help $c.Name -ErrorAction SilentlyContinue
    $syn  = if ($help) { ($help.Synopsis -replace '\s+', ' ').Trim() } else { '' }
    # A synopsis that just echoes the syntax line is treated as missing.
    if ([string]::IsNullOrWhiteSpace($syn) -or $syn.StartsWith("$($c.Name) [")) { $syn = '' }
    if (-not $syn -and $overrides.ContainsKey($c.Name)) { $syn = $overrides[$c.Name] }
    $info[$c.Name] = $syn
}

$publicDir = Join-Path $moduleRoot 'src\Public'
function Get-SourceLink([string]$name) {
    $file = "$name.ps1"
    if (-not (Test-Path (Join-Path $publicDir $file))) {
        $hit = Get-ChildItem $publicDir -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue |
            Where-Object { Select-String -Path $_.FullName -Pattern "function\s+$([regex]::Escape($name))\b" -Quiet } |
            Select-Object -First 1
        if ($hit) { $file = $hit.Name }
    }
    return "$RepoBase/blob/$Ref/src/Public/$file"
}

function HtmlEncode([string]$s) {
    if ($null -eq $s) { return '' }
    $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;')
}

# --- Build HTML --------------------------------------------------------------
$sb = New-Object System.Text.StringBuilder
$null = $sb.AppendLine('<!DOCTYPE html>')
$null = $sb.AppendLine('<html lang="en">')
$null = $sb.AppendLine('<head>')
$null = $sb.AppendLine('  <meta charset="utf-8">')
$null = $sb.AppendLine('  <meta name="viewport" content="width=device-width, initial-scale=1">')
$null = $sb.AppendLine("  <title>Cmdlet reference - MSIXForcelets ($($cmds.Count) cmdlets)</title>")
$null = $sb.AppendLine('  <meta name="description" content="Complete cmdlet reference for MSIXForcelets: open, repack, sign and fix MSIX packages, Package Support Framework, desktop7 shortcuts, virtual registry, capabilities and pre-built application fixes.">')
$null = $sb.AppendLine('  <link rel="canonical" href="https://msixforcelets.nick-it.de/cmdlets.html">')
$null = $sb.AppendLine('  <meta name="theme-color" content="#0d1117">')
$null = $sb.AppendLine('  <link rel="icon" type="image/x-icon" href="favicon.ico">')
$null = $sb.AppendLine('  <link rel="stylesheet" href="style.css">')
$null = $sb.AppendLine('</head>')
$null = $sb.AppendLine('<body>')
$null = $sb.AppendLine('  <header class="hero hero-slim">')
$null = $sb.AppendLine('    <nav class="nav"><a class="brand" href="index.html">MSIX<span class="accent">Forcelets</span></a>')
$null = $sb.AppendLine('      <div class="nav-links"><a href="quickstart.html">Quickstart</a><a href="build-your-own-fix.html">Build a fix</a><a href="cmdlets.html">Cmdlets</a><a href="about.html">About</a><a href="' + $RepoBase + '">GitHub</a></div></nav>')
$null = $sb.AppendLine('    <div class="hero-content"><h1>Cmdlet reference</h1>')
$null = $sb.AppendLine("    <p class=""lead"">$($cmds.Count) cmdlets, grouped by task. Each links to its source on GitHub (ref <code>$Ref</code>).</p></div>")
$null = $sb.AppendLine('  </header>')
$null = $sb.AppendLine('  <main class="section">')

# Category index
$null = $sb.AppendLine('  <nav class="toc">')
foreach ($cat in $categories.Keys) {
    $slug = ($cat -replace '&amp;','').ToLower() -replace '[^a-z0-9]+','-' -replace '(^-|-$)',''
    $null = $sb.AppendLine("    <a href=""#$slug"">$cat</a>")
}
$null = $sb.AppendLine('  </nav>')

$emitted = New-Object System.Collections.Generic.HashSet[string]
foreach ($cat in $categories.Keys) {
    $slug = ($cat -replace '&amp;','').ToLower() -replace '[^a-z0-9]+','-' -replace '(^-|-$)',''
    $null = $sb.AppendLine("  <section class=""cat""><h2 id=""$slug"">$cat</h2><div class=""grid"">")
    foreach ($name in $categories[$cat]) {
        if (-not $info.ContainsKey($name)) { continue }   # skip cmdlets not present in this build
        $null = $emitted.Add($name)
        $anchor = $name.ToLower()
        $link   = Get-SourceLink $name
        $desc   = HtmlEncode $info[$name]
        if (-not $desc) { $desc = '<span class="muted">No synopsis.</span>' }
        $null = $sb.AppendLine("    <article class=""card cmd"" id=""$anchor"">")
        $null = $sb.AppendLine("      <h3><a href=""$link"" title=""View source on GitHub"">$name</a></h3>")
        $null = $sb.AppendLine("      <p>$desc</p></article>")
    }
    $null = $sb.AppendLine('  </div></section>')
}

# Anything not mapped
$other = $info.Keys | Where-Object { -not $emitted.Contains($_) } | Sort-Object
if ($other) {
    $null = $sb.AppendLine('  <section class="cat"><h2 id="other">Other</h2><div class="grid">')
    foreach ($name in $other) {
        $anchor = $name.ToLower(); $link = Get-SourceLink $name
        $desc = HtmlEncode $info[$name]; if (-not $desc) { $desc = '<span class="muted">No synopsis.</span>' }
        $null = $sb.AppendLine("    <article class=""card cmd"" id=""$anchor""><h3><a href=""$link"">$name</a></h3><p>$desc</p></article>")
    }
    $null = $sb.AppendLine('  </div></section>')
}

$null = $sb.AppendLine('  </main>')
$null = $sb.AppendLine('  <footer class="footer"><div class="footer-inner"><span>&copy; 2026 Andreas Nick &mdash; <a href="https://www.nick-it.de">nick-it.de</a></span>')
$null = $sb.AppendLine('  <span class="footer-links"><a href="index.html">Home</a><a href="cmdlets.html">Cmdlets</a><a href="' + $RepoBase + '">GitHub</a><a href="legal.html">Legal</a><a href="privacy.html">Privacy</a><a href="datenschutz.html">Datenschutz</a></span></div></footer>')
$null = $sb.AppendLine('<script defer src="consent.js"></script></body></html>')

[System.IO.File]::WriteAllText($OutFile, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Verbose "Wrote $OutFile ($($cmds.Count) cmdlets, $($categories.Count) categories)." -Verbose
