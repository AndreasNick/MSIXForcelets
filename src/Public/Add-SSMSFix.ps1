function Add-SSMSFix {
    [CmdletBinding()]
  
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.FileInfo]
        $MsixFile,
        [System.IO.DirectoryInfo] $MSIXFolder = ($env:Temp + "\MSIX_TEMP_" + [system.guid]::NewGuid().ToString()),
        [Switch] $Force,
        [String] $OutputFilePath = "",
        [String] $Subject = ""

    )      
 
    if ($OutputFileName -eq "") {
        $OutputFileName = $MsixFile
    }

    $Package = Open-MSIXPackage -MsixFile $MsixFile -Force:$force -MSIXFolder $MSIXFolder

    
    #Close-MSIXPackage -MSIXFolder 'c:\temp\ssms' -MSIXFile $OutputFilePath
    #break

    if ($Subject -ne "") {
        Set-MSIXPublisher -MSIXFolder $MsixFolder -PublisherSubject $Subject
    }

    # Check is Admin?
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

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
        reg.exe unload $('HKLM\' + $HiveTempName)
        Start-Sleep -Seconds 1
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
            & $SetACLScriptBlock $MSIXFolder
        }

        Start-Sleep -Seconds 2

        # NOT Working:Move SSMS.exe to the top in AppxManifest.xml
        <#
        $xmlPath = Join-Path -Path $MSIXFolder -ChildPath "AppxManifest.xml"
        $xml = [xml](Get-Content $xmlPath)
        $ssmsApp = $xml.Package.Applications.Application | Where-Object { $_.Id -eq "SSMS" }

        $xml.Package.Applications.RemoveChild($ssmsApp) | Out-Null
        $xml.Package.Applications.PrependChild($ssmsApp) | Out-Null
        $xml.Save($xmlPath)
        #>

        Close-MSIXPackage -MSIXFolder $($Package.FullName) -MSIXFile $OutputFilePath
    }
    catch {
        Write-Verbose "Error adding SSMS Fix" -Verbose
        "Error $_"
    }

}