function Add-MSIXGimpFix {
<#
.SYNOPSIS
Adds a GIMP fix to an MSIX package.

.DESCRIPTION
The Add-MSIXGimpFix function adds a GIMP fix to an MSIX package. It performs the following steps:
1. Opens the MSIX package.
2. Sets the publisher subject if provided.
3. Adds a search path override for DLL files.
4. Removes the Twain driver folder.
5. Closes the MSIX package.

.PARAMETER MsixFile
The path to the MSIX file.

.PARAMETER MSIXFolder
The folder where the MSIX package will be extracted. If not provided, a temporary folder will be used.

.PARAMETER Force
Forces the operation to proceed even if it would overwrite existing files.

.PARAMETER OutputFilePath
The path to the output MSIX file. If not provided, the input MSIX file will be used.

.PARAMETER Subject
The publisher subject to set.

.EXAMPLE
Add-MSIXGimpFix -MsixFile "C:\Path\To\Package.msix" -OutputFilePath "C:\Path\To\Output.msix" -Subject "My Publisher"

This example adds a GIMP fix to the specified MSIX package, sets the publisher subject, and saves the modified package to the specified output file.
.NOTES
# This is a full fix! You only need the MSIX File
Author: Andreas Nick
Date: 01/09/2023
https://www.nick-it.de
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
        Write-Error "Error adding Gimp Fix" 
        "Error $_"
    }
}