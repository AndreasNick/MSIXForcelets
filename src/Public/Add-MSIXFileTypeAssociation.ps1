function Add-MSIXFileTypeAssociation {
<#
.SYNOPSIS
    Adds a windows.fileTypeAssociation (FTA) to an Application in an MSIX package.
.DESCRIPTION
    Creates a uap3:FileTypeAssociation under the target Application so double-clicking
    a registered file extension activates the packaged app. Required namespaces
    (uap, uap2, uap3 and uap7 for a default verb) are declared automatically.

    The cmdlet is additive and idempotent: calling it again with the same -Name
    appends missing file extensions and adds/updates the given verb (matched by
    -VerbId) instead of creating a duplicate block. One verb per call - run it again
    or pipe to add more verbs.
.PARAMETER MSIXFolderPath
    Expanded MSIX package folder. Pipeline by property name (e.g. from Get-MSIXApplications).
.PARAMETER AppId
    Target Application Id. Binds from Get-MSIXApplications (Id). Omit to auto-detect
    when the package has exactly one Application.
.PARAMETER Name
    FTA group name. Forced to lower case; must not contain whitespace (schema rule).
.PARAMETER FileType
    One or more file extensions (a leading dot is added if missing).
.PARAMETER VerbId
    Verb id (default 'open' - the verb invoked on a double-click).
.PARAMETER VerbParameters
    Verb parameters passed to the app (default '"%1"' - the selected file path).
.PARAMETER VerbDisplayName
    Context-menu display text for the verb (defaults to VerbId).
.PARAMETER ExtendedVerb
    Show the verb only with Shift held down (uap3:Verb Extended="true").
.PARAMETER DefaultVerb
    Mark the verb as the default (uap7:Default="true").
.PARAMETER Logo
    Package-relative path to a logo image (uap:Logo, e.g. Assets\ext.png).
.PARAMETER InfoTip
    Tooltip text for the file type (uap:InfoTip).
.PARAMETER MultiSelectModel
    Activation model for multi-file selection: Player, Document or Single.
.EXAMPLE
    Get-MSIXApplications -MSIXFolder $pkg |
        Where-Object { $_.Executable -like '*putty.exe' } |
        Add-MSIXFileTypeAssociation -Name putty -FileType .putty
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

        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Name,

        [Parameter(Mandatory = $true, Position = 2)]
        [string[]] $FileType,

        [string] $VerbId = 'open',
        [string] $VerbParameters = '"%1"',
        [string] $VerbDisplayName,
        [switch] $ExtendedVerb,
        [switch] $DefaultVerb,

        [string] $Logo,
        [string] $InfoTip,

        [ValidateSet('Player', 'Document', 'Single')]
        [string] $MultiSelectModel
    )

    process {
        # --- Validate / normalize inputs --------------------------------------------
        if ($Name -match '\s') {
            Write-Error "FileTypeAssociation Name '$Name' must not contain whitespace (schema rule)."
            return
        }
        $Name = $Name.ToLowerInvariant()
        if ($Name.Length -lt 1 -or $Name.Length -gt 64) {
            Write-Error "FileTypeAssociation Name must be 1-64 characters."
            return
        }

        $normFileTypes = @()
        foreach ($ext in $FileType) {
            $e = $ext.Trim()
            if (-not $e.StartsWith('.')) { $e = ".$e" }
            $normFileTypes += $e.ToLowerInvariant()
        }

        $manifestPath = Join-Path $MSIXFolderPath 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "AppxManifest.xml not found in: $($MSIXFolderPath.FullName)"
            return
        }

        $manifest = New-Object System.Xml.XmlDocument
        $manifest.Load($manifestPath)

        # Ensure namespaces before building the namespace manager.
        $prefixes = @('uap', 'uap2', 'uap3')
        if ($DefaultVerb) { $prefixes += 'uap7' }
        Add-MSIXManifestNamespace -Manifest $manifest -Prefixes $prefixes

        $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
        $AppXNamespaces.GetEnumerator() | ForEach-Object { $null = $nsmgr.AddNamespace($_.Key, $_.Value) }

        $uapUri  = $AppXNamespaces['uap']
        $uap2Uri = $AppXNamespaces['uap2']
        $uap3Uri = $AppXNamespaces['uap3']
        $uap7Uri = $AppXNamespaces['uap7']

        # --- Resolve target Application ---------------------------------------------
        if ($AppId) {
            $app = $manifest.SelectSingleNode("//ns:Package/ns:Applications/ns:Application[@Id='$AppId']", $nsmgr)
            if ($null -eq $app) {
                Write-Error "Application '$AppId' not found in AppxManifest.xml."
                return
            }
        }
        else {
            $apps = @($manifest.SelectNodes('//ns:Package/ns:Applications/ns:Application', $nsmgr))
            if ($apps.Count -eq 0) {
                Write-Error "No Application found in AppxManifest.xml."
                return
            }
            if ($apps.Count -gt 1) {
                $ids = ($apps | ForEach-Object { $_.GetAttribute('Id') }) -join ', '
                Write-Error "Multiple Applications found ($ids). Specify -AppId."
                return
            }
            $app   = $apps[0]
            $AppId = $app.GetAttribute('Id')
        }

        if (-not $PSCmdlet.ShouldProcess($AppId, "Add file type association '$Name' ($($normFileTypes -join ', '))")) {
            return
        }

        # --- Ensure Extensions node -------------------------------------------------
        $extensionsNode = $app.SelectSingleNode('ns:Extensions', $nsmgr)
        if ($null -eq $extensionsNode) {
            $extensionsNode = $manifest.CreateElement('Extensions', $AppXNamespaces['ns'])
            $null = $app.AppendChild($extensionsNode)
        }

        # --- Find existing FTA for this Name (merge) or create a new block ----------
        $ftaNode = $app.SelectSingleNode("ns:Extensions/uap3:Extension[@Category='windows.fileTypeAssociation']/uap3:FileTypeAssociation[@Name='$Name']", $nsmgr)

        if ($null -eq $ftaNode) {
            $extNode = $manifest.CreateElement('uap3:Extension', $uap3Uri)
            $null = $extNode.SetAttribute('Category', 'windows.fileTypeAssociation')

            $ftaNode = $manifest.CreateElement('uap3:FileTypeAssociation', $uap3Uri)
            $null = $ftaNode.SetAttribute('Name', $Name)
            if ($MultiSelectModel) { $null = $ftaNode.SetAttribute('MultiSelectModel', $MultiSelectModel) }

            # Child order per schema: Logo, InfoTip, SupportedFileTypes, SupportedVerbs.
            if ($Logo) {
                $logoEl = $manifest.CreateElement('uap:Logo', $uapUri)
                $logoEl.InnerText = $Logo
                $null = $ftaNode.AppendChild($logoEl)
            }
            if ($InfoTip) {
                $itEl = $manifest.CreateElement('uap:InfoTip', $uapUri)
                $itEl.InnerText = $InfoTip
                $null = $ftaNode.AppendChild($itEl)
            }

            $sftEl = $manifest.CreateElement('uap:SupportedFileTypes', $uapUri)
            $null = $ftaNode.AppendChild($sftEl)

            $null = $extNode.AppendChild($ftaNode)
            $null = $extensionsNode.AppendChild($extNode)
            Write-Verbose "Created FTA '$Name' on Application '$AppId'."
        }
        else {
            if ($MultiSelectModel) { $null = $ftaNode.SetAttribute('MultiSelectModel', $MultiSelectModel) }
            Write-Verbose "Merging into existing FTA '$Name' on Application '$AppId'."
        }

        # --- Ensure file extensions -------------------------------------------------
        $sftEl = $ftaNode.SelectSingleNode('uap:SupportedFileTypes', $nsmgr)
        if ($null -eq $sftEl) {
            $sftEl = $manifest.CreateElement('uap:SupportedFileTypes', $uapUri)
            $null = $ftaNode.AppendChild($sftEl)
        }
        foreach ($e in $normFileTypes) {
            $exists = $false
            foreach ($ft in $sftEl.SelectNodes('uap:FileType', $nsmgr)) {
                if ($ft.InnerText -eq $e) { $exists = $true; break }
            }
            if (-not $exists) {
                $ftEl = $manifest.CreateElement('uap:FileType', $uapUri)
                $ftEl.InnerText = $e
                $null = $sftEl.AppendChild($ftEl)
            }
        }

        # --- Ensure the verb --------------------------------------------------------
        $svEl = $ftaNode.SelectSingleNode('uap2:SupportedVerbs', $nsmgr)
        if ($null -eq $svEl) {
            $svEl = $manifest.CreateElement('uap2:SupportedVerbs', $uap2Uri)
            $null = $ftaNode.AppendChild($svEl)
        }

        $verbEl = $svEl.SelectSingleNode("uap3:Verb[@Id='$VerbId']", $nsmgr)
        if ($null -eq $verbEl) {
            $verbEl = $manifest.CreateElement('uap3:Verb', $uap3Uri)
            $null = $verbEl.SetAttribute('Id', $VerbId)
            $null = $svEl.AppendChild($verbEl)
        }
        if ($VerbParameters) { $null = $verbEl.SetAttribute('Parameters', $VerbParameters) }
        if ($ExtendedVerb)   { $null = $verbEl.SetAttribute('Extended', 'true') }
        if ($DefaultVerb)    { $null = $verbEl.SetAttribute('Default', $uap7Uri, 'true') }
        $verbEl.InnerText = if ($VerbDisplayName) { $VerbDisplayName } else { $VerbId }

        $manifest.Save($manifestPath)
        Write-Verbose "Saved $manifestPath"
    }
}
