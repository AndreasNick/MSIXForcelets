
function Add-MSIXDisableVREGOrRegistryWrite {
    <#
    .SYNOPSIS
    Disables  VFS and VREG in MSIX / APPX package
    
    .DESCRIPTION
    Disables  VFS and VREG in einem MSIX / APPX package.
    >>> ATTENTION <<< - the package cannot be opened with the Packaging Tool afterwards. It does not 
    seem to know the namespace "desktop6" yet. An installation is only possible via the PoweerShell "Add-AppXPackage".
    
    .PARAMETER MSIXFolder
    The unzipped MSIX folder
    
    .PARAMETER DisableFileSystemWriteVirtualization
    desktop6:FileSystemWriteVirtualization
    Indicates whether virtualization for the file system is enabled for your desktop application. 
    If disabled, other apps can read or write the same file system entries as your application.
    
    .PARAMETER DisableRegistryWriteVirtualization
    desktop6:RegistryWriteVirtualization
    Indicates whether virtualization for the registry is enabled for your desktop application. 
    If disabled, other apps can read or write the same registry entries as your application
    
    .EXAMPLE
    Add-MSIXCapabilities -MSIXFolder $Package  -Capabilities unvirtualizedResources 
    Add-DisableVREGOrRegistryWrite -MSIXFolder $Package -DisableFileSystemWriteVirtualization -DisableRegistryWriteVirtualization
    
    .NOTES
    The idea is from this blog
    https://www.advancedinstaller.com/msix-disable-registry-file-redirection.html
    
    Author: Andreas Nick
    Date: 01/10/2022
    https://www.nick-it.de
    #>
    param(    
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Switch] $DisableFileSystemWriteVirtualization,
        [Switch] $DisableRegistryWriteVirtualization
    )

    process {
        <#
            <Properties>
            <desktop6:FileSystemWriteVirtualization>disabled</desktop6:FileSystemWriteVirtualization>
            <desktop6:RegistryWriteVirtualization>disabled</desktop6:RegistryWriteVirtualization>
            </Properties>
            #>
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            Write-Verbose "[ERROR] The MSIX temporary folder not exist - skip disableVREGOrRegistryWrite"
        }
        else {
            if ($DisableFileSystemWriteVirtualization -or $DisableRegistryWriteVirtualization) {
                $manifest = New-Object xml
                $manifest.Load((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
                
                $nsmgr = New-Object System.Xml.XmlNamespaceManager $manifest.NameTable
                $AppXNamespaces.GetEnumerator() | ForEach-Object {
                    $nsmgr.AddNamespace($_.key, $_.value)
                }
                $nsmgr.AddNamespace("desktop6", $Script:AppXNamespaces['desktop6'])


                $properties = $manifest.SelectSingleNode("//ns:Package/ns:Properties", $nsmgr)
                if ($DisableFileSystemWriteVirtualization) {
                    if ($null -eq $manifest.SelectSingleNode("//ns:Package/ns:Properties/desktop6:FileSystemWriteVirtualization", $nsmgr)) {
                        $disFSW = $manifest.CreateElement("desktop6:FileSystemWriteVirtualization", $Script:AppXNamespaces['desktop6'])
                        $disFSW.InnerText = "disabled"
                        $properties.AppendChild($disFSW)
                    }
                    else {
                        Write-Verbose "[INFORMATION] desktop6:FileSystemWriteVirtualization already exist"
                    }
                }
                if ($DisableRegistryWriteVirtualization) {
                    if ($null -eq $manifest.SelectSingleNode("//ns:Package/ns:Properties/desktop6:RegistryWriteVirtualization", $nsmgr)) {
                        $disvreg = $manifest.CreateElement("desktop6:RegistryWriteVirtualization", $Script:AppXNamespaces['desktop6'])
                        $disvreg.InnerText = "disabled"
                        $properties.AppendChild($disvreg)
                    }
                    else {
                        Write-Verbose "[INFORMATION] desktop6:RegistryWriteVirtualization already exist"
                    }
                }
                $manifest.PreserveWhitespace = $false
                $manifest.Save((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
            }
            else {
                Write-Verbose "[INFORMATION] DisableFileSystemWriteVirtualization or DisableRegistryWriteVirtualization are not set - skip"
            }
        }
    }
}
