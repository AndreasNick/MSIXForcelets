

function Open-MSIXPackage {
<#
.SYNOPSIS
Opens an MSIX package and unpacks its contents to a specified folder.

.DESCRIPTION
The Open-MSIXPackage function opens an MSIX package and unpacks its contents to a specified folder. 

.PARAMETER MsixFile
Specifies the MSIX package file to be opened. This parameter is mandatory.

.PARAMETER MSIXFolder
Specifies the folder where the contents of the MSIX package will be unpacked. If not specified, a temporary folder will be created.

.PARAMETER ClearOutputFolder
Specifies whether to clear the output folder before unpacking the MSIX package. By default, the existing files in the output folder will not be cleared.

.PARAMETER Force
Specifies whether to force the creation of the output folder if it does not exist. By default, the output folder will be created only if it does not exist.

.EXAMPLE
$MSIXExpandedFolder = Open-MSIXPackage -MsixFile "C:\Path\To\Package.msix" -MSIXFolder "C:\Output\Folder" -ClearOutputFolder -Force
This example opens the specified MSIX package and unpacks its contents to the specified output folder. It clears the output folder before unpacking and forces the creation of the output folder if it does not exist.
.NOTES
Author: Andreas Nick
https://www.nick-it.de
#>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.FileInfo]
        $MsixFile,
        [System.IO.DirectoryInfo] $MSIXFolder = ($env:Temp + "\MSIX_TEMP_" + [system.guid]::NewGuid().ToString()),
        [bool] $ClearOutputFolder = $false,
        [Switch] $Force
    )
     
    process {
        if (-not (Test-Path $MsixFile )) {
            Write-Warning "the  file $($MsixFile.FullName) not exist"
        }

        if ((Test-Path $MSIXFolder) -and $ClearOutputFolder) {
            #Check there is an AppxManifest
            if (Test-Path (Join-Path -Path $MSIXFolder -ChildPath AppxManifest.xml)) {
                Remove-Item -Path $MSIXFolder -Recurse -Force
            }
        }

        if (-not (Test-Path $MSIXFolder)) {
            Write-Verbose "Force status: $($Force) creating folder $($MSIXFolder.FullName)"
            New-Item $MSIXFolder -ItemType Directory -force:$Force | Out-Null
        }

        <#
        Options:
        --------
            /pfn: Unpacks all files to a subdirectory under the specified output path,
                named after the package full name.
            /nv, /noValidation: Skips validation that ensures the package will be
                installable on Windows. The validation include: existence of files
                referenced in manifest, ContentGroupMap correctness, and additional
                manifest validation on Protocols and FileTypeAssociation. By default,
                all semantic validation is performed.
            /kf: Use this option to encrypt or decrypt the package or bundle using a
                key file. This option cannot be combined with /kt.
            /kt: Use this option to encrypt or decrypt the package or bundle using the
                global test key. This option cannot be combined with /kf.
            /nd: Skips decryption when unpacking an encrypted package or bundle.
            /o, /overwrite: Forces the output to overwrite any existing files with the
                same name. By default, the user is asked whether to overwrite existing
                files with the same name. You can't use this option with /no.
            /no, /noOverwrite: Prevents the output from overwriting any existing files
                with the same name. By default, the user is asked whether to overwrite
                existing files with the same name. You can't use this option with /o.
            /v, /verbose: Enables verbose output of messages to the console.
          
        #>      
        MakeAppx unpack -o -p $($MsixFile.FullName) -d $($MSIXFolder.FullName) | Out-Default
        if ($lastexitcode -ne 0) {

            Write-Error "ERROR: MSIX Cannot open Package"
            Return $Null
        }

        return $MSIXFolder
    }
}

