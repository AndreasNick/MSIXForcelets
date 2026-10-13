function Get-MSIXLegacyToolingSource {
<#
.SYNOPSIS
    Returns the newest older side-by-side module version folder that still holds downloaded tooling.

.DESCRIPTION
    Up to version 1.0.5 the tooling (MSIXPSF, Libs\MSIXPackaging, Libs\MSIXCore) was downloaded
    into the module's own version folder. Update-Module installs a new version next to the old one,
    so the old folder is the source for Copy-MSIXTooling. Returns $null when nothing is found.
#>
    [CmdletBinding()]
    [OutputType([System.IO.DirectoryInfo])]
    param()

    $current     = $Script:ScriptPath
    $versionRoot = Split-Path $current -Parent

    Get-ChildItem -Path $versionRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne $current -and ($_.Name -as [version]) } |
        Sort-Object { [version]$_.Name } -Descending |
        Where-Object {
            $dir = $_.FullName
            $Script:ToolingFolders | Where-Object { Test-Path (Join-Path $dir $_) }
        } |
        Select-Object -First 1
}
