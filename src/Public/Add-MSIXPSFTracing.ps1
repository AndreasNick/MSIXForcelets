<#
.SYNOPSIS
Adds tracing configuration for a specific executable in an MSIX package.

.DESCRIPTION
The Add-MSIXPSFTracing function adds tracing configuration for a specific executable in an MSIX package. It modifies the "config.json.xml" file in the MSIX package to include the necessary tracing settings.

.PARAMETER MSIXFolder
The path to the MSIX package folder.

.PARAMETER Executable
The name of the executable to add tracing configuration for. This can be specified as a regular expression pattern.

.PARAMETER TraceMethod
The method to use for tracing. Valid values are 'printf', 'eventlog', and 'outputDebugString'. The default value is 'eventlog'.

.PARAMETER TraceLevel
The level of tracing to enable. Valid values are 'always', 'ignoreSuccess', 'allFailures', 'unexpectedFailures', and 'ignore'. The default value is 'always'.

.PARAMETER IgnoreDllLoad
A switch parameter indicating whether to ignore tracing for DLL loads. By default, DLL loads are not ignored.

.PARAMETER PSFArchitektur
The architecture of the PSF (Package Support Framework) to use. Valid values are '64Bit', '32Bit', and 'Automatic'. The default value is 'Automatic'.

.EXAMPLE
Add-MSIXPSFTracing -MSIXFolder "C:\MyMSIXPackage" -Executable "MyApp.exe" -TraceMethod "eventlog" -TraceLevel "allFailures"
This example adds tracing configuration for the executable "MyApp.exe" in the MSIX package located at "C:\MyMSIXPackage". The tracing method used is "eventlog" and the trace level is set to "allFailures".

.NOTES
- This function requires the "config.json.xml" file to exist in the specified MSIX package folder.
- The function modifies the "config.json.xml" file to add or update the tracing configuration for the specified executable.
- The function saves the modified "config.json.xml" file in the same location.
.LINK
#>

function Add-MSIXPSFTracing {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)] 
        [String] $Executable,
        
        [ValidateSet('printf', 'eventlog', 'outputDebugString')]
        [String] $TraceMethod = 'eventlog',
        
        [ValidateSet('always', 'ignoreSuccess', 'allFailures', 'unexpectedFailures', 'ignore')]
        [String] $TraceLevel = 'always',
        
        [switch] $IgnoreDllLoad,
        
        [ValidateSet('64Bit', '32Bit', 'Automatic')]
        [String] $PSFArchitektur = 'Automatic'
    )
    
    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "config.json.xml") )) {
            Write-Warning "[ERROR] The MSIX config.json.xml does not exist"
            return $null
        }
        else {
            $conxml = New-Object xml
            $conxml.Load((Join-Path $MSIXFolder -ChildPath "config.json.xml"))
            if (-not $conxml.SelectSingleNode('//processes')) {
                Write-Verbose "[INFORMATION] Create processes node"
                $processes = $conxml.CreateElement("processes")
                $conxml.configuration.AppendChild($processes) | Out-Null
            }

            $appNode = $conxml.SelectSingleNode('//processes/process/executable[text()' + "='" + $Executable + "']")
            if (-not $appNode) {
                #Create Executable node
                Write-Verbose "[INFORMATION] Process node for $Executable does not exist, creating the process node"
                [System.Xml.XmlElement] $proc = $conxml.CreateElement("process")
                $exec = $conxml.CreateElement("executable")
                $exec.InnerText = $Executable
                $proc.AppendChild($exec) | Out-Null
                ($conxml.SelectSingleNode('//processes')).AppendChild($proc) | Out-Null
            } 
            $appNode = $conxml.SelectSingleNode('//processes/process/executable[text()' + "='" + $Executable + "']")
    
            if (-not $appNode.ParentNode.fixups) {
                Write-Verbose "[INFORMATION] Create Fixup Element for node $Executable"
                $fixups = $conxml.CreateElement("fixups")
                $appNode.ParentNode.AppendChild($fixups)  | Out-Null
            }

            $fixupNode = $null
            if ($PSFArchitektur -eq '32Bit') {
                $fixupNode = $conxml.SelectSingleNode('//fixups/fixup/dll[text()' + "='TraceFixup32.dll']")
            }
            else {
                $fixupNode = $conxml.SelectSingleNode('//fixups/fixup/dll[text()' + "='TraceFixup64.dll']")
            }

            if (-not $fixupNode) {
                #Create TraceNode
                Write-Verbose "[INFORMATION] Create fixup TraceFixup32.dll Element for node $Executable"
                $fixup = $conxml.CreateElement("fixup")
                $dll = $conxml.CreateElement("dll")
                if ($PSFArchitektur -eq '32Bit') {
                    $dll.InnerText = 'TraceFixup32.dll'
                }
                elseif ($PSFArchitektur -eq '64Bit') {
                    $dll.InnerText = 'TraceFixup64.dll'
                }
                else {
                    $dll.InnerText = 'TraceFixup.dll'
                }
                $fixup.AppendChild($dll)

                $Config = $conxml.CreateElement("config")
                $fixup.AppendChild($config)
          
                $rp = $conxml.CreateElement("traceMethod")
                $rp.InnerText = $TraceMethod
                $Config.AppendChild($rp)
                
                $tls = $conxml.CreateElement("traceLevels")
                $trl = $conxml.CreateElement("traceLevel")
                $trl.SetAttribute("level", 'default')
                $trl.InnerText = $TraceLevel
                $tls.AppendChild($trl)
                $Config.AppendChild($tls)
                $appNode.ParentNode.SelectNodes('fixups').AppendChild($fixup)  | Out-Null
            }
            else {
                #The node exists
            }
            $conxml.PreserveWhitespace = $false
            $conxml.Save((Join-Path $MSIXFolder -ChildPath "config.json.xml"))
        }
    }
}
