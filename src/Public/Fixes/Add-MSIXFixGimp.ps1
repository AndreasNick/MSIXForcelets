function Add-MSIXFixGimp {
<#
.SYNOPSIS
Adds a GIMP fix to an MSIX package.

.DESCRIPTION
The Add-MSIXFixGimp function adds a GIMP fix to an MSIX package. It performs the following steps:
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
Add-MSIXFixGimp  -MsixFile "C:\Path\To\Package.msix" -OutputFilePath "C:\Path\To\Output.msix" -Subject "My Publisher"

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

    $Package = Open-MSIXPackage -MsixFile $MsixFile -Force:$force -MSIXFolder $MSIXFolder
    if (-not $Package) {
        throw "Failed to open MSIX package: $($MsixFile.FullName)"
    }

    try {
        if ($Subject -ne "") {
            Set-MSIXPublisher -MSIXFolder $MsixFolder -PublisherSubject $Subject
        }

        #ToFind needed DLL Files
        Add-MSIXloaderSearchPathOverride -FolderPaths "Bin",'VFS\ProgramFilesX64\GIMP 3\bin','VFS\ProgramFilesX64\GIMP 2\bin' -MSIXFolderPath $MsixFolder

        # Disable Update Search — patch gimprc in all known locations
        # (root-packaged, VFS GIMP 2, VFS GIMP 3; spaces become %20 in MSIX paths)
        $gimpRcCandidates = @(
            "$MsixFolder\etc\gimp\2.0\gimprc"
            "$MsixFolder\etc\gimp\3.0\gimprc"
            "$MsixFolder\VFS\ProgramFilesX64\GIMP%202\etc\gimp\2.0\gimprc"
            "$MsixFolder\VFS\ProgramFilesX64\GIMP%203\etc\gimp\3.0\gimprc"
        )
        foreach ($gimpRcPath in $gimpRcCandidates) {
            if (-not (Test-Path $gimpRcPath)) { continue }
            $content = Get-Content $gimpRcPath -Raw
            if ($content -match 'check-updates yes') {
                $content = $content -replace 'check-updates yes', 'check-updates no'
                Set-Content $gimpRcPath -Value $content
                Write-Verbose "Update check disabled: $gimpRcPath"
            } else {
                Write-Verbose "No changes needed: $gimpRcPath"
            }
        }

        # Remove plug-ins folder — all known locations
        $pluginsCandidates = @(
            "$MsixFolder\lib\gimp\2.0\plug-ins"
            "$MsixFolder\VFS\ProgramFilesX64\GIMP%202\lib\gimp\2.0\plug-ins"
            "$MsixFolder\VFS\ProgramFilesX64\GIMP%203\lib\gimp\3.0\plug-ins"
        )
        foreach ($pluginsPath in $pluginsCandidates) {
            if (-not (Test-Path $pluginsPath)) { continue }
            Remove-Item -Path $pluginsPath -Recurse -Force -Confirm:$false
            Write-Verbose "Removed plug-ins: $pluginsPath"
        }

        Close-MSIXPackage -MSIXFolder $MsixFolder -MSIXFile $OutputFilePath 
    }
    catch {
        Write-Error "Error adding Gimp Fix" 
        "Error $_"
    }
}