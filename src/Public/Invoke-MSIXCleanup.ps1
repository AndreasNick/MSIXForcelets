
function Invoke-MSIXCleanup {
<#
.SYNOPSIS
    Removes unsupported or unnecessary artifacts from an expanded MSIX package.

.DESCRIPTION
    Cleans up an expanded MSIX package folder before repacking. Each cleanup action
    is controlled by a separate parameter that defaults to $true, so all actions run
    unless explicitly disabled.

    Cleanup actions:

      RemoveShortcutExtensions
          Removes desktop7:Extension Category="windows.shortcut" elements from
          AppxManifest.xml. These are not reliably supported and can cause
          packaging validation errors.

      RemoveInstallerFolder
          Deletes VFS\Windows\Installer and its contents. This folder contains
          MSI installer caches that have no function inside an MSIX container
          and can be very large.

      RemoveDebugSymbols
          Deletes all *.pdb files from the package tree. Debug symbols are not
          needed in production packages and increase package size.

      RemoveTempFiles
          Deletes *.tmp files and the VFS\Windows\Temp folder.

      RemoveLogFiles
          Deletes *.log files from the package tree. Installation logs left
          behind by setup routines have no purpose inside an MSIX container.

      RemoveEmptyDirectories
          Removes empty directories from the package tree after all other
          cleanup actions have run.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain AppxManifest.xml).

.PARAMETER RemoveShortcutExtensions
    Remove desktop7:Extension Category="windows.shortcut" from AppxManifest.xml.
    Default: $true.

.PARAMETER RemoveInstallerFolder
    Delete VFS\Windows\Installer. Default: $true.

.PARAMETER RemoveDebugSymbols
    Delete all *.pdb files. Default: $true.

.PARAMETER RemoveTempFiles
    Delete *.tmp files and VFS\Windows\Temp. Default: $true.

.PARAMETER RemoveLogFiles
    Delete *.log files. Default: $true.

.PARAMETER RemoveEmptyDirectories
    Remove empty directories after all other actions. Default: $true.

.EXAMPLE
    Invoke-MSIXCleanup -MSIXFolder "C:\MSIXTemp\WinRAR"

.EXAMPLE
    Invoke-MSIXCleanup -MSIXFolder "C:\MSIXTemp\App" -RemoveDebugSymbols $false

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [bool] $RemoveShortcutExtensions = $true,
        [bool] $RemoveInstallerFolder    = $true,
        [bool] $RemoveDebugSymbols       = $true,
        [bool] $RemoveTempFiles          = $true,
        [bool] $RemoveLogFiles           = $true,
        [bool] $RemoveEmptyDirectories   = $true
    )

    process {
        $manifestPath = Join-Path $MSIXFolder 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "AppxManifest.xml not found in: $($MSIXFolder.FullName)"
            return
        }

        # --- Remove desktop7 shortcut extensions from AppxManifest ---
        if ($RemoveShortcutExtensions) {
            $manifest = New-Object xml
            $manifest.Load($manifestPath)

            $nsBase  = 'http://schemas.microsoft.com/appx/manifest/foundation/windows10'
            $nsDesk7 = 'http://schemas.microsoft.com/appx/manifest/desktop/windows10/7'

            $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
            $null = $nsmgr.AddNamespace('ns',    $nsBase)
            $null = $nsmgr.AddNamespace('desk7', $nsDesk7)

            $shortcutNodes = $manifest.SelectNodes(
                "//desk7:Extension[@Category='windows.shortcut']", $nsmgr)

            if ($shortcutNodes.Count -gt 0) {
                foreach ($node in $shortcutNodes) {
                    if ($PSCmdlet.ShouldProcess($manifestPath, "Remove desktop7:Extension windows.shortcut")) {
                        $null = $node.ParentNode.RemoveChild($node)
                    }
                }
                Write-Verbose "Removed $($shortcutNodes.Count) desktop7 shortcut extension(s) from AppxManifest.xml."

                # Remove empty Extensions elements left behind
                $emptyExtensions = $manifest.SelectNodes('//ns:Extensions[not(*)]', $nsmgr)
                foreach ($node in $emptyExtensions) {
                    $null = $node.ParentNode.RemoveChild($node)
                }

                $manifest.Save($manifestPath)
            }
            else {
                Write-Verbose "No desktop7 shortcut extensions found in AppxManifest.xml."
            }
        }

        # --- Remove VFS\Windows\Installer ---
        if ($RemoveInstallerFolder) {
            $installerPath = Join-Path $MSIXFolder.FullName 'VFS\Windows\Installer'
            if (Test-Path $installerPath) {
                if ($PSCmdlet.ShouldProcess($installerPath, 'Remove VFS\Windows\Installer')) {
                    Remove-Item $installerPath -Recurse -Force
                    Write-Verbose "Removed VFS\Windows\Installer."
                }
            }
            else {
                Write-Verbose "VFS\Windows\Installer not found — skipped."
            }
        }

        # In Windows PowerShell 5.1 -Filter also matches 8.3 short names ('Text.Logic' -> 'TEXT~1.LOG',
        # 'x.bin.LOG1', 'page.tmpl' -> 'PAGE~1.TMP'), so every filtered search re-checks the real extension.

        # --- Remove debug symbols ---
        if ($RemoveDebugSymbols) {
            $pdbFiles = @(Get-ChildItem -Path $MSIXFolder.FullName -Filter '*.pdb' -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object Extension -eq '.pdb')
            foreach ($file in $pdbFiles) {
                if ($PSCmdlet.ShouldProcess($file.FullName, 'Remove .pdb file')) {
                    Remove-Item $file.FullName -Force
                }
            }
            if ($pdbFiles.Count -gt 0) {
                Write-Verbose "Removed $($pdbFiles.Count) .pdb file(s)."
            }
            else {
                Write-Verbose "No .pdb files found — skipped."
            }
        }

        # --- Remove temp files and VFS\Windows\Temp ---
        if ($RemoveTempFiles) {
            $tempFolder = Join-Path $MSIXFolder.FullName 'VFS\Windows\Temp'
            if (Test-Path $tempFolder) {
                if ($PSCmdlet.ShouldProcess($tempFolder, 'Remove VFS\Windows\Temp')) {
                    Remove-Item $tempFolder -Recurse -Force
                    Write-Verbose "Removed VFS\Windows\Temp."
                }
            }

            $tmpFiles = @(Get-ChildItem -Path $MSIXFolder.FullName -Filter '*.tmp' -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object Extension -eq '.tmp')
            foreach ($file in $tmpFiles) {
                if ($PSCmdlet.ShouldProcess($file.FullName, 'Remove .tmp file')) {
                    Remove-Item $file.FullName -Force
                }
            }
            if ($tmpFiles.Count -gt 0) {
                Write-Verbose "Removed $($tmpFiles.Count) .tmp file(s)."
            }
            else {
                Write-Verbose "No .tmp files found — skipped."
            }
        }

        # --- Remove log files ---
        if ($RemoveLogFiles) {
            $logFiles = @(Get-ChildItem -Path $MSIXFolder.FullName -Filter '*.log' -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object Extension -eq '.log')
            foreach ($file in $logFiles) {
                if ($PSCmdlet.ShouldProcess($file.FullName, 'Remove .log file')) {
                    Remove-Item $file.FullName -Force
                }
            }
            if ($logFiles.Count -gt 0) {
                Write-Verbose "Removed $($logFiles.Count) .log file(s)."
            }
            else {
                Write-Verbose "No .log files found — skipped."
            }
        }

        # --- Remove empty directories ---
        # Repeat while a pass removed something (a parent becomes empty once its children are gone).
        # Stop as soon as a pass removes nothing: with -WhatIf nothing is ever deleted and a locked
        # folder fails silently - both previously kept the loop running forever.
        if ($RemoveEmptyDirectories) {
            $removed = 0
            do {
                $removedThisPass = 0
                $emptyDirs = @(Get-ChildItem -Path $MSIXFolder.FullName -Recurse -Directory -ErrorAction SilentlyContinue |
                    Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue) } |
                    Sort-Object { $_.FullName.Length } -Descending)
                foreach ($dir in $emptyDirs) {
                    if ($PSCmdlet.ShouldProcess($dir.FullName, 'Remove empty directory')) {
                        Remove-Item -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue
                        if (-not (Test-Path -LiteralPath $dir.FullName)) {
                            $removedThisPass++
                        }
                    }
                }
                $removed += $removedThisPass
            } while ($removedThisPass -gt 0)

            if ($removed -gt 0) {
                Write-Verbose "Removed $removed empty director(ies)."
            }
        }
    }
}
