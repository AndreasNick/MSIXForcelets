function Get-MSIXFileTypeAssociation {
<#
.SYNOPSIS
    Reads windows.fileTypeAssociation (FTA) entries from an expanded MSIX package.
.DESCRIPTION
    Returns one object per uap3:FileTypeAssociation found under the package's
    Applications. The objects carry ApplicationId, Name and MSIXFolderPath so they
    pipe straight into Set-/Remove-MSIXFileTypeAssociation.
.PARAMETER MSIXFolderPath
    Expanded MSIX package folder. Pipeline by property name (e.g. from Get-MSIXApplications).
.PARAMETER AppId
    Limit the result to one Application Id. Binds from Get-MSIXApplications (Id).
.PARAMETER Name
    Limit the result to a single FTA name.
.EXAMPLE
    Get-MSIXApplications -MSIXFolder $pkg | Get-MSIXFileTypeAssociation
.NOTES
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [Alias('MSIXFolder')]
        [System.IO.DirectoryInfo] $MSIXFolderPath,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string] $AppId,

        [Parameter(Position = 1)]
        [string] $Name
    )

    process {
        $manifestPath = Join-Path $MSIXFolderPath 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "AppxManifest.xml not found in: $($MSIXFolderPath.FullName)"
            return
        }

        $manifest = New-Object System.Xml.XmlDocument
        $manifest.Load($manifestPath)

        $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
        $AppXNamespaces.GetEnumerator() | ForEach-Object { $null = $nsmgr.AddNamespace($_.Key, $_.Value) }

        foreach ($app in $manifest.SelectNodes('//ns:Package/ns:Applications/ns:Application', $nsmgr)) {
            $thisId = $app.GetAttribute('Id')
            if ($AppId -and $thisId -ne $AppId) { continue }

            $ftaNodes = $app.SelectNodes("ns:Extensions/uap3:Extension[@Category='windows.fileTypeAssociation']/uap3:FileTypeAssociation", $nsmgr)
            foreach ($fta in $ftaNodes) {
                if ($Name -and $fta.GetAttribute('Name') -ne $Name) { continue }
                ConvertTo-MSIXFtaObject -FtaNode $fta -Nsmgr $nsmgr -ApplicationId $thisId -MSIXFolderPath $MSIXFolderPath.FullName
            }
        }
    }
}
