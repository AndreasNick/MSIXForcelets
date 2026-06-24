function Set-MSIXApplicationIcon {
<#
.SYNOPSIS
    Regenerates an application's icon assets (incl. unplated target sizes) and wires them in.
.DESCRIPTION
    Convenience wrapper around New-MSIXAssetFrom (-IncludeUnplatedTargetSizes) and
    Set-MSIXApplicationVisualElements. Fixes boxed/plated Start-menu and taskbar icons by
    producing transparent assets - including Square44x44Logo.targetsize-*_altform-unplated -
    and pointing the application's VisualElements at them with a transparent BackgroundColor.

    Works for one app (-AppId / pipeline from Get-MSIXApplications) or all apps when -AppId is
    omitted. The icon source defaults to each application's own executable. Rebuild the resource
    index afterwards so the new assets are used: Close-MSIXPackage -RegenerateResource.
.PARAMETER SourcePath
    Icon source (.exe / .dll / .ico / .png / ...). Defaults to the application's own executable.
.PARAMETER AssetId
    Asset filename prefix. Defaults to the application Id.
.EXAMPLE
    Get-MSIXApplications -MSIXFolder $pkg | Set-MSIXApplicationIcon
    Close-MSIXPackage -MSIXFolder $pkg -MSIXFile $out -Force -RegenerateResource
.NOTES
    Andreas Nick, 2026
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [Alias('MSIXFolder')]
        [System.IO.DirectoryInfo] $MSIXFolderPath,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string] $AppId,

        [System.IO.FileInfo] $SourcePath,

        [string] $AssetId,

        [string] $BackgroundColor = 'transparent',

        [switch] $SetAsPackageLogo
    )

    process {
        $allApps = Get-MSIXApplications -MSIXFolder $MSIXFolderPath
        $targets = if ($AppId) { @($allApps | Where-Object { $_.Id -eq $AppId }) } else { @($allApps) }

        if ($targets.Count -eq 0) {
            Write-Warning "No matching Application found$(if ($AppId) { " for AppId '$AppId'" })."
            return
        }

        foreach ($app in $targets) {
            if (-not $PSCmdlet.ShouldProcess($app.Id, 'Regenerate and set application icon')) { continue }

            $src = if ($PSBoundParameters.ContainsKey('SourcePath')) { $SourcePath } else { Join-Path $MSIXFolderPath.FullName $app.Executable }
            $aid = if ($PSBoundParameters.ContainsKey('AssetId'))    { $AssetId }    else { $app.Id }

            $genArgs = @{
                MSIXFolder                 = $MSIXFolderPath
                SourcePath                 = $src
                AssetId                    = $aid
                IncludeUnplatedTargetSizes = $true
            }
            if ($SetAsPackageLogo) { $genArgs.SetAsPackageLogo = $true }

            $res = New-MSIXAssetFrom @genArgs
            if ($null -eq $res) {
                Write-Warning "Asset generation failed for '$($app.Id)' (source '$src')."
                continue
            }

            Set-MSIXApplicationVisualElements -MSIXFolderPath $MSIXFolderPath -Id $app.Id `
                -AssetId $res.AssetId -BackgroundColor $BackgroundColor
            Write-Verbose "Set icon for '$($app.Id)' from '$src' (AssetId '$($res.AssetId)')."
        }
    }
}
