
function Import-MSIXSparseShellExtension {
<#
.SYNOPSIS
    Merges shell extension declarations from an inner sparse MSIX into the main AppxManifest.xml.

.DESCRIPTION
    Some applications (e.g. WinRAR, Notepad++) ship their shell extension (COM server,
    file explorer context menus, file type associations) as a separate sparse MSIX package
    inside their VFS folder. A companion installer executable deploys that inner package at
    runtime. Inside a repackaged MSIX container the deployment fails because the WindowsApps
    path is read-only.

    This function:

      1. Opens the inner MSIX as a ZIP archive and reads its AppxManifest.xml.
      2. Copies any missing xmlns: declarations and IgnorableNamespaces entries from the
         sparse Package element to the main Package element.
      3. For every Application in the sparse manifest that carries an Extensions block,
         finds the matching Application in the main manifest by Id, or falls back to the
         first Application if no match is found.
      4. Appends all Extension child elements to that Application's Extensions element
         (creating the Extensions element if it does not exist yet).
      5. Optionally deletes the sparse MSIX file and a companion installer executable after
         the merge so they cannot cause errors at runtime.

    With -ConvertSurrogateToInProcess every com:SurrogateServer block is rewritten to
    com:InProcessServer. The DLL path is resolved from the directory of SparsePackagePath.
    Note: com:InProcessServer is not valid in the current MSIX manifest schema - this
    parameter is reserved for potential future schema support and currently has no effect.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain AppxManifest.xml).

.PARAMETER SparsePackagePath
    Package-relative path to the inner sparse MSIX file, e.g.
    "VFS\ProgramFilesX64\WinRAR\RarExtPackage.msix".

.PARAMETER InstallerExePath
    Optional package-relative path to the companion installer executable to delete, e.g.
    "VFS\ProgramFilesX64\WinRAR\RarExtInstaller.exe".

.PARAMETER TargetAppId
    Id of the Application in the main manifest that receives the merged Extensions.
    When omitted the function first tries to find an Application whose Id matches the one
    in the sparse manifest; if that fails it falls back to the first Application.

.PARAMETER DeleteOnly
    When set, deletes InstallerExePath and SparsePackagePath without reading or merging
    any Extension elements. Use this when the main manifest already contains the required
    shell extension declarations and the files just need to be removed.

.PARAMETER ExcludeCategories
    One or more Extension Category attribute values to skip during the merge.
    When omitted all Extension elements are merged (default).
    Example: to keep only the classic COM shell extension and skip modern file type
    associations use: -ExcludeCategories @('windows.fileTypeAssociation')
    Known categories in sparse shell packages:
      windows.comServer                  - COM SurrogateServer (classic RarExt.dll style)
      windows.fileExplorerContextMenus   - desktop4/5 context menu wiring
      windows.fileTypeAssociation        - modern FTA verbs (uap/uap3)

.PARAMETER ConvertSurrogateToInProcess
    When set, converts every com:SurrogateServer declaration inside a windows.comServer
    extension to a com:InProcessServer declaration during the merge.

    Use this when the sparse package registers a shell extension DLL (e.g. RarExt.dll,
    NppShell.dll) as an out-of-process COM surrogate and the context menu entries do not
    work after the merge.

    Why the surrogate does not work for shell extensions:
    Shell extension interfaces (IContextMenu, IShellExtInit, IShellIconOverlayIdentifier)
    require the DLL to run inside the calling process (Explorer). An out-of-process
    surrogate (dllhost.exe) hosts the DLL in a separate process where Explorer cannot
    pass its in-memory selection context. The menu entries appear but clicking them fails.
    Switching to com:InProcessServer loads the DLL directly into Explorer, which is what
    the Shell expects.

    The DLL path in the generated com:InProcessServer is resolved relative to the
    directory of SparsePackagePath inside the main package, e.g. if SparsePackagePath is
    'VFS\ProgramFilesX64\WinRAR\RarExtPackage.msix' and the Class Path attribute is
    'RarExt.dll', the resulting path is 'VFS\ProgramFilesX64\WinRAR\RarExt.dll'.

.EXAMPLE
    Import-MSIXSparseShellExtension -MSIXFolder "C:\MSIXTemp\WinRAR" `
        -SparsePackagePath 'VFS\ProgramFilesX64\WinRAR\RarExtPackage.msix' `
        -InstallerExePath  'VFS\ProgramFilesX64\WinRAR\RarExtInstaller.exe'

.EXAMPLE
    Import-MSIXSparseShellExtension -MSIXFolder "C:\MSIXTemp\Notepad++" `
        -SparsePackagePath 'VFS\ProgramFilesX64\Notepad++\NppShell.msix' `
        -InstallerExePath  'VFS\ProgramFilesX64\Notepad++\NppShellInstaller.exe' `
        -TargetAppId       'NotepadPlusPlus'

.EXAMPLE
    # Import only the modern file type associations, skip the classic COM shell extension
    Import-MSIXSparseShellExtension -MSIXFolder "C:\MSIXTemp\App" `
        -SparsePackagePath 'VFS\ProgramFilesX64\App\ShellExt.msix' `
        -ExcludeCategories @('windows.comServer', 'windows.fileExplorerContextMenus')

.EXAMPLE
    # Convert the out-of-process COM surrogate to in-process so shell extension verbs work
    Import-MSIXSparseShellExtension -MSIXFolder "C:\MSIXTemp\WinRAR" `
        -SparsePackagePath         'VFS\ProgramFilesX64\WinRAR\RarExtPackage.msix' `
        -InstallerExePath          'VFS\ProgramFilesX64\WinRAR\RarExtInstaller.exe' `
        -ConvertSurrogateToInProcess

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [Parameter(Mandatory = $true, Position = 1)]
        [String] $SparsePackagePath,

        [String] $InstallerExePath = '',

        [String] $TargetAppId = '',

        [string[]] $ExcludeCategories = @(),

        # When set, only delete InstallerExePath and SparsePackagePath without merging
        # any Extensions. Use this when the main manifest already contains the required
        # shell extension declarations.
        [Switch] $DeleteOnly,

        # Converts com:SurrogateServer registrations to com:InProcessServer so that shell
        # extension DLLs are loaded in-process by Explorer instead of in an isolated host.
        # Required for IContextMenu / IShellExtInit shell extensions to function correctly.
        [Switch] $ConvertSurrogateToInProcess
    )

    process {
        $sparseFull = Join-Path $MSIXFolder.FullName $SparsePackagePath

        # --- DeleteOnly: remove files without touching the manifest ---
        if ($DeleteOnly) {
            if ($InstallerExePath -ne '') {
                $installerFull = Join-Path $MSIXFolder.FullName $InstallerExePath
                if (Test-Path $installerFull) {
                    if ($PSCmdlet.ShouldProcess($installerFull, 'Remove companion installer')) {
                        Remove-Item $installerFull -Force
                        Write-Verbose "Removed companion installer: $InstallerExePath"
                    }
                }
            }
            if (Test-Path $sparseFull) {
                if ($PSCmdlet.ShouldProcess($sparseFull, 'Remove sparse MSIX')) {
                    Remove-Item $sparseFull -Force
                    Write-Verbose "Removed sparse package: $SparsePackagePath"
                }
            }
            return
        }

        $manifestPath = Join-Path $MSIXFolder 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "AppxManifest.xml not found in: $($MSIXFolder.FullName)"
            return
        }

        if (-not (Test-Path $sparseFull)) {
            Write-Verbose "Sparse package not found, skipping: $SparsePackagePath"
            return
        }

        # --- Delete companion installer before reading the sparse package ---
        if ($InstallerExePath -ne '') {
            $installerFull = Join-Path $MSIXFolder.FullName $InstallerExePath
            if (Test-Path $installerFull) {
                if ($PSCmdlet.ShouldProcess($installerFull, 'Remove companion installer')) {
                    Remove-Item $installerFull -Force
                    Write-Verbose "Removed companion installer: $InstallerExePath"
                }
            }
        }

        # --- Read AppxManifest.xml from the sparse MSIX (ZIP) ---
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        $zip = [System.IO.Compression.ZipFile]::OpenRead($sparseFull)
        $entry = $zip.Entries |
            Where-Object { $_.FullName -eq 'AppxManifest.xml' } |
            Select-Object -First 1

        $sparseManifestContent = $null
        if ($null -ne $entry) {
            $stream = $entry.Open()
            $reader = New-Object System.IO.StreamReader($stream)
            $sparseManifestContent = $reader.ReadToEnd()
            $reader.Dispose()
            $stream.Dispose()
        }
        $zip.Dispose()

        if (-not $sparseManifestContent) {
            Write-Warning "AppxManifest.xml not found inside '$SparsePackagePath' - no extensions merged."
            return
        }

        $sparseXml = [xml]$sparseManifestContent
        $mainXml   = New-Object xml
        $mainXml.Load($manifestPath)

        $nsBase    = 'http://schemas.microsoft.com/appx/manifest/foundation/windows10'
        $mainNsmgr = New-Object System.Xml.XmlNamespaceManager($mainXml.NameTable)
        $mainNsmgr.AddNamespace('ns', $nsBase)
        $sparseNsmgr = New-Object System.Xml.XmlNamespaceManager($sparseXml.NameTable)
        $sparseNsmgr.AddNamespace('ns', $nsBase)

        $sparsePackageEl = $sparseXml.DocumentElement
        $mainPackageEl   = $mainXml.DocumentElement

        # --- Copy missing xmlns: declarations ---
        foreach ($attr in $sparsePackageEl.Attributes) {
            if ($attr.Name -like 'xmlns:*' -and
                $mainPackageEl.GetAttribute($attr.Name) -eq '') {
                $null = $mainPackageEl.SetAttribute($attr.Name, $attr.Value)
                Write-Verbose "Added namespace: $($attr.Name) = $($attr.Value)"
            }
        }

        # --- Merge IgnorableNamespaces ---
        $sparseIgnorable = $sparsePackageEl.GetAttribute('IgnorableNamespaces')
        if ($sparseIgnorable) {
            $mainIgnorable = $mainPackageEl.GetAttribute('IgnorableNamespaces')
            $combined = (($mainIgnorable + ' ' + $sparseIgnorable).Trim() -split '\s+' |
                Select-Object -Unique) -join ' '
            $null = $mainPackageEl.SetAttribute('IgnorableNamespaces', $combined)
            Write-Verbose "Merged IgnorableNamespaces: $combined"
        }

        # --- Merge Extension elements ---
        $sparseApps = $sparseXml.SelectNodes('//ns:Application[ns:Extensions]', $sparseNsmgr)
        if ($sparseApps.Count -eq 0) {
            Write-Warning "No Application with Extensions found in sparse manifest '$SparsePackagePath'."
        }

        $totalMerged = 0
        foreach ($sparseApp in $sparseApps) {
            $sparseAppId      = $sparseApp.GetAttribute('Id')
            $sparseExtensions = $sparseApp.SelectSingleNode('ns:Extensions', $sparseNsmgr)

            # Resolve target Application: explicit parameter > match by sparse Id > first Application
            $mainApp = $null
            if ($TargetAppId -ne '') {
                $mainApp = $mainXml.SelectSingleNode(
                    "//ns:Application[@Id='$TargetAppId']", $mainNsmgr)
                if ($null -eq $mainApp) {
                    Write-Warning "TargetAppId '$TargetAppId' not found in main manifest."
                }
            }
            if ($null -eq $mainApp -and $sparseAppId -ne '') {
                $mainApp = $mainXml.SelectSingleNode(
                    "//ns:Application[@Id='$sparseAppId']", $mainNsmgr)
            }
            if ($null -eq $mainApp) {
                $mainApp = $mainXml.SelectSingleNode('//ns:Application', $mainNsmgr)
            }

            if ($null -eq $mainApp) {
                Write-Warning "No target Application found in main manifest for sparse app '$sparseAppId'."
                continue
            }

            $mainExtensions = $mainApp.SelectSingleNode('ns:Extensions', $mainNsmgr)
            if ($null -eq $mainExtensions) {
                $mainExtensions = $mainXml.CreateElement('Extensions', $nsBase)
                $null = $mainApp.AppendChild($mainExtensions)
            }

            $count   = 0
            $skipped = 0
            foreach ($child in @($sparseExtensions.ChildNodes)) {
                $category = $child.GetAttribute('Category')
                if ($ExcludeCategories.Count -gt 0 -and $ExcludeCategories -contains $category) {
                    Write-Verbose "Skipped Extension Category='$category' (ExcludeCategories)."
                    $skipped++
                    continue
                }

                # Before merging a comServer extension, remove any existing com:Extension in
                # the main manifest that declares the same Class Id. Without this, packages that
                # already carry the CLSID inline (e.g. WinRAR Store MSIX) end up with a duplicate
                # key which causes a MakeAppx schema identity-constraint violation.
                if ($category -eq 'windows.comServer') {
                    $sparseClasses = @($child.SelectNodes(".//*[local-name()='Class']"))
                    foreach ($cls in $sparseClasses) {
                        $clsId = $cls.GetAttribute('Id')
                        if (-not $clsId) { continue }
                        $clsIdLower = $clsId.ToLower()

                        $allClasses = @($mainXml.SelectNodes("//*[local-name()='Class']"))
                        foreach ($existing in $allClasses) {
                            if ($existing.GetAttribute('Id').ToLower() -ne $clsIdLower) { continue }

                            # Walk up to the nearest Extension ancestor and remove it
                            $extNode = $existing.ParentNode
                            while ($null -ne $extNode -and $extNode.LocalName -ne 'Extension') {
                                $extNode = $extNode.ParentNode
                            }
                            if ($null -ne $extNode -and $null -ne $extNode.ParentNode) {
                                $null = $extNode.ParentNode.RemoveChild($extNode)
                                Write-Verbose "Removed duplicate com:Extension for CLSID '$clsId' from main manifest."
                            }
                        }
                    }
                }

                # NOTE: com:InProcessServer is not valid in the MSIX manifest schema.
                # com:ComServer only accepts ExeServer and SurrogateServer children.
                # ConvertSurrogateToInProcess is therefore a no-op and reserved for
                # potential future schema support.
                if ($false -and $category -eq 'windows.comServer' -and $ConvertSurrogateToInProcess) {
                    $comNs    = 'http://schemas.microsoft.com/appx/manifest/com/windows10'
                    $extClone = $child.CloneNode($true)

                    $surrogates = @($extClone.SelectNodes(".//*[local-name()='SurrogateServer']"))
                    foreach ($surrogate in $surrogates) {
                        $comServerEl = $surrogate.ParentNode

                        # Collect unique DLL names from Class/@Path — typically all classes share one DLL
                        $dllNames = @($surrogate.ChildNodes |
                            Where-Object { $_.LocalName -eq 'Class' -and $_.GetAttribute('Path') -ne '' } |
                            ForEach-Object { $_.GetAttribute('Path') } |
                            Select-Object -Unique)

                        # Build one InProcessServer per unique DLL
                        foreach ($dllName in $dllNames) {
                            $fullDllPath = if ($sparsePackageDir -ne '') {
                                "$($sparsePackageDir)\$dllName"
                            } else {
                                $dllName
                            }

                            $inproc = $extClone.OwnerDocument.CreateElement('com:InProcessServer', $comNs)

                            $pathEl = $extClone.OwnerDocument.CreateElement('com:Path', $comNs)
                            $pathEl.InnerText = $fullDllPath
                            $null = $inproc.AppendChild($pathEl)

                            foreach ($cls in @($surrogate.ChildNodes | Where-Object { $_.LocalName -eq 'Class' })) {
                                if ($cls.GetAttribute('Path') -ne $dllName) { continue }
                                $newCls = $extClone.OwnerDocument.CreateElement('com:Class', $comNs)
                                foreach ($attr in $cls.Attributes) {
                                    if ($attr.LocalName -ne 'Path') {
                                        $null = $newCls.SetAttribute($attr.Name, $attr.Value)
                                    }
                                }
                                $null = $inproc.AppendChild($newCls)
                            }

                            $null = $comServerEl.InsertBefore($inproc, $surrogate)
                            Write-Verbose "Converted SurrogateServer to InProcessServer: $fullDllPath"
                        }

                        $null = $comServerEl.RemoveChild($surrogate)
                    }

                    $child = $extClone
                }

                if ($PSCmdlet.ShouldProcess(
                    "Category='$category' -> Application '$($mainApp.GetAttribute('Id'))'",
                    'Merge Extension')) {
                    $imported = $mainXml.ImportNode($child, $true)
                    $null = $mainExtensions.AppendChild($imported)
                    $count++
                }
            }
            Write-Verbose ("Merged $count Extension element(s) from sparse app '$sparseAppId'" +
                           " into Application '$($mainApp.GetAttribute('Id'))'." +
                           $(if ($skipped -gt 0) { " Skipped: $skipped." } else { '' }))
            $totalMerged += $count
        }

        $mainXml.PreserveWhiteSpace = $false
        $mainXml.Save($manifestPath)
        Write-Verbose "Saved AppxManifest.xml with $totalMerged merged Extension element(s)."

        # --- Remove sparse package after successful merge ---
        if ($PSCmdlet.ShouldProcess($sparseFull, 'Remove sparse MSIX after merge')) {
            Remove-Item $sparseFull -Force
            Write-Verbose "Removed sparse package: $SparsePackagePath"
        }
    }
}
