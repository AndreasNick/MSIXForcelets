
function Add-MSIXPsfFrameworkFiles {
    <#
.SYNOPSIS
    Adds MSIX PSF framework files to a specified MSIX folder.

.DESCRIPTION
    The Add-MSIXPsfFrameworkFiles function is used to add MSIX PSF framework files to a specified MSIX folder. 
    It copies the necessary files from the PSF base path to the MSIX folder. Optionally, it can include the PSF monitor files as well.

.PARAMETER MSIXFolder
    Specifies the expanded MSIX folder where the PSF framework files will be added.
    
.PARAMETER PSFArchitektur
    Specifies which PSF binaries to copy: x64, x86, or Both (default).
    Both copies x64 and x86 files and is the recommended setting for most packages.

.PARAMETER AllFixups
    Copies all available fixup DLLs and wrapper scripts into the MSIX folder.
    This is the default behaviour when no individual fixup switches are specified.

.PARAMETER IncludePSFMonitor
    Copies the PSF Monitor binaries into VFS\SystemX64 and VFS\SystemX86.
    Not included by default.

.OUTPUTS
    None

.EXAMPLE
    Add-MSIXPsfFrameworkFiles -MSIXFolder "C:\MyMSIXFolder" -IncludePSFMonitor

.EXAMPLE
    Add-MSIXPsfFrameworkFiles -MSIXFolder "C:\MyMSIXFolder" -PSFArchitektur x64
.NOTES
https://www.nick-it.de
Andreas Nick, 2024
#>
    [CmdletBinding(DefaultParameterSetName = 'CommonParameters', 
        SupportsShouldProcess = $true, 
        PositionalBinding = $false)]
    #[OutputType([system.version])]
    param(
        [Parameter(ParameterSetName = 'AllFixups')]
        [Parameter(ParameterSetName = 'IndividualFixups')]        
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'CommonParameters')]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Parameter(ParameterSetName = 'CommonParameters')]
        [Parameter(ParameterSetName = 'AllFixups')]
        [Parameter(ParameterSetName = 'IndividualFixups')]
        # Valid values: x64 | x86 | Both. Both copies x64 and x86 files (recommended).
        [ValidateSet('x64', 'x86', 'Both')]
        [String] $PSFArchitektur = 'Both',
        [Parameter(ParameterSetName = 'AllFixups')]
        [Parameter(ParameterSetName = 'IndividualFixups')]
        [Parameter(ParameterSetName = 'CommonParameters')]
        [switch] $IncludePSFMonitor,

        [Parameter(ParameterSetName = 'AllFixups')]
        [switch] $AllFixups, #every Fixup

        [Parameter(ParameterSetName = 'IndividualFixups')]
        [switch] $DLLFixup, #Dynamic Library Fixup
        [Parameter(ParameterSetName = 'IndividualFixups')]
        [switch] $EnvFixup, #Environment Fixup
        [Parameter(ParameterSetName = 'IndividualFixups')]
        [switch] $FRFixup, #File Redirection Fixup
        [Parameter(ParameterSetName = 'IndividualFixups')]
        [switch] $MFFixup, # Tim Mangans MFR Fixup
        [Parameter(ParameterSetName = 'IndividualFixups')]
        [switch] $RegLegacyFixup, # Registry Legacy Fixup
        [Parameter(ParameterSetName = 'IndividualFixups')]
        [switch] $TraceFixup,
        [Parameter(ParameterSetName = 'IndividualFixups')]
        [switch] $StartPowerShellWrapperScripts
    )

    begin {
        Write-Verbose "Adding PSF framework files to: $($MSIXFolder.FullName)"
        # VC++ Runtime DLLs to copy into VFS\SystemX64 (from PSF amd64\)
        $x64Files = @(
            'msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll',
            'vcruntime140.dll', 'vcruntime140_1.dll'
        )
        # VC++ Runtime DLLs to copy into VFS\SystemX86 (from PSF win32\)
        # vcruntime140_1.dll is x64-only; msvcp140_1/2 added per VC++ 2019/2022
        $x32Files = @(
            'msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll',
            'vcruntime140.dll'
        )
        $CoreFiles = @('PsfLauncher', 'PsfRunDll', 'PsfRuntime')
    }
    
    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            Write-Error "The MSIX temporary folder not exist"
            throw "The MSIX temporary folder not exist"
        }
        else {


            $UseArch = switch ($PSFArchitektur) {
                'Both' { @('64', '32') }
                'x86'  { @('32') }
                default { @('64') }
            }
            
          
            # Copy VC++ Runtime DLLs - only files present in the active PSF folder
            if ($UseArch -contains "64") {
                if (-not (Test-Path "$MSIXFolder\VFS\SystemX64")) {
                    New-Item -Path "$MSIXFolder\VFS\SystemX64" -ItemType Directory | Out-Null
                }
                foreach ($file in $x64Files) {
                    $src = Join-Path $PsfBasePath "amd64\$file"
                    if (Test-Path $src) {
                        Copy-Item $src -Destination "$MSIXFolder\VFS\SystemX64\" -Force | Out-Null
                        Write-Verbose "Copied (x64) $file"
                    }
                    else {
                        Write-Warning "VCRuntime file not found in PSF amd64\: $file"
                    }
                }
            }
            if ($UseArch -contains "32") {
                if (-not (Test-Path "$MSIXFolder\VFS\SystemX86")) {
                    New-Item -Path "$MSIXFolder\VFS\SystemX86" -ItemType Directory | Out-Null
                }
                foreach ($file in $x32Files) {
                    $src = Join-Path $PsfBasePath "win32\$file"
                    if (Test-Path $src) {
                        Copy-Item $src -Destination "$MSIXFolder\VFS\SystemX86\" -Force | Out-Null
                        Write-Verbose "Copied (x86) $file"
                    }
                    else {
                        Write-Warning "VCRuntime file not found in PSF win32\: $file"
                    }
                }
            }

            # PSF source info (present in newer downloads)
            $sourceInfo = Join-Path $PsfBasePath "SOURCE.txt"
            if (Test-Path $sourceInfo) {
                Copy-Item $sourceInfo -Destination "$MSIXFolder\" -Force | Out-Null
            }

            Foreach ($arch in $UseArch) {
                #Copy Core Files
                Foreach ($file in $CoreFiles) {
                    $CopyFile = Join-Path $PsfBasePath -ChildPath $($file + $arch + '*')
                    Write-Verbose "Copy $CopyFile to $MSIXFolder" 
                    Copy-Item "$PsfBasePath\$file$arch*" -Destination "$MSIXFolder\"  -Force | Out-Null
                }
                

                #Copy Fixes
                if ($DLLFixup) {
                    Copy-Item "$PsfBasePath\DynamicLibraryFixup$arch.dll" -Destination $MSIXFolder  | Out-Null
                }
                if ($EnvFixup) {
                    Copy-Item "$PsfBasePath\EnvVarFixup$arch.dll" -Destination $MSIXFolder  | Out-Null
                }
                if ($FRFixup) {
                    Copy-Item "$PsfBasePath\FileRedirectionFixup$arch.dll" -Destination $MSIXFolder  | Out-Null
                }
                if ($MFFixup) {
                    Copy-Item "$PsfBasePath\MFRFixup$arch.dll" -Destination $MSIXFolder -ea SilentlyContinue | Out-Null
                }
                if ($TraceFixup) {
                    Copy-Item "$PsfBasePath\TraceFixup$arch.dll" -Destination $MSIXFolder  | Out-Null
                }
                if ($RegLegacyFixup) {
                    Copy-Item "$PsfBasePath\RegLegacyFixups$arch.dll" -Destination $MSIXFolder  | Out-Null
                }
                # Default behaviour (no fixup switches passed) = copy all fixups
                if ($AllFixups -or $PSCmdlet.ParameterSetName -eq 'CommonParameters') {
                    Copy-Item "$PsfBasePath\DynamicLibraryFixup$arch.dll" -Destination $MSIXFolder -Force | Out-Null
                    Copy-Item "$PsfBasePath\EnvVarFixup$arch.dll" -Destination $MSIXFolder -Force | Out-Null
                    Copy-Item "$PsfBasePath\FileRedirectionFixup$arch.dll" -Destination $MSIXFolder -Force | Out-Null
                    Copy-Item "$PsfBasePath\MFRFixup$arch.dll" -Destination $MSIXFolder -Force -ErrorAction SilentlyContinue | Out-Null
                    Copy-Item "$PsfBasePath\TraceFixup$arch.dll" -Destination $MSIXFolder -Force | Out-Null
                    Copy-Item "$PsfBasePath\RegLegacyFixups$arch.dll" -Destination $MSIXFolder -Force | Out-Null
                    Copy-Item "$PsfBasePath\StartingScriptWrapper.ps1" -Destination $MSIXFolder -Force | Out-Null
                    Copy-Item "$PsfBasePath\StartMenuCmdScriptWrapper.ps1" -Destination $MSIXFolder -Force -ErrorAction SilentlyContinue | Out-Null
                    Copy-Item "$PsfBasePath\StartMenuShellLaunchWrapperScript.ps1" -Destination $MSIXFolder -Force -ErrorAction SilentlyContinue | Out-Null
                    # Tim Mangan PSF only — silently skipped when using Microsoft PSF
                    Copy-Item "$PsfBasePath\PsfFtaCom$arch.exe" -Destination $MSIXFolder -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }

            if ($StartPowerShellWrapperScripts) {
                Copy-Item "$PsfBasePath\StartingScriptWrapper.ps1" -Destination $MSIXFolder  | Out-Null
                Copy-Item "$PsfBasePath\StartMenuCmdScriptWrapper.ps1" -Destination $MSIXFolder  -ea SilentlyContinue | Out-Null
                Copy-Item "$PsfBasePath\StartMenuShellLaunchWrapperScript.ps1" -Destination $MSIXFolder  -ea SilentlyContinue | Out-Null
            }
        

            if ($IncludePSFMonitor) {
                Write-Verbose "Copy 32Bit Monitor Files" 
                #Copy-Item "$PsfBasePath\PSFMonitor*" -Destination "$MSIXFolder\"  -Force | Out-Null

                #Copy All Systemfiles
                if ($UseArch -contains "64") {
                    Copy-Item "$PsfBasePath\amd64\*" -Destination "$MSIXFolder\VFS\SystemX64"  -Force | Out-Null
                }
                
                if ($UseArch -contains "32") {
                    Copy-Item "$PsfBasePath\win32\*" -Destination "$MSIXFolder\VFS\SystemX86"  -Force | Out-Null
                }
            }
        } 
    }
}


