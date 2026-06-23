function Remove-MSIXFileTypeAssociation {
<#
.SYNOPSIS
    Removes windows.fileTypeAssociation (FTA) entries from an MSIX package.
.DESCRIPTION
    Selects FTAs by -Name or by -FileType and removes them. With -VerbId only that
    verb is removed and the association is kept. An Extensions node left empty is
    pruned. Works with Get-MSIXApplications and Get-MSIXFileTypeAssociation pipelines.
.PARAMETER MSIXFolderPath
    Expanded MSIX package folder. Pipeline by property name.
.PARAMETER AppId
    Limit removal to one Application Id. Binds from Get-MSIXApplications (Id) or
    Get-MSIXFileTypeAssociation (ApplicationId). Omit to act across all Applications.
.PARAMETER Name
    Remove the FTA with this name.
.PARAMETER FileType
    Remove FTAs whose supported file types include this extension (leading dot optional).
.PARAMETER VerbId
    Remove only this verb from the matched FTAs instead of the whole association.
.EXAMPLE
    Get-MSIXApplications -MSIXFolder $pkg | Remove-MSIXFileTypeAssociation -FileType .html
.EXAMPLE
    Get-MSIXFileTypeAssociation -MSIXFolder $pkg -Name putty | Remove-MSIXFileTypeAssociation
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

        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1)]
        [string] $Name,

        [string] $FileType,

        [string] $VerbId
    )

    process {
        if (-not $Name -and -not $FileType) {
            Write-Error "Specify -Name or -FileType to select what to remove."
            return
        }

        $manifestPath = Join-Path $MSIXFolderPath 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "AppxManifest.xml not found in: $($MSIXFolderPath.FullName)"
            return
        }

        $matchExt = $null
        if ($FileType) {
            $matchExt = $FileType.Trim()
            if (-not $matchExt.StartsWith('.')) { $matchExt = ".$matchExt" }
            $matchExt = $matchExt.ToLowerInvariant()
        }

        $manifest = New-Object System.Xml.XmlDocument
        $manifest.Load($manifestPath)

        $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
        $AppXNamespaces.GetEnumerator() | ForEach-Object { $null = $nsmgr.AddNamespace($_.Key, $_.Value) }

        $removedAny = $false

        foreach ($app in $manifest.SelectNodes('//ns:Package/ns:Applications/ns:Application', $nsmgr)) {
            $thisId = $app.GetAttribute('Id')
            if ($AppId -and $thisId -ne $AppId) { continue }

            $extNode = $app.SelectSingleNode('ns:Extensions', $nsmgr)
            if ($null -eq $extNode) { continue }

            foreach ($ext in @($extNode.SelectNodes("uap3:Extension[@Category='windows.fileTypeAssociation']", $nsmgr))) {
                $fta = $ext.SelectSingleNode('uap3:FileTypeAssociation', $nsmgr)
                if ($null -eq $fta) { continue }

                $ftaName = $fta.GetAttribute('Name')
                if ($Name -and $ftaName -ne $Name.ToLowerInvariant()) { continue }

                if ($matchExt) {
                    $hasExt = $false
                    foreach ($ft in $fta.SelectNodes('uap:SupportedFileTypes/uap:FileType', $nsmgr)) {
                        if ($ft.InnerText.ToLowerInvariant() -eq $matchExt) { $hasExt = $true; break }
                    }
                    if (-not $hasExt) { continue }
                }

                if ($VerbId) {
                    $verbEl = $fta.SelectSingleNode("uap2:SupportedVerbs/uap3:Verb[@Id='$VerbId']", $nsmgr)
                    if ($null -eq $verbEl) { continue }
                    if (-not $PSCmdlet.ShouldProcess($thisId, "Remove verb '$VerbId' from FTA '$ftaName'")) { continue }
                    $svEl = $verbEl.ParentNode
                    $null = $svEl.RemoveChild($verbEl)
                    if ($svEl.SelectNodes('uap3:Verb', $nsmgr).Count -eq 0) { $null = $fta.RemoveChild($svEl) }
                    $removedAny = $true
                    Write-Verbose "Removed verb '$VerbId' from FTA '$ftaName' on '$thisId'."
                }
                else {
                    if (-not $PSCmdlet.ShouldProcess($thisId, "Remove FTA '$ftaName'")) { continue }
                    $null = $extNode.RemoveChild($ext)
                    $removedAny = $true
                    Write-Verbose "Removed FTA '$ftaName' from '$thisId'."
                }
            }

            # Drop an Extensions node that is now empty.
            if ($null -ne $extNode -and $extNode.SelectNodes('*').Count -eq 0) {
                $null = $app.RemoveChild($extNode)
            }
        }

        if ($removedAny) {
            $manifest.Save($manifestPath)
            Write-Verbose "Saved $manifestPath"
        }
        else {
            Write-Warning "No matching file type association found to remove."
        }
    }
}
