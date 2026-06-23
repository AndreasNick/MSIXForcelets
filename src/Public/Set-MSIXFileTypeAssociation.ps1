function Set-MSIXFileTypeAssociation {
<#
.SYNOPSIS
    Updates an existing windows.fileTypeAssociation (FTA) in an MSIX package.
.DESCRIPTION
    Modifies an FTA that already exists (use Add-MSIXFileTypeAssociation to create one).
    -FileType REPLACES the registered extension list; -Logo/-InfoTip/-MultiSelectModel
    update those attributes; the verb parameters add or update the verb matched by -VerbId.
    Accepts FTA objects from Get-MSIXFileTypeAssociation via the pipeline.
.PARAMETER MSIXFolderPath
    Expanded MSIX package folder. Pipeline by property name.
.PARAMETER AppId
    Application Id. Binds from Get-MSIXApplications (Id) or Get-MSIXFileTypeAssociation (ApplicationId).
.PARAMETER Name
    Name of the FTA to update.
.PARAMETER FileType
    Replacement extension list (a leading dot is added if missing).
.PARAMETER VerbId
    Verb to add or update.
.PARAMETER VerbParameters
    Verb parameters.
.PARAMETER VerbDisplayName
    Context-menu display text for the verb.
.PARAMETER ExtendedVerb
    Show the verb only with Shift held down.
.PARAMETER DefaultVerb
    Mark the verb as the default (uap7:Default).
.PARAMETER Logo
    Package-relative path to a logo image (uap:Logo).
.PARAMETER InfoTip
    Tooltip text (uap:InfoTip).
.PARAMETER MultiSelectModel
    Activation model for multi-file selection: Player, Document or Single.
.EXAMPLE
    Get-MSIXFileTypeAssociation -MSIXFolder $pkg -Name putty | Set-MSIXFileTypeAssociation -Logo 'Assets\putty.png'
.NOTES
    Andreas Nick, 2026
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [Alias('MSIXFolder')]
        [System.IO.DirectoryInfo] $MSIXFolderPath,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id', 'ApplicationId')]
        [string] $AppId,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [string] $Name,

        [string[]] $FileType,

        [string] $VerbId,
        [string] $VerbParameters,
        [string] $VerbDisplayName,
        [switch] $ExtendedVerb,
        [switch] $DefaultVerb,

        [string] $Logo,
        [string] $InfoTip,

        [ValidateSet('Player', 'Document', 'Single')]
        [string] $MultiSelectModel
    )

    process {
        $manifestPath = Join-Path $MSIXFolderPath 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "AppxManifest.xml not found in: $($MSIXFolderPath.FullName)"
            return
        }

        $manifest = New-Object System.Xml.XmlDocument
        $manifest.Load($manifestPath)

        $prefixes = @('uap', 'uap2', 'uap3')
        if ($DefaultVerb) { $prefixes += 'uap7' }
        Add-MSIXManifestNamespace -Manifest $manifest -Prefixes $prefixes

        $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
        $AppXNamespaces.GetEnumerator() | ForEach-Object { $null = $nsmgr.AddNamespace($_.Key, $_.Value) }

        $uapUri  = $AppXNamespaces['uap']
        $uap2Uri = $AppXNamespaces['uap2']
        $uap3Uri = $AppXNamespaces['uap3']
        $uap7Uri = $AppXNamespaces['uap7']

        # Locate the FTA (optionally scoped to a single Application).
        $appFilter = if ($AppId) { "[@Id='$AppId']" } else { '' }
        $ftaNode = $manifest.SelectSingleNode("//ns:Package/ns:Applications/ns:Application$appFilter/ns:Extensions/uap3:Extension[@Category='windows.fileTypeAssociation']/uap3:FileTypeAssociation[@Name='$Name']", $nsmgr)

        if ($null -eq $ftaNode) {
            $scope = if ($AppId) { "Application '$AppId'" } else { 'the package' }
            Write-Error "No file type association named '$Name' found in $scope. Use Add-MSIXFileTypeAssociation to create it."
            return
        }

        $ownerId = $ftaNode.SelectSingleNode('ancestor::ns:Application', $nsmgr).GetAttribute('Id')
        if (-not $PSCmdlet.ShouldProcess($ownerId, "Update file type association '$Name'")) {
            return
        }

        if ($PSBoundParameters.ContainsKey('MultiSelectModel')) {
            $null = $ftaNode.SetAttribute('MultiSelectModel', $MultiSelectModel)
        }

        # Replace the extension list when -FileType is supplied.
        if ($PSBoundParameters.ContainsKey('FileType')) {
            $sftEl = $ftaNode.SelectSingleNode('uap:SupportedFileTypes', $nsmgr)
            if ($null -ne $sftEl) { $null = $ftaNode.RemoveChild($sftEl) }
            $sftEl = $manifest.CreateElement('uap:SupportedFileTypes', $uapUri)
            foreach ($ext in $FileType) {
                $e = $ext.Trim()
                if (-not $e.StartsWith('.')) { $e = ".$e" }
                $ftEl = $manifest.CreateElement('uap:FileType', $uapUri)
                $ftEl.InnerText = $e.ToLowerInvariant()
                $null = $sftEl.AppendChild($ftEl)
            }
            # Keep schema order: SupportedFileTypes before SupportedVerbs.
            $svExisting = $ftaNode.SelectSingleNode('uap2:SupportedVerbs', $nsmgr)
            if ($null -ne $svExisting) { $null = $ftaNode.InsertBefore($sftEl, $svExisting) }
            else { $null = $ftaNode.AppendChild($sftEl) }
        }

        # Logo / InfoTip.
        if ($PSBoundParameters.ContainsKey('Logo')) {
            $logoEl = $ftaNode.SelectSingleNode('uap:Logo', $nsmgr)
            if ($null -eq $logoEl) {
                $logoEl = $manifest.CreateElement('uap:Logo', $uapUri)
                $null = $ftaNode.PrependChild($logoEl)
            }
            $logoEl.InnerText = $Logo
        }
        if ($PSBoundParameters.ContainsKey('InfoTip')) {
            $itEl = $ftaNode.SelectSingleNode('uap:InfoTip', $nsmgr)
            if ($null -eq $itEl) {
                $itEl = $manifest.CreateElement('uap:InfoTip', $uapUri)
                $sftRef = $ftaNode.SelectSingleNode('uap:SupportedFileTypes', $nsmgr)
                if ($null -ne $sftRef) { $null = $ftaNode.InsertBefore($itEl, $sftRef) }
                else { $null = $ftaNode.AppendChild($itEl) }
            }
            $itEl.InnerText = $InfoTip
        }

        # Add or update the verb (only when -VerbId is supplied).
        if ($VerbId) {
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
            if ($PSBoundParameters.ContainsKey('VerbParameters')) { $null = $verbEl.SetAttribute('Parameters', $VerbParameters) }
            if ($ExtendedVerb) { $null = $verbEl.SetAttribute('Extended', 'true') }
            if ($DefaultVerb)  { $null = $verbEl.SetAttribute('Default', $uap7Uri, 'true') }
            $verbEl.InnerText = if ($VerbDisplayName) { $VerbDisplayName } else { $VerbId }
        }

        $manifest.Save($manifestPath)
        Write-Verbose "Saved $manifestPath"
    }
}
