#Get Script root with myinvocation
$ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module "$ScriptRoot\..\src\MSIXForcelets.psm1" -verbose -Force 

$CertPassword = 'mypass' | ConvertTo-SecureString -Force -AsPlainText
$CertPath = "$ScriptRoot\NewSelfSigningCert.pfx"
$MSIXOutputfilename = "$env:userProfile\Desktop\FreeOrion_5.0.1.0_x64_NewFile.msix"

break

#$Subject = 'CN=Nick Informationstechnik GmbH, O=Nick Informationstechnik GmbH, L=Hannover, S=Niedersachsen, C=DE'
$Subject = (Get-PfxData -FilePath $CertPath -Password $CertPassword).EndEntityCertificates.subject
$Package = Open-MSIXPackage -MsixFile "$env:userProfile\Desktop\FreeOrion_5.0.1.0_x64__5g7qmyvpqtbge.msix" -Force

Set-MSIXPublisher -MSIXFolder $Package -PublisherSubject $Subject
Get-MSIXPackageVersion -MSIXFolder $Package

break

Set-MSIXActivePSFFramework -version TimManganPSF
Add-MSIXPsfFrameworkFiles -MSIXFolder $Package -PSFArchitektur 64And32Bit -TraceFixup -IncludePSFMonitor -Verbose 
#Remove-MSIXPsfFiles -MSIXFolder $Package -Verbose
Remove-MSIXPSFMonitorFiles -MSIXFolder $Package -Verbose

Backup-MSIXManifest -MSIXFolder $Package 

#Restore Manifest if Backup Exist
Copy-Item "$Package\*_AppxManifest.xml" -Destination "$Package\appxmanifest.xml" -Force
Remove-Item $Package\Config.json.xml -Force

$apps = Get-MSIXApplications -MSIXFolder $Package

# Create json entries with Working directory
# This comment specifies the file path of the script. It indicates that both forward slashes and backslashes are allowed, except for a single backslash. 
# If a single backslash is present, it should be replaced with a forward slash using the Replace('\', '/') method.
#$WorkingDirectory = (Split-Path $app.Executable -Parent).Replace('\', '/') 

# FreeOrion need a Working Directory!
$WorkingDirectory = 'C:/Program Files (x86)/FreeOrion'


foreach($app in $apps) {
    Update-MSIXVisualElements -MSIXFolder $Package  -ApplicationId $app.ID -AppListEntry "default"
    
    $exe = Join-Path -Path $Package -ChildPath $app.Executable
    if((Get-MSIXAppExeArchitectureType $exe ) -eq 'I386') {
        Add-MSXIXPSFShim -MSIXFolder $Package -PSFArchitektur 32Bit -MISXAppID $app.Id  #-WorkingDirectory $WorkingDirectory -Verbose
    }
    else {
        Add-MSXIXPSFShim -MSIXFolder $Package -PSFArchitektur 64Bit -MISXAppID $app.Id  #-WorkingDirectory $WorkingDirectory -Verbose
    }
}

# Not needed - i sugest zu start the Monitor outside, if deeded
# Need Capability AdministratorCapability
# "c:/Windows/System32/PSFMonitor.exe" not work anymore. Need Admin rights and run as admin is not enough
# >> Die CMD wird außerhalb der virtuellen Blase gestartet. Daher kann ich auch hier keinen PSF Monitor starten
# >> Ohne "AsAdmin" funktioniert eine CMD.exe nicht. Da Rechte fehlen.
#Get-MSIXApplications -MSIXFolder $Package | Add-MSIXPSFMonitor -MSIXFolder $Package -Executable "c:/Windows/System32/cmd.exe" -Asadmin -Verbose
#Add-MSIXCapabilities -MSIXFolder $Package -Capabilities "runFullTrust", "allowElevation" -Verbose

Add-MSIXPSFTracing -MSIXFolder $Package -Executable "FreeOrion" -PSFArchitektur 32Bit -TraceMethod outputDebugString -TraceLevel allFailures -Verbose

#& explorer.exe $Package 

break

$package | Close-MSIXPackage -MSIXFile $MSIXOutputfilename -KeepMSIXFolder -Verbose
Set-MSIXSignature -MSIXFile $MSIXOutputfilename -PfxCert $CertPath  -CertPassword $CertPassword 

break
Get-AppPackage FreeOrion* | Remove-AppPackage






