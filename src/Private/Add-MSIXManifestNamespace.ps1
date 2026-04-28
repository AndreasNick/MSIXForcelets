function Add-MSIXManifestNamespace {
<#
.SYNOPSIS
    Ensures namespace declarations are present on the AppxManifest root element.

.DESCRIPTION
    For each given prefix, checks whether xmlns:<prefix> is already declared on
    <Package>. Missing declarations are added using the URI from $AppXNamespaces.
    The prefix is also appended to IgnorableNamespaces when not yet listed.
    The foundation namespace prefix 'ns' is skipped (it is the default xmlns).

.PARAMETER Manifest
    The loaded AppxManifest.xml XmlDocument to update in place.

.PARAMETER Prefixes
    One or more namespace prefixes to ensure (e.g. 'uap6', 'rescap', 'desktop7').
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [xml] $Manifest,

        [Parameter(Mandatory = $true)]
        [string[]] $Prefixes
    )

    $root = $Manifest.DocumentElement

    foreach ($prefix in $Prefixes) {
        if ($prefix -eq 'ns') { continue }

        $uri = $AppXNamespaces[$prefix]
        if ($null -eq $uri) {
            Write-Warning "Unknown namespace prefix '$prefix' - not in AppXNamespaces."
            continue
        }

        if (-not $root.HasAttribute("xmlns:$prefix")) {
            $null = $root.SetAttribute("xmlns:$prefix", $uri)
            Write-Verbose "Added namespace: xmlns:$prefix"
        }

        if ($root.HasAttribute('IgnorableNamespaces')) {
            $current = $root.GetAttribute('IgnorableNamespaces')
            if ($current -notmatch "\b$([regex]::Escape($prefix))\b") {
                $null = $root.SetAttribute('IgnorableNamespaces', "$current $prefix")
                Write-Verbose "Added '$prefix' to IgnorableNamespaces."
            }
        }
        else {
            $null = $root.SetAttribute('IgnorableNamespaces', $prefix)
            Write-Verbose "Created IgnorableNamespaces with '$prefix'."
        }
    }
}
