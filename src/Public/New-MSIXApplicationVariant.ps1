
function New-MSIXApplicationVariant {
<#
.SYNOPSIS
    Clones an Application entry in AppxManifest.xml under a new Id.

.DESCRIPTION
    Creates a deep copy of an existing Application element and inserts it into the
    Applications section with a new @Id. Optionally overrides the Executable
    attribute and the AppListEntry visibility on the cloned entry.

    Use this to create a second launcher variant for the same executable that
    requires different command-line arguments. After cloning, call
    Add-MSIXPSFShim on the new Id to wire it through a dedicated PSF launcher
    with the desired -Arguments value.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain AppxManifest.xml).

.PARAMETER SourceAppId
    @Id of the Application entry to clone.

.PARAMETER NewAppId
    @Id to assign to the cloned Application entry. Must be unique within the manifest.

.PARAMETER Executable
    Optional. Overrides the Executable attribute on the cloned entry.
    Useful when the variant should launch a different binary.

.PARAMETER AppListEntry
    Optional. Sets the AppListEntry attribute on the cloned uap:VisualElements element.
    Accepted values: 'default', 'none'.
    Use 'none' to hide the variant from the Start menu (typical for argument-only variants).

.PARAMETER DisplayName
    Optional. Sets the DisplayName on the cloned uap:VisualElements (the Start-menu name).
    The variant reuses the source app's existing logo assets - no new assets are generated.

.PARAMETER WithoutExtensions
    Optional switch. Removes the cloned <Extensions> (file type associations, protocols,
    shortcuts, aliases) from the variant. Use this for a pure launcher variant so it does not
    duplicate / conflict with the source app's registrations.

.EXAMPLE
    # Create a hidden WinRAR variant for silent operation, then wire it through PSF
    New-MSIXApplicationVariant -MSIXFolder "C:\MSIXTemp\WinRAR" `
        -SourceAppId "WinRAR" -NewAppId "WinRAR_Silent" -AppListEntry none

    Add-MSIXPSFShim -MSIXFolder "C:\MSIXTemp\WinRAR" `
        -MSIXAppID "WinRAR_Silent" -Arguments "-s" -PSFArchitektur x64

.OUTPUTS
    System.String
    The new Application Id ($NewAppId) on success.

.NOTES
    The cloned entry inherits all child elements (Extensions, VisualElements, etc.)
    from the source. Review the manifest after cloning to remove or adjust
    child elements that should not be duplicated (e.g. execution aliases).
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [Parameter(Mandatory = $true, Position = 1)]
        [String] $SourceAppId,

        [Parameter(Mandatory = $true, Position = 2)]
        [String] $NewAppId,

        [String] $Executable = '',

        [ValidateSet('default', 'none')]
        [String] $AppListEntry = '',

        [String] $DisplayName = '',

        [Alias('NoExtensions')]
        [switch] $WithoutExtensions
    )

    $manifestPath = Join-Path $MSIXFolder 'AppxManifest.xml'
    if (-not (Test-Path $manifestPath)) {
        Write-Error "AppxManifest.xml not found in: $($MSIXFolder.FullName)"
        return
    }

    $manifest = New-Object xml
    $nsmgr = New-Object System.Xml.XmlNamespaceManager $manifest.NameTable
    $AppXNamespaces.GetEnumerator() | ForEach-Object {
        $nsmgr.AddNamespace($_.Key, $_.Value)
    }
    $manifest.Load($manifestPath)

    $sourceApp = $manifest.SelectSingleNode(
        "//ns:Package/ns:Applications/ns:Application[@Id='$SourceAppId']", $nsmgr)
    if ($null -eq $sourceApp) {
        Write-Error "Application '$SourceAppId' not found in AppxManifest.xml."
        return
    }

    $conflict = $manifest.SelectSingleNode(
        "//ns:Package/ns:Applications/ns:Application[@Id='$NewAppId']", $nsmgr)
    if ($null -ne $conflict) {
        Write-Error "Application '$NewAppId' already exists in AppxManifest.xml."
        return
    }

    $clone = $sourceApp.CloneNode($true)
    $null = $clone.SetAttribute('Id', $NewAppId)

    if ($Executable -ne '') {
        $null = $clone.SetAttribute('Executable', $Executable)
    }

    if ($AppListEntry -ne '') {
        $veNode = $clone.SelectSingleNode('uap:VisualElements', $nsmgr)
        if ($null -ne $veNode) {
            $null = $veNode.SetAttribute('AppListEntry', $AppListEntry)
        }
        else {
            Write-Warning "uap:VisualElements not found on cloned Application '$NewAppId' — AppListEntry not set."
        }
    }

    if ($DisplayName -ne '') {
        $veNode = $clone.SelectSingleNode('uap:VisualElements', $nsmgr)
        if ($null -ne $veNode) {
            $null = $veNode.SetAttribute('DisplayName', $DisplayName)
        }
        else {
            Write-Warning "uap:VisualElements not found on cloned Application '$NewAppId' — DisplayName not set."
        }
    }

    if ($WithoutExtensions) {
        # A launcher variant should not re-register the source app's FTAs / protocols / shortcuts -
        # that would duplicate them and conflict with the source app. Drop the cloned Extensions.
        $extNodes = @($clone.SelectNodes("*[local-name()='Extensions']"))
        foreach ($x in $extNodes) { $null = $clone.RemoveChild($x) }
        if ($extNodes.Count -gt 0) {
            Write-Verbose "Removed $($extNodes.Count) Extensions node(s) from variant '$NewAppId'."
        }
    }

    $applicationsNode = $manifest.SelectSingleNode("//ns:Package/ns:Applications", $nsmgr)
    $null = $applicationsNode.AppendChild($clone)

    $manifest.PreserveWhitespace = $false
    $manifest.Save($manifestPath)

    Write-Verbose "Application '$SourceAppId' cloned as '$NewAppId'."
    Write-Output $NewAppId
}
