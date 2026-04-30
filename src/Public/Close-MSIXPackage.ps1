
function Close-MSIXPackage {
<#
.SYNOPSIS
    Packs an expanded MSIX folder back into a signed .msix file.

.DESCRIPTION
    Converts config.json.xml to config.json (via XSLT), removes redundant PSF
    launcher stubs when renamed per-app copies exist, then calls MakeAppx to
    repack the folder.

    The temporary extraction folder is deleted after packing unless -KeepMSIXFolder
    is specified or the module configuration value KeepTempFolder is $true.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder.

.PARAMETER MSIXFile
    Target path for the repacked .msix file.

.PARAMETER KeepMSIXFolder
    When specified, the temporary folder is kept after packing.
    When omitted, the module configuration value KeepTempFolder is used (default: $false).

.PARAMETER Force
    Removes an existing output file before packing. Without this switch the
    function relies on MakeAppx -o; use -Force when MakeAppx fails because
    the output file is locked or already present.

.EXAMPLE
    Close-MSIXPackage -MSIXFolder "C:\Temp\MSIXTemp" -MSIXFile "C:\Temp\MyApp.msix"

.EXAMPLE
    Close-MSIXPackage -MSIXFolder "C:\Temp\MSIXTemp" -MSIXFile "C:\Temp\MyApp.msix" -Force

.EXAMPLE
    Close-MSIXPackage -MSIXFolder "C:\Temp\MSIXTemp" -MSIXFile "C:\Temp\MyApp.msix" -KeepMSIXFolder

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2024
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
        [Switch] $KeepMSIXFolder,
        [Switch] $Force
    )

    process {
        if (-not (Test-Path $MSIXFolder)) {
            Write-Error "The MSIX temporary folder does not exist."
            return $null
        }
        else {
            if (Test-Path $MSIXFile.FullName) {
                if ($Force) {
                    Remove-Item $MSIXFile.FullName -Force
                    Write-Verbose "Removed existing output file: $($MSIXFile.FullName)"
                } else {
                    Write-Warning "Output file already exists: $($MSIXFile.FullName). Use -Force to overwrite."
                }
            }
            $configFile = Join-Path $MSIXFolder -ChildPath "config.json.xml"
            #Create config.json
            if(Test-Path $configFile){
                Convert-MSIXPSFXML2JSON -xml $configFile -xsl (Join-Path -path $Script:ScriptPath -ChildPath "Data\Format.xsl") -output (Join-Path $MSIXFolder -ChildPath "config.json")
            } else {
                Write-Warning "No config.json.xml found. A config.json is not created."
            }
            # Remove original PSF launcher stubs when renamed per-app copies exist.
            # Best practice renames PsfLauncher64/32.exe to <AppId>_PsfLauncherX.exe;
            # the originals are then redundant and must not be packed.
            $renamedLaunchers = @(Get-ChildItem -Path $MSIXFolder.FullName -Filter '*_PsfLauncher?.exe' -ErrorAction SilentlyContinue)
            if ($renamedLaunchers.Count -gt 0) {
                foreach ($stubName in @('PsfLauncher32.exe', 'PsfLauncher64.exe')) {
                    $stubPath = Join-Path $MSIXFolder.FullName $stubName
                    if (Test-Path $stubPath) {
                        Remove-Item $stubPath -Force -ErrorAction SilentlyContinue
                        Write-Verbose "Removed original launcher stub: $stubName"
                    }
                }
            }

            $manifestPath = Join-Path $MSIXFolder.FullName 'AppxManifest.xml'
            if (Test-Path $manifestPath) {
                $valid = Test-MSIXManifest -ManifestPath $manifestPath -Verbose:($VerbosePreference -eq 'Continue')
                if (-not $valid) {
                    Write-Warning "AppxManifest.xml has schema validation errors (see warnings above). Packing may fail."
                }
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
                if ($PSBoundParameters.ContainsKey('KeepMSIXFolder')) {
                    $keepFolder = $KeepMSIXFolder.IsPresent
                } else {
                    $keepFolder = $Script:MSIXForceletsConfig.KeepTempFolder
                }

                if (-not $keepFolder) {
                    Write-Verbose "Remove MSIX temp folder $MSIXFolder"
                    Remove-Item $MSIXFolder -Recurse -Confirm:$false -ErrorAction SilentlyContinue
                    if (Test-Path $MSIXFolder) {
                        Write-Verbose "Force remove MSIX temp folder $MSIXFolder"
                        & Cmd.exe /C rmdir /S /Q "$MSIXFolder" 2>$null
                    }
                }
            }
            
        }
    }
}
