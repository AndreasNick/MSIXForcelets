function Remove-MSIXServices {
<#
.SYNOPSIS
    Removes Windows service declarations from an expanded MSIX package's manifest.

.DESCRIPTION
    Removes desktop6:Extension entries of category "windows.service" from
    AppxManifest.xml. For each removed service it also strips a matching COM
    ServiceServer extension (com2:Extension with a ServiceServer whose
    ServiceName matches). When the hosting Application becomes an empty
    service-host afterwards (no remaining extensions and AppListEntry="none"),
    the Application element itself is removed too - unless -KeepHostApplication
    is set.

    Designed to clean up services that an MSIX Packaging Tool capture pulled in
    by accident (e.g. Visual Studio installer / diagnostics services when
    repackaging SSMS), which can break deployment or activation of the package.

    Accepts pipeline input from Get-MSIXServices. The manifest is saved once per
    folder after all pipeline objects are processed.

.PARAMETER MSIXFolderPath
    Path to the expanded MSIX package folder containing AppxManifest.xml.
    Accepts pipeline input by property name (supplied by Get-MSIXServices).

.PARAMETER ServiceName
    Name of a specific service to remove. Accepted from the pipeline. When
    omitted, ALL windows.service declarations in the folder are removed.

.PARAMETER KeepHostApplication
    Keep the hosting Application element even if it becomes an empty
    service-host after the service is removed. By default such pure
    service-host applications (AppListEntry="none", no other extensions) are
    removed entirely.

.EXAMPLE
    Get-MSIXServices -MSIXFolder $pkg | Remove-MSIXServices

    Removes every declared service (and empty service-host apps) from the package.

.EXAMPLE
    Get-MSIXServices -MSIXFolder $pkg |
        Where-Object ServiceName -like 'VS*' |
        Remove-MSIXServices

    Removes only the Visual Studio services, keeps everything else.

.EXAMPLE
    Remove-MSIXServices -MSIXFolderPath $pkg -ServiceName 'VSStandardCollectorService150'

    Removes a single named service directly.

.NOTES
    Service capabilities (rescap:localSystemServices / packagedServices) are
    intentionally left in place; they are harmless when sideloading. Remove them
    manually from <Capabilities> if you want a minimal manifest.

    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolderPath,

        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1)]
        [string] $ServiceName,

        [switch] $KeepHostApplication
    )

    begin {
        # Keyed by resolved folder path -> list of service names to remove (empty = all)
        $pending = @{}
    }

    process {
        $key = $MSIXFolderPath.FullName
        if (-not $pending.ContainsKey($key)) {
            $pending[$key] = [System.Collections.Generic.List[string]]::new()
        }
        if (-not [string]::IsNullOrEmpty($ServiceName)) {
            $pending[$key].Add($ServiceName)
        }
    }

    end {
        foreach ($folder in $pending.Keys) {
            $manifestPath = Join-Path $folder 'AppxManifest.xml'
            if (-not (Test-Path $manifestPath)) {
                Write-Warning "AppxManifest.xml not found in '$folder' - skipping."
                continue
            }

            $manifest = New-Object System.Xml.XmlDocument
            $manifest.PreserveWhitespace = $false
            $manifest.Load($manifestPath)

            $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
            $null = $nsmgr.AddNamespace('default',  'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
            $null = $nsmgr.AddNamespace('uap',      'http://schemas.microsoft.com/appx/manifest/uap/windows10')
            $null = $nsmgr.AddNamespace('desktop6', 'http://schemas.microsoft.com/appx/manifest/desktop/windows10/6')
            $null = $nsmgr.AddNamespace('com2',     'http://schemas.microsoft.com/appx/manifest/com/windows10/2')

            $targetNames = $pending[$folder]   # empty list = remove all
            $removedAny  = $false

            $applications = @($manifest.SelectNodes('//default:Package/default:Applications/default:Application', $nsmgr))
            foreach ($app in $applications) {
                $appId          = $app.GetAttribute('Id')
                $extensionsNode = $app.SelectSingleNode('default:Extensions', $nsmgr)
                if ($null -eq $extensionsNode) { continue }

                $svcExtensions = @($extensionsNode.SelectNodes("desktop6:Extension[@Category='windows.service']", $nsmgr))
                foreach ($ext in $svcExtensions) {
                    $svc     = $ext.SelectSingleNode('desktop6:Service', $nsmgr)
                    $svcName = if ($null -ne $svc) { $svc.GetAttribute('Name') } else { '' }

                    if ($targetNames.Count -gt 0 -and $targetNames -notcontains $svcName) {
                        continue
                    }

                    if (-not $PSCmdlet.ShouldProcess($folder, "Remove service '$svcName' (Application '$appId')")) {
                        continue
                    }

                    $null = $extensionsNode.RemoveChild($ext)
                    $removedAny = $true
                    Write-Verbose "Removed windows.service '$svcName' from Application '$appId'."

                    # Strip a matching COM ServiceServer extension (same ServiceName)
                    foreach ($comExt in @($extensionsNode.SelectNodes('com2:Extension', $nsmgr))) {
                        $serviceServer = $comExt.SelectSingleNode(".//*[local-name()='ServiceServer']", $nsmgr)
                        if ($null -ne $serviceServer -and $serviceServer.GetAttribute('ServiceName') -eq $svcName) {
                            $null = $extensionsNode.RemoveChild($comExt)
                            Write-Verbose "Removed COM ServiceServer for '$svcName' from Application '$appId'."
                        }
                    }
                }

                # Drop the hosting Application if it is now a pure, empty service host
                if (-not $KeepHostApplication) {
                    $remaining   = $extensionsNode.SelectNodes('*')
                    $visualElems = $app.SelectSingleNode("*[local-name()='VisualElements']")
                    $appListEntry = if ($null -ne $visualElems) { $visualElems.GetAttribute('AppListEntry') } else { '' }

                    if ($remaining.Count -eq 0) {
                        # Remove the now-empty <Extensions> node either way
                        $null = $app.RemoveChild($extensionsNode)

                        if ($appListEntry -eq 'none') {
                            $null = $app.ParentNode.RemoveChild($app)
                            Write-Verbose "Removed empty service-host Application '$appId' (AppListEntry=none)."
                        }
                    }
                }
            }

            if ($removedAny) {
                $manifest.Save($manifestPath)
                Write-Verbose "Saved $manifestPath"
            }
            else {
                Write-Warning "No matching services found in '$folder'."
            }
        }
    }
}
