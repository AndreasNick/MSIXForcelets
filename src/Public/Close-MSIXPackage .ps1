
function Close-MSIXPackage {
<#
.SYNOPSIS
Closes an MSIX package by packing it and optionally removing the temporary folder.

.DESCRIPTION
The Close-MSIXPackage function is used to close an MSIX package by packing it and optionally removing the temporary folder.

.PARAMETER MSIXFolder
Specifies the path to the MSIX temporary folder.

.PARAMETER MSIXFile
Specifies the path to the MSIX file.

.PARAMETER KeepMSIXFolder
Indicates whether to keep the MSIX temporary folder after closing the package.

.EXAMPLE
Close-MSIXPackage -MSIXFolder "C:\Temp\MSIXTemp" -MSIXFile "C:\Temp\MyApp.msix" -KeepMSIXFolder

This example closes the MSIX package located at "C:\Temp\MyApp.msix" by packing it and keeps the temporary folder "C:\Temp\MSIXTemp".

.NOTES

#>


    [CmdletBinding()]
    #[OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            #ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [System.IO.FileInfo] $MSIXFile,
        [Switch] $KeepMSIXFolder
    )

    process {
        if (-not (Test-Path $MSIXFolder)) {
            Write-Error "The MSIX temporary folder does not exist."
            return $null
        }
        else {
            $configFile = Join-Path $MSIXFolder -ChildPath "config.json.xml"
            #Create config.json
            if(Test-Path $configFile){
                Convert-MSIXPSFXML2JSON -xml $configFile -xsl (Join-Path -path $Script:ScriptPath -ChildPath "Data\Format.xsl") -output (Join-Path $MSIXFolder -ChildPath "config.json")
            } else {
                Write-Warning "No config.json.xml found. A config.json is not created."
            }
            if($VerbosePreference -eq 'Continue'){
                MakeAppx pack -o -p $MsixFile.FullName -d  $MSIXFolder.FullName | Out-Default
            } else {
                MakeAppx pack -o -p $MsixFile.FullName -d  $MSIXFolder.FullName | Out-Null
            }
            
            #-l 
            if ($lastexitcode -ne 0) {
                Write-Error "ERROR: MSIX Cannot close Package"
                return $null
            }
            else {
                if (-Not $KeepMSIXFolder) {
                    Write-Verbose "Remove MSIX temp folder $MSIXFolder"
                    Remove-Item $MSIXFolder -Recurse -Confirm:$false -ErrorAction SilentlyContinue
                    if(Test-Path $MSIXFolder){
                        Write-Verbose "Force remove MSIX temp folder $MSIXFolder"
                        & Cmd.exe /C rmdir /S /Q "$MSIXFolder" 2>$null
                    }
                }
            }
            
        }
    }
}
