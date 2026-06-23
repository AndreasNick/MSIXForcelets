function ConvertTo-MSIXFtaObject {
<#
.SYNOPSIS
    Converts a uap3:FileTypeAssociation XML node into a PSCustomObject.
.DESCRIPTION
    Internal helper shared by the *-MSIXFileTypeAssociation cmdlets. The returned
    object exposes ApplicationId and MSIXFolderPath so it binds straight back into
    Set-/Remove-MSIXFileTypeAssociation via ValueFromPipelineByPropertyName.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement] $FtaNode,

        [Parameter(Mandatory = $true)]
        [System.Xml.XmlNamespaceManager] $Nsmgr,

        [Parameter(Mandatory = $true)]
        [string] $ApplicationId,

        [Parameter(Mandatory = $true)]
        [string] $MSIXFolderPath
    )

    $fileTypes = @()
    foreach ($ft in $FtaNode.SelectNodes('uap:SupportedFileTypes/uap:FileType', $Nsmgr)) {
        $fileTypes += $ft.InnerText
    }

    $verbs = @()
    foreach ($v in $FtaNode.SelectNodes('uap2:SupportedVerbs/uap3:Verb', $Nsmgr)) {
        $verbs += [PSCustomObject]@{
            Id          = $v.GetAttribute('Id')
            DisplayName = $v.InnerText
            Parameters  = $v.GetAttribute('Parameters')
            Extended    = ($v.GetAttribute('Extended') -eq 'true')
            Default     = ($v.GetAttribute('Default', $AppXNamespaces['uap7']) -eq 'true')
        }
    }

    $logoNode    = $FtaNode.SelectSingleNode('uap:Logo', $Nsmgr)
    $infoTipNode = $FtaNode.SelectSingleNode('uap:InfoTip', $Nsmgr)
    $displayNode = $FtaNode.SelectSingleNode('uap3:DisplayName', $Nsmgr)
    if ($null -eq $displayNode) { $displayNode = $FtaNode.SelectSingleNode('uap:DisplayName', $Nsmgr) }

    [PSCustomObject]@{
        ApplicationId    = $ApplicationId
        Name             = $FtaNode.GetAttribute('Name')
        FileType         = $fileTypes
        Verbs            = $verbs
        Logo             = if ($logoNode)    { $logoNode.InnerText }    else { $null }
        InfoTip          = if ($infoTipNode) { $infoTipNode.InnerText } else { $null }
        DisplayName      = if ($displayNode) { $displayNode.InnerText } else { $null }
        Parameters       = $FtaNode.GetAttribute('Parameters')
        MultiSelectModel = $FtaNode.GetAttribute('MultiSelectModel')
        MSIXFolderPath   = $MSIXFolderPath
    }
}
