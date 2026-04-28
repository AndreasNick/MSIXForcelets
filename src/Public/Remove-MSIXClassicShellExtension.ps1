
function Remove-MSIXClassicShellExtension {
<#
.SYNOPSIS
    Removes classic COM-based shell extension declarations from AppxManifest.xml.

.DESCRIPTION
    Scans AppxManifest.xml in an expanded MSIX package folder and removes Extension
    elements whose Category matches one of the classic COM shell extension categories:

      windows.comServer                                   - COM server registration
      windows.fileExplorerContextMenus                    - desktop4/5 CLSID verb wiring
      windows.fileExplorerClassicContextMenuHandler       - desktop9 classic handler (references CLSID)
      windows.fileExplorerClassicDragDropContextMenuHandler - desktop9 drag-drop handler

    All four categories must be removed together. MakeAppx validates that every CLSID
    referenced in fileExplorerClassicContextMenuHandler has a matching windows.comServer
    registration in the same package. Removing comServer without removing the handlers
    leaves dangling CLSID references and causes a manifest validation error.

    Modern shell extension declarations are intentionally left untouched:

      windows.fileTypeAssociation - modern verb-based file type associations (uap3)

    Use this function after Import-MSIXSparseShellExtension when the COM-based classic
    context menu entries are visible in Explorer but do not execute correctly (because
    the MSIX sandbox prevents the COM surrogate from locating the host executable or
    accessing required registry keys outside the package's virtual hive).

    The modern file type association verbs (uap3) work without COM and continue to
    provide the right-click "Add to..." entry in the Windows 11 context menu.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain AppxManifest.xml).

.PARAMETER Categories
    One or more Extension Category values to remove.
    Defaults to 'windows.comServer' and 'windows.fileExplorerContextMenus'.
    Override to target a different set of categories.

.EXAMPLE
    Remove-MSIXClassicShellExtension -MSIXFolder "C:\MSIXTemp\WinRAR"

.EXAMPLE
    # Remove only the COM server registration, keep the context menu wiring
    Remove-MSIXClassicShellExtension -MSIXFolder "C:\MSIXTemp\WinRAR" `
        -Categories 'windows.comServer'

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [string[]] $Categories = @(
            'windows.comServer',
            'windows.fileExplorerContextMenus',
            'windows.fileExplorerClassicContextMenuHandler',
            'windows.fileExplorerClassicDragDropContextMenuHandler'
        )
    )

    process {
        $manifestPath = Join-Path $MSIXFolder 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "AppxManifest.xml not found in: $($MSIXFolder.FullName)"
            return
        }

        $manifest = New-Object xml
        $manifest.Load($manifestPath)

        $extensions = @($manifest.SelectNodes("//*[local-name()='Extension']"))
        $removed = 0

        foreach ($ext in $extensions) {
            $category = $ext.GetAttribute('Category')
            if ($Categories -notcontains $category) { continue }

            if ($PSCmdlet.ShouldProcess("Extension Category='$category'", 'Remove')) {
                $null = $ext.ParentNode.RemoveChild($ext)
                Write-Verbose "Removed Extension Category='$category'."
                $removed++
            }
        }

        if ($removed -eq 0) {
            Write-Verbose "No matching Extension elements found - nothing removed."
            return
        }

        # Remove Extensions container elements that have no element children left.
        # MakeAppx rejects an Extensions element that contains only whitespace text nodes.
        # Use XPath not(*) to match elements with no element children regardless of whitespace.
        $emptyExtensionsNodes = @($manifest.SelectNodes("//*[local-name()='Extensions' and not(*)]"))
        foreach ($node in $emptyExtensionsNodes) {
            $null = $node.ParentNode.RemoveChild($node)
            Write-Verbose "Removed empty Extensions element."
        }

        $manifest.PreserveWhitespace = $false
        $manifest.Save($manifestPath)
        Write-Verbose "Removed $removed Extension element(s) from AppxManifest.xml."
    }
}
