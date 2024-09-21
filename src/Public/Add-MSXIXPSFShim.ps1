

function Add-MSXIXPSFShim {
<#
.SYNOPSIS
Adds a PSF shim to an MSIX application.

.DESCRIPTION
The Add-MSXIXPSFShim function adds a PSF (Package Support Framework) shim to an MSIX application. 
The PSF shim allows for intercepting and modifying application behavior without modifying the original application code.

.PARAMETER MSIXFolder
The path to the MSIX folder (expanded MSIX package) where the AppxManifest.xml and config.json.xml files are located.

.PARAMETER MISXAppID
The MSIX application ID.

.PARAMETER WorkingDirectory
The working directory for the application.

.PARAMETER Arguments
The arguments for the application.

.PARAMETER PSFArchitektur
The architecture of the PSF launcher to use. Valid values are '64Bit' and '32Bit'.

.OUTPUTS
Returns an integer indicating the success or failure of the operation.

.EXAMPLE
Add-MSXIXPSFShim -MSIXFolder "C:\MSIXFolder" -MISXAppID "MyApp" -WorkingDirectory "C:\MyApp" -Arguments "-arg1 value1"

This example adds a PSF shim to the MSIX application with the ID "MyApp" located in the "C:\MSIXFolder" directory. 
The working directory for the application is set to "C:\MyApp" and the arguments are set to "-arg1 value1".

.NOTES
The Add-MSXIXPSFShim function requires the PSF (Package Support Framework) to be installed on the system.
Make sure to run this function with administrative privileges.
https://www.nick-it.de
Andreas Nick, 2022


#>

    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder, #Path to the MSIX Folder (expanded MSIX Package)
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)] 
        [Alias('Id')] 
        [String] $MISXAppID, #MSIX Application ID
        [String] $WorkingDirectory = '', #Working directory for the application
        [String] $Arguments = '', #Argumens for the application
        [ValidateSet('64Bit', '32Bit')] #Depends on the application architecture PSFLauncher32 for 32Bit and PSFLauncher64 for 64Bit
        [String] $PSFArchitektur = '32Bit'
    )
 
    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            Write-Error "The MSIX temporary folder does not exist"
            return $null
        }
        else {
            Write-Verbose "Add PSF shim: $MISXAppID"
            $AppxManigest = New-Object xml
            $AppxManigest.Load((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
            
            $ns = New-Object System.Xml.XmlNamespaceManager $AppxManigest.NameTable 
            $ns.AddNamespace("ns", 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
            #$AppxManigest.SelectNodes("//Applications/Application ",$ns)            
            $node = $AppxManigest.SelectSingleNode($("//ns:Application[@Id=" + "'" + $MISXAppID + "']"), $ns)

            if ($null -eq $node) {
                Write-Warning "Application $MISXAppID not found"
            }
            else {
                #Change App In AppXManifest
                #Save the exec Path
                $Executable = $node.Executable
                if ($PSFArchitektur -eq "64Bit") {
                    $node.Executable = "PsfLauncher64.exe"
                }
                else {
                    $node.Executable = "PsfLauncher32.exe"
                }
                #Change App in the Config.json template
                $conxml = New-Object xml
                
                if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "config.json.xml") )) {
                    $conxml = [xml] '<configuration><applications></applications></configuration>'
                }
                else {
                    #Load Config
                    $conxml.Load((Join-Path $MSIXFolder -ChildPath "config.json.xml"))
                }
                #Add Application
                $appnode = $conxml.SelectSingleNode('//application/id[text()' + "='" + $MISXAppID + "']")
                if ($null -eq $appnode) {
                    Write-Verbose "[Information] Add $MISXAppID to config.json.xml"
                    $approot = $conxml.SelectSingleNode('//applications')
                    $r = $conxml.CreateElement("application") 
                    $r.AppendChild($conxml.CreateElement("id")) | Out-Null
                    $r.AppendChild($conxml.CreateElement("executable")) | Out-Null
                    #
                    $r.AppendChild($conxml.CreateElement("workingDirectory")) | Out-Null
                    if ($WorkingDirectory -ne '') {
                        $r.workingDirectory = $WorkingDirectory
                    }
                    if ($Arguments -ne '') {
                        $r.AppendChild($conxml.CreateElement("arguments")) | Out-Null
                        $r.workingDirectory = $Arguments
                    }

                    $r.id = $MISXAppID
                    #$r.executable = $($Executable -replace '\\', '/')
                    $r.executable = $($Executable -replace '\\', '\\')
                    $approot.AppendChild($r) | Out-Null
                    #Save config
                    $conxml.PreserveWhiteSpace = $false
                    $conxml.Save((Join-Path $MSIXFolder -ChildPath "config.json.xml"))
                }
                $AppxManigest.Save((Join-Path $MSIXFolder -ChildPath "AppxManifest.xml"))
                # Create config.json
                #
            }
        }
    }
}
