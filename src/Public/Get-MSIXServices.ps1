function Get-MSIXServices {
<#
.SYNOPSIS
    Lists the Windows services declared in an expanded MSIX package's manifest.

.DESCRIPTION
    Scans AppxManifest.xml for desktop6:Extension entries of category
    "windows.service" and returns one object per declared service. Each result
    carries the hosting Application Id plus the service attributes (name,
    startup type, start account, executable).

    MSIX Packaging Tool conversions often capture unrelated services into a
    package (e.g. Visual Studio installer services when repackaging SSMS).
    Such localSystem services can break deployment or activation of the whole
    package. Pipe the results into Remove-MSIXServices to strip them out.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder containing AppxManifest.xml.

.EXAMPLE
    Get-MSIXServices -MSIXFolder "C:\MSIXTemp\SSMS22"

.EXAMPLE
    Get-MSIXServices -MSIXFolder $pkg | Format-Table ApplicationId, ServiceName, StartAccount

.EXAMPLE
    # Remove every captured service
    Get-MSIXServices -MSIXFolder $pkg | Remove-MSIXServices

.OUTPUTS
    PSCustomObject with: ApplicationId, ServiceName, StartupType, StartAccount,
    Executable, HasComServer, MSIXFolderPath. The MSIXFolderPath and ServiceName
    properties bind to Remove-MSIXServices via ValueFromPipelineByPropertyName.

.NOTES
    https://www.nick-it.de
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
        $null = $nsmgr.AddNamespace('default',  'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
        $null = $nsmgr.AddNamespace('desktop6', 'http://schemas.microsoft.com/appx/manifest/desktop/windows10/6')
        $null = $nsmgr.AddNamespace('com2',     'http://schemas.microsoft.com/appx/manifest/com/windows10/2')

        $applications = $manifest.SelectNodes('//default:Package/default:Applications/default:Application', $nsmgr)
        foreach ($app in $applications) {
            $appId = $app.GetAttribute('Id')

            $serviceExtensions = $app.SelectNodes(
                "default:Extensions/desktop6:Extension[@Category='windows.service']", $nsmgr)
            foreach ($ext in $serviceExtensions) {
                $svc = $ext.SelectSingleNode('desktop6:Service', $nsmgr)
                if ($null -eq $svc) {
                    Write-Verbose "Service extension on '$appId' has no desktop6:Service child - skipping."
                    continue
                }

                # Detect an accompanying COM ServiceServer (matched by ServiceName)
                $hasComServer = $null -ne $app.SelectSingleNode(
                    "default:Extensions/com2:Extension/com2:ComServer/*[local-name()='ServiceServer']", $nsmgr)

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
