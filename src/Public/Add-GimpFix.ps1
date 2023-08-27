function Add-GimpFix {
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
 
    if($null -eq $MsixFile){

        Write-Error "Empty MSIX path" 
        return $null
    }

    if ($null -eq $OutputFilePath) {
        $OutputFilePath = $MsixFile
    }

    try {
        [System.IO.DirectoryInfo] $Package = Open-MSIXPackage -MsixFile $MsixFile -Force:$force -MSIXFolder $MSIXFolder

        if ($Subject -ne "") {
            Set-MSIXPublisher -MSIXFolder $MsixFolder -PublisherSubject $Subject
        }

        #ToFind needed DLL Files
        Add-MSIXloaderSearchPathOverride -FolderPaths "Bin" -MSIXFolderPath $MsixFolder

        #Remove Twain Driver
        Write-Information "Remove Folder lib\gimp\2.0\plug-ins\twain"
        Remove-Item -Path (Join-Path -Path $MsixFolder -ChildPath '\lib\gimp\2.0\plug-ins\twain') -Recurse -Force -Confirm:$false

        Close-MSIXPackage -MSIXFolder $MsixFolder -MSIXFile $OutputFilePath
    }
    catch {
        Write-Error "Error adding SSMS Fix" 
        "Error $_"
    }
}