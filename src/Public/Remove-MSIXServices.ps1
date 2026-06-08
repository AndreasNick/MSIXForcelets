function Remove-MSIXServices {
<#
.SYNOPSIS
    Removes windows.service declarations (+ matching COM ServiceServer and empty
    service-host apps) from an MSIX manifest. Once no service remains, the
    localSystemServices/packagedServices capabilities are dropped too
    (keeps the install dialog from demanding admin) - unless -KeepServiceCapabilities.
.PARAMETER MSIXFolderPath
    Expanded MSIX package folder. Pipeline by property name.
.PARAMETER ServiceName
    Name of a specific service. Omit to remove all.
.PARAMETER KeepHostApplication
    Keep the hosting Application even if it becomes an empty service-host.
.EXAMPLE
    Get-MSIXServices -MSIXFolder $pkg | Remove-MSIXServices
.NOTES
    Andreas Nick, 2026
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolderPath,

        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1)]
        [string] $ServiceName,

        [switch] $KeepHostApplication,
        # Keep the rescap service capabilities even when no service remains.
        # By default they are removed once the last service is gone - otherwise
        # the install dialog keeps showing "installs a service" + admin prompt.
        [switch] $KeepServiceCapabilities
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
            $AppXNamespaces.GetEnumerator() | ForEach-Object { $null = $nsmgr.AddNamespace($_.Key, $_.Value) }

            $targetNames = $pending[$folder]   # empty list = remove all
            $removedAny  = $false

            $applications = @($manifest.SelectNodes('//ns:Package/ns:Applications/ns:Application', $nsmgr))
            foreach ($app in $applications) {
                $appId          = $app.GetAttribute('Id')
                $extensionsNode = $app.SelectSingleNode('ns:Extensions', $nsmgr)
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

            # Once no windows.service remains, drop the now-pointless service
            # capabilities - otherwise the install dialog still shows "installs a
            # service" and demands admin rights.
            if ($removedAny -and -not $KeepServiceCapabilities) {
                $stillHasService = $manifest.SelectSingleNode("//desktop6:Extension[@Category='windows.service']", $nsmgr)
                if ($null -eq $stillHasService) {
                    foreach ($capName in 'localSystemServices', 'packagedServices') {
                        $cap = $manifest.SelectSingleNode("//*[local-name()='Capability'][@Name='$capName']", $nsmgr)
                        if ($null -ne $cap) {
                            $null = $cap.ParentNode.RemoveChild($cap)
                            Write-Verbose "Removed service capability '$capName'."
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
