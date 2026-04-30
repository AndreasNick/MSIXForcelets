function Add-MSIXFixWinRARModernShell {
<#
.SYNOPSIS
    Replaces the WinRAR classic context menu with MsixModernContextMenuHandler
    for the Windows 11 modern context menu (top section, IExplorerCommand).

.DESCRIPTION
    Replaces the classic RarExt.dll shell extension (IContextMenu via COM surrogate /
    PsfFtaCom) with MsixModernContextMenuHandler.dll (IExplorerCommand, in-process).

    Changes applied to the package:
      Removes classic shell extension entries from the manifest and replace is


.PARAMETER MsixFile
    Path to the WinRAR MSIX file to modify.

.PARAMETER MSIXFolder
    Temporary extraction folder. Defaults to a unique path under %TEMP%.

.PARAMETER OutputFilePath
    Path for the repackaged MSIX. Defaults to overwriting the source file.

.PARAMETER Subject
    Publisher subject string (CN=...). When provided, Set-MSIXPublisher is called.

.PARAMETER Version
    Package version to set (e.g. '7.20.1.6').

.PARAMETER HandlerLibsPath
    Folder containing MsixModernContextMenuHandler.dll and .json.
    Defaults to the module's Libs\Fixes\WinRarModernContextMenuReplacement folder.

.PARAMETER Force
    Overwrites existing files in the extraction folder without prompting.

.PARAMETER KeepMSIXFolder
    Keeps the temporary extraction folder after packing.

.EXAMPLE
    Add-MSIXFixWinRARModernShell -MsixFile "C:\Packages\WinRAR.msix" -Verbose

.EXAMPLE
    Add-MSIXFixWinRARModernShell `
        -MsixFile       "C:\Packages\WinRAR.msix" `
        -OutputFilePath "C:\Packages\WinRAR_modern.msix" `
        -Subject        "CN=Contoso, O=Contoso, C=DE" `
        -Version        "7.20.1.6" `
        -Verbose

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.FileInfo] $MsixFile,

        [System.IO.DirectoryInfo] $MSIXFolder = ($env:Temp + '\MSIX_TEMP_' + [System.Guid]::NewGuid().ToString()),

        [System.IO.FileInfo] $OutputFilePath = $null,

        [string] $Subject = '',
        [string] $Version = '',

        [string] $HandlerLibsPath = (Join-Path $PSScriptRoot '..\Libs\Fixes\WinRarModernContextMenuReplacement'),

        [switch] $Force,
        [switch] $KeepMSIXFolder
    )

    process {
        if ($null -eq $OutputFilePath) {
            $OutputFilePath = $MsixFile
        }

        try {
            $null = Open-MSIXPackage -MsixFile $MsixFile -Force:$Force -MSIXFolder $MSIXFolder

            if ($Subject -ne '') {
                Set-MSIXPublisher -MSIXFolder $MSIXFolder -PublisherSubject $Subject
            }

            if ($Version -ne '') {
                Set-MSIXPackageVersion -MSIXFolder $MSIXFolder -MSVersion $Version
                Write-Verbose "Package version set to $Version"
            }

            Invoke-MSIXCleanup -MSIXFolder $MSIXFolder

            # RarExt.dll and RarExt32.dll are the classic IContextMenu shell extension DLLs.
            # Remove
            foreach ($artifact in @('Uninstall.exe', 'RarExt.dll', 'RarExt32.dll')) {
                $artifactPath = Join-Path $MSIXFolder.FullName "VFS\ProgramFilesX64\WinRAR\$artifact"
                if (Test-Path $artifactPath) {
                    Remove-Item $artifactPath -Force
                    Write-Verbose "Removed WinRAR artifact: $artifact"
                }
            }

            # Remove classic shell extension manifest entries
            Remove-MSIXClassicShellExtension -MSIXFolder $MSIXFolder -Categories @(
                'windows.fileExplorerClassicContextMenuHandler',
                'windows.fileExplorerClassicDragDropContextMenuHandler',
                'windows.fileExplorerContextMenus'
            )

            # Copy MsixModernContextMenuHandler.dll + .json to the package root.
            $libsResolved = [IO.Path]::GetFullPath($HandlerLibsPath)
            $vfsWinRAR    = Join-Path $MSIXFolder.FullName 'VFS\ProgramFilesX64\WinRAR'
            $pkgRoot      = $MSIXFolder.FullName
            $dllSrc       = Join-Path $libsResolved 'MsixModernContextMenuHandler.dll'
            $jsonSrc      = Join-Path $libsResolved 'MsixModernContextMenuHandler.json'

            if (-not (Test-Path $dllSrc))  { throw "Handler DLL not found: $dllSrc" }
            if (-not (Test-Path $jsonSrc)) { throw "Handler JSON not found: $jsonSrc" }

            Copy-Item $dllSrc  $pkgRoot  -Force
            Copy-Item $jsonSrc $pkgRoot  -Force
            Write-Verbose "Copied MsixModernContextMenuHandler.dll + .json to package root"

            Copy-Item $dllSrc  $vfsWinRAR -Force
            Copy-Item $jsonSrc $vfsWinRAR -Force
            Write-Verbose "Copied MsixModernContextMenuHandler.dll + .json into VFS\ProgramFilesX64\WinRAR"

            # --- Manifest: remove old comServer, add desktop4/5 FileExplorerContextMenus ---

            $manifestPath = Join-Path $MSIXFolder.FullName 'AppxManifest.xml'
            $xml = New-Object System.Xml.XmlDocument
            $xml.Load($manifestPath)

            $comNs    = 'http://schemas.microsoft.com/appx/manifest/com/windows10'
            $d4Ns     = 'http://schemas.microsoft.com/appx/manifest/desktop/windows10/4'
            $d5Ns     = 'http://schemas.microsoft.com/appx/manifest/desktop/windows10/5'
            # Single CLSID for all ItemTypes — VS Code and Notepad++ both use one CLSID.
            # Two CLSIDs caused an Explorer crash (KERNELBASE.dll 0xc0000005) before the DLL
            # was even loaded. One CLSID, multiple ItemType registrations = proven pattern.
            $clsid    = '4A7B3C1D-E2F5-4689-ABCD-EF1234567891'

            # Remove all existing comServer extensions (old RarExt.dll SurrogateServer).
            foreach ($node in @($xml.SelectNodes(
                    "//*[local-name()='Extension' and @Category='windows.comServer']"))) {
                $null = $node.ParentNode.RemoveChild($node)
                Write-Verbose "Removed old comServer extension"
            }

            # Target the Application that runs WinRAR.exe (before PSF shimming renames it).
            # A generic first-match approach picks the wrong Application when the package
            # declares multiple Applications (e.g. a separate RarExtInstaller entry).
            $winrarAppNode = $null
            foreach ($candidateApp in @($xml.SelectNodes("//*[local-name()='Application']"))) {
                if ($candidateApp.GetAttribute('Executable') -like '*WinRAR.exe') {
                    $winrarAppNode = $candidateApp
                    break
                }
            }
            if ($null -eq $winrarAppNode) {
                $winrarAppNode = $xml.SelectSingleNode("//*[local-name()='Application']")
                Write-Warning "No Application with WinRAR.exe found - falling back to first Application."
            }

            # Locate or create the Extensions element under the target Application.
            # Use ChildNodes iteration to avoid XPath single-quote quoting issues.
            $appExtNode = $null
            foreach ($childNode in $winrarAppNode.ChildNodes) {
                if ($childNode.LocalName -eq 'Extensions') {
                    $appExtNode = $childNode
                    break
                }
            }
            if (-not $appExtNode) {
                $appExtNode = $xml.CreateElement(
                    'Extensions',
                    'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
                $null = $winrarAppNode.AppendChild($appExtNode)
                Write-Verbose "Created Extensions element under WinRAR Application."
            }

            # Ensure required namespaces are declared on the root element.
            foreach ($ns in @(
                    @{ Prefix = 'xmlns:com';      Uri = $comNs },
                    @{ Prefix = 'xmlns:desktop4'; Uri = $d4Ns  },
                    @{ Prefix = 'xmlns:desktop5'; Uri = $d5Ns  })) {
                if (-not $xml.DocumentElement.HasAttribute($ns.Prefix)) {
                    $xml.DocumentElement.SetAttribute($ns.Prefix, $ns.Uri)
                    Write-Verbose "Added $($ns.Prefix) namespace to manifest root"
                }
            }

            # Add desktop4 and desktop5 to IgnorableNamespaces 
            $ignorable = $xml.DocumentElement.GetAttribute('IgnorableNamespaces')
            $nsToAdd = @('desktop4', 'desktop5') | Where-Object { $ignorable -notmatch "\b$_\b" }
            if ($nsToAdd.Count -gt 0) {
                $xml.DocumentElement.SetAttribute(
                    'IgnorableNamespaces',
                    ($ignorable.TrimEnd() + ' ' + ($nsToAdd -join ' ')).Trim())
                Write-Verbose "IgnorableNamespaces updated: added $($nsToAdd -join ', ')"
            }

            $comExt       = $xml.CreateElement('com:Extension', $comNs)
            $comExt.SetAttribute('Category', 'windows.comServer')
            $comServer    = $xml.CreateElement('com:ComServer', $comNs)
            $comSurrogate = $xml.CreateElement('com:SurrogateServer', $comNs)
            $comSurrogate.SetAttribute('DisplayName', 'MsixModernContextMenuHandler')
            $comClass     = $xml.CreateElement('com:Class', $comNs)
            $comClass.SetAttribute('Id', $clsid)
            $comClass.SetAttribute('Path', 'MsixModernContextMenuHandler.dll')
            $comClass.SetAttribute('ThreadingModel', 'STA')
            $null = $comSurrogate.AppendChild($comClass)
            $null = $comServer.AppendChild($comSurrogate)
            $null = $comExt.AppendChild($comServer)
            $null = $appExtNode.AppendChild($comExt)
            Write-Verbose "Added com:SurrogateServer for MsixModernContextMenuHandler.dll (STA)"

            $d4Ext   = $xml.CreateElement('desktop4:Extension', $d4Ns)
            $d4Ext.SetAttribute('Category', 'windows.fileExplorerContextMenus')
            $d4Menus = $xml.CreateElement('desktop4:FileExplorerContextMenus', $d4Ns)

            foreach ($itemType in @('*', 'Directory')) {
                $d5Item = $xml.CreateElement('desktop5:ItemType', $d5Ns)
                $d5Item.SetAttribute('Type', $itemType)
                $d5Verb = $xml.CreateElement('desktop5:Verb', $d5Ns)
                $d5Verb.SetAttribute('Id', 'ModernMenu')
                $d5Verb.SetAttribute('Clsid', $clsid)
                $null = $d5Item.AppendChild($d5Verb)
                $null = $d4Menus.AppendChild($d5Item)
            }

            $null = $d4Ext.AppendChild($d4Menus)
            $null = $appExtNode.AppendChild($d4Ext)
            Write-Verbose "Added desktop4:FileExplorerContextMenus (*, Directory) to Application/Extensions"

            # Remove capabilities WinRAR does not need when deployed outside the Store
            foreach ($capName in @('internetClient')) {
                $capNode = $xml.SelectSingleNode(
                    "//*[local-name()='Capability' and @Name='$capName']")
                if ($capNode) {
                    $null = $capNode.ParentNode.RemoveChild($capNode)
                    Write-Verbose "Removed Capability: $capName"
                }
            }

            $xml.Save($manifestPath)

            # --- PSF for WinRAR.exe ---

            Add-MSIXInstalledLocationVirtualization -MSIXFolderPath $MSIXFolder
            Add-MSIXPsfFrameworkFiles -MSIXFolder $MSIXFolder

            $apps = Get-MSIXApplications -MSIXFolder $MSIXFolder
            if ($null -eq $apps -or $apps.Count -eq 0) {
                Write-Warning "No application entries found in AppxManifest.xml."
            }
            else {
                $shimmedIds = @{}
                foreach ($app in $apps) {
                    Write-Verbose "Adding PSF shim for application: $($app.Id)"
                    $newId = Add-MSXIXPSFShim -MSIXFolder $MSIXFolder -MISXAppID $app.Id -PSFArchitektur x64
                    $shimmedIds[$app.Id] = $newId
                }

                $winrarApp = $apps | Where-Object { $_.Executable -like '*WinRAR.exe' } | Select-Object -First 1
                if ($null -ne $winrarApp) {
                    $winrarNewId = $shimmedIds[$winrarApp.Id]
                    Add-MSIXAppExecutionAlias -MSIXFolder $MSIXFolder `
                        -MISXAppID $winrarNewId `
                        -CommandlineAlias 'WinRAR.exe' `
                        -Executable 'VFS\ProgramFilesX64\WinRAR\WinRAR.exe'

                    # PSFLauncher is intentionally NOT set in the deployed JSON.
                }
            }

            Add-MSIXPSFDefaultRegLegacy -MSIXFolder $MSIXFolder
            Add-MSIXPSFMFRFixup -MSIXFolder $MSIXFolder -IlvAware $true

            # Move IExplorerCommand extensions to a hidden Application to suppress the
            # Windows 11 Application-level grouping flyout. 
            if ($null -ne $winrarNewId) {
                $xmlPost = New-Object System.Xml.XmlDocument
                $xmlPost.Load($manifestPath)

                $shimmedApp = $null
                foreach ($appNode in @($xmlPost.SelectNodes("//*[local-name()='Application']"))) {
                    if ($appNode.GetAttribute('Id') -eq $winrarNewId) {
                        $shimmedApp = $appNode
                        break
                    }
                }

                if ($null -ne $shimmedApp) {
                    $shimmedExts = $null
                    foreach ($child in $shimmedApp.ChildNodes) {
                        if ($child.LocalName -eq 'Extensions') {
                            $shimmedExts = $child
                            break
                        }
                    }

                    if ($null -ne $shimmedExts) {
                        $toMove = @()
                        foreach ($ext in @($shimmedExts.ChildNodes)) {
                            $cat = $ext.GetAttribute('Category')
                            if ($cat -eq 'windows.comServer' -or $cat -eq 'windows.fileExplorerContextMenus') {
                                $toMove += $ext
                            }
                        }

                        if ($toMove.Count -gt 0) {
                            $fNs = 'http://schemas.microsoft.com/appx/manifest/foundation/windows10'

                            $helperApp = $xmlPost.CreateElement('Application', $fNs)
                            $helperApp.SetAttribute('Id', 'WinRARMenuHelper')
                            $helperApp.SetAttribute('Executable', 'VFS\ProgramFilesX64\WinRAR\RarExtInstaller.exe')
                            $helperApp.SetAttribute('EntryPoint', 'Windows.FullTrustApplication')

                            # AppListEntry="none" is an attribute of uap:VisualElements,
                            # Suppress the Start-menu entry on the clone.
                            $sourceVe = $null
                            foreach ($child in $shimmedApp.ChildNodes) {
                                if ($child.LocalName -eq 'VisualElements') {
                                    $sourceVe = $child
                                    break
                                }
                            }
                            if ($null -ne $sourceVe) {
                                $veEl = $sourceVe.CloneNode($true)
                                $null = $veEl.SetAttribute('AppListEntry', 'none')
                                $null = $veEl.SetAttribute('DisplayName', 'WinRAR Menu Handler')
                                $null = $helperApp.AppendChild($veEl)
                            }
                            else {
                                Write-Warning "No VisualElements found on '$winrarNewId' - WinRARMenuHelper will lack VisualElements."
                            }

                            $helperExts = $xmlPost.CreateElement('Extensions', $fNs)
                            foreach ($ext in $toMove) {
                                $null = $shimmedExts.RemoveChild($ext)
                                $null = $helperExts.AppendChild($ext)
                            }
                            $null = $helperApp.AppendChild($helperExts)

                            $appsEl = $xmlPost.SelectSingleNode("//*[local-name()='Applications']")
                            $null = $appsEl.AppendChild($helperApp)

                            $xmlPost.Save($manifestPath)
                            Write-Verbose "Moved context menu extensions to hidden Application 'WinRARMenuHelper'"
                        }
                    }
                }
            }

            Close-MSIXPackage -MSIXFolder $MSIXFolder -MSIXFile $OutputFilePath -Force:$Force -KeepMSIXFolder:$KeepMSIXFolder
            "WinRAR modern shell fix applied: $OutputFilePath"
        }
        catch {
            Write-Error "Error applying WinRAR modern shell fix: $_"
        }
    }
}
