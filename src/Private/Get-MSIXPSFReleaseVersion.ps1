function Get-MSIXPSFReleaseVersion {
<#
.SYNOPSIS
    Returns a sortable [version] for a PSF release folder name ('2026.05.01_release', '2026-2-22_release', '1.0.240212.1').
.NOTES
    Release folders are named after the release tag, whose format varies. Comparing the names as
    strings is culture-sensitive and differs between Windows PowerShell 5.1 and PowerShell 7
    (5.1 ignores the '-'), so the newest release must be determined by version.
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    # 'TimManganPSF\2026-2-22_release' -> '2026-2-22' -> '2026.2.22'
    $leaf = ($Name -split '\\')[-1]
    $text = (($leaf -split '_')[0]) -replace '-', '.'
    $version = $null
    if ([version]::TryParse($text, [ref]$version)) {
        return $version
    }
    return [version]'0.0'
}
