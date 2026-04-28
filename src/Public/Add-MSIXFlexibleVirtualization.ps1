
function Add-MSIXFlexibleVirtualization {
<#
.SYNOPSIS
    Configures registry and file system write virtualization pass-through in AppxManifest.xml.

.DESCRIPTION
    Adds manifest declarations so that container processes write registry keys and file
    system paths to the real system locations instead of the package's virtual hives
    (User.dat / VirtualFileSystem).

    Two parameter sets select the approach:

    Disable (default):
      Adds desktop6:RegistryWriteVirtualization and/or desktop6:FileSystemWriteVirtualization
      with value "disabled". Disables ALL write virtualization for the selected target(s).
      Pattern used by WinRAR.ShellExtension. Works on Windows 10 1903+.
      Use -DisableRegistry and/or -DisableFileSystem.

    Selective:
      Adds virtualization:RegistryWriteVirtualization with ExcludedKeys and/or
      virtualization:FileSystemWriteVirtualization with ExcludedDirectories.
      Only the specified paths bypass virtualization; everything else remains virtualized.
      Windows 11+ only.

    Both approaches add rescap:Capability Name="unvirtualizedResources" to <Capabilities>.

    Namespaces:
      xmlns:desktop6       = http://schemas.microsoft.com/appx/manifest/desktop/windows10/6
      xmlns:rescap         = http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities
      xmlns:virtualization = http://schemas.microsoft.com/appx/manifest/virtualization/windows10

    Note: when PsfFtaCom hosts a COM shell extension (IContextMenu DLL) inside the MSIX
    container, the DLL sees the virtual registry and VFS -- unvirtualizedResources is then
    NOT required. Use this cmdlet only when container processes genuinely need to write to
    the real system registry or filesystem (e.g. startup scripts, non-COM applications).

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder.

.PARAMETER DisableRegistry
    (Disable set) Adds desktop6:RegistryWriteVirtualization = disabled.
    All registry writes from container processes go to the real system registry.

.PARAMETER DisableFileSystem
    (Disable set) Adds desktop6:FileSystemWriteVirtualization = disabled.
    All filesystem writes from container processes go to the real filesystem.

.PARAMETER RegistryKeyPaths
    (Selective set) HKCU paths in the form 'HKEY_CURRENT_USER\SOFTWARE\...'.
    Only HKCU paths are valid; HKLM paths cannot be excluded from virtualization.
    Windows 11+ only.

.PARAMETER DirectoryPaths
    (Selective set) AppData paths to exclude, e.g. '%USERPROFILE%\AppData\Roaming\MyApp'.
    Must be under %USERPROFILE%\AppData. Windows 11+ only.

.EXAMPLE
    # Disable all registry write virtualization (WinRAR.ShellExtension pattern)
    Add-MSIXFlexibleVirtualization -MSIXFolder $MSIXFolder -DisableRegistry

.EXAMPLE
    # Disable both registry and filesystem write virtualization
    Add-MSIXFlexibleVirtualization -MSIXFolder $MSIXFolder -DisableRegistry -DisableFileSystem

.EXAMPLE
    # Selectively exclude specific HKCU registry paths (Windows 11+ only)
    Add-MSIXFlexibleVirtualization -MSIXFolder $MSIXFolder `
        -RegistryKeyPaths @('HKEY_CURRENT_USER\SOFTWARE\WinRAR', 'HKEY_CURRENT_USER\SOFTWARE\WinRAR SFX')

.EXAMPLE
    # Selectively exclude registry keys and filesystem paths (Windows 11+ only)
    Add-MSIXFlexibleVirtualization -MSIXFolder $MSIXFolder `
        -RegistryKeyPaths @('HKEY_CURRENT_USER\SOFTWARE\MyApp') `
        -DirectoryPaths   @('%USERPROFILE%\AppData\Roaming\MyApp')

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding(DefaultParameterSetName = 'Disable')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Disable',   Position = 0)]
        [Parameter(Mandatory = $true, ParameterSetName = 'Selective', Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch] $DisableRegistry,

        [Parameter(ParameterSetName = 'Disable')]
        [Switch] $DisableFileSystem,

        [Parameter(ParameterSetName = 'Selective')]
        [string[]] $RegistryKeyPaths = @(),

        [Parameter(ParameterSetName = 'Selective')]
        [string[]] $DirectoryPaths = @()
    )

    $manifestPath = Join-Path $MSIXFolder 'AppxManifest.xml'
    if (-not (Test-Path $manifestPath)) {
        Write-Error "AppxManifest.xml not found in: $($MSIXFolder.FullName)"
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

    # rescap is required by both approaches.
    if ($packageEl.GetAttribute('xmlns:rescap') -eq '') {
        $null = $packageEl.SetAttribute('xmlns:rescap', $nsRescap)
        Write-Verbose "Added xmlns:rescap to Package element."
    }
    $ignorable = $packageEl.GetAttribute('IgnorableNamespaces')
    if ($ignorable -notmatch '\brescap\b') {
        $ignorable = ($ignorable + ' rescap').Trim()
        $packageEl.SetAttribute('IgnorableNamespaces', $ignorable)
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

    if ($PSCmdlet.ParameterSetName -eq 'Disable') {
        if ($packageEl.GetAttribute('xmlns:desktop6') -eq '') {
            $null = $packageEl.SetAttribute('xmlns:desktop6', $nsD6)
            Write-Verbose "Added xmlns:desktop6 to Package element."
        }
        $ignorable = $packageEl.GetAttribute('IgnorableNamespaces')
        if ($ignorable -notmatch '\bdesktop6\b') {
            $ignorable = ($ignorable + ' desktop6').Trim()
            $packageEl.SetAttribute('IgnorableNamespaces', $ignorable)
        }

        if ($DisableRegistry) {
            if ($null -eq $propsEl.SelectSingleNode('d6:RegistryWriteVirtualization', $nsmgr)) {
                $el = $xml.CreateElement('desktop6', 'RegistryWriteVirtualization', $nsD6)
                $el.InnerText = 'disabled'
                $null = $propsEl.AppendChild($el)
                Write-Verbose "Added desktop6:RegistryWriteVirtualization = disabled."
            }
        }

        if ($DisableFileSystem) {
            if ($null -eq $propsEl.SelectSingleNode('d6:FileSystemWriteVirtualization', $nsmgr)) {
                $el = $xml.CreateElement('desktop6', 'FileSystemWriteVirtualization', $nsD6)
                $el.InnerText = 'disabled'
                $null = $propsEl.AppendChild($el)
                Write-Verbose "Added desktop6:FileSystemWriteVirtualization = disabled."
            }
        }
    }
    else {
        # Selective approach: exclude only specific paths (Windows 11+).
        if ($packageEl.GetAttribute('xmlns:virtualization') -eq '') {
            $null = $packageEl.SetAttribute('xmlns:virtualization', $nsVirt)
            Write-Verbose "Added xmlns:virtualization to Package element."
        }
        $ignorable = $packageEl.GetAttribute('IgnorableNamespaces')
        if ($ignorable -notmatch '\bvirtualization\b') {
            $ignorable = ($ignorable + ' virtualization').Trim()
            $packageEl.SetAttribute('IgnorableNamespaces', $ignorable)
        }

        if ($RegistryKeyPaths.Count -gt 0) {
            if ($null -eq $propsEl.SelectSingleNode('virt:RegistryWriteVirtualization', $nsmgr)) {
                $virtEl = $xml.CreateElement('virtualization', 'RegistryWriteVirtualization', $nsVirt)
                $keysEl = $xml.CreateElement('virtualization', 'ExcludedKeys', $nsVirt)
                foreach ($keyPath in $RegistryKeyPaths) {
                    $keyEl = $xml.CreateElement('virtualization', 'ExcludedKey', $nsVirt)
                    $keyEl.InnerText = $keyPath
                    $null = $keysEl.AppendChild($keyEl)
                    Write-Verbose "Declared ExcludedKey: $keyPath"
                }
                $null = $virtEl.AppendChild($keysEl)
                $null = $propsEl.AppendChild($virtEl)
                Write-Verbose "Added virtualization:RegistryWriteVirtualization with $($RegistryKeyPaths.Count) ExcludedKey(s)."
            }
        }

        if ($DirectoryPaths.Count -gt 0) {
            if ($null -eq $propsEl.SelectSingleNode('virt:FileSystemWriteVirtualization', $nsmgr)) {
                $virtEl = $xml.CreateElement('virtualization', 'FileSystemWriteVirtualization', $nsVirt)
                $dirsEl = $xml.CreateElement('virtualization', 'ExcludedDirectories', $nsVirt)
                foreach ($dirPath in $DirectoryPaths) {
                    $dirEl = $xml.CreateElement('virtualization', 'ExcludedDirectory', $nsVirt)
                    $dirEl.InnerText = $dirPath
                    $null = $dirsEl.AppendChild($dirEl)
                    Write-Verbose "Declared ExcludedDirectory: $dirPath"
                }
                $null = $virtEl.AppendChild($dirsEl)
                $null = $propsEl.AppendChild($virtEl)
                Write-Verbose "Added virtualization:FileSystemWriteVirtualization with $($DirectoryPaths.Count) ExcludedDirectory/ies."
            }
        }
    }

    $xml.PreserveWhitespace = $false
    $xml.Save($manifestPath)
    Write-Verbose "Saved AppxManifest.xml with flexible virtualization declarations ($($PSCmdlet.ParameterSetName) mode)."
}
