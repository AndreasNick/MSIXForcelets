
function Add-MSIXCapabilities {
<#
.SYNOPSIS
    Adds capabilities to an expanded MSIX package manifest.

.DESCRIPTION
    Modifies AppxManifest.xml in an expanded MSIX package folder to include the
    specified capabilities. Already-present capabilities are skipped silently.
    Creates the <Capabilities> element if it does not yet exist.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain AppxManifest.xml).

.PARAMETER Capabilities
    One or more capability names to add. Each name is validated against the known
    set of MSIX capabilities and mapped to the correct XML namespace automatically.

.EXAMPLE
    Add-MSIXCapabilities -MSIXFolder "C:\MSIXTemp\MyApp" -Capabilities "internetClient"

.EXAMPLE
    Add-MSIXCapabilities -MSIXFolder "C:\MSIXTemp\MyApp" -Capabilities "internetClient", "privateNetworkClientServer"

.NOTES
    Author: Andreas Nick
    https://www.nick-it.de
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [Parameter(Mandatory = $true)]
        [ValidateSet(
            "runFullTrust", "allowElevation",
            "internetClient", "internetClientServer", "privateNetworkClientServer",
            "allJoyn", "codeGeneration",
            "enterpriseAuthentication", "videosLibrary", "musicLibrary", "contacts",
            "appointments", "blockedChatMessages", "picturesLibrary",
            "userAccountInformation", "removableStorage", "phoneCall", "voipCall",
            "chat", "sharedUserCertificates", "objects3D", "phoneCallHistoryPublic",
            "spatialPerception", "remoteSystem", "backgroundMediaPlayback",
            "userNotificationListener", "offlineMapsManagement", "userDataTasks",
            "graphicsCapture", "globalMediaControl", "gazeInput", "recordedCallsFolder",
            "systemManagement", "lowLevelDevices", "accessoryManager",
            "documentsLibrary", "location", "microphone", "webcam", "radios",
            "unvirtualizedResources",
            IgnoreCase = $false)]
        [string[]] $Capabilities
    )

    begin {
        # Maps capability name to its XML element tag (prefix:LocalName or LocalName only)
        $capabilityTag = @{
            "internetClient"             = "Capability"
            "internetClientServer"       = "Capability"
            "privateNetworkClientServer" = "Capability"
            "allJoyn"                    = "Capability"
            "codeGeneration"             = "Capability"
            "enterpriseAuthentication"   = "uap:Capability"
            "videosLibrary"              = "uap:Capability"
            "musicLibrary"               = "uap:Capability"
            "contacts"                   = "uap:Capability"
            "appointments"               = "uap:Capability"
            "blockedChatMessages"        = "uap:Capability"
            "picturesLibrary"            = "uap:Capability"
            "userAccountInformation"     = "uap:Capability"
            "removableStorage"           = "uap:Capability"
            "phoneCall"                  = "uap:Capability"
            "voipCall"                   = "uap:Capability"
            "chat"                       = "uap:Capability"
            "sharedUserCertificates"     = "uap:Capability"
            "objects3D"                  = "uap:Capability"
            "phoneCallHistoryPublic"     = "uap2:Capability"
            "spatialPerception"          = "uap2:Capability"
            "remoteSystem"               = "uap3:Capability"
            "backgroundMediaPlayback"    = "uap3:Capability"
            "userNotificationListener"   = "uap3:Capability"
            "offlineMapsManagement"      = "uap4:Capability"
            "userDataTasks"              = "uap4:Capability"
            "graphicsCapture"            = "uap6:Capability"
            "globalMediaControl"         = "uap7:Capability"
            "gazeInput"                  = "uap7:Capability"
            "recordedCallsFolder"        = "mobile:Capability"
            "systemManagement"           = "iot:Capability"
            "lowLevelDevices"            = "iot:Capability"
            "accessoryManager"           = "rescap:Capability"
            "documentsLibrary"           = "rescap:Capability"
            "runFullTrust"               = "rescap:Capability"
            "allowElevation"             = "rescap:Capability"
            "location"                   = "DeviceCapability"
            "microphone"                 = "DeviceCapability"
            "webcam"                     = "DeviceCapability"
            "radios"                     = "DeviceCapability"
            "unvirtualizedResources"     = "rescap:Capability"
        }
    }

    process {
        $manifestPath = Join-Path $MSIXFolder 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "AppxManifest.xml not found in: $($MSIXFolder.FullName)"
            return
        }

        $manifest = New-Object xml
        $manifest.Load($manifestPath)

        $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
        $AppXNamespaces.GetEnumerator() | ForEach-Object { $nsmgr.AddNamespace($_.Key, $_.Value) }

        # Ensure <Capabilities> exists
        $capsNode = $manifest.SelectSingleNode('//ns:Capabilities', $nsmgr)
        if ($null -eq $capsNode) {
            $capsNode = $manifest.CreateElement('Capabilities', $AppXNamespaces['ns'])
            $null = $manifest.DocumentElement.AppendChild($capsNode)
            Write-Verbose "Created <Capabilities> element."
        }

        # Collect all prefixes needed and ensure they are declared on the root element
        $prefixesNeeded = $Capabilities | ForEach-Object {
            $t = $capabilityTag[$_]
            if ($t -match '^(?<prefix>[^:]+):') { $Matches.prefix }
        } | Select-Object -Unique
        if ($prefixesNeeded) {
            Add-MSIXManifestNamespace -Manifest $manifest -Prefixes $prefixesNeeded
        }

        $changed = $false
        foreach ($cap in $Capabilities) {
            $tag = $capabilityTag[$cap]

            # Build namespace-aware XPath: plain "Capability" / "DeviceCapability" live in ns namespace
            $xpathTag = if ($tag -eq 'Capability' -or $tag -eq 'DeviceCapability') { "ns:$tag" } else { $tag }
            $existing = $manifest.SelectSingleNode("//ns:Capabilities/$xpathTag[@Name='$cap']", $nsmgr)
            if ($null -ne $existing) {
                Write-Verbose "Capability '$cap' already present - skipped."
                continue
            }

            # Resolve element namespace URI
            $elemNamespace = $AppXNamespaces['ns']
            if ($tag -match '^(?<prefix>[^:]+):') {
                $elemNamespace = $AppXNamespaces[$Matches.prefix]
            }

            $elem = $manifest.CreateElement($tag, $elemNamespace)
            $null = $elem.SetAttribute('Name', $cap)
            $null = $capsNode.AppendChild($elem)
            Write-Verbose "Added capability: $cap ($tag)"
            $changed = $true
        }

        if ($changed) {
            $manifest.PreserveWhitespace = $false
            $manifest.Save($manifestPath)
        }
    }
}
