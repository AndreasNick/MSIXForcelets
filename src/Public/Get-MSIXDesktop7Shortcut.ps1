function Get-MSIXDesktop7Shortcut {
<#
.SYNOPSIS
    Lists the desktop7:Shortcut entries from an MSIX manifest.
.PARAMETER MSIXFolder
    Expanded MSIX package folder (contains AppxManifest.xml).
.EXAMPLE
    Get-MSIXDesktop7Shortcut -MSIXFolder $pkg
.NOTES
    Token-to-VFS resolution / validation lives in Repair-MSIXDesktop7Shortcut -
    this cmdlet only reads the manifest.
    Tim Mangan: https://www.tmurgent.com/TmBlog/?p=3857
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder
    )

    process {
        $manifestPath = Join-Path $MSIXFolder.FullName 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "The MSIX folder does not contain AppxManifest.xml: $($MSIXFolder.FullName)"
            return
        }

        $manifest = New-Object System.Xml.XmlDocument
        $manifest.Load($manifestPath)

        $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
        $AppXNamespaces.GetEnumerator() | ForEach-Object { $null = $nsmgr.AddNamespace($_.Key, $_.Value) }

        # desktop10:DisplayName / desktop10:Description are localizable attributes in a
        # separate namespace; read them by URI so they resolve regardless of prefix.
        $desktop10Ns = $AppXNamespaces['desktop10']

        foreach ($app in $manifest.SelectNodes('//ns:Package/ns:Applications/ns:Application', $nsmgr)) {
            $appId = $app.GetAttribute('Id')
            foreach ($sc in $app.SelectNodes("ns:Extensions/desktop7:Extension[@Category='windows.shortcut']/desktop7:Shortcut", $nsmgr)) {
                [PSCustomObject]@{
                    ApplicationId               = $appId
                    File                        = $sc.GetAttribute('File')
                    Icon                        = $sc.GetAttribute('Icon')
                    Arguments                   = $sc.GetAttribute('Arguments')
                    Description                 = $sc.GetAttribute('Description')
                    PinToStartMenu              = ($sc.GetAttribute('PinToStartMenu') -in @('true', '1'))
                    ExcludeFromShowInNewInstall = ($sc.GetAttribute('ExcludeFromShowInNewInstall') -in @('true', '1'))
                    DisplayName                 = $sc.GetAttribute('DisplayName', $desktop10Ns)
                    LocalizedDescription        = $sc.GetAttribute('Description', $desktop10Ns)
                    MSIXFolderPath              = $MSIXFolder.FullName
                }
            }
        }
    }
}
