function Resolve-MSIXShortcutTokenPath {
<#
.SYNOPSIS
    Resolves a desktop7:Shortcut File/Icon token to a package-relative path.
.DESCRIPTION
    Maps "[{Common Programs}]\Sub\App.lnk" to "VFS\Common Programs\Sub\App.lnk"
    using the module-wide $ShortcutLocationTokens table. Returns $null for an
    unknown token.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $TokenPath
    )

    if ([string]::IsNullOrEmpty($TokenPath)) { return $null }
    foreach ($tok in $ShortcutLocationTokens.Keys) {
        if ($TokenPath.StartsWith($tok)) {
            $rest = $TokenPath.Substring($tok.Length).TrimStart('\')
            $base = $ShortcutLocationTokens[$tok]
            if ($base) { return (Join-Path $base $rest) } else { return $rest }
        }
    }
    return $null
}

function Resolve-MSIXShortcutOnDiskPath {
<#
.SYNOPSIS
    Returns the on-disk path for a package-relative path, or $null if absent.
.DESCRIPTION
    MakeAppx unpack (Open-MSIXPackage) decodes OPC names to spaces, but a raw ZIP
    extract keeps them %20-encoded. Tries the decoded form first, then the
    %20-encoded form, so either package layout resolves.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $FolderPath,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $Relative
    )

    if ([string]::IsNullOrEmpty($Relative)) { return $null }
    $decoded = Join-Path $FolderPath $Relative
    if (Test-Path $decoded) { return $decoded }
    $encoded = Join-Path $FolderPath ($Relative -replace ' ', '%20')
    if (Test-Path $encoded) { return $encoded }
    return $null
}
