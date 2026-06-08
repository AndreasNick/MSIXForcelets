function Remove-MSIXPackageIntegrity {
<#
.SYNOPSIS
    Disables MSIX package content integrity enforcement.
.DESCRIPTION
    Removes the uap10:PackageIntegrity element from AppxManifest.xml and deletes
    the AppxMetadata\CodeIntegrity.cat catalog. Mandatory after modifying and
    re-signing a third-party package.
.PARAMETER MSIXFolderPath
    Expanded MSIX package folder containing AppxManifest.xml. Pipeline by property name.
.EXAMPLE
    Remove-MSIXPackageIntegrity -MSIXFolderPath $MSIXFolder
.NOTES
    Andreas Nick, 2026 - https://www.nick-it.de
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolderPath
    )

    process {
        $manifestPath = Join-Path $MSIXFolderPath 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Warning "AppxManifest.xml not found in '$MSIXFolderPath' - skipping."
            return
        }

        if ($PSCmdlet.ShouldProcess($manifestPath, 'Remove PackageIntegrity / CodeIntegrity.cat')) {
            $manifest = New-Object System.Xml.XmlDocument
            $manifest.Load($manifestPath)

            $integrity = $manifest.SelectSingleNode("//*[local-name()='PackageIntegrity']")
            if ($null -ne $integrity) {
                $null = $integrity.ParentNode.RemoveChild($integrity)
                $manifest.Save($manifestPath)
                Write-Verbose 'Removed uap10:PackageIntegrity from AppxManifest.xml.'
            }
            else {
                Write-Verbose 'No PackageIntegrity element present.'
            }

            $catalog = Join-Path $MSIXFolderPath 'AppxMetadata\CodeIntegrity.cat'
            if (Test-Path $catalog) {
                Remove-Item $catalog -Force
                Write-Verbose 'Deleted AppxMetadata\CodeIntegrity.cat.'
            }
        }
    }
}
