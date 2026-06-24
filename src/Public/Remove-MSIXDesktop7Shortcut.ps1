function Remove-MSIXDesktop7Shortcut {
<#
.SYNOPSIS
    Removes desktop7:Shortcut entries (+ the physical .lnk) from an MSIX package.
.PARAMETER MSIXFolderPath
    Expanded MSIX package folder. Pipeline by property name.
.PARAMETER File
    File token of a specific shortcut. Omit to remove all.
.PARAMETER KeepLnkFile
    Keep the physical .lnk (only remove the manifest entry).
.PARAMETER RemoveIcon
    Also delete the icon file (may be the shared app logo - use with care).
.EXAMPLE
    Get-MSIXDesktop7Shortcut -MSIXFolder $pkg | Remove-MSIXDesktop7Shortcut
.NOTES
    Andreas Nick, 2026
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolderPath,

        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1)]
        [string] $File,

        [switch] $KeepLnkFile,
        [switch] $RemoveIcon
    )

    begin {
        # Keyed by folder -> list of File tokens to remove (empty = all)
        $pending = @{}
    }

    process {
        $key = $MSIXFolderPath.FullName
        if (-not $pending.ContainsKey($key)) {
            $pending[$key] = [System.Collections.Generic.List[string]]::new()
        }
        if (-not [string]::IsNullOrEmpty($File)) {
            $pending[$key].Add($File)
        }
    }

    end {
        foreach ($folder in $pending.Keys) {
            $manifestPath = Join-Path $folder 'AppxManifest.xml'
            if (-not (Test-Path $manifestPath)) {
                Write-Warning "AppxManifest.xml not found in '$folder' - skipping."
                continue
            }

            $manifest = New-Object System.Xml.XmlDocument
            $manifest.PreserveWhitespace = $false
            $manifest.Load($manifestPath)

            $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
            $AppXNamespaces.GetEnumerator() | ForEach-Object { $null = $nsmgr.AddNamespace($_.Key, $_.Value) }

            $targets    = $pending[$folder]   # empty = all
            $removedAny = $false

            # desktop7:Shortcut may live under each Application's Extensions AND directly under the
            # package-level Extensions - collect both so package-level shortcuts are removed too.
            $extNodes = @()
            foreach ($app in @($manifest.SelectNodes('//ns:Package/ns:Applications/ns:Application', $nsmgr))) {
                $e = $app.SelectSingleNode('ns:Extensions', $nsmgr)
                if ($null -ne $e) { $extNodes += $e }
            }
            $pkgExt = $manifest.SelectSingleNode('/ns:Package/ns:Extensions', $nsmgr)
            if ($null -ne $pkgExt) { $extNodes += $pkgExt }

            foreach ($extNode in $extNodes) {
                foreach ($ext in @($extNode.SelectNodes("desktop7:Extension[@Category='windows.shortcut']", $nsmgr))) {
                    $sc       = $ext.SelectSingleNode('desktop7:Shortcut', $nsmgr)
                    $fileTok  = if ($null -ne $sc) { $sc.GetAttribute('File') } else { '' }
                    $iconTok  = if ($null -ne $sc) { $sc.GetAttribute('Icon') } else { '' }

                    if ($targets.Count -gt 0 -and $targets -notcontains $fileTok) { continue }
                    if (-not $PSCmdlet.ShouldProcess($folder, "Remove desktop7:Shortcut '$fileTok'")) { continue }

                    $null = $extNode.RemoveChild($ext)
                    $removedAny = $true
                    Write-Verbose "Removed desktop7:Shortcut '$fileTok'."

                    if (-not $KeepLnkFile) {
                        $rel = Resolve-MSIXShortcutTokenPath -TokenPath $fileTok
                        if ($rel) {
                            $lnk = Resolve-MSIXShortcutOnDiskPath -FolderPath $folder -Relative $rel
                            if ($lnk) { Remove-Item $lnk -Force; Write-Verbose "Deleted .lnk: $rel" }
                        }
                    }

                    if ($RemoveIcon -and $iconTok) {
                        $relIcon = Resolve-MSIXShortcutTokenPath -TokenPath $iconTok
                        if ($relIcon) {
                            $ico = Resolve-MSIXShortcutOnDiskPath -FolderPath $folder -Relative $relIcon
                            if ($ico) { Remove-Item $ico -Force; Write-Verbose "Deleted icon: $relIcon" }
                        }
                    }
                }

                # Drop an empty <Extensions> node (works for Application and Package level).
                if ($null -ne $extNode -and $extNode.SelectNodes('*').Count -eq 0) {
                    $null = $extNode.ParentNode.RemoveChild($extNode)
                }
            }

            if ($removedAny) {
                $manifest.Save($manifestPath)
                Write-Verbose "Saved $manifestPath"
            }
            else {
                Write-Warning "No matching desktop7:Shortcut found in '$folder'."
            }
        }
    }
}
