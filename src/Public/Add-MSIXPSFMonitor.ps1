<#
.SYNOPSIS
Adds a PSF Monitor configuration to the MSIX config.json.xml file.

.DESCRIPTION
The Add-MSIXPSFMonitor function adds a PSF Monitor configuration to the MSIX config.json.xml file for a specific MSIX application. The PSF Monitor allows monitoring and intercepting of certain executables within the MSIX package.

.PARAMETER MSIXFolder
The path to the folder containing the MSIX package.

.PARAMETER MISXAppID
The ID of the MSIX application to add the PSF Monitor configuration for.

.PARAMETER Executable
The path to the executable to be monitored by the PSF Monitor.

.PARAMETER Arguments
Optional. Additional arguments to be passed to the monitored executable.

.PARAMETER Asadmin
Optional switch. Specifies whether the monitored executable should be run with administrator privileges.

.PARAMETER Monitorwait
Optional switch. Specifies whether the PSF Monitor should wait for the monitored executable to exit before continuing.

.NOTES
- The function requires the AdministratorCapability capability.
- The function modifies the config.json.xml file within the MSIX package.
- Need Capability AdministratorCapability

>>> ATTANTION <<<
>>> "c:/Windows/System32/PSFMonitor.exe" not work anymore. Need Admin rights and run as admin is not enough
>>> The CMD is started outside the virtual bubble. Therefore I cannot start a PSF monitor here either
>>> without "AsAdmin" a CMD.exe does not work. Because rights and deeded Files are missing.
>>>>>>>>-<<<<<<<<

Author: Andreas Nick
Date: 01/10/2022
https://www.nick-it.de


.EXAMPLE
Add-MSIXPSFMonitor -MSIXFolder "C:\MyMSIXPackage" -MISXAppID "MyApp" -Executable "C:\Windows\System32\cmd.exe" -Asadmin -Verbose
Adds a PSF Monitor configuration to the MSIX config.json.xml file for the "MyApp" MSIX application. The PSF Monitor will monitor the "cmd.exe" executable and run it with administrator privileges.
Get-MSIXApplications -MSIXFolder $Package | Add-MSIXPSFMonitor -MSIXFolder $Package -Executable "c:/Windows/System32/cmd.exe" -Asadmin -Verbose
Add-MSIXCapabilities -MSIXFolder $Package -Capabilities "runFullTrust", "allowElevation" -Verbose

#>
function Add-MSIXPSFMonitor {
    [CmdletBinding()]
    #[OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)] 
        [Alias('Id')] 
        [String] $MISXAppID,
        [Parameter(Mandatory = $true)]
        [ArgumentCompleter( { 'c:/windows/system32/PsfMonitorx64.exe', 'c:/windows/SysWOW64/PsfMonitorx86.exe', 'DebugView.exe', 'c:/Windows/System32/cmd.exe' })]
        $Executable, #"PsfMonitorX64.exe", "c:/windows/system32/cmd.exe", "DebugView.exe"...
        $Arguments = '', #"/g", "/c dir c:\\ /s"
        [switch] $Asadmin,
        [switch] $Monitorwait
    )

    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "config.json.xml") )) {
            Write-Warning "[ERROR] The MSIX config.json.xml not exist"
            return $null
        }
        else {
            $conxml = New-Object xml
            $conxml.Load((Join-Path $MSIXFolder -ChildPath "config.json.xml"))
            $appNode = $conxml.SelectSingleNode('//application/id[text()' + "='" + $MISXAppID + "']")

            if ($null -eq $appNode) {
                throw "ERROR The application not exist in MSIX config.json.xml - skip"
                #return $null
            }

            # Check if a monitor with the same executable already exists
            Write-Verbose "Checking if monitor executable '$Executable' is already configured for this application."
            
            if ($appNode.SelectSingleNode("//application/monitor")) {
                Write-Warning "A Monitor entry is already configured for this application - skipping for '$Executable'."
                return $null
            }

            
            #<monitor>
            #<executable>PsfMonitor.exe</executable>
            #<arguments></arguments>
            #<asadmin>true</asadmin>
            #</monitor>

            $m = $conxml.CreateElement("monitor") 
            $m.AppendChild($conxml.CreateElement("executable")) | Out-Null
            $m.executable = $Executable

            if ($Arguments -ne '') {
                $m.AppendChild($conxml.CreateElement("arguments")) | Out-Null
                $m.arguments = $Arguments
            }
            if ($Asadmin) {
                $m.AppendChild($conxml.CreateElement("asadmin")) | Out-Null
                $m.asadmin = 'true'
            }
            if ($Monitorwait) {
                $m.AppendChild($conxml.CreateElement("wait")) | Out-Null
                $m.asadmin = 'wait'
            }
            $appNode.ParentNode.AppendChild($m) | Out-Null
            $conxml.PreserveWhiteSpace = $false
            $conxml.Save((Join-Path $MSIXFolder -ChildPath "config.json.xml"))
        }
    }
}
