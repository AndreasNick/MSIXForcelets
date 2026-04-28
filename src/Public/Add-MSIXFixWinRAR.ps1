function Add-MSIXFixWinRAR {
<#
.SYNOPSIS
    Injects the Package Support Framework into a WinRAR 64-bit MSIX package.

.DESCRIPTION
    Opens the WinRAR MSIX package and applies the PSF fixes

.PARAMETER MsixFile
    Path to the WinRAR MSIX file to modify.

.PARAMETER MSIXFolder
    Temporary extraction folder. Defaults to a unique path under %TEMP%.

.PARAMETER OutputFilePath
    Path for the repackaged MSIX. Defaults to overwriting the source file.

.PARAMETER Subject
    Publisher subject string (CN=...). When provided, Set-MSIXPublisher is called
    to align the manifest publisher with the signing certificate.

.PARAMETER Force
    Overwrites existing files in the extraction folder without prompting.

.PARAMETER KeepMSIXFolder
    Keeps the temporary extraction folder after packing. Useful for troubleshooting.

.EXAMPLE
    Add-MSIXFixWinRAR -MsixFile "C:\Packages\WinRAR.msix"

.EXAMPLE
    Add-MSIXFixWinRAR `
        -MsixFile       "C:\Packages\WinRAR.msix" `
        -OutputFilePath "C:\Packages\WinRAR_PSF.msix" `
        -Subject        "CN=Contoso, O=Contoso, C=DE" `
        -Verbose

.NOTES
    Requires an active PSF framework set via Set-MSIXActivePSFFramework.
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

        [System.IO.DirectoryInfo] $MSIXFolder = ($env:Temp + "\MSIX_TEMP_" + [System.Guid]::NewGuid().ToString()),

        [System.IO.FileInfo] $OutputFilePath = $null,

        [String] $Subject = "",

        [Switch] $Force,
        [Switch] $KeepMSIXFolder
    )

    process {
        if ($null -eq $OutputFilePath) {
            $OutputFilePath = $MsixFile
        }

        try {
            $null = Open-MSIXPackage -MsixFile $MsixFile -Force:$Force -MSIXFolder $MSIXFolder

            if ($Subject -ne "") {
                Set-MSIXPublisher -MSIXFolder $MSIXFolder -PublisherSubject $Subject
            }

            # Remove unsupported desktop7 shortcuts and common installer leftovers
            Invoke-MSIXCleanup -MSIXFolder $MSIXFolder

            # WinRAR needs internetClient for update checks and online features
            Add-MSIXCapabilities -MSIXFolder $MSIXFolder -Capabilities 'internetClient'

            # Uninstall.exe has no purpose inside the MSIX container.
            $uninstallPath = Join-Path $MSIXFolder.FullName 'VFS\ProgramFilesX64\WinRAR\Uninstall.exe'
            if (Test-Path $uninstallPath) {
                Remove-Item $uninstallPath -Force
                Write-Verbose "Removed WinRAR artifact: Uninstall.exe"
            }

            # The MSIX Packaging Tool already captures all shell extension declarations
            # (comServer, desktop9 handlers, fileTypeAssociation) from the RarExtInstaller.exe
            # deployment into the main manifest. Importing from the sparse would replace the
            # correct DLL path with a different one and create duplicate extension entries.
            # Delete the sparse files so they cannot cause failed deployment at runtime.
            
            Import-MSIXSparseShellExtension -MSIXFolder $MSIXFolder `
                -SparsePackagePath 'VFS\ProgramFilesX64\WinRAR\RarExtPackage.msix' `
                -InstallerExePath  'VFS\ProgramFilesX64\WinRAR\RarExtInstaller.exe' `
                -DeleteOnly

            # Search Path (WinRAR DLLs are in VFS\ProgramFilesX64\WinRAR)
            Add-MSIXloaderSearchPathOverride -MSIXFolderPath $MSIXFolder -FolderPaths "VFS\ProgramFilesX64\WinRAR"

            Add-MSIXInstalledLocationVirtualization -MSIXFolderPath $MSIXFolder

            # rarext.dll is registered as com:SurrogateServer and does not use MSIX APIs

            Remove-MSIXClassicShellExtension -MSIXFolder $MSIXFolder

            # Copy MsixContextMenuHandler.dll + JSON to the WinRAR VFS directory and
            $cmhLibsDir   = Join-Path $Script:ScriptPath 'Libs\Fixes\WinRarContextMenuReplacement'
            $cmhDllSrc    = Join-Path $cmhLibsDir 'MsixContextMenuHandler.dll'
            $cmhJsonSrc   = Join-Path $cmhLibsDir 'MsixContextMenuHandler.json'
            $winrarVfsDir = Join-Path $MSIXFolder.FullName 'VFS\ProgramFilesX64\WinRAR'

            if ((Test-Path $cmhDllSrc) -and (Test-Path $cmhJsonSrc)) {
                # Two separate GUIDs: AppId identifies the COM application (surrogate host),
                # CLSID identifies the context menu handler class.
                $cmhAppId        = [Guid]::NewGuid().ToString('D').ToLower()
                $cmhClsidNoBrace = [Guid]::NewGuid().ToString('D').ToLower()
                $cmhClsid        = '{' + $cmhClsidNoBrace.ToUpper() + '}'

                Copy-Item $cmhDllSrc -Destination $winrarVfsDir -Force
                Write-Verbose "Copied MsixContextMenuHandler.dll to $winrarVfsDir"

                # Inject the generated CLSID into the JSON config so DllGetClassObject
                # responds to exactly the CLSID declared in the manifest.
                $cmhCfg = Get-Content $cmhJsonSrc -Raw | ConvertFrom-Json
                Add-Member -InputObject $cmhCfg -MemberType NoteProperty -Name 'clsid' -Value $cmhClsid -Force
                $dstJsonPath = Join-Path $winrarVfsDir 'MsixContextMenuHandler.json'
                $dstJsonText = $cmhCfg | ConvertTo-Json -Depth 10
                [IO.File]::WriteAllText($dstJsonPath, $dstJsonText, [Text.Encoding]::UTF8)
                Write-Verbose "Wrote MsixContextMenuHandler.json (CLSID: $cmhClsid)"

                # Register the DLL and context menu handler in AppxManifest.xml.
                $cmhManifestPath = Join-Path $MSIXFolder.FullName 'AppxManifest.xml'
                $cmhManifest = New-Object xml
                $cmhManifest.Load($cmhManifestPath)

                $cmhNsMgr = New-Object System.Xml.XmlNamespaceManager($cmhManifest.NameTable)
                $AppXNamespaces.GetEnumerator() | ForEach-Object { $cmhNsMgr.AddNamespace($_.Key, $_.Value) }

                # Prefer the Application that runs WinRAR.exe; fall back to the first one.
                $cmhAppNode = $cmhManifest.SelectSingleNode(
                    "//ns:Application[contains(@Executable,'WinRAR.exe')]", $cmhNsMgr)
                if ($null -eq $cmhAppNode) {
                    $cmhAppNode = $cmhManifest.SelectSingleNode('//ns:Application', $cmhNsMgr)
                }

                if ($null -ne $cmhAppNode) {
                    $cmhExtNode = $cmhAppNode.SelectSingleNode('ns:Extensions', $cmhNsMgr)
                    if ($null -eq $cmhExtNode) {
                        $cmhExtNode = $cmhManifest.CreateElement('Extensions', $AppXNamespaces['ns'])
                        $null = $cmhAppNode.AppendChild($cmhExtNode)
                    }

                    Add-MSIXManifestNamespace -Manifest $cmhManifest -Prefixes 'com', 'desktop9'

                    $nsCom      = $AppXNamespaces['com']
                    $nsDesktop9 = $AppXNamespaces['desktop9']

                    # com:SurrogateServer is the schema-valid way to register a DLL COM server
                    # in MSIX. com:Class/@Path names the DLL so DllHost can load it.
                    $comExt = $cmhManifest.CreateElement('com', 'Extension', $nsCom)
                    $null = $comExt.SetAttribute('Category', 'windows.comServer')
                    $comServer = $cmhManifest.CreateElement('com', 'ComServer', $nsCom)
                    $null = $comExt.AppendChild($comServer)
                    $surrogate = $cmhManifest.CreateElement('com', 'SurrogateServer', $nsCom)
                    $null = $surrogate.SetAttribute('AppId', $cmhAppId)
                    $null = $comServer.AppendChild($surrogate)
                    $cmhClassEl = $cmhManifest.CreateElement('com', 'Class', $nsCom)
                    $null = $cmhClassEl.SetAttribute('Id', $cmhClsidNoBrace)
                    $null = $cmhClassEl.SetAttribute('Path', 'VFS\ProgramFilesX64\WinRAR\MsixContextMenuHandler.dll')
                    $null = $cmhClassEl.SetAttribute('ThreadingModel', 'STA')
                    $null = $surrogate.AppendChild($cmhClassEl)
                    $null = $cmhExtNode.AppendChild($comExt)

                    # desktop9:ExtensionHandler entries — follow 7-Zip MSIX pattern:
                    # Type="*" for all files, Type="Directory" and Type="Folder" for directories.
                    $d9Ext = $cmhManifest.CreateElement('desktop9', 'Extension', $nsDesktop9)
                    $null = $d9Ext.SetAttribute('Category', 'windows.fileExplorerClassicContextMenuHandler')
                    $d9Handler = $cmhManifest.CreateElement('desktop9', 'FileExplorerClassicContextMenuHandler', $nsDesktop9)
                    $null = $d9Ext.AppendChild($d9Handler)
                    foreach ($handlerType in @('*', 'Directory', 'Folder')) {
                        $d9Entry = $cmhManifest.CreateElement('desktop9', 'ExtensionHandler', $nsDesktop9)
                        $null = $d9Entry.SetAttribute('Type', $handlerType)
                        $null = $d9Entry.SetAttribute('Clsid', $cmhClsidNoBrace)
                        $null = $d9Handler.AppendChild($d9Entry)
                    }
                    $null = $cmhExtNode.AppendChild($d9Ext)

                    $cmhManifest.PreserveWhitespace = $false
                    $cmhManifest.Save($cmhManifestPath)
                    Write-Verbose "Registered MsixContextMenuHandler in AppxManifest.xml (CLSID: $cmhClsid)"
                }
                else {
                    Write-Warning "No Application found in AppxManifest.xml - MsixContextMenuHandler not registered."
                }
            }
            else {
                Write-Warning "MsixContextMenuHandler files not found in: $cmhLibsDir - skipping context menu handler."
            }

            # Copy PSF binaries: VC++ Runtime DLLs, launcher, fixup DLLs, scripts
            Add-MSIXPsfFrameworkFiles -MSIXFolder $MSIXFolder

            # Redirect every regular application entry through PsfLauncher64.
            # Add-MSXIXPSFShim renames the Application Id and returns the new Id.
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
            }

            # Add execution alias so WinRAR.exe can be invoked from Run dialog and command line.
            $winrarApp = $apps | Where-Object { $_.Executable -like '*WinRAR.exe' } | Select-Object -First 1
            if ($null -ne $winrarApp) {
                $winrarNewId = $shimmedIds[$winrarApp.Id]
                Add-MSIXAppExecutionAlias -MSIXFolder $MSIXFolder `
                    -MISXAppID $winrarNewId `
                    -CommandlineAlias 'WinRAR.exe' `
                    -Executable 'VFS\ProgramFilesX64\WinRAR\WinRAR.exe'
            }

            Add-MSIXPSFDefaultRegLegacy -MSIXFolder $MSIXFolder

            Add-MSIXPSFMFRFixup -MSIXFolder $MSIXFolder -IlvAware 'true'

            Add-MSIXPSFDynamicLibraryFixup -MSIXFolder $MSIXFolder

            Close-MSIXPackage -MSIXFolder $MSIXFolder -MSIXFile $OutputFilePath -Force:$Force -KeepMSIXFolder:$KeepMSIXFolder
            "WinRAR PSF fix applied: $OutputFilePath"
        }
        catch {
            Write-Error "Error applying WinRAR PSF fix: $_"
        }
    }
}
