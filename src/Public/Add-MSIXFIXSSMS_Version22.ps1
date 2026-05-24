
<# not working today #>

function Add-MSIXFixSSMSVersion22 {
<#
.SYNOPSIS
    Repairs an SSMS 21/22 MSIX package (VS2022-shell based) so its applications start.

.DESCRIPTION
    Repairs an SSMS 21/22 MSIX package
.PARAMETER MsixFile
    The SSMS MSIX file to fix. Mandatory.

.PARAMETER MSIXFolder
    Working folder for the expanded package. Defaults to a unique temp folder.

.PARAMETER Force
    Forwarded to Open-MSIXPackage; also allows the registry-ACL step to elevate.

.PARAMETER OutputFilePath
    Target path for the fixed MSIX. Defaults to overwriting MsixFile.

.PARAMETER Subject
    Optional publisher subject to set (Set-MSIXPublisher).

.PARAMETER RemoveServices
    Remove captured windows.service declarations. Default $true.

.PARAMETER RemoveAppRuntimeDependency
    Remove the Microsoft.WindowsAppRuntime.* PackageDependency. Default $true.

.PARAMETER RemoveSetupApp
    Remove the leftover Visual Studio Installer "SETUP" application. Default $true.

.PARAMETER EnableILV
    Add InstalledLocationVirtualization. Default $true.

.PARAMETER EnableMFR
    Add Tim Mangan MFRFixup (requires the Tim Mangan PSF to be the active
    framework). Default $true.

.PARAMETER SetRegistryACL
    Grant write access to User.dat\Software (virtual HKCU). Requires admin
    (or -Force to elevate). Default $true.

.PARAMETER PSFArchitecture
    PSF binary architecture. Default 'x64' (SSMS 21+ is 64-bit).

.EXAMPLE
    Add-MSIXFixSSMSVersion22 -MsixFile 'C:\Pkg\SSMS22.msix' -Force

.EXAMPLE
    # Only strip the VS ballast, no PSF/ILV:
    Add-MSIXFixSSMSVersion22 -MsixFile $msix -EnableILV:$false -EnableMFR:$false -SetRegistryACL:$false

.NOTES
    Background and the SSMS 20-vs-22 manifest diff are documented in
    Test\InternalDocs\MSIX-Grundlagen-KB.md.
    FRF and MFR must never be combined on the same process - this fix uses MFR only.
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, Position = 0)]
        [System.IO.FileInfo] $MsixFile,

        [System.IO.DirectoryInfo] $MSIXFolder = ($env:Temp + '\MSIX_TEMP_' + [System.Guid]::NewGuid().ToString()),
        [Switch] $Force,
        [System.IO.FileInfo] $OutputFilePath = $null,
        [String] $Subject = '',

        [bool] $RemoveServices             = $true,
        [bool] $RemoveAppRuntimeDependency = $true,
        [bool] $RemoveSetupApp             = $true,
        [bool] $EnableILV                  = $true,
        [bool] $EnableMFR                  = $true,
        [bool] $SetRegistryACL             = $true,

        [ValidateSet('x64', 'x86')]
        [String] $PSFArchitecture = 'x64'
    )

    if ($null -eq $OutputFilePath) {
        $OutputFilePath = $MsixFile
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    # Grants Everyone FullControl on User.dat\Software (virtual HKCU) so SSMS can
    # persist user settings. Runs in a separate (optionally elevated) process
    # because the hive must be loaded with reg.exe and the file is locked otherwise.
    $SetACLScriptBlock = {
        param([string] $MSIXFolder)
        $HiveTempName = 'TempHiveSSMS22'
        Start-Sleep -Seconds 2
        & reg.exe load $('HKLM\' + $HiveTempName) (Join-Path $MSIXFolder -ChildPath 'User.dat')
        Start-Sleep -Seconds 2
        $everyone   = New-Object System.Security.Principal.SecurityIdentifier 'S-1-1-0'
        $acl        = Get-Acl -Path $('HKLM:\' + $HiveTempName + '\Software')
        $acType     = [System.Security.AccessControl.AccessControlType]::Allow
        $regRights  = [System.Security.AccessControl.RegistryRights]::FullControl
        $inhFlags   = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit
        $prFlags    = [System.Security.AccessControl.PropagationFlags]::None
        $accessRule = New-Object System.Security.AccessControl.RegistryAccessRule ($everyone, $regRights, $inhFlags, $prFlags, $acType)
        $acl.AddAccessRule($accessRule)
        Set-Acl -Path $('HKLM:\' + $HiveTempName + '\Software') -AclObject $acl
        Start-Sleep -Seconds 2
    }

    $UnloadRegHive = {
        $HiveTempName = 'TempHiveSSMS22'
        reg.exe unload $('HKLM\' + $HiveTempName)
        Start-Sleep -Seconds 1
    }

    $Package = Open-MSIXPackage -MsixFile $MsixFile -Force:$Force -MSIXFolder $MSIXFolder

    try {
        if ($Subject -ne '') {
            Set-MSIXPublisher -MSIXFolder $MSIXFolder -PublisherSubject $Subject
        }

        # --- 1. Strip captured Visual Studio installer services ---------------
        if ($RemoveServices) {
            $services = Get-MSIXServices -MSIXFolder $MSIXFolder
            if ($services) {
                $services | Remove-MSIXServices
                Write-Verbose "Removed services: $(($services.ServiceName) -join ', ')"
            }
            else {
                Write-Verbose 'No windows.service declarations found.'
            }
        }

        # --- 2. Drop the WindowsAppRuntime PackageDependency ------------------
        if ($RemoveAppRuntimeDependency) {
            $deps = Get-MSIXDependencies -MSIXFolder $MSIXFolder |
                Where-Object { $_.Name -like 'Microsoft.WindowsAppRuntime*' }
            if ($deps) {
                $deps | Remove-MSIXDependencies
                Write-Verbose "Removed dependency: $(($deps.Name) -join ', ')"
            }
            else {
                Write-Verbose 'No WindowsAppRuntime dependency found.'
            }
        }

        # --- 3. Remove the leftover Visual Studio Installer SETUP app ----------
        if ($RemoveSetupApp) {
            $apps = Get-MSIXApplications -MSIXFolder $MSIXFolder
            if ($apps.Id -contains 'SETUP') {
                Remove-MSIXApplications -MSIXFolder $MSIXFolder -MISXAppID 'SETUP'
                Write-Verbose 'Removed Visual Studio Installer application "SETUP".'
            }
        }

        # --- 4. InstalledLocationVirtualization (file-system COW) -------------
        if ($EnableILV) {
            Add-MSIXInstalledLocationVirtualization -MSIXFolderPath $MSIXFolder
            Write-Verbose 'Added InstalledLocationVirtualization.'
        }

        # --- 5. Tim Mangan MFRFixup (Modern File Redirection), ILV-aware ------
        if ($EnableMFR) {
            Add-MSIXPsfFrameworkFiles -MSIXFolder $MSIXFolder -PSFArchitektur $PSFArchitecture -MFFixup

            # Wrap every remaining application in PsfLauncher so PsfRuntime loads
            foreach ($app in (Get-MSIXApplications -MSIXFolder $MSIXFolder)) {
                $null = Add-MSXIXPSFShim -MSIXFolder $MSIXFolder -MISXAppID $app.Id -PSFArchitektur $PSFArchitecture
                Write-Verbose "Wrapped application '$($app.Id)' with PsfLauncher."
            }

            # ilvAware=true -> ILV owns Copy-on-Write, MFR only intercepts paths
            Add-MSIXPSFMFRFixup -MSIXFolder $MSIXFolder -IlvAware $EnableILV
            Write-Verbose "Added MFRFixup (ilvAware=$EnableILV)."
        }

        # --- 6. Grant write access to the virtual HKCU (User.dat\Software) ----
        if ($SetRegistryACL) {
            if ((Test-Path (Join-Path $MSIXFolder 'User.dat'))) {
                $scriptContent = $SetACLScriptBlock.ToString()
                $fullCommand   = "& { $scriptContent } '$MSIXFolder'"
                $encodedSet    = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($fullCommand))
                $encodedUnload = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($UnloadRegHive.ToString()))

                if ($isAdmin) {
                    Start-Process powershell.exe -ArgumentList " -encodedCommand $encodedSet"    -Wait
                    Start-Sleep -Seconds 2
                    Start-Process powershell.exe -ArgumentList " -encodedCommand $encodedUnload" -Wait
                }
                elseif ($Force) {
                    Start-Process powershell.exe -ArgumentList " -encodedCommand $encodedSet"    -Verb RunAs -Wait
                    Start-Sleep -Seconds 2
                    Start-Process powershell.exe -ArgumentList " -encodedCommand $encodedUnload" -Verb RunAs -Wait
                }
                else {
                    Write-Warning 'SetRegistryACL needs administrator rights. Re-run as admin or with -Force. Skipping registry ACL step.'
                }
                Start-Sleep -Seconds 2
            }
            else {
                Write-Warning "User.dat not found in '$MSIXFolder' - skipping registry ACL step."
            }
        }

        Write-Verbose "Re-packing fixed MSIX to: $OutputFilePath"
        Close-MSIXPackage -MSIXFolder $($Package.FullName) -MSIXFile $OutputFilePath -Force:$Force
        Write-Verbose 'SSMS 22 fix applied. Remember to sign the package (Set-MSIXSignature).'
    }
    catch {
        Write-Error "Error applying SSMS 22 fix: $_"
        throw
    }
}
