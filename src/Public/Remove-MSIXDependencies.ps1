function Remove-MSIXDependencies {
<#
.SYNOPSIS
    Removes PackageDependency entries from an expanded MSIX package's manifest.

.DESCRIPTION
    Removes <PackageDependency> elements from the <Dependencies> section of
    AppxManifest.xml. The mandatory <TargetDeviceFamily> entry is never touched.

    Useful to strip framework dependencies that an MSIX Packaging Tool capture
    added but that the app does not actually require (e.g. a
    Microsoft.WindowsAppRuntime.* reference that prevents every app from
    launching when that runtime is absent on the target).

    Accepts pipeline input from Get-MSIXDependencies. The manifest is saved once
    per folder after all pipeline objects are processed.

    Caution: removing a dependency the app really needs will break it at
    runtime. Verify against the app's requirements before stripping.

.PARAMETER MSIXFolderPath
    Path to the expanded MSIX package folder containing AppxManifest.xml.
    Accepts pipeline input by property name (supplied by Get-MSIXDependencies).

.PARAMETER Name
    Name of a specific PackageDependency to remove. Accepted from the pipeline.
    When omitted, ALL <PackageDependency> entries in the folder are removed
    (TargetDeviceFamily always stays).

.EXAMPLE
    Get-MSIXDependencies -MSIXFolder $pkg |
        Where-Object Name -like 'Microsoft.WindowsAppRuntime*' |
        Remove-MSIXDependencies

    Removes only the WindowsAppRuntime framework dependency.

.EXAMPLE
    Remove-MSIXDependencies -MSIXFolderPath $pkg -Name 'Microsoft.WindowsAppRuntime.1.4'

    Removes a single named dependency directly.

.EXAMPLE
    Get-MSIXDependencies -MSIXFolder $pkg | Remove-MSIXDependencies -WhatIf

    Shows what would be removed without modifying the manifest.

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolderPath,

        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1)]
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
            $null = $nsmgr.AddNamespace('default', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')

            $dependenciesNode = $manifest.SelectSingleNode('//default:Package/default:Dependencies', $nsmgr)
            if ($null -eq $dependenciesNode) {
                Write-Warning "No <Dependencies> section in '$folder' - nothing to do."
                continue
            }

            $targetNames = $pending[$folder]   # empty list = remove all PackageDependency entries
            $removedAny  = $false

            foreach ($dep in @($dependenciesNode.SelectNodes('default:PackageDependency', $nsmgr))) {
                $depName = $dep.GetAttribute('Name')

                if ($targetNames.Count -gt 0 -and $targetNames -notcontains $depName) {
                    continue
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
