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
The monitor program PsfLauncher starts before the app. Resolved relative to the package root.
Defaults to 'VFS\SystemX64\PsfMonitor.exe' - the PsfMonitor shipped by
Add-MSIXPsfFrameworkFiles -IncludePSFMonitor. Override only for a different monitor or location.

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

>>> NOTE <<<
>>> Reference the monitor by a package-root-relative path (e.g. the default
>>> 'VFS\SystemX64\PsfMonitor.exe'). PsfLauncher resolves it against the package install root,
>>> so it points at the real physical file - which an elevated (asadmin) monitor can reach even
>>> though it runs outside the virtual bubble. An absolute 'C:\Windows\System32\...' path does
>>> NOT work, because that location only exists virtualized inside the bubble.
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
        [ArgumentCompleter( { 'VFS\SystemX64\PsfMonitor.exe', 'VFS\SystemX64\PsfMonitorx64.exe', 'VFS\SystemX86\PsfMonitorx86.exe', 'DebugView.exe' })]
        [string] $Executable = 'VFS\SystemX64\PsfMonitor.exe',
        $Arguments = '', #"/g", "/c dir c:\\ /s"
        [switch] $Asadmin,
        [switch] $Monitorwait
    )

    process {
        if (-not (Test-Path $MSIXFolder.FullName -PathType Container)) {
            Write-Error "MSIXFolder not found: $($MSIXFolder.FullName)"
            return
        }

        if ([string]::IsNullOrWhiteSpace($MISXAppID)) {
            Write-Error "-MISXAppID must not be empty or whitespace."
            return
        }

        if ([string]::IsNullOrWhiteSpace($Executable)) {
            Write-Error "-Executable must not be empty."
            return
        }

        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "config.json.xml") )) {
            Write-Error "config.json.xml not found in: $($MSIXFolder.FullName). Run Add-MSXIXPSFShim first."
            return
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
            
            if ($appNode.ParentNode.SelectSingleNode("monitor")) {
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
                $m.wait = 'true'
            }
            $appNode.ParentNode.AppendChild($m) | Out-Null

            # Exclude PsfMonitor itself from fixup injection. Without this the catch-all '.*'
            # process rule also matches PsfMonitor, PSF injects into the monitor, and it can
            # relaunch repeatedly. Add a no-fixup process entry BEFORE the catch-all '.*'
            # (PSF matches processes in order, first match wins) - just like the existing
            # PsfLauncher / PsfFtaCom / PowerShell exclusions.
            $processes = $conxml.SelectSingleNode('//processes')
            if ($processes) {
                $monitorExcl = $processes.SelectSingleNode("process[executable='.*[Pp]sf[Mm]onitor.*']")
                if (-not $monitorExcl) {
                    $excl = $conxml.CreateElement('process')
                    $exclExe = $conxml.CreateElement('executable')
                    $exclExe.InnerText = '.*[Pp]sf[Mm]onitor.*'
                    $excl.AppendChild($exclExe) | Out-Null
                    $catchAll = $processes.SelectSingleNode("process[executable='.*']")
                    if ($catchAll) {
                        $processes.InsertBefore($excl, $catchAll) | Out-Null
                    }
                    else {
                        $processes.AppendChild($excl) | Out-Null
                    }
                    Write-Verbose "Added PsfMonitor process exclusion before the catch-all '.*' rule."
                }
            }

            $conxml.PreserveWhiteSpace = $false
            $conxml.Save((Join-Path $MSIXFolder -ChildPath "config.json.xml"))
        }
    }
}
