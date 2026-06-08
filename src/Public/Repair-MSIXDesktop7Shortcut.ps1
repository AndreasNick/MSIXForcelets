function Repair-MSIXDesktop7Shortcut {
<#
.SYNOPSIS
    Relocates desktop7:Shortcut entries from the all-users Start Menu
    ([{Common Programs}]) to the per-user Start Menu ([{Programs}]).
.DESCRIPTION
    A per-user MSIX install does not populate the all-users Start Menu
    (C:\ProgramData\...\Start Menu\Programs), so [{Common Programs}] shortcuts
    never appear. [{Programs}] (per-user) does. This moves both the manifest
    File token and the physical .lnk; Icon, Arguments and Description are kept
    unchanged (an Icon pointing at an .exe is valid per the desktop7 schema).
.PARAMETER MSIXFolderPath
    Expanded MSIX package folder. Pipeline by property name.
.PARAMETER File
    File token of a specific shortcut. Omit to relocate every [{Common Programs}] one.
.EXAMPLE
    Get-MSIXDesktop7Shortcut -MSIXFolder $pkg | Repair-MSIXDesktop7Shortcut
.NOTES
    Tim Mangan: https://www.tmurgent.com/TmBlog/?p=3857
    Andreas Nick, 2026
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolderPath,

        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1)]
        [string] $File
    )

    begin {
        # Keyed by folder -> list of File tokens passed via pipeline (empty = all)
        $pending = @{}

        $fromToken = '[{Common Programs}]'
        $toToken   = '[{Programs}]'
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

            $targets = $pending[$folder]   # empty = all
            $changed = $false

            foreach ($sc in @($manifest.SelectNodes('//desktop7:Shortcut', $nsmgr))) {
                $fileTok = $sc.GetAttribute('File')
                if (-not $fileTok.StartsWith($fromToken)) { continue }
                if ($targets.Count -gt 0 -and $targets -notcontains $fileTok) { continue }

                $newFileTok = $toToken + $fileTok.Substring($fromToken.Length)
                if (-not $PSCmdlet.ShouldProcess($folder, "Relocate shortcut '$fileTok' -> '$newFileTok'")) { continue }

                # Move the physical .lnk to match the new token's VFS folder.
                $oldOnDisk = Resolve-MSIXShortcutOnDiskPath -FolderPath $folder -Relative (Resolve-MSIXShortcutTokenPath -TokenPath $fileTok)
                $newRel    = Resolve-MSIXShortcutTokenPath -TokenPath $newFileTok
                if ($oldOnDisk -and $newRel) {
                    # Mirror the package's encoding (makeappx = spaces, raw ZIP = %20)
                    if ($oldOnDisk -like '*%20*') { $newRel = $newRel -replace ' ', '%20' }
                    $newOnDisk = Join-Path $folder $newRel
                    $newDir    = Split-Path $newOnDisk -Parent
                    if (-not (Test-Path $newDir)) { $null = New-Item -ItemType Directory -Path $newDir -Force }
                    Move-Item -LiteralPath $oldOnDisk -Destination $newOnDisk -Force
                    Write-Verbose "Moved .lnk -> $newRel"
                }
                else {
                    Write-Warning "Physical .lnk for '$fileTok' not found - updating manifest only."
                }

                $null = $sc.SetAttribute('File', $newFileTok)
                $changed = $true
                Write-Verbose "Relocated '$fileTok' -> '$newFileTok'."
            }

            if ($changed) {
                $manifest.Save($manifestPath)
                Write-Verbose "Saved $manifestPath"
            }
            else {
                Write-Warning "No [{Common Programs}] shortcuts to relocate in '$folder'."
            }
        }
    }
}
