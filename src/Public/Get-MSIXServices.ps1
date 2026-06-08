function Get-MSIXServices {
<#
.SYNOPSIS
    Lists windows.service declarations in an MSIX manifest (one object per service,
    incl. ApplicationId, ServiceName, StartAccount, HasComServer).
.PARAMETER MSIXFolder
    Expanded MSIX package folder (contains AppxManifest.xml).
.EXAMPLE
    Get-MSIXServices -MSIXFolder $pkg | Remove-MSIXServices
.NOTES
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

        $applications = $manifest.SelectNodes('//ns:Package/ns:Applications/ns:Application', $nsmgr)
        foreach ($app in $applications) {
            $appId = $app.GetAttribute('Id')

            $serviceExtensions = $app.SelectNodes(
                "ns:Extensions/desktop6:Extension[@Category='windows.service']", $nsmgr)
            foreach ($ext in $serviceExtensions) {
                $svc = $ext.SelectSingleNode('desktop6:Service', $nsmgr)
                if ($null -eq $svc) {
                    Write-Verbose "Service extension on '$appId' has no desktop6:Service child - skipping."
                    continue
                }

                # Detect an accompanying COM ServiceServer (matched by ServiceName)
                $hasComServer = $null -ne $app.SelectSingleNode(
                    "ns:Extensions/com2:Extension/com2:ComServer/*[local-name()='ServiceServer']", $nsmgr)

                Write-Verbose "Found service '$($svc.GetAttribute('Name'))' on Application '$appId'"
                [PSCustomObject]@{
                    ApplicationId  = $appId
                    ServiceName    = $svc.GetAttribute('Name')
                    StartupType    = $svc.GetAttribute('StartupType')
                    StartAccount   = $svc.GetAttribute('StartAccount')
                    Executable     = $ext.GetAttribute('Executable')
                    HasComServer   = $hasComServer
                    MSIXFolderPath = $MSIXFolder.FullName
                }
            }
        }
    }
}
