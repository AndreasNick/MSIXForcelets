
function Add-MSIXFlexibleVirtualization {
<#
.SYNOPSIS
    Configures registry and file system write virtualization pass-through in AppxManifest.xml.

.DESCRIPTION
    Adds manifest declarations so that container processes write registry keys and file
    system paths to the real system locations instead of the package's virtual hives
    (User.dat / VirtualFileSystem).

    One simple call per task - no arrays, no %ENV% strings. Three parameter sets:

    Disable (default, Windows 10 1903+):
      Disables ALL write virtualization for the selected target(s).
        Add-MSIXFlexibleVirtualization -MSIXFolder $pkg -DisableRegistry -DisableFileSystem

    Directory (Windows 10 Build 20348+ / Windows 11):
      Excludes ONE AppData sub-folder from file system virtualization.
        Add-MSIXFlexibleVirtualization -MSIXFolder $pkg -KnownFolder RoamingAppData -Folder 'Mozilla'

    Registry (Windows 10 Build 20348+ / Windows 11):
      Excludes ONE HKCU key from registry virtualization.
        Add-MSIXFlexibleVirtualization -MSIXFolder $pkg -RegistryKey 'HKEY_CURRENT_USER\SOFTWARE\Mozilla'

    Call the Directory/Registry forms repeatedly to exclude several paths; each call appends
    to the existing FileSystemWriteVirtualization / RegistryWriteVirtualization element.
    All forms add rescap:Capability Name="unvirtualizedResources" to <Capabilities>.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder.

.PARAMETER DisableRegistry
    (Disable set) Adds desktop6:RegistryWriteVirtualization = disabled.

.PARAMETER DisableFileSystem
    (Disable set) Adds desktop6:FileSystemWriteVirtualization = disabled.

.PARAMETER KnownFolder
    (Directory set) The AppData known folder, e.g. RoamingAppData. Combined with -Folder to
    form $(KnownFolder:<KnownFolder>)\<Folder>. Tab-completes the allowed values.

.PARAMETER Folder
    (Directory set) Sub-path under -KnownFolder, e.g. 'Mozilla' or 'Vendor\App'.

.PARAMETER RegistryKey
    (Registry set) A single HKCU key. Accepts the full 'HKEY_CURRENT_USER\SOFTWARE\Mozilla',
    the 'HKCU\...' / 'HKCU:\...' shorthand, or a bare subkey ('SOFTWARE\Mozilla') - all are
    normalized to HKEY_CURRENT_USER. HKLM is rejected (only HKCU may be excluded).

.EXAMPLE
    Add-MSIXFlexibleVirtualization -MSIXFolder $pkg -KnownFolder RoamingAppData -Folder 'Mozilla'

.EXAMPLE
    Add-MSIXFlexibleVirtualization -MSIXFolder $pkg -RegistryKey 'HKEY_CURRENT_USER\SOFTWARE\Mozilla'

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding(DefaultParameterSetName = 'Disable')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Disable',   Position = 0)]
        [Parameter(Mandatory = $true, ParameterSetName = 'Directory', Position = 0)]
        [Parameter(Mandatory = $true, ParameterSetName = 'Registry',  Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch] $DisableRegistry,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch] $DisableFileSystem,

        [Parameter(Mandatory = $true, ParameterSetName = 'Directory')]
        [ValidateSet(
            'AccountPictures', 'AdminTools', 'AppDataDesktop', 'AppDataDocuments',
            'AppDataFavorites', 'AppDataProgramData', 'ApplicationShortcuts', 'CDBurning',
            'Cookies', 'GameTasks', 'History', 'ImplicitAppShortcuts', 'InternetCache',
            'Libraries', 'LocalAppData', 'LocalAppDataLow', 'NetHood', 'OriginalImages',
            'PrintHood', 'Programs', 'QuickLaunch', 'Recent', 'Ringtones', 'RoamingAppData',
            'RoamedTileImages', 'RoamingTiles', 'SearchHistory', 'SearchTemplates', 'SendTo',
            'SidebarParts', 'StartMenu', 'Startup', 'Templates', 'UserPinned',
            'UserProgramFiles', 'UserProgramFilesCommon'
        )]
        [string] $KnownFolder,

        [Parameter(Mandatory = $true, ParameterSetName = 'Directory')]
        [string] $Folder,

        [Parameter(Mandatory = $true, ParameterSetName = 'Registry')]
        [string] $RegistryKey
    )

    $manifestPath = Join-Path $MSIXFolder 'AppxManifest.xml'
    if (-not (Test-Path $manifestPath)) {
        Write-Error "AppxManifest.xml not found in: $($MSIXFolder.FullName)"
        return
    }

    if ($PSCmdlet.ParameterSetName -eq 'Registry') {
        # Friendly input: accept 'HKEY_CURRENT_USER\...', 'HKCU\...', 'HKCU:\...' or a bare
        # subkey ('SOFTWARE\Mozilla') and normalize to the manifest's required HKCU form.
        # Only HKCU is allowed (per the flexible-virtualization rules); HKLM is rejected.
        $RegistryKey = $RegistryKey.Trim()
        if ($RegistryKey -match '^(HKLM|HKEY_LOCAL_MACHINE)') {
            Write-Error "Only HKCU is allowed - HKLM keys cannot be excluded from virtualization."
            return
        }
        if ($RegistryKey -match '^HKCU:?\\') {
            $RegistryKey = 'HKEY_CURRENT_USER\' + ($RegistryKey -replace '^HKCU:?\\', '')
        }
        elseif ($RegistryKey -notmatch '^HKEY_CURRENT_USER\\') {
            $RegistryKey = 'HKEY_CURRENT_USER\' + $RegistryKey.TrimStart('\')
        }
    }
    if ($PSCmdlet.ParameterSetName -eq 'Directory' -and [string]::IsNullOrWhiteSpace($Folder)) {
        Write-Error "-Folder must not be empty."
        return
    }

    $xml = New-Object xml
    $xml.Load($manifestPath)

    $nsBase   = 'http://schemas.microsoft.com/appx/manifest/foundation/windows10'
    $nsRescap = 'http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities'
    $nsD6     = 'http://schemas.microsoft.com/appx/manifest/desktop/windows10/6'
    $nsVirt   = 'http://schemas.microsoft.com/appx/manifest/virtualization/windows10'

    $nsmgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $null = $nsmgr.AddNamespace('ns',     $nsBase)
    $null = $nsmgr.AddNamespace('rescap', $nsRescap)
    $null = $nsmgr.AddNamespace('d6',     $nsD6)
    $null = $nsmgr.AddNamespace('virt',   $nsVirt)

    $packageEl = $xml.DocumentElement

    # rescap + unvirtualizedResources are required by every form.
    if ($packageEl.GetAttribute('xmlns:rescap') -eq '') {
        $null = $packageEl.SetAttribute('xmlns:rescap', $nsRescap)
        Write-Verbose "Added xmlns:rescap to Package element."
    }
    $ignorable = $packageEl.GetAttribute('IgnorableNamespaces')
    if ($ignorable -notmatch '\brescap\b') {
        $packageEl.SetAttribute('IgnorableNamespaces', ($ignorable + ' rescap').Trim())
    }

    $capsEl = $xml.SelectSingleNode('/ns:Package/ns:Capabilities', $nsmgr)
    if ($null -eq $capsEl) {
        $capsEl = $xml.CreateElement('Capabilities', $nsBase)
        $null = $packageEl.AppendChild($capsEl)
    }
    if ($null -eq $capsEl.SelectSingleNode("rescap:Capability[@Name='unvirtualizedResources']", $nsmgr)) {
        $capEl = $xml.CreateElement('rescap', 'Capability', $nsRescap)
        $null = $capEl.SetAttribute('Name', 'unvirtualizedResources')
        $null = $capsEl.AppendChild($capEl)
        Write-Verbose "Added rescap:Capability 'unvirtualizedResources'."
    }

    $propsEl = $xml.SelectSingleNode('/ns:Package/ns:Properties', $nsmgr)
    if ($null -eq $propsEl) {
        $propsEl = $xml.CreateElement('Properties', $nsBase)
        $null = $packageEl.PrependChild($propsEl)
    }

    switch ($PSCmdlet.ParameterSetName) {

        'Disable' {
            if ($packageEl.GetAttribute('xmlns:desktop6') -eq '') {
                $null = $packageEl.SetAttribute('xmlns:desktop6', $nsD6)
                Write-Verbose "Added xmlns:desktop6 to Package element."
            }
            $ig = $packageEl.GetAttribute('IgnorableNamespaces')
            if ($ig -notmatch '\bdesktop6\b') {
                $packageEl.SetAttribute('IgnorableNamespaces', ($ig + ' desktop6').Trim())
            }

            if ($DisableRegistry -and $null -eq $propsEl.SelectSingleNode('d6:RegistryWriteVirtualization', $nsmgr)) {
                $el = $xml.CreateElement('desktop6', 'RegistryWriteVirtualization', $nsD6)
                $el.InnerText = 'disabled'
                $null = $propsEl.AppendChild($el)
                Write-Verbose "Added desktop6:RegistryWriteVirtualization = disabled."
            }
            if ($DisableFileSystem -and $null -eq $propsEl.SelectSingleNode('d6:FileSystemWriteVirtualization', $nsmgr)) {
                $el = $xml.CreateElement('desktop6', 'FileSystemWriteVirtualization', $nsD6)
                $el.InnerText = 'disabled'
                $null = $propsEl.AppendChild($el)
                Write-Verbose "Added desktop6:FileSystemWriteVirtualization = disabled."
            }
        }

        default {
            # Directory / Registry: selective exclusion (append to existing element).
            if ($packageEl.GetAttribute('xmlns:virtualization') -eq '') {
                $null = $packageEl.SetAttribute('xmlns:virtualization', $nsVirt)
                Write-Verbose "Added xmlns:virtualization to Package element."
            }
            $ig = $packageEl.GetAttribute('IgnorableNamespaces')
            if ($ig -notmatch '\bvirtualization\b') {
                $packageEl.SetAttribute('IgnorableNamespaces', ($ig + ' virtualization').Trim())
            }

            if ($PSCmdlet.ParameterSetName -eq 'Registry') {
                $rvEl = $propsEl.SelectSingleNode('virt:RegistryWriteVirtualization', $nsmgr)
                if ($null -eq $rvEl) {
                    $rvEl = $xml.CreateElement('virtualization', 'RegistryWriteVirtualization', $nsVirt)
                    $null = $propsEl.AppendChild($rvEl)
                }
                $keysEl = $rvEl.SelectSingleNode('virt:ExcludedKeys', $nsmgr)
                if ($null -eq $keysEl) {
                    $keysEl = $xml.CreateElement('virtualization', 'ExcludedKeys', $nsVirt)
                    $null = $rvEl.AppendChild($keysEl)
                }
                $exists = $false
                foreach ($k in $keysEl.SelectNodes('virt:ExcludedKey', $nsmgr)) {
                    if ($k.InnerText -eq $RegistryKey) { $exists = $true; break }
                }
                if ($exists) {
                    Write-Verbose "ExcludedKey already present: $RegistryKey"
                }
                else {
                    $keyEl = $xml.CreateElement('virtualization', 'ExcludedKey', $nsVirt)
                    $keyEl.InnerText = $RegistryKey
                    $null = $keysEl.AppendChild($keyEl)
                    Write-Verbose "Added ExcludedKey: $RegistryKey"
                }
            }
            else {
                $excludedValue = '$(KnownFolder:{0})\{1}' -f $KnownFolder, $Folder.Trim().TrimStart('\')

                $fvEl = $propsEl.SelectSingleNode('virt:FileSystemWriteVirtualization', $nsmgr)
                if ($null -eq $fvEl) {
                    $fvEl = $xml.CreateElement('virtualization', 'FileSystemWriteVirtualization', $nsVirt)
                    $null = $propsEl.AppendChild($fvEl)
                }
                $dirsEl = $fvEl.SelectSingleNode('virt:ExcludedDirectories', $nsmgr)
                if ($null -eq $dirsEl) {
                    $dirsEl = $xml.CreateElement('virtualization', 'ExcludedDirectories', $nsVirt)
                    $null = $fvEl.AppendChild($dirsEl)
                }
                $exists = $false
                foreach ($d in $dirsEl.SelectNodes('virt:ExcludedDirectory', $nsmgr)) {
                    if ($d.InnerText -eq $excludedValue) { $exists = $true; break }
                }
                if ($exists) {
                    Write-Verbose "ExcludedDirectory already present: $excludedValue"
                }
                else {
                    $dirEl = $xml.CreateElement('virtualization', 'ExcludedDirectory', $nsVirt)
                    $dirEl.InnerText = $excludedValue
                    $null = $dirsEl.AppendChild($dirEl)
                    Write-Verbose "Added ExcludedDirectory: $excludedValue"
                }
            }
        }
    }

    $xml.PreserveWhitespace = $false
    $xml.Save($manifestPath)
    Write-Verbose "Saved AppxManifest.xml ($($PSCmdlet.ParameterSetName) mode)."
}
