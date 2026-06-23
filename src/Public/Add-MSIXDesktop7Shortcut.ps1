function Add-MSIXDesktop7Shortcut {
<#
.SYNOPSIS
    Adds a working desktop7:Shortcut to an MSIX app: a physical .lnk that targets the
    app's native install path (the icon is taken from that executable) at a per-user
    location. -Location tab-completes the folders.
.PARAMETER MSIXFolder
    Expanded MSIX package folder.
.PARAMETER AppId
    Id of the Application the shortcut belongs to.
.PARAMETER Name
    Shortcut file name without extension. Defaults to the AppId.
.PARAMETER Location
    Target folder token, e.g. '[{Programs}]' (default) or '[{Desktop}]'. Use a per-user
    location; system locations ('[{Common Programs}]', '[{Common Desktop}]') do not render
    the shortcut icon. Tab-completes.
.PARAMETER SubFolder
    Optional sub-folder under the location, e.g. 'Putty'. On the Desktop this creates a real
    folder holding the shortcuts. NOTE: the Windows 11 Start menu does NOT show sub-folders
    for packaged shortcuts - the .lnk is created physically but entries appear flat (one per
    AUMID), so a Start-menu group is not displayed.
.PARAMETER Arguments
    Optional command-line arguments.
.PARAMETER Description
    Optional shortcut tooltip.
.PARAMETER PinToStartMenu
    When set, pins the shortcut to the Start menu (desktop7:Shortcut PinToStartMenu="true").
.PARAMETER IconSource
    Optional icon source (.ico/.exe/.dll). Omit to use the app's own executable. A file
    already inside the package is referenced in place; an external file is copied next to
    the app executable (a resolvable location). A .png under Assets\ does not render.
.EXAMPLE
    Add-MSIXDesktop7Shortcut -MSIXFolder $pkg -AppId 'CHROME' -Location '[{Desktop}]'
.NOTES
    Tim Mangan: https://www.tmurgent.com/TmBlog/?p=3857
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [Parameter(Mandatory = $true, Position = 1)]
        [string] $AppId,

        [string] $Name,

        [ArgumentCompleter({
            '[{Programs}]', '[{Desktop}]',
            '[{Common Programs}]', '[{Common Desktop}]'
        })]
        [string] $Location = '[{Programs}]',

        [string] $SubFolder   = '',
        [string] $Arguments   = '',
        [string] $Description = '',
        [string] $IconSource  = '',
        [switch] $PinToStartMenu
    )

    # Placement target must be a known location with a real VFS folder
    # ('[{Package}]' resolves to the root and is not a valid shortcut location).
    if (-not $ShortcutLocationTokens.Contains($Location) -or [string]::IsNullOrEmpty($ShortcutLocationTokens[$Location])) {
        $valid = ($ShortcutLocationTokens.GetEnumerator() | Where-Object { $_.Value } | ForEach-Object { $_.Key }) -join ', '
        Write-Error "Invalid Location token '$Location'. Use one of: $valid"
        return
    }

    # All-users locations deploy the .lnk but it does NOT appear under per-user MSIX
    # deployment. Only per-user locations ([{Programs}] / [{Desktop}]) render.
    if ($Location -eq '[{Common Programs}]' -or $Location -eq '[{Common Desktop}]') {
        Write-Warning "Location '$Location' is an all-users path; desktop7 shortcuts there do not appear under per-user MSIX deployment. Prefer '[{Programs}]' or '[{Desktop}]'."
    }

    $manifestPath = Join-Path $MSIXFolder.FullName 'AppxManifest.xml'
    if (-not (Test-Path $manifestPath)) {
        Write-Error "AppxManifest.xml not found in: $($MSIXFolder.FullName)"
        return
    }

    $desktop7Ns = $AppXNamespaces['desktop7']

    $manifest = New-Object System.Xml.XmlDocument
    $manifest.PreserveWhitespace = $false
    $manifest.Load($manifestPath)

    $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
    $AppXNamespaces.GetEnumerator() | ForEach-Object { $null = $nsmgr.AddNamespace($_.Key, $_.Value) }

    $app = $manifest.SelectSingleNode("//ns:Package/ns:Applications/ns:Application[@Id='$AppId']", $nsmgr)
    if ($null -eq $app) {
        Write-Error "Application '$AppId' not found in manifest."
        return
    }

    $executable = $app.GetAttribute('Executable')
    if ([string]::IsNullOrEmpty($Name)) { $Name = $AppId }

    # The .lnk launch target and the default icon both come from the application
    # executable - verify it is present in the package.
    if (-not (Test-Path (Join-Path $MSIXFolder.FullName $executable))) {
        Write-Warning "Application executable not found in package: $executable. Launch target and default icon may not resolve."
    }

    # --- 1. Resolve the Icon reference -----------------------------------------
    # The shortcut icon is taken from the .lnk's target executable (see section 2). The
    # manifest Icon points at that same executable inside the package - the pattern used
    # by captured shortcuts (e.g. Icon="[{Package}]\bin\app.exe"). An explicit IconSource
    # may point at another file inside the package (.exe/.dll/.ico).
    if ([string]::IsNullOrEmpty($IconSource)) {
        $iconRef = '[{Package}]\' + $executable
    }
    else {
        if (-not (Test-Path $IconSource)) {
            Write-Error "Icon source not found: $IconSource"
            return
        }
        $iconExt = [System.IO.Path]::GetExtension($IconSource).ToLowerInvariant()
        if ($iconExt -notin @('.ico', '.exe', '.dll')) {
            Write-Warning "Icon source extension '$iconExt' may not render as a shortcut icon. Use .ico/.exe/.dll (a .png does not resolve for a desktop7 shortcut)."
        }
        $fullIcon = (Resolve-Path $IconSource).Path
        $pkgRoot  = $MSIXFolder.FullName.TrimEnd('\')
        if ($fullIcon -like "$pkgRoot\*") {
            # Already inside the package - reference it in place.
            $iconRef = '[{Package}]\' + $fullIcon.Substring($pkgRoot.Length + 1)
        }
        else {
            # External file: copy it next to the application executable - a per-user
            # resolvable VFS location (the only kind that renders). Icons under Assets\
            # do NOT resolve for a desktop7 shortcut.
            $exeRelDir = Split-Path $executable -Parent
            $destDir   = if ([string]::IsNullOrEmpty($exeRelDir)) { $pkgRoot } else { Join-Path $pkgRoot $exeRelDir }
            if (-not (Test-Path $destDir)) {
                Write-Error "Cannot copy icon: application folder '$exeRelDir' does not exist in the package."
                return
            }
            $iconLeaf = Split-Path $fullIcon -Leaf
            Copy-Item -LiteralPath $fullIcon -Destination (Join-Path $destDir $iconLeaf) -Force
            $iconRelPath = if ([string]::IsNullOrEmpty($exeRelDir)) { $iconLeaf } else { Join-Path $exeRelDir $iconLeaf }
            $iconRef = '[{Package}]\' + $iconRelPath
            Write-Verbose "Copied external icon into package: $iconRelPath"
        }
    }

    # --- 2. Build the native TargetPath: the app's original install path. The shortcut
    # icon is taken from this executable, so it must resolve on the deployed machine,
    # e.g. VFS\ProgramFilesX86\App\app.exe -> C:\Program Files (x86)\App\app.exe.
    $nativeTarget = $executable
    $nativeMap = @{
        'VFS\ProgramFilesX64\'    = ($env:ProgramW6432 + '\')
        'VFS\ProgramFilesX86\'    = (${env:ProgramFiles(x86)} + '\')
        'VFS\ProgramFilesCommonX64\' = ($env:CommonProgramW6432 + '\')
        'VFS\ProgramFilesCommonX86\' = (${env:CommonProgramFiles(x86)} + '\')
        'VFS\SystemX64\'          = ($env:windir + '\System32\')
        'VFS\SystemX86\'          = ($env:windir + '\SysWOW64\')
        'VFS\Windows\'            = ($env:windir + '\')
    }
    foreach ($k in $nativeMap.Keys) {
        if ($nativeTarget -like "$k*") {
            $nativeTarget = $nativeMap[$k] + $nativeTarget.Substring($k.Length)
            break
        }
    }
    if (-not [System.IO.Path]::IsPathRooted($nativeTarget)) {
        # Package-root-relative executable -> assume WindowsApps native location is unknown; keep a plausible path
        $nativeTarget = Join-Path $env:ProgramW6432 $nativeTarget
    }

    # --- 3. Write the physical .lnk into the package ---------------------------
    $vfsDir  = Join-Path $MSIXFolder.FullName $ShortcutLocationTokens[$Location]
    if ($SubFolder) { $vfsDir = Join-Path $vfsDir $SubFolder }
    if (-not (Test-Path $vfsDir)) { $null = New-Item -ItemType Directory -Path $vfsDir -Force }
    $lnkPath = Join-Path $vfsDir ($Name + '.lnk')

    # File token written to the manifest (location + optional sub-folder + file name).
    $fileToken = if ($SubFolder) { $Location + '\' + $SubFolder + '\' + $Name + '.lnk' } else { $Location + '\' + $Name + '.lnk' }

    $wshShell = New-Object -ComObject WScript.Shell
    try {
        $lnk = $wshShell.CreateShortcut($lnkPath)
        $lnk.TargetPath = $nativeTarget
        if ($Arguments)   { $lnk.Arguments   = $Arguments }
        if ($Description) { $lnk.Description = $Description }
        $lnk.Save()
    }
    finally {
        $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wshShell)
    }
    Write-Verbose "Wrote .lnk: $lnkPath (TargetPath=$nativeTarget)"

    # --- 4. Ensure desktop7 namespace, then add the shortcut extension ---------
    $root = $manifest.DocumentElement
    if (-not $root.HasAttribute('xmlns:desktop7')) {
        $null = $root.SetAttribute('xmlns:desktop7', $desktop7Ns)
        $ign = $root.GetAttribute('IgnorableNamespaces')
        if ($ign -notmatch '\bdesktop7\b') {
            $null = $root.SetAttribute('IgnorableNamespaces', ("$ign desktop7").Trim())
        }
    }

    $extensions = $app.SelectSingleNode('ns:Extensions', $nsmgr)
    if ($null -eq $extensions) {
        $extensions = $manifest.CreateElement('Extensions', $AppXNamespaces['ns'])
        $null = $app.AppendChild($extensions)
    }

    $ext = $manifest.CreateElement('desktop7:Extension', $desktop7Ns)
    $null = $ext.SetAttribute('Category', 'windows.shortcut')
    $sc  = $manifest.CreateElement('desktop7:Shortcut', $desktop7Ns)
    $null = $sc.SetAttribute('File', $fileToken)
    $null = $sc.SetAttribute('Icon', $iconRef)
    if ($Arguments)      { $null = $sc.SetAttribute('Arguments', $Arguments) }
    if ($Description)    { $null = $sc.SetAttribute('Description', $Description) }
    if ($PinToStartMenu) { $null = $sc.SetAttribute('PinToStartMenu', 'true') }
    $null = $ext.AppendChild($sc)
    $null = $extensions.AppendChild($ext)

    $manifest.Save($manifestPath)
    Write-Verbose "Added desktop7:Shortcut '$Name' for application '$AppId' at $Location."

    [PSCustomObject]@{
        ApplicationId  = $AppId
        Name           = $Name
        File           = $fileToken
        Icon           = $iconRef
        PinToStartMenu = [bool]$PinToStartMenu
        LnkPath        = $lnkPath
    }
}
