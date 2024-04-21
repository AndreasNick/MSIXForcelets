function Add-MSIXRegAccessFix {
    <#
.SYNOPSIS
Adds registry access fix for an expanded MSIX folder.

.DESCRIPTION
The Add-MSIXRegAccessFix function adds registry access fix for an expanded MSIX folder. It sets the necessary permissions on the registry keys to allow access.

.PARAMETER MSIXFolder
Specifies the expanded MSIX folder. This parameter is mandatory.

.PARAMETER Force
Indicates whether to force the script to run with administrator privileges. If not specified, the script will output an error message if it is not run as an administrator.

.PARAMETER CustomScript
Specifies a custom script block to be executed after setting the registry access fix. The script block is called with the parameter $TempHive, which represents the temporary registry hive.

.EXAMPLE
>>> The Custom script is optional!
Add-MSIXRegAccessFix -MSIXFolder "C:\Path\To\MSIXFolder" -Force -CustomScript {
            param($TempHive)
            # Wrong key here. Do not use!!!
            $key = "HKLM:$TempHive\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown"
            $name = "bEnableProtectedModeAppContainer"
            $value = 1
            New-Item -Path $key -Force
            New-ItemProperty -Path $key -Name $name -Value $value -PropertyType DWORD -Force
        } 
 }

.NOTES
Idea source url's for the solution: 
https://techcommunity.microsoft.com/t5/modern-work-app-consult-blog/packaging-adobe-reader-dc-for-avd-msix-appattach/ba-p/3572098
https://www.advancedinstaller.com/package-adobe-reader-dc-for-avd-msix-appattach.html
>> someone has made a copy ;-)
    
https://www.nick-it.de
Andreas Nick, 2024

#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Switch] $Force,
        # For Open Reg File. Set RegKeys here. The hive is loaded in HKLM\TempHive\Software 
        # {}
        [scriptblock] $CustomScript #Called with parameter $TempHive
    )   

    if (-not (Test-Path $MSIXFolder)) {
        throw "The specified expanded MSIX folder $($MSIXFolder.FullName) does not exist."
    }

    
    # Check is Admin?
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warning "This script must be run as an administrator."
    }

    $SetACLScriptBlock = {
        param(
            [string] $MSIXFolder
        )
        Write-Output "Folder Path : $MSIXFolder" 
        $HiveTempName = 'TempHive'# + [GUID]::NewGuid().ToString()
        Start-Sleep -Seconds 2
        & reg.exe load $('HKLM\' + $HiveTempName) (Join-Path $MSIXFolder -ChildPath "User.dat") 
        Start-Sleep -Seconds 2
        $everyone = New-Object System.Security.Principal.SecurityIdentifier 'S-1-1-0'
        $acl = Get-Acl -Path $('HKLM:\' + $HiveTempName + '\Software')  

        $acType = [System.Security.AccessControl.AccessControlType]::Allow
        $regRights = [System.Security.AccessControl.RegistryRights]::FullControl
        $inhFlags = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit
        $prFlags = [System.Security.AccessControl.PropagationFlags]::None
        $accessRule = New-Object System.Security.AccessControl.RegistryAccessRule ($everyone, $regRights, $inhFlags, $prFlags, $acType)
        $acl.AddAccessRule($accessRule)

        Set-Acl -Path  $('HKLM:\' + $HiveTempName + '\Software') -AclObject $acl

        Start-Sleep -Seconds 2
    }


    $UnloadRegHive = {
        $HiveTempName = 'TempHive'
        $counter = 0
        while(Test-Path('HKLM:\' + $HiveTempName)) {
            Write-Verbose "Unloading registry hive $($HiveTempName) trying $counter"
            $counter++
            if ($counter -gt 10) {
                Write-Wrror "Could not unload the registry hive $($HiveTempName). Please remove manual"
                break
            }
            Start-Sleep -Seconds 3
            reg.exe unload $('HKLM\' + $HiveTempName)
            Start-Sleep -Seconds 2
        }
    }


    try {
        if (-not $isAdmin) {
            # If the script is not running with admin rights
            if ($PSCmdlet.MyInvocation.BoundParameters["Force"].IsPresent) {
                $scriptContent = $SetACLScriptBlock.ToString()
                $fullCommand = "& { $scriptContent } '$MSIXFolder'"

                # Convert the command to bytes and then to a Base64 string
                $bytes = [System.Text.Encoding]::Unicode.GetBytes($fullCommand)
                $encodedCommand = [Convert]::ToBase64String($bytes)

                # Start the new PowerShell instance with the encoded command
                Start-Process powershell.exe -ArgumentList " -encodedCommand $encodedCommand" -Verb RunAs -Wait #-noexit

                Start-Sleep -seconds 3
                # Custom Script
                $HiveTempName = 'TempHive'# + [GUID]::NewGuid().ToString()
                if ($null -ne $CustomScript) {
                    $CustomScript.Invoke($HiveTempName)
                }
                else {
                    Write-Warning "No CustomScript defined."
                }
                

                Start-Sleep -seconds 3

                $bytes2 = [System.Text.Encoding]::Unicode.GetBytes($UnloadRegHive)
                $encodedCommand2 = [Convert]::ToBase64String( $bytes2 )
                Start-Process powershell.exe -ArgumentList " -encodedCommand $encodedCommand2"  -Verb RunAs -Wait 
				

            }
            else {
                # Otherwise, output an error message
                Write-Error "This script must be run as an administrator. Please re-run as Administrator or with -Force to elevate privileges."
                exit 1
            }
        }
        else {
           
            $scriptContent = $SetACLScriptBlock.ToString()
            $fullCommand = "& { $scriptContent } '$MSIXFolder'"

            # Convert the command to bytes and then to a Base64 string
            $bytes = [System.Text.Encoding]::Unicode.GetBytes($fullCommand)
            $encodedCommand = [Convert]::ToBase64String($bytes)
            Start-Process powershell.exe -ArgumentList " -encodedCommand $encodedCommand" -Wait #-noexit
            
            # Custom Script
            $HiveTempName = 'TempHive'# + [GUID]::NewGuid().ToString()
            if ($null -ne $CustomScript) {
                $CustomScript.Invoke($HiveTempName)
            }
            else {
                Write-Warning "No CustomScript defined."
            }

            Start-Sleep -seconds 2
            $bytes2 = [System.Text.Encoding]::Unicode.GetBytes($UnloadRegHive)
            $encodedCommand2 = [Convert]::ToBase64String( $bytes2 )
            Start-Process powershell.exe -ArgumentList " -encodedCommand $encodedCommand2"  -Wait 

        }
    }

    catch {
        Write-Verbose "Error change virtual registry key permission."
        Write-Error $_.Exception.Message
    }

    finally {
        # Der Hive kann irgendwie nur über einen andren Prozess entladen werden!

    } 
}
    


