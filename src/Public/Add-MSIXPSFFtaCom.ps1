
function Add-MSIXPSFFtaCom {
<#
.SYNOPSIS
    Moves shell extension entries from an existing Application to a new PsfFtaCom surrogate.

.DESCRIPTION
    Fixes shell extensions (context menu handlers, file type associations, COM surrogate
    servers) that do not work correctly inside an MSIX container by routing them through
    Tim Mangan's PsfFtaCom executable.

    The original MSIX manifest already contains all required extension elements
    (com:Extension, uap3:Extension, desktop9:Extension, namespace declarations) under an
    existing Application entry. This function:

      1. Auto-detects the Application that contains the shell extension Extensions block.
         If more than one Application has Extensions, SourceAppId must be specified.
      2. Creates a new Application element pointing to PsfFtaCom64.exe or PsfFtaCom32.exe
         with AppListEntry=none (hidden from the Start menu).
         VisualElements logos are copied from the source Application.
      3. Moves the entire Extensions block from the source Application to the new
         FtaCom Application. The source Application is left without Extensions.
      4. Updates all uap3:Verb Parameters in the moved Extensions to prepend the
         real application executable path. PsfFtaCom requires the full package-relative
         path as the first verb argument (e.g. "VFS\ProgramFilesX64\App\App.exe" "%1").
         The original executable is read from config.json.xml when Add-MSXIXPSFShim
         has already run; otherwise it is taken from the source Application attribute.
      5. Creates or updates config.json.xml with hasShellVerbs=true for this entry.

    Call Add-MSIXPsfFrameworkFiles before this function so that PsfFtaCom64.exe /
    PsfFtaCom32.exe are already present in the MSIX package root.

    Tim Mangan PSF only. Requires Set-MSIXActivePSFFramework to point to a TimMangan path.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain AppxManifest.xml).

.PARAMETER PSFArchitektur
    Architecture of the PsfFtaCom executable: Auto, x64, or x86.
    When omitted, PSFDefaultArchitecture from module configuration is used.
    Auto resolves to x64.

.PARAMETER SourceAppId
    Id of the Application whose Extensions block is moved to the new FtaCom Application.
    Optional — auto-detected when only one Application has an Extensions child.

.PARAMETER FtaComAppId
    Id for the new FtaCom Application element.
    Optional — defaults to "<SourceAppId>PsfFtaComSixFour" (x64) or
    "<SourceAppId>PsfFtaComThirtyTwo" (x86).

.PARAMETER TerminateChildren
    Written to config.json.xml. Tim Mangan PSF always writes this field.
    Default: $false.

.EXAMPLE
    Add-MSIXPSFFtaCom -MSIXFolder "C:\MSIXTemp\WinRAR"

.EXAMPLE
    Add-MSIXPSFFtaCom -MSIXFolder "C:\MSIXTemp\App" -PSFArchitektur x86

.EXAMPLE
    Add-MSIXPSFFtaCom -MSIXFolder "C:\MSIXTemp\App" -SourceAppId "AppHelper" -FtaComAppId "AppHelper_ShellExt"

.NOTES
    Tim Mangan PSF only. Requires Set-MSIXActivePSFFramework to point to a TimMangan path.
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        # Valid values: Auto | x64 | x86. When omitted, PSFDefaultArchitecture from module config is used.
        [ValidateSet('Auto', 'x64', 'x86')]
        [String] $PSFArchitektur,

        [String] $SourceAppId,
        [String] $FtaComAppId,

        # Extension Category values to keep in the source Application instead of moving
        # to the PsfFtaCom Application. Use this to leave context menu handlers or FTA
        # declarations in the visible application so that Windows DEH can process them.
        [string[]] $ExcludeCategories = @(),

        # Tim Mangan PSF — always written to config.json.xml.
        [bool] $TerminateChildren = $false
    )

    process {
        if (-not ($Script:PsfBasePath -like '*TimMangan*')) {
            Write-Error "Add-MSIXPSFFtaCom requires Tim Mangan PSF. Use Set-MSIXActivePSFFramework to select a TimMangan PSF path."
            return
        }

        $manifestPath = Join-Path $MSIXFolder 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "AppxManifest.xml not found in: $($MSIXFolder.FullName)"
            return
        }

        # --- Resolve architecture ---
        if ($PSBoundParameters.ContainsKey('PSFArchitektur')) {
            $resolvedArch = $PSFArchitektur
        }
        else {
            $resolvedArch = $Script:MSIXForceletsConfig.PSFDefaultArchitecture
        }

        if ($resolvedArch -eq 'Auto') {
            $resolvedArch = 'x64'
        }

        $ftaSourceExe = if ($resolvedArch -eq 'x64') { 'PsfFtaCom64.exe' } else { 'PsfFtaCom32.exe' }
        $ftaArch      = if ($resolvedArch -eq 'x64') { '64' } else { '32' }

        # PsfFtaCom exe must be present — Add-MSIXPsfFrameworkFiles copies it.
        if (-not (Test-Path (Join-Path $MSIXFolder.FullName $ftaSourceExe))) {
            Write-Warning "$ftaSourceExe not found in MSIX package root. Run Add-MSIXPsfFrameworkFiles first."
        }

        # --- Load AppxManifest ---
        $manifest = New-Object xml
        $manifest.Load($manifestPath)

        $nsBase = 'http://schemas.microsoft.com/appx/manifest/foundation/windows10'
        $nsUap  = 'http://schemas.microsoft.com/appx/manifest/uap/windows10'
        $nsUap3 = 'http://schemas.microsoft.com/appx/manifest/uap/windows10/3'

        $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
        $null = $nsmgr.AddNamespace('ns',   $nsBase)
        $null = $nsmgr.AddNamespace('uap',  $nsUap)
        $null = $nsmgr.AddNamespace('uap3', $nsUap3)

        # --- Auto-detect source Application ---
        if ($SourceAppId) {
            $sourceApp = $manifest.SelectSingleNode("//ns:Application[@Id='$SourceAppId']", $nsmgr)
            if ($null -eq $sourceApp) {
                Write-Error "Application '$SourceAppId' not found in AppxManifest.xml."
                return
            }
        }
        else {
            $appsWithExtensions = $manifest.SelectNodes(
                '//ns:Application[ns:Extensions]', $nsmgr)

            if ($appsWithExtensions.Count -eq 0) {
                Write-Error "No Application with an Extensions element found in AppxManifest.xml."
                return
            }
            if ($appsWithExtensions.Count -gt 1) {
                $ids = ($appsWithExtensions | ForEach-Object { $_.GetAttribute('Id') }) -join ', '
                Write-Error "Multiple Applications with Extensions found: $ids. Specify -SourceAppId."
                return
            }

            $sourceApp = $appsWithExtensions.Item(0)
            $SourceAppId = $sourceApp.GetAttribute('Id')
            Write-Verbose "Auto-detected source Application: $SourceAppId"
        }

        # Strip the PsfLauncher<Letter> suffix added by Add-MSXIXPSFShim so the FtaCom
        # Application Id and exe name are always derived from the original base name,
        # not from the launcher-specific Id (e.g. "WINRAR" not "WINRARPsfLauncherA").
        $baseId = $SourceAppId -replace 'PsfLauncher[A-Za-z]$', ''

        if (-not $FtaComAppId) {
            $FtaComAppId = if ($resolvedArch -eq 'x64') {
                "$($baseId)PsfFtaComSixFour"
            } else {
                "$($baseId)PsfFtaComThirtyTwo"
            }
        }

        # Rename PsfFtaCom following best practice: <BaseId>_PsfFtaCom<Arch>.exe
        # The default processes section adds an explicit '.*_PsfFtaCom.*' entry so the
        # process is visible in the config; the catch-all '.*' still injects fixup DLLs.
        $ftaExeName  = "$($baseId)_PsfFtaCom$($ftaArch).exe"
        $srcFtaPath  = Join-Path $MSIXFolder.FullName $ftaSourceExe
        $destFtaPath = Join-Path $MSIXFolder.FullName $ftaExeName
        if ((Test-Path $srcFtaPath) -and -not (Test-Path $destFtaPath)) {
            Copy-Item $srcFtaPath $destFtaPath -Force
            Write-Verbose "Copied $ftaSourceExe -> $ftaExeName"
        }
        elseif (Test-Path $destFtaPath) {
            Write-Verbose "Renamed FtaCom exe already present: $ftaExeName"
        }

        # Determine the real executable path for verb parameter updates.
        # config.json.xml (written by Add-MSXIXPSFShim) holds the original path even when
        # the manifest Executable attribute already points to PsfLauncher.
        $realExe = $null
        $configXmlPath = Join-Path $MSIXFolder 'config.json.xml'
        if (Test-Path $configXmlPath) {
            $conxmlCheck = New-Object xml
            $conxmlCheck.Load($configXmlPath)
            $exeNode = $conxmlCheck.SelectSingleNode("//application[id='$SourceAppId']/executable")
            if ($null -ne $exeNode) {
                # InnerText contains JSON-escaped double backslashes (written by Add-MSXIXPSFShim).
                # Normalise back to single backslash before using in XML manifest attributes.
                $realExe = $exeNode.InnerText -replace '\\\\', '\'
            }
        }
        if (-not $realExe) {
            $realExe = $sourceApp.GetAttribute('Executable')
        }
        Write-Verbose "Real executable for verb parameters: $realExe"

        # --- Build FtaCom Application if not yet present ---
        $existingFtaApp = $manifest.SelectSingleNode("//ns:Application[@Id='$FtaComAppId']", $nsmgr)
        if ($null -ne $existingFtaApp) {
            Write-Verbose "Application '$FtaComAppId' already exists in AppxManifest.xml — skipped."
        }
        else {
            $applicationsNode = $manifest.SelectSingleNode('//ns:Applications', $nsmgr)

            $appEl = $manifest.CreateElement('Application', $nsBase)
            $null = $appEl.SetAttribute('Id', $FtaComAppId)
            $null = $appEl.SetAttribute('Executable', $ftaExeName)
            $null = $appEl.SetAttribute('EntryPoint', 'Windows.FullTrustApplication')

            # Copy VisualElements from source Application and set AppListEntry=none.
            $sourceVe = $sourceApp.SelectSingleNode('uap:VisualElements', $nsmgr)
            if ($null -ne $sourceVe) {
                $veEl = $sourceVe.CloneNode($true)
                $null = $veEl.SetAttribute('AppListEntry', 'none')
                $null = $veEl.SetAttribute('DisplayName',  ($ftaExeName -replace '\.exe', ''))
                $null = $veEl.SetAttribute('Description', 'Launcher for FTA Shell Verbs and Dummy holder for COM')
                $null = $appEl.AppendChild($veEl)
            }
            else {
                Write-Warning "No VisualElements found on '$SourceAppId'. New Application will lack VisualElements."
            }

            # Move Extensions from source Application to this new FtaCom Application.
            # Extensions whose Category is in ExcludeCategories are left in the source app.
            $sourceExtensions = $sourceApp.SelectSingleNode('ns:Extensions', $nsmgr)
            if ($null -ne $sourceExtensions) {
                if ($ExcludeCategories.Count -gt 0) {
                    # Separate extensions: move qualifying ones, leave excluded ones in source.
                    $ftaExtensions = $manifest.CreateElement('Extensions', $nsBase)
                    $toMove   = @($sourceExtensions.ChildNodes | Where-Object {
                        $ExcludeCategories -notcontains $_.GetAttribute('Category')
                    })
                    $toKeep   = @($sourceExtensions.ChildNodes | Where-Object {
                        $ExcludeCategories -contains $_.GetAttribute('Category')
                    })
                    foreach ($node in $toMove) {
                        $null = $ftaExtensions.AppendChild($node)
                    }
                    if ($toKeep.Count -eq 0) {
                        $null = $sourceApp.RemoveChild($sourceExtensions)
                    }
                    else {
                        Write-Verbose "Kept $($toKeep.Count) extension(s) in '$SourceAppId': $($toKeep | ForEach-Object { $_.GetAttribute('Category') } | Select-Object -Unique)"
                    }
                    $null = $appEl.AppendChild($ftaExtensions)
                    $sourceExtensions = $ftaExtensions
                    Write-Verbose "Moved $($toMove.Count) extension(s) from '$SourceAppId' to '$FtaComAppId'."
                }
                else {
                    $null = $sourceApp.RemoveChild($sourceExtensions)
                    $null = $appEl.AppendChild($sourceExtensions)
                    Write-Verbose "Moved Extensions from '$SourceAppId' to '$FtaComAppId'."
                }

                # Update uap3:Verb Parameters — PsfFtaCom requires the full executable path
                # as the first argument so it knows which process to launch for the file type.
                if ($realExe) {
                    $verbs = $sourceExtensions.SelectNodes('.//uap3:Verb', $nsmgr)
                    foreach ($verb in $verbs) {
                        # Normalize existing Parameters: sparse packages may contain double
                        # backslashes (JSON-escape artefact). Always write back normalized form.
                        $params = $verb.GetAttribute('Parameters') -replace '\\\\', '\'
                        if ($params -notmatch [regex]::Escape($realExe)) {
                            $params = "`"$realExe`" $params"
                        }
                        $null = $verb.SetAttribute('Parameters', $params)
                    }
                    if ($verbs.Count -gt 0) {
                        Write-Verbose "Updated $($verbs.Count) verb Parameter(s) with: $realExe"
                    }
                }
            }
            else {
                Write-Warning "No Extensions element found under Application '$SourceAppId'."
            }

            $null = $applicationsNode.AppendChild($appEl)
            Write-Verbose "Added Application '$FtaComAppId' to AppxManifest.xml."
        }

        $manifest.Save($manifestPath)

        # --- Update config.json.xml ---
        $configXmlPath = Join-Path $MSIXFolder 'config.json.xml'
        $conxml = New-Object xml

        if (Test-Path $configXmlPath) {
            $conxml.Load($configXmlPath)
        }
        else {
            $conxml = [xml] '<configuration><applications></applications></configuration>'
        }

        $existingEntry = $conxml.SelectSingleNode("//application/id[text()='$FtaComAppId']")
        if ($null -ne $existingEntry) {
            Write-Verbose "Entry '$FtaComAppId' already present in config.json.xml — skipped."
        }
        else {
            $appRoot = $conxml.SelectSingleNode('//applications')

            $r = $conxml.CreateElement('application')

            $idEl = $conxml.CreateElement('id')
            $idEl.InnerText = $FtaComAppId
            $null = $r.AppendChild($idEl)

            # No <executable> for FtaCom entries — PsfFtaCom does not launch a child process.

            $argEl = $conxml.CreateElement('arguments')
            $argEl.InnerText = ''
            $null = $r.AppendChild($argEl)

            $wdEl = $conxml.CreateElement('workingDirectory')
            $wdEl.InnerText = ''
            $null = $r.AppendChild($wdEl)

            $pmiEl = $conxml.CreateElement('preventMultipleInstances')
            $pmiEl.InnerText = 'false'
            $null = $r.AppendChild($pmiEl)

            $tcEl = $conxml.CreateElement('terminateChildren')
            $tcEl.InnerText = $TerminateChildren.ToString().ToLower()
            $null = $r.AppendChild($tcEl)

            $hsEl = $conxml.CreateElement('hasShellVerbs')
            $hsEl.InnerText = 'true'
            $null = $r.AppendChild($hsEl)

            $null = $appRoot.AppendChild($r)
            Write-Verbose "Added entry '$FtaComAppId' to config.json.xml (hasShellVerbs=true)."
        }

        $conxml.PreserveWhiteSpace = $false
        $conxml.Save($configXmlPath)
    }
}
