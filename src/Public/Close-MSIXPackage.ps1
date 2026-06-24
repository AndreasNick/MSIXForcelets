
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

.PARAMETER PrettyPrint
    Re-formats AppxManifest.xml with indentation and line breaks before packing,
    so the manifest inside the package stays human-readable.

.PARAMETER RegenerateResource
    Rebuilds resources.pri with makepri before packing. Use after changing assets so Windows
    resolves the icons correctly (fixes plated/boxed Start-menu icons caused by a stale index).

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
        [Switch] $Force,
        [Switch] $PrettyPrint,
        [Switch] $RegenerateResource
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

            # Re-serialize the manifest with indentation so the packed copy is readable.
            if ($PrettyPrint -and (Test-Path $manifestPath)) {
                $fmtDoc = New-Object System.Xml.XmlDocument
                $fmtDoc.PreserveWhitespace = $false
                $fmtDoc.Load($manifestPath)

                $settings = New-Object System.Xml.XmlWriterSettings
                $settings.Indent = $true
                $settings.IndentChars = '  '
                $settings.NewLineChars = "`r`n"
                $settings.Encoding = New-Object System.Text.UTF8Encoding($false)

                $writer = [System.Xml.XmlWriter]::Create($manifestPath, $settings)
                try { $fmtDoc.Save($writer) } finally { $writer.Dispose() }
                Write-Verbose "Pretty-printed AppxManifest.xml"
            }

            if (Test-Path $manifestPath) {
                $valid = Test-MSIXManifest -ManifestPath $manifestPath -Verbose:($VerbosePreference -eq 'Continue')
                if (-not $valid) {
                    Write-Warning "AppxManifest.xml has schema validation errors (see warnings above). Packing may fail."
                }
            }

            # Rebuild resources.pri so Windows resolves the (possibly changed) assets correctly.
            if ($RegenerateResource) {
                $makepri = Join-Path $Script:MSIXPackagingPath 'makepri.exe'
                if (-not (Test-Path $makepri)) {
                    Write-Warning "makepri.exe not found at '$makepri'. Run Update-MSIXTooling. Skipping resource index regeneration."
                }
                elseif (-not (Test-Path $manifestPath)) {
                    Write-Warning "AppxManifest.xml not found - skipping resource index regeneration."
                }
                else {
                    $priConfig = Join-Path $env:TEMP ('priconfig_' + [System.Guid]::NewGuid().ToString('N') + '.xml')
                    $priFile   = Join-Path $MSIXFolder.FullName 'resources.pri'
                    try {
                        # Remove the stale index first so makepri writes a clean one.
                        if (Test-Path $priFile) { Remove-Item $priFile -Force }

                        if ($VerbosePreference -eq 'Continue') {
                            & $makepri createconfig /cf $priConfig /dq 'en-US' /o | Out-Default
                            & $makepri new /pr $MSIXFolder.FullName /cf $priConfig /mn $manifestPath /of $priFile /o | Out-Default
                        }
                        else {
                            & $makepri createconfig /cf $priConfig /dq 'en-US' /o | Out-Null
                            & $makepri new /pr $MSIXFolder.FullName /cf $priConfig /mn $manifestPath /of $priFile /o | Out-Null
                        }

                        if ($LASTEXITCODE -ne 0) {
                            Write-Warning "makepri returned exit code $LASTEXITCODE - resources.pri may be incomplete."
                        }
                        else {
                            Write-Verbose "Regenerated resources.pri via makepri."
                        }
                    }
                    finally {
                        if (Test-Path $priConfig) { Remove-Item $priConfig -Force -ErrorAction SilentlyContinue }
                    }
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
