
function New-MSIXPortalPage {
  <#
.SYNOPSIS
Creates a new MSIX portal page.

.DESCRIPTION
The New-MSIXPortalPage function creates a new MSIX portal page by generating an HTML file with links to MSIX packages and their corresponding app installers. It takes the web server base URL, template path, packages, output path, and a switch parameter to indicate whether to copy the packages.

.PARAMETER WebServerBaseURL
The base URL of the web server where the MSIX packages and app installers will be hosted.

.PARAMETER TemplatePath
The path to the template file that will be used to generate the portal page.

.PARAMETER Packages
An array of PSCustomObject representing the MSIX packages.

.PARAMETER OutputPath
The path where the generated HTML file and copied packages will be saved.

.PARAMETER CopyPackages
A switch parameter indicating whether to copy the packages to the output path.

.EXAMPLE
New-MSIXPortalPage -WebServerBaseURL "http://example.com/" -TemplatePath "C:\Templates\portal-template.html" -Packages $packages -OutputPath "C:\Output" -CopyPackages
This example creates a new MSIX portal page using the specified web server base URL, template path, packages, output path, and copies the packages to the output path.
.NOTES
# Work with user rights!
https://www.nick-it.de
Andreas Nick, 2024
#>
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
 


    $href = $('ms-appinstaller:?source=' + $ConfigFileURI)

    $('<center><a href="' + $href + '">' + '<img src="data:image/png;base64,' + $image.Base64Image + '" width="150" height="150"  title="' + $app.DisplayName + "`n" + '" /></a></center>') `
    | Out-File  -FilePath $(Join-Path -Path $OutputPath -ChildPath "index.html")  -Append -Encoding UTF8
    '</div>' | Out-File  -FilePath $(Join-Path -Path $OutputPath -ChildPath "index.html")  -Append -Encoding utf8

 
    if ($CopyPackages) {
      Copy-Item -Path $app.ConfigPath -Destination (Join-Path -Path (Join-Path -Path $OutputPath -ChildPath "MSIXPackages") -ChildPath $MSIXPackageName)
    }
  

    New-MSIXAppInstallerConfiguration -MSIXFileURL $MSIXURI -ConfigFileURL $ConfigFileURI -ApplicationName $app.Name -Publisher $App.Publisher -Version $app.Version `
      -ProcessorArchitecture $app.ProcessorArchitecture -OutputPath (Join-Path -Path $OutputPath -ChildPath "MSIXPackages")
  }

  '</div>' | Out-File  -FilePath $(Join-Path -Path $OutputPath -ChildPath "index.html")  -Append -Encoding utf8
  '</body>' + "`r`n" + '</html>' | Out-File  -FilePath $(Join-Path -Path $OutputPath -ChildPath "index.html")  -Append -Encoding utf8

}
