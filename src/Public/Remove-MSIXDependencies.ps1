function Remove-MSIXDependencies {
<#
.SYNOPSIS
    Removes PackageDependency entries from an MSIX manifest. TargetDeviceFamily
    is never touched.
.PARAMETER MSIXFolderPath
    Expanded MSIX package folder. Pipeline by property name.
.PARAMETER Name
    Name of the PackageDependency to remove; supports wildcards
    (e.g. 'Microsoft.WindowsAppRuntime*'). Omit to remove all.
.EXAMPLE
    Remove-MSIXDependencies -MSIXFolder $pkg -Name 'Microsoft.WindowsAppRuntime*'
.EXAMPLE
    Get-MSIXDependencies -MSIXFolder $pkg | Where-Object Name -like '*WindowsAppRuntime*' | Remove-MSIXDependencies
.NOTES
    Andreas Nick, 2026
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [Alias('MSIXFolder')]
        [System.IO.DirectoryInfo] $MSIXFolderPath,

        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('DependencyPackageName')]
        [string] $Name
    )

    begin {
        # Keyed by resolved folder path -> list of dependency names to remove (empty = all)
        $pending = @{}
    }

    process {
        $key = $MSIXFolderPath.FullName
        if (-not $pending.ContainsKey($key)) {
            $pending[$key] = [System.Collections.Generic.List[string]]::new()
        }
        if (-not [string]::IsNullOrEmpty($Name)) {
            $pending[$key].Add($Name)
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

            $dependenciesNode = $manifest.SelectSingleNode('//ns:Package/ns:Dependencies', $nsmgr)
            if ($null -eq $dependenciesNode) {
                Write-Warning "No <Dependencies> section in '$folder' - nothing to do."
                continue
            }

            $targetNames = $pending[$folder]   # empty list = remove all PackageDependency entries
            $removedAny  = $false

            foreach ($dep in @($dependenciesNode.SelectNodes('ns:PackageDependency', $nsmgr))) {
                $depName = $dep.GetAttribute('Name')

                if ($targetNames.Count -gt 0) {
                    # Match by wildcard so '-Name Microsoft.WindowsAppRuntime*' works; a literal
                    # name without wildcards still matches exactly.
                    $isTarget = $false
                    foreach ($pattern in $targetNames) {
                        if ($depName -like $pattern) { $isTarget = $true; break }
                    }
                    if (-not $isTarget) { continue }
                }

                if (-not $PSCmdlet.ShouldProcess($folder, "Remove PackageDependency '$depName'")) {
                    continue
                }

                $null = $dependenciesNode.RemoveChild($dep)
                $removedAny = $true
                Write-Verbose "Removed PackageDependency '$depName'."
            }

            if ($removedAny) {
                $manifest.Save($manifestPath)
                Write-Verbose "Saved $manifestPath"
            }
            else {
                Write-Warning "No matching PackageDependency found in '$folder'."
            }
        }
    }
}
