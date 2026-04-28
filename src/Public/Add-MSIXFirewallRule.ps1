function Add-MSIXFirewallRule {
<#$
.SYNOPSIS
    Adds a firewall rule to the AppxManifest.xml of an MSIX package.

.DESCRIPTION
    The Add-MSIXFirewallRule function creates a windows.firewallRules extension
    entry in the AppxManifest.xml for a given application. The rule allows
    specifying direction, protocol and port for an executable inside the
    package.

.PARAMETER MSIXFolder
    The path to the expanded MSIX package.

.PARAMETER MISXAppID
    The AppID of the application to which the rule should be added.

.PARAMETER Executable
    Executable file inside the package that the rule applies to.

.PARAMETER Direction
    Direction of the firewall rule. Allowed values are 'in' or 'out'.

.PARAMETER IPProtocol
    Network protocol for the rule. Allowed values are 'TCP' or 'UDP'.

.PARAMETER Port
    Local port to open. The port is used for LocalPortMin and LocalPortMax.

.PARAMETER Profile
    Optional firewall profile. Defaults to 'all'.

.EXAMPLE
    Add-MSIXFirewallRule -MSIXFolder "C:\MyApp" -MISXAppID "App" -Executable "app.exe" -Direction in -IPProtocol TCP -Port 4810
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        [System.IO.DirectoryInfo]$MSIXFolder,
        [Parameter(Mandatory=$true, Position=1)]
        [Alias('Id')]
        [string]$MISXAppID,
        [Parameter(Mandatory=$true, Position=2)]
        [string]$Executable,
        [Parameter(Mandatory=$true)]
        [ValidateSet('in','out')]
        [string]$Direction,
        [Parameter(Mandatory=$true)]
        [ValidateSet('TCP','UDP')]
        [string]$IPProtocol,
        [Parameter(Mandatory=$true)]
        [int]$Port,
        [string]$Profile = 'all'
    )

    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath 'AppxManifest.xml'))) {
            Write-Verbose '[ERROR] The MSIX temporary folder does not exist - skip adding FirewallRule'
            return
        }

        $manifest = New-Object xml
        $manifest.Load((Join-Path $MSIXFolder -ChildPath 'AppxManifest.xml'))

        $nsmgr = New-Object System.Xml.XmlNamespaceManager $manifest.NameTable
        $AppXNamespaces.GetEnumerator() | ForEach-Object { $nsmgr.AddNamespace($_.key, $_.value) }
        $nsmgr.AddNamespace('desktop2', $AppXNamespaces['desktop2'])

        $appNode = $manifest.SelectSingleNode("//ns:Package/ns:Applications/ns:Application[@Id='" + $MISXAppID + "']", $nsmgr)
        if (-not $appNode) {
            Write-Verbose '[ERROR] Application does not exist - skipping adding FirewallRule'
            return
        }

        if (-not $appNode.extensions) {
            $ext = $manifest.CreateElement('Extensions', $AppXNamespaces['ns'])
            $appNode.AppendChild($ext) | Out-Null
        }

        $extensionNode = $manifest.SelectSingleNode("//ns:Application[@Id='" + $MISXAppID + "']/ns:Extensions/desktop2:Extension[@Category='windows.firewallRules']", $nsmgr)
        if (-not $extensionNode) {
            $extensionNode = $manifest.CreateElement('desktop2:Extension', $AppXNamespaces['desktop2'])
            $extensionNode.SetAttribute('Category','windows.firewallRules')
            $manifest.SelectSingleNode("//ns:Application[@Id='" + $MISXAppID + "']/ns:Extensions", $nsmgr).AppendChild($extensionNode) | Out-Null
        }

        $existingRule = $manifest.SelectSingleNode("//desktop2:Extension[@Category='windows.firewallRules']/desktop2:FirewallRules[@Executable='" + $Executable + "']", $nsmgr)
        if ($existingRule) {
            Write-Verbose "[WARNING] A firewall rule for executable '$Executable' already exists - skipping"
            return
        }

        $fwNode = $manifest.CreateElement('desktop2:FirewallRules', $AppXNamespaces['desktop2'])
        $fwNode.SetAttribute('Executable', $Executable)
        $rule = $manifest.CreateElement('desktop2:Rule', $AppXNamespaces['desktop2'])
        $rule.SetAttribute('Direction', $Direction)
        $rule.SetAttribute('IPProtocol', $IPProtocol)
        $rule.SetAttribute('LocalPortMin', $Port)
        $rule.SetAttribute('LocalPortMax', $Port)
        $rule.SetAttribute('Profile', $Profile)
        $fwNode.AppendChild($rule) | Out-Null
        $extensionNode.AppendChild($fwNode) | Out-Null

        $manifest.PreserveWhitespace = $false
        $manifest.Save((Join-Path $MSIXFolder -ChildPath 'AppxManifest.xml'))
    }
}

