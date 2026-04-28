
function Convert-MSIXClassicContextMenuToVerbs {
<#
.SYNOPSIS
    Converts classic COM-based context menu verbs to modern executable-based uap3 verbs.

.DESCRIPTION
    Adds verb entries to every windows.fileTypeAssociation extension in
    AppxManifest.xml. Each verb directly invokes the package application with the given
    command-line parameters - no COM server required.

    Use this as an alternative to COM-based shell extensions (windows.comServer +
    windows.fileExplorerContextMenus with Clsid verbs) when the COM surrogate cannot
    reach the host executable at runtime inside the MSIX container.

    Limitations compared to COM-based verbs:
      - Verb display text is static. Dynamic names like "Add to 'foldername.rar'" are
        not possible; use a fixed label such as "Add to archive (WinRAR)" instead.
      - Custom icons per verb are not supported (the application icon is used).
      - Only a single selected file is passed via %1 by default (see MultiSelectModel).

    The modern verbs appear in both the Windows 11 context menu (modern panel) and the
    classic context menu (via "Show more options"). They work without a COM registration
    and without a surrogate process.

    By default, windows.comServer and windows.fileExplorerContextMenus extensions are
    removed after adding the verbs, which eliminates the broken classic entries that
    appear but do not execute. Pass -KeepClassicExtensions to retain them alongside
    the new verbs.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain AppxManifest.xml).

.PARAMETER VerbMappings
    Array of hashtables, each describing one verb to add. Required keys:
      Text       - Display text shown in the context menu.
      Parameters - Command-line arguments passed to the application. Use %1 as a
                   placeholder for the selected file path (quoted by the Shell).
    Optional keys:
      Id              - Verb identifier (letters and digits only, max 30 chars).
                        Auto-derived from Text if omitted.
      MultiSelectModel - 'Single' (default), 'Player', or 'Document'.

.PARAMETER KeepClassicExtensions
    When set, keeps windows.comServer and windows.fileExplorerContextMenus extensions
    after adding the new verbs. By default they are removed.

.EXAMPLE
    # WinRAR: replace COM-based verbs with simple executable verbs
    Convert-MSIXClassicContextMenuToVerbs -MSIXFolder "C:\MSIXTemp\WinRAR" `
        -VerbMappings @(
            @{ Text = 'Add to archive (WinRAR)';       Parameters = 'a "%1"'  },
            @{ Text = 'Extract here';                   Parameters = 'x "%1"'  },
            @{ Text = 'Extract to folder';              Parameters = 'e "%1"'  }
        )

.EXAMPLE
    # Keep the classic entries for comparison (do not remove them)
    Convert-MSIXClassicContextMenuToVerbs -MSIXFolder "C:\MSIXTemp\WinRAR" `
        -VerbMappings @(
            @{ Text = 'Add to archive (WinRAR)'; Parameters = 'a "%1"' }
        ) `
        -KeepClassicExtensions

.NOTES
    https://www.nick-it.de

#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [Parameter(Mandatory = $true)]
        [hashtable[]] $VerbMappings,

        # When set, keeps windows.comServer and windows.fileExplorerContextMenus after adding verbs.
    [switch] $KeepClassicExtensions
    )

    process {
        $manifestPath = Join-Path $MSIXFolder 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "AppxManifest.xml not found in: $($MSIXFolder.FullName)"
            return
        }

        $manifest = New-Object xml
        $manifest.Load($manifestPath)

        $nsBase = 'http://schemas.microsoft.com/appx/manifest/foundation/windows10'
        $nsUap2 = 'http://schemas.microsoft.com/appx/manifest/uap/windows10/2'
        $nsUap3 = 'http://schemas.microsoft.com/appx/manifest/uap/windows10/3'

        $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
        $nsmgr.AddNamespace('ns',   $nsBase)
        $nsmgr.AddNamespace('uap2', $nsUap2)
        $nsmgr.AddNamespace('uap3', $nsUap3)

        Add-MSIXManifestNamespace -Manifest $manifest -Prefixes 'uap3'

        # Validate and normalise verb mappings
        $verbs = foreach ($map in $VerbMappings) {
            if (-not $map.ContainsKey('Text') -or -not $map.ContainsKey('Parameters')) {
                Write-Warning "VerbMapping is missing 'Text' or 'Parameters' key - skipped."
                continue
            }
            $id = if ($map.ContainsKey('Id') -and $map['Id'] -ne '') {
                $map['Id']
            }
            else {
                # Auto-derive Id: keep only letters and digits, max 30 chars
                ($map['Text'] -replace '[^A-Za-z0-9]', '') -replace '^(.{1,30}).*$', '$1'
            }
            $multiSelect = if ($map.ContainsKey('MultiSelectModel')) { $map['MultiSelectModel'] } else { 'Single' }
            [PSCustomObject]@{ Id = $id; Text = $map['Text']; Parameters = $map['Parameters']; MultiSelectModel = $multiSelect }
        }

        if ($verbs.Count -eq 0) {
            Write-Warning "No valid VerbMappings provided - nothing added."
            return
        }

        # Find all FileTypeAssociation elements
        $ftaNodes = @($manifest.SelectNodes(
            "//uap3:Extension[@Category='windows.fileTypeAssociation']/uap3:FileTypeAssociation",
            $nsmgr))

        if ($ftaNodes.Count -eq 0) {
            Write-Warning "No windows.fileTypeAssociation extensions found in AppxManifest.xml."
            return
        }

        $changed = $false
        foreach ($fta in $ftaNodes) {
            $ftaName = $fta.GetAttribute('Name')

            # Remove any uap3:SupportedVerbs that may have been added by a previous run
            # (that element is not valid in manifests with MinVersion < 10.0.22000.0).
            $uap3Sv = $fta.SelectSingleNode('uap3:SupportedVerbs', $nsmgr)
            if ($null -ne $uap3Sv) {
                $null = $fta.RemoveChild($uap3Sv)
                Write-Verbose "Removed uap3:SupportedVerbs from FileTypeAssociation '$ftaName'."
            }

            # Reuse the existing uap2:SupportedVerbs if present (MSIX PT writes this);
            # create one only when the FTA has no verb container at all.
            $verbsNode = $fta.SelectSingleNode('uap2:SupportedVerbs', $nsmgr)
            if ($null -eq $verbsNode) {
                $verbsNode = $manifest.CreateElement('uap2:SupportedVerbs', $nsUap2)
                $null = $fta.AppendChild($verbsNode)
                Write-Verbose "Created uap2:SupportedVerbs in FileTypeAssociation '$ftaName'."
            }

            # Remove any of our custom verbs from previous runs (idempotency).
            $verbIds = foreach ($v in $verbs) { $v.Id }
            foreach ($existingVerb in @($verbsNode.SelectNodes('uap3:Verb', $nsmgr))) {
                if ($verbIds -contains $existingVerb.GetAttribute('Id')) {
                    $null = $verbsNode.RemoveChild($existingVerb)
                }
            }

            if (-not $PSCmdlet.ShouldProcess("FileTypeAssociation '$ftaName'", 'Add verbs to SupportedVerbs')) {
                continue
            }

            foreach ($verb in $verbs) {
                $verbEl = $manifest.CreateElement('uap3:Verb', $nsUap3)
                $null = $verbEl.SetAttribute('Id',               $verb.Id)
                $null = $verbEl.SetAttribute('Parameters',       $verb.Parameters)
                $null = $verbEl.SetAttribute('MultiSelectModel', $verb.MultiSelectModel)
                $verbEl.InnerText = $verb.Text
                $null = $verbsNode.AppendChild($verbEl)
                Write-Verbose "Added verb '$($verb.Id)' to FileTypeAssociation '$ftaName'."
            }

            $changed = $true
        }

        if (-not $changed) { return }

        if (-not $KeepClassicExtensions) {
            $classicCategories = @(
                'windows.comServer',
                'windows.fileExplorerContextMenus',
                'windows.fileExplorerClassicContextMenuHandler',
                'windows.fileExplorerClassicDragDropContextMenuHandler'
            )
            foreach ($ext in @($manifest.SelectNodes("//*[local-name()='Extension']"))) {
                if ($classicCategories -contains $ext.GetAttribute('Category')) {
                    $null = $ext.ParentNode.RemoveChild($ext)
                    Write-Verbose "Removed classic Extension Category='$($ext.GetAttribute('Category'))'."
                }
            }

            # Remove Extensions container elements left empty by the removals above.
            # Use not(*) to match elements with no element children regardless of whitespace.
            $emptyExtensionsNodes = @($manifest.SelectNodes("//*[local-name()='Extensions' and not(*)]"))
            foreach ($node in $emptyExtensionsNodes) {
                $null = $node.ParentNode.RemoveChild($node)
                Write-Verbose "Removed empty Extensions element."
            }
        }

        $manifest.PreserveWhitespace = $false
        $manifest.Save($manifestPath)
    }
}
