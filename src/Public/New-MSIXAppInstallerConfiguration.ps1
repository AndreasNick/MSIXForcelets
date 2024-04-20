function New-MSIXAppInstallerConfiguration {
    param(
      [String] $ConfigFileURL, #Location of the ConfigFile
      [String] $MSIXFileURL, #Location of the ConfigFile
      [String] $OutputPath, 
      [String] $ApplicationName,
      [String] $Publisher,
      [String] $Version,
      [ValidateSet('x86', 'x64', 'ARM')]
      [String] $ProcessorArchitecture = 'x64'
    )
  
  
$AppInstallerConf = [xml] @'
  <?xml version="1.0" encoding="utf-8"?>
    <AppInstaller
      Version="VERSION"
      Uri="CONFIGFILEURL" xmlns="http://schemas.microsoft.com/appx/appinstaller/2018">
      <MainPackage
        Name="APPLICATIONNAME"
        Publisher="PUBLISHER"
        Version="VERSION"
        ProcessorArchitecture="PROCESSORARCHITECTURE"
        Uri="MSIXFILEURL" />
      <UpdateSettings>
        <OnLaunch HoursBetweenUpdateChecks="0" ShowPrompt="true" />
      </UpdateSettings>
    </AppInstaller>
'@
  
    $AppInstallerConf.AppInstaller.Version = $Version
    $AppInstallerConf.AppInstaller.Uri = $ConfigFileURL
    $AppInstallerConf.AppInstaller.MainPackage.Name = $ApplicationName
    $AppInstallerConf.AppInstaller.MainPackage.Publisher = $Publisher
    $AppInstallerConf.AppInstaller.MainPackage.Version = $Version
    $AppInstallerConf.AppInstaller.MainPackage.ProcessorArchitecture = $ProcessorArchitecture
    $AppInstallerConf.AppInstaller.MainPackage.Uri = $MSIXFileURL
  
    $StringWriter = New-Object System.IO.StringWriter
    $XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter
    $xmlWriter.Formatting = "indented"
    $xmlWriter.Indentation = 2
    $AppInstallerConf.WriteContentTo($XmlWriter)
    $XmlWriter.Flush()
    $StringWriter.Flush()
    Write-Output $StringWriter.ToString() | Out-File -Encoding utf8  -FilePath (Join-path $OutputPath -ChildPath $($ApplicationName + '.appinstaller')) 
  
  }