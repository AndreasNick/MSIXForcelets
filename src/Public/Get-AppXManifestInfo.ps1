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