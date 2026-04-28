function Get-MSIXIconsFromPackage {
    <#
        .SYNOPSIS
        Short description
  
        .DESCRIPTION
        Long description
  
        .PARAMETER Path
        Parameter description
  
        .PARAMETER Applist
        a list of applications from the AppXManifestInfo (Get-AppVManifestInfo)
  
        .PARAMETER Type
        [System.Collections.arrayList] with ichon informations
  
        .EXAMPLE
        $AppList = Get-AppXManifestInfo  C:\temp\test\PowerDirector12-Spezial.msix | Select-Object -Property Shortcuts
        Get-AppVIconsFromPackage -Path C:\temp\test\PowerDirector12-Spezial.msix -Applist $AppList
  
        .NOTES
        https://www.nick-it.de
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
        $ResultList = New-Object System.Collections.ArrayList
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
                
                Write-Verbose $("Extract image file " + $icon.Icon + " with " + $bytes.count + " bytes") 
                
                $MSIXIconInfo = "" | Select-Object -Property  Target, Base64Image, ImageType
                $MSIXIconInfo.Base64Image = $iconBase64
                $MSIXIconInfo.Target = $icon.Executable
                $MSIXIconInfo.ImageType = 'png'
                $null = $resultlist.Add($MSIXIconInfo)
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