function Add-MSIXPSFPowerShellScript {
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
        [Alias('Id')] 
        [String] $MISXAppID,
        [Parameter(Mandatory = $true, ParameterSetName = 'StartScript')]
        [switch] $StartScript,
        [Parameter(Mandatory = $true, ParameterSetName = 'EndScript')]
        [switch] $EndScript,
        [Parameter(Mandatory = $true)]
        [ArgumentCompleter( { 'Startscript.ps1', 'Endscript.ps1' })]
        [String]$ScriptPath, 
        [ArgumentCompleter( { '%MsixWritablePackageRoot%\\VFS\LocalAppData\\Vendor' })]
        [String] $ScriptArguments, 
        [ArgumentCompleter( { '-ExecutionPolicy Bypass' })]
        [String] $ScriptExecutionMode,
        [switch] $StopOnScriptError,
        [switch] $RunOnce,
        [switch] $ShowWindow,
        [Parameter(ParameterSetName = 'StartScript')]
        [switch] $WaitForScriptToFinish,
        [Parameter(ParameterSetName = 'StartScript')]
        [int] $ScriptTimeout = -1
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

        if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
            Write-Error "-ScriptPath must not be empty."
            return
        }
        if ($ScriptPath -match '/') {
            Write-Warning "-ScriptPath '$ScriptPath' contains a forward slash. Use backslash for package-relative paths."
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
                Write-Warning "[ERROR] The application not exist in MSIX config.json.xml - skip"
                return $null
            }
            else {
                <#
                "stopOnScriptError": false,
                "scriptExecutionMode": "-ExecutionPolicy Bypass",
                "startScript":
                {
                  "waitForScriptToFinish": true,
                  "timeout": 30000,
                  "runOnce": true,
                  "showWindow": false,
                  "scriptPath": "PackageStartScript.ps1",
                  "waitForScriptToFinish": true
                  "scriptArguments": "%MsixWritablePackageRoot%\\VFS\LocalAppData\\Vendor",
                },
                "endScript":
                {
                  "scriptPath": "\\server\scriptshare\\RunMeAfter.ps1",
                  "scriptArguments": "ThisIsMe.txt"
                }
                #>
                $m = $null

                if ($ScriptExecutionMode -ne "") {
                    $em = $conxml.SelectSingleNode('//application/id[text()' + "='" + $MISXAppID + "']/../scriptExecutionMode")
                    if ($em) {
                        $em.InnerText = $ScriptExecutionMode
                    }
                    else {
                        $em = $conxml.CreateElement("scriptExecutionMode") 
                        
                        $appNode.ParentNode.AppendChild($em)
                        $em.InnerText = $ScriptExecutionMode
                        $appNode.ParentNode.AppendChild($em)
                    }
                }
                if ($StopOnScriptError.IsPresent) {
                    $em = $conxml.SelectSingleNode('//application/id[text()' + "='" + $MISXAppID + "']/../stopOnScriptError")
                    if ($em) {
                        $em.InnerText = $StopOnScriptError.ToString().ToLower()
                    }
                    else {
                        $em = $conxml.CreateElement("stopOnScriptError") 
                        $em.InnerText = $StopOnScriptError.ToString().ToLower()
                        $appNode.ParentNode.AppendChild($em)
                    }
                }
                else {
                    $em = $conxml.SelectSingleNode('//application/id[text()' + "='" + $MISXAppID + "']/../stopOnScriptError")
                    if ($em) {
                        Write-Verbose "[INFORMATION] Remove stopOnScriptError node for $MISXAppID"
                        $em.ParentNode.RemoveChild($em)
                    }
                }

                if ($StartScript.IsPresent) {
                    if ($conxml.SelectSingleNode('//application/id[text()' + "='" + $MISXAppID + "']/../startScript")) {
                        Write-Warning "[WARNING] A start script for $MISXAppID already exist. Please remove it first"
                    }
                    else {
                        $m = $conxml.CreateElement("startScript") 
                    }
                }

                if ($EndScript.IsPresent) {
                    if ($conxml.SelectSingleNode('//application/id[text()' + "='" + $MISXAppID + "']/../endScript")) {
                        Write-Warning "[WARNING] A end script for $MISXAppID already exist. Please remove it first"
                    }
                    else {
                        $m = $conxml.CreateElement("endScript") 
                    }
                }

                if ($m) {
                    if ($ScriptTimeout -ge 0) {
                        $to = $conxml.CreateElement("timeout")
                        $to.InnerText = $ScriptTimeout
                        $m.AppendChild($to) | Out-Null
                    }

                    if ($WaitForScriptToFinish.IsPresent) {
                        $wa = $conxml.CreateElement("waitForScriptToFinish")
                        $wa.InnerText = $WaitForScriptToFinish.ToString().ToLower()
                        $m.AppendChild($wa) | Out-Null
                    }

                    if ($ShowWindow.IsPresent) {
                        $sw = $conxml.CreateElement("showWindow")
                        $sw.InnerText = $ShowWindow.ToString().ToLower()
                        $m.AppendChild($sw) | Out-Null
                    }

                    if ($RunOnce.IsPresent) {
                        $sw = $conxml.CreateElement("runOnce")
                        $sw.InnerText = $RunOnce.ToString().ToLower()
                        $m.AppendChild($sw) | Out-Null
                    }

                    if ($ScriptArguments -ne "") {
                        $sw = $conxml.CreateElement("scriptArguments")
                        $sw.InnerText = $ScriptArguments
                        $m.AppendChild($sw) | Out-Null
                    }   

                    $sp = $conxml.CreateElement("scriptPath")
                    $sp.InnerText = $ScriptPath
                    $m.AppendChild($sp) | Out-Null

                    $appNode.ParentNode.AppendChild($m)
                    $conxml.PreserveWhiteSpace = $false
                    $conxml.Save((Join-Path $MSIXFolder -ChildPath "config.json.xml"))
                }
            }
        }
    }
}
