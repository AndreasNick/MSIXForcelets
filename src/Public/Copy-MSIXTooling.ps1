function Copy-MSIXTooling {
<#
.SYNOPSIS
    Copies the downloaded tooling from an older module version into the module-root Tooling folder.

.DESCRIPTION
    The tooling (PSF builds, Windows SDK packaging tools, MSIX Core) is kept in the module root next
    to the version folders (...\Modules\MSIXForcelets\Tooling), so it survives Update-Module. Up to
    version 1.0.5 it was downloaded into the version folder itself; after Update-Module this cmdlet
    takes it over instead of downloading it again. An AllUsers installation (under Program Files)
    needs an elevated PowerShell. Without -SourcePath the newest older side-by-side version is used.
    The old version is left untouched - remove it afterwards with Uninstall-Module.

.EXAMPLE
    Copy-MSIXTooling -Verbose
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [System.IO.DirectoryInfo] $SourcePath
    )

    if (-not $SourcePath) {
        $SourcePath = Get-MSIXLegacyToolingSource
        if (-not $SourcePath) {
            Write-Error ("No older MSIXForcelets version with tooling found next to '$($Script:ScriptPath)'. " +
                "Pass -SourcePath or download the tooling with Install-MSIXForceletsAllRequirements.")
            return
        }
    }
    if (-not (Test-Path $SourcePath.FullName -PathType Container)) {
        Write-Error "Source folder not found: $($SourcePath.FullName)"
        return
    }
    if ($SourcePath.FullName.TrimEnd('\') -eq $Script:ToolingPath.TrimEnd('\')) {
        Write-Warning "Source and tooling folder are the same ($($Script:ToolingPath)) - nothing to copy."
        return
    }

    Assert-MSIXToolingWritable

    $copied = @()
    foreach ($folder in $Script:ToolingFolders) {
        $src = Join-Path $SourcePath.FullName $folder
        if (-not (Test-Path $src)) { continue }
        $dst = Join-Path $Script:ToolingPath $folder
        if ($PSCmdlet.ShouldProcess($dst, "Copy tooling from $src")) {
            New-Item -ItemType Directory -Path $dst -Force | Out-Null
            Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force -ErrorAction Stop
            Write-Verbose "Copied $folder -> $dst"
            $copied += $folder
        }
    }

    if ($copied.Count -gt 0) {
        $currentVersion = $MyInvocation.MyCommand.Module.Version
        Write-Warning ("Tooling copied to $($Script:ToolingPath). Reload the module with 'Import-Module MSIXForcelets -Force'. " +
            "Old versions can now be removed: Get-InstalledModule MSIXForcelets -AllVersions | " +
            "Where-Object Version -ne '$currentVersion' | Uninstall-Module")

        [PSCustomObject]@{
            Source      = $SourcePath.FullName
            Destination = $Script:ToolingPath
            Folders     = $copied
        }
    }
}
