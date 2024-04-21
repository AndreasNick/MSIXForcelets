

function Add-MSIXFixAcrobatReaderDC {
<#
.SYNOPSIS
    Adds a fix for Acrobat Reader DC to an MSIX package.

.DESCRIPTION
    This function adds a fix for Acrobat Reader DC to an MSIX package. It performs the following steps:
    1. Opens the MSIX package using the Open-MSIXPackage function.
    2. Sets the publisher subject using the Set-MSIXPublisher function, if a subject is provided.
    3. Adds a registry access fix using the Add-MSIXRegAccessFix function.
    4. Sets a virtual registry key using the Set-MSIXVirtualRegistryKey function.
    5. Closes the MSIX package using the Close-MSIXPackage function.

.PARAMETER MsixFile
    Specifies the MSIX file to which the fix should be added. This parameter is mandatory.

.PARAMETER MSIXFolder
    Specifies the folder where the MSIX package will be extracted. If not provided, a temporary folder will be used.

.PARAMETER Force
    Indicates whether to force the operation. If specified, the operation will be performed even if it would overwrite existing files.

.PARAMETER OutputFilePath
    Specifies the path where the modified MSIX package should be saved. If not provided, the original MSIX file will be overwritten.

.PARAMETER Subject
    Specifies the publisher subject to set for the MSIX package.

.EXAMPLE
    Add-MSIXFixAcrobatReaderDC -MsixFile "C:\Path\To\Package.msix" -OutputFilePath "C:\Path\To\ModifiedPackage.msix" -Subject "CN=MyPublisher"

    This example adds a fix for Acrobat Reader DC to the specified MSIX package. It sets the publisher subject to "CN=MyPublisher" and saves the modified package to the specified output file path.

.NOTES
    source url's for the solution: 
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
        [System.IO.FileInfo] $MsixFile,
        [System.IO.DirectoryInfo] $MSIXFolder = ($env:Temp + "\MSIX_TEMP_" + [system.guid]::NewGuid().ToString()),
        [Switch] $Force,
        [System.IO.FileInfo] $OutputFilePath = $null,
        [String] $Subject = ""

    )  
    if ($null -eq $OutputFilePath) {
        $OutputFilePath = $MsixFile
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warning "The Acrobat Reader DC MSIX Fix  must be run as an administrator! Stop"
        throw "The Acrobat Reader DC MSIX Fix  must be run as an administrator! Stop"
    }

    $Package = Open-MSIXPackage -MsixFile $MsixFile -Force:$force -MSIXFolder $MSIXFolder
    

    try {
        if ($Subject -ne "") {
            Set-MSIXPublisher -MSIXFolder $MsixFolder -PublisherSubject $Subject
        }

        $IsForce = $PSCmdlet.MyInvocation.BoundParameters["Force"].IsPresent -eq $true
        Add-MSIXRegAccessFix -MSIXFolder $MSIXFolder -force:$IsForce -Verbose #Change registry user rights, onlay as admin! 

        # Set Keys in the virtual HKLM Reg
        #Set-MSIXVirtualRegistryKey -HiveFilePath (Join-Path $Package -ChildPath "Registry.dat") -KeyPath "REGISTRY\MACHINE\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown" -ValueName "bEnableProtectedModeAppContainer" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
        #Set-MSIXVirtualRegistryKey -HiveFilePath (Join-Path $Package -ChildPath "Registry.dat") -KeyPath "REGISTRY\MACHINE\SOFTWARE\WOW6432Node\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown" -ValueName "bEnableProtectedModeAppContainer" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-MSIXVirtualRegistryKey -HiveFilePath (Join-Path $Package -ChildPath "Registry.dat") -KeyPath "REGISTRY\MACHINE\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown" -ValueName "bProtectedMode" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-MSIXVirtualRegistryKey -HiveFilePath (Join-Path $Package -ChildPath "Registry.dat") -KeyPath "REGISTRY\MACHINE\SOFTWARE\WOW6432Node\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown" -ValueName "bProtectedMode" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)



        # Script for the user.dat (wrong hive)
        <#
        -CustomScript {
            param($TempHive)
            #Create  DWORD bEnableProtectedModeAppContainer=1 in  REGISTRY\MACHINE\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown
            Write-Verbose "Adding AcrobatReader fix reg bEnableProtectedModeAppContainer=1"
            $key = "HKLM:$TempHive\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown"
            Write-Verbose "in $key"
            $name = "bEnableProtectedModeAppContainer"
            $value = 1
            New-Item -Path $key -Force
            New-ItemProperty -Path $key -Name $name -Value $value -PropertyType DWORD -Force
        } 
        #> 
      
    }
    catch {
        Write-Error "Error adding AcrobatReader Fix" 
        Write-Verbose "Error $_"
        throw "Error adding AcrobatReader Fix" 
    }

    try {
        
    }

    finally {
       Close-MSIXPackage -MSIXFolder $($Package.FullName) -MSIXFile $OutputFilePath 
    }
}