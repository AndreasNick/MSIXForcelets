Add-Type -AssemblyName System.IO
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$AppxManifestInfo = "Name, DisplayName, Publisher, ProcessorArchitecture, Version, Description, ConfigPath, UncompressedSize, MaxfileSize, MaxfilePath, FileCount, Applications"
$AppxManifestInfo = @($AppxManifestInfo.replace("`n", "").replace("`r", "").replace(" ", "").split(',') )
Remove-TypeData -TypeName 'AppxManifestInfo' -ea SilentlyContinue

$AppxManifestConfig = @{
  MemberType = 'NoteProperty'
  TypeName   = 'AppxManifestInfo'
  Value      = $null
}
foreach ($item in $AppxManifestInfo) {
  Update-TypeData @AppxManifestConfig -MemberName $item -force
}

#Icon Extractor return Format
$IconInfo = @("Target", "Base64Image", "ImageType")

$IconConfig = @{
  MemberType = 'NoteProperty'
  TypeName   = 'MSIXIconObject'
  Value      = $null
}
foreach ($item in $IconInfo) {
  Update-TypeData @IconConfig -MemberName $item -force
}

function Get-ReadAllBytes([System.IO.BinaryReader] $reader) {
  
  $bufferSize = 4096
  $ms = New-object System.IO.MemoryStream
  $buffer = new-Object byte[] $bufferSize
  $count = 0
  do {
    $count = $reader.Read($buffer, 0, $buffer.Length)
    If ($count -gt 0) { 
      $ms.Write($buffer, 0, $count)
    }
  } While ($count -ne 0)

  
  $ms.Close()
  return $ms.ToArray()
}

function Get-BitmapAsIconStream {
  <#
      .SYNOPSIS
      Helper funtions. Icons are not supportet from a dotnet class    
    
      .DESCRIPTION
      Helper funtions. Icons are not supportet from a dotnet class   
    
      .PARAMETER SourceBitmap
      A Bitmap Image
    
      .PARAMETER Fs
      fs [System.IO.MemoryStream
    
      .NOTES
      https://stackoverflow.com/questions/11434673/bitmap-save-to-save-an-icon-actually-saves-a-png
    #>
    
  param (
    [Parameter( Position = 0, Mandatory = $true, ValueFromPipelineByPropertyName = $True)] 
    [System.Drawing.Bitmap] $SourceBitmap, 
    [Parameter( Position = 1, Mandatory = $true, ValueFromPipelineByPropertyName = $True)] 
    [System.IO.MemoryStream] $Fs
  )
    
  # ICO header
  $Fs.WriteByte(0)
  $Fs.WriteByte(0)
  $Fs.WriteByte(1) 
  $Fs.WriteByte(0)
  $Fs.WriteByte(1) 
  $Fs.WriteByte(0)

  # Image size
  $Fs.WriteByte([byte] $SourceBitmap.Width)
    
  $Fs.WriteByte([byte] $SourceBitmap.Height)
  # Palette
  $Fs.WriteByte(0)
  # Reserved
  $Fs.WriteByte(0)
  # Number of color planes
  $Fs.WriteByte(0)
  $Fs.WriteByte(0)
  # Bits per pixel
  $Fs.WriteByte(32)
  $Fs.WriteByte(0)

  # Data size, will be written after the data
  $Fs.WriteByte(0)
  $Fs.WriteByte(0)
  $Fs.WriteByte(0)
  $Fs.WriteByte(0)

  # Offset to image data, fixed at 22
  $Fs.WriteByte(22)
  $Fs.WriteByte(0)
  $Fs.WriteByte(0)
  $Fs.WriteByte(0)

  # Writing actual data
  $null = $SourceBitmap.Save($Fs, [System.Drawing.Imaging.ImageFormat]::png)

  # Getting data length (file length minus header)
  [long] $Len = $FS.Length - 22

  # Write it in the correct place
  $null = $Fs.Seek(14, [System.IO.SeekOrigin]::Begin)
  $Fs.WriteByte([byte] ($Len -band 0x00ff))
  $Fs.WriteByte([byte] ($Len -shr 8))
  $Fs.WriteByte([byte] ($Len -shr 16))
  $Fs.WriteByte([byte] ($Len -shr 25))

  #$Fs.Close()
}


function Get-MSIXIconsFromPackage {
  <#
      .SYNOPSIS
      Short description

      .DESCRIPTION
      Long description

      .PARAMETER Path
      Parameter description

      .PARAMETER Applist
      
      .PARAMETER Type
      type to return

      .EXAMPLE
      $IconList = Get-AppVManifestInfo  C:\temp\test\PowerDirector12-Spezial.appv | Select-Object -Property Shortcuts
      Get-AppVIconsFromPackage -Path C:\temp\test\PowerDirector12-Spezial.appv -Iconlist $IconList

      .NOTES
      https://www.software-virtualisierung.de
      Andreas Nick, 2019/2020
  #>
  [CmdletBinding()]
  [Alias()]
  [OutputType([System.Collections.arrayList])] #,'MSIXIconObject'
  
  param( 
   
    [Parameter( Position = 0, Mandatory = $true, ValueFromPipelineByPropertyName = $True)] 
    [Alias('ConfigPath')] 
    [System.IO.FileInfo] $Path,
    [Parameter( Position = 1, Mandatory = $true, ValueFromPipelineByPropertyName = $True)] [Alias('Applications')]
    [PSCustomObject[]]  $Applist
    #[ValidateSet('Bmp', 'Emf', 'Gif',  'Jpeg', 'Png', 'Tiff', 'Wmf','ico')][string] $ImageType = "Png"
  )

  Process {
    Write-Verbose "Process for Icons - MSIX Path: $($Path.FullName) "
    $resultlist = New-Object System.Collections.ArrayList
    try {
      $ResultList = new-Object System.Collections.ArrayList
      if (Test-Path $Path.FullName) {
        [System.IO.Compression.zipArchive] $arc = [System.IO.Compression.ZipFile]::OpenRead($Path.FullName)
        foreach ($icon in @($Applist)) {
          if ($icon.VisualElements) {
            Write-Verbose "Extract from package path : $($icon.VisualElements.IconPath)" 
            [System.IO.Compression.ZipArchiveEntry] $ix = $arc.GetEntry(($($icon.VisualElements.IconPath) -replace '\\', '/')) 
            if ($null -eq $ix ) {
              #Not Found ! Get default Icon
              Write-Verbose "Image not fond in the archiv! Is the file deletet? User default yoda.icon $iPath" 
              #$iconBase64 = Get-DefaultImage -ImageType $ImageType
            }
            else {
              [System.IO.binaryreader] $appvfile = $ix.Open()
              [byte[]] $bytes = Get-ReadAllBytes -reader $appvfile
              $iconBase64 = [Convert]::ToBase64String($bytes)
              
              write-verbose $("Extract image file " + $icon.Icon + " with " + $bytes.count + " bytes") 
              
              $MSIXIconInfo = "" | Select-Object -Property  Target, Base64Image, ImageType
              $MSIXIconInfo.Base64Image = $iconBase64
              $MSIXIconInfo.Target = $icon.Executable
              $MSIXIconInfo.ImageType = 'png'
              $null = $resultlist.add($MSIXIconInfo)
              $appvfile.Close()
            }
          }
        }
      }
    }
    catch [System.UnauthorizedAccessException] {
      [Management.Automation.ErrorRecord] $e = $_

      $info = [PSCustomObject]@{
        Exception = $e.Exception.Message
        Reason    = $e.CategoryInfo.Reason
        Target    = $e.CategoryInfo.TargetName
        Script    = $e.InvocationInfo.ScriptName
        Line      = $e.InvocationInfo.ScriptLineNumber
        Column    = $e.InvocationInfo.OffsetInLine
      }
    }

    if ($arc) { $arc.Dispose() }
    if ($appvfile) { $appvfile.Dispose() }
    return @($resultlist)
  }


}


function Get-AppXManifestInfo {
  <#
        .SYNOPSIS
        Get and anylyse a the AppXanifest.xml inside a App-V Package

        .DESCRIPTION
        Get and anylyse the AppXanifest.xml inside a App-V Package. Supply informations about the package ans skripts

        .PARAMETER Path
        Path to the .msix file

        .EXAMPLE
        Get-AppXManifestInfo -Path paintdotnet.appv

        .NOTES
        Andreas Nick - 2019

        .LINK
        https://www.software-virtualisierung.de
    #>
    
  [Alias()]
  [OutputType('AppxManifestInfo')]
  param( 
    [Parameter( Position = 0, Mandatory, ValueFromPipeline)] [System.IO.FileInfo] $Path
  )

  Process {
    #CONSTANT
    #Namespaces
    #$NamespaceXmlns = 'http://schemas.microsoft.com/appx/2010/manifest' 

    [xml] $appxxml = $NUll
    [xml] $appvStreamMapp = $NUll
      
    $fileCount = 0
          
    try {
      if (Test-Path $Path.FullName) {
        [System.IO.Compression.zipArchive] $arc = [System.IO.Compression.ZipFile]::OpenRead($Path.FullName)
        [System.IO.Compression.ZipArchiveEntry]$appxmanifest = $arc.GetEntry("AppxManifest.xml")
      
        $maxfileSize = 0
        $maxfileName = ""
        $uncompressedSize = 0
        $fileCount = $arc.Entries.Count
      
        foreach ($file in $arc.Entries) {
          if ($file.Length -gt $maxfileSize) {
            $maxfileSize = $file.Length
            $maxfileName = $file.FullName
          }
          $UncompressedSize += $file.Length
        }
      
        [system.IO.StreamReader]$z = $appxmanifest.Open()
        $appxxml = $z.ReadToEnd()
        $z = $null
      }
      else {
        Write-Verbose "AppV file not found" 
        throw [System.IO.FileNotFoundException] "$Path not found."
      }
    }
    catch [System.UnauthorizedAccessException] {
      [Management.Automation.ErrorRecord]$e = $_

      $info = [PSCustomObject]@{
        Exception = $e.Exception.Message
        Reason    = $e.CategoryInfo.Reason
        Target    = $e.CategoryInfo.TargetName
        Script    = $e.InvocationInfo.ScriptName
        Line      = $e.InvocationInfo.ScriptLineNumber
        Column    = $e.InvocationInfo.OffsetInLine
      }
      return $info
    }

    $InfoObj = @("Name, DisplayName, Publisher, ProcessorArchitecture, Version, Description, ConfigPath, UncompressedSize, MaxfileSize, MaxfilePath, FileCount, Applications".replace("`n", "").replace("`r", "").replace(" ", "").split(','))
    $AppxInfo = New-Object PSCustomObject
    $InfoObj | ForEach-Object { $AppxInfo | add-member -membertype NoteProperty -name $_ -Value $null }

    $AppxInfo.Name = $appxxml.Package.Identity.Name
    $AppxInfo.Publisher = $appxxml.Package.Identity.Publisher
    $AppxInfo.ProcessorArchitecture = $appxxml.Package.Identity.ProcessorArchitecture
    $AppxInfo.Version = $appxxml.Package.Identity.Version
    $AppxInfo.DisplayName = $appxxml.Package.Properties.DisplayName
    $AppxInfo.MaxfilePath = $maxfileName
    $AppxInfo.MaxfileSize = $maxfileSize
    $AppxInfo.UncompressedSize = $UncompressedSize
    $AppxInfo.FileCount = $fileCount 
    $AppxInfo.ConfigPath = $Path.FullName
      

    #$Namespaces = @($appxxml.SelectNodes('//namespace::*[not(. = ../../namespace::*)]'))
      
    if ($appxxml.Package.Applications) {
      $AppXInfo.Applications = New-Object System.Collections.ArrayList
        
      foreach ($sub in @($appxxml.Package.Applications.ChildNodes)) {
        $App = "" | Select-Object -Property Id
        $App.ID = $sub.Id
          
        if ($sub.Executable) {
          $App | add-member -membertype NoteProperty -name Executable -Value $sub.Executable
        }
        if ($sub.VisualElements) {
          $sk = "" | Select-Object -Property IconPath, Description, BackgroundColor
          # $sk.IconPath = $sub.VisualElements.Square150x150Logo
          # Today only for own Packages
          $sk.IconPath = ($sub.VisualElements.Square150x150Logo) -replace '.png$', '.scale-100.png' #in the Package in different sizes
            
          $sk.Description = $sub.VisualElements.Description
          $sk.BackgroundColor = $sub.VisualElements.BackgroundColor
          $App | add-member -membertype NoteProperty -name VisualElements -Value $sk
        }
          
        $AppXInfo.Applications.Add($App) | Out-Null
      }
        
       
    }
      
    return $AppXInfo
  }
  
}

function New-AppInstallerConfiguration {
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

function New-MSIXPortalPage {
  param(
    [URI] $WebServerBaseURL,
    [System.IO.FileInfo] $TemplatePath,
    [PSCustomObject[]] $Packages,
    [System.IO.DirectoryInfo] $OutputPath,
    [Switch] $CopyPackages
  )

  if (-not (Test-Path (Join-Path -Path $OutputPath -ChildPath "MSIXPackages"))) {
    New-Item -Path  (Join-Path -Path $OutputPath -ChildPath "MSIXPackages") -ItemType Directory
  }

  Get-Content $TemplatePath -Encoding UTF8 | Out-File  -FilePath $(Join-Path -Path $OutputPath -ChildPath "index.html") -Encoding utf8
  '<div class="row">' | Out-File  -FilePath $(Join-Path -Path $OutputPath -ChildPath "index.html")  -Append -Encoding utf8
  Foreach ($app in $Packages) {
    '<div class="col-sm-3">'  | Out-File  -FilePath $(Join-Path -Path $OutputPath -ChildPath "index.html")  -Append -Encoding utf8
    '<center>' + $app.DisplayName + '</center>' | Out-File  -FilePath $(Join-Path -Path $OutputPath -ChildPath "index.html")  -Append -Encoding utf8

    $image = $app | Get-MSIXIconsFromPackage -Verbose
    $MSIXPackageName = $app.Name + '.msix'
    $AppInstallerName = $app.Name + '.appinstaller'
    
    #sollen nun shares sein!
    $MSIXURI = [Uri] $($WebServerBaseURL.AbsoluteUri + "MSIXPackages" + '/' + $MSIXPackageName)
    $ConfigFileURI = [Uri] $($WebServerBaseURL.AbsoluteUri + "MSIXPackages" + '/' + $AppInstallerName )
 


    $href = $('ms-appinstaller:?source='+ $ConfigFileURI)

    $('<center><a href="'+ $href +'">' + '<img src="data:image/png;base64,' + $image.Base64Image + '" width="150" height="150"  title="' + $app.DisplayName + "`n" + '" /></a></center>') `
    | Out-File  -FilePath $(Join-Path -Path $OutputPath -ChildPath "index.html")  -Append -Encoding UTF8
    '</div>' | Out-File  -FilePath $(Join-Path -Path $OutputPath -ChildPath "index.html")  -Append -Encoding utf8

 
    if ($CopyPackages) {
      Copy-Item -Path $app.ConfigPath -Destination (Join-Path -Path (Join-Path -Path $OutputPath -ChildPath "MSIXPackages") -ChildPath $MSIXPackageName)
    }
  

    New-AppInstallerConfiguration -MSIXFileURL $MSIXURI -ConfigFileURL $ConfigFileURI -ApplicationName $app.Name -Publisher $App.Publisher -Version $app.Version `
      -ProcessorArchitecture $app.ProcessorArchitecture -OutputPath (Join-Path -Path $OutputPath -ChildPath "MSIXPackages")
  }

  '</div>' | Out-File  -FilePath $(Join-Path -Path $OutputPath -ChildPath "index.html")  -Append -Encoding utf8
  '</body>' + "`r`n" + '</html>' | Out-File  -FilePath $(Join-Path -Path $OutputPath -ChildPath "index.html")  -Append -Encoding utf8

}




  





