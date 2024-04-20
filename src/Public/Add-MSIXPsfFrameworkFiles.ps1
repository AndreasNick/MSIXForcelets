
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
    Specifies the PSF architecture. Valid values are '64Bit', '32Bit', and '64And32Bit'. 
    The default value is '64And32Bit', which includes both 64-bit and 32-bit files.
    Tipp: Use allways '64And32Bit' to be sure that all needed files are copied.

.PARAMETER IncludePSFMonitor
    Specifies whether to include the PSF monitor files in the MSIX folder. 
    By default, this parameter is not specified, which means the PSF monitor files will not be included.

.OUTPUTS
    None

.EXAMPLE
    Add-MSIXPsfFrameworkFiles -MSIXFolder "C:\MyMSIXFolder" -PSFArchitektur '64And32Bit' -IncludePSFMonitor
    Adds the PSF framework files to the specified MSIX folder, including both 64-bit and 32-bit files, and includes the PSF monitor files.

.EXAMPLE
    Add-MSIXPsfFrameworkFiles -MSIXFolder "C:\MyMSIXFolder" -PSFArchitektur '64Bit'
    Adds the PSF framework files to the specified MSIX folder, including only 64-bit files, and excludes the PSF monitor files.
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
        [ValidateSet('64Bit', '32Bit', '64And32Bit')]
        [String] $PSFArchitektur = '64And32Bit',
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
        $x32Files = @('msvcp140.dll', 'ucrtbased.dll', 'vcruntime140.dll')
        $x64Files = @('msvcp140.dll', 'ucrtbased.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')
        $CoreFiles = @('PsfLauncher', 'PsfRunDll', 'PsfRuntime')
    }
    
    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "AppxManifest.xml") )) {
            Write-Error "The MSIX temporary folder not exist"
            throw "The MSIX temporary folder not exist"
        }
        else {


            $UseArch = @('64')

            if ($PSFArchitektur -eq '64And32Bit') {
                $UseArch = @('64', '32');
            }

            if ($PSFArchitektur -eq '32Bit') {
                $UseArch = @('32')
            }
            
          
            #Copy Library Files
            if ($UseArch -contains "64") {
                if ( -not (Test-Path "$MSIXFolder\VFS\SystemX64" )) {
                    New-Item -Path "$MSIXFolder\VFS\SystemX64" -ItemType Directory
                }
                Foreach ($file in $x64Files) {
                    Copy-Item "$PsfBasePath\amd64\$file" -Destination "$MSIXFolder\VFS\SystemX64\"  -Force -Container | Out-Null
                }
            }
            if ($UseArch -contains "32") {
                if ( -not (Test-Path "$MSIXFolder\VFS\SystemX86")) {
                    New-Item -Path "$MSIXFolder\VFS\SystemX86" -ItemType Directory
                }
                Foreach ($file in $x32Files) {
                    Copy-Item "$PsfBasePath\win32\$file" -Destination "$MSIXFolder\VFS\SystemX86\"  -Force -Container | Out-Null
                }
            }

            # PSF Version Info
            Copy-Item "$PsfBasePath\Version.txt" -Destination "$MSIXFolder\"  -Force | Out-Null

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
                if ($AllFixups) {
                    Copy-Item "$PsfBasePath\DynamicLibraryFixup$arch.dll" -Destination $MSIXFolder  | Out-Null
                    Copy-Item "$PsfBasePath\EnvVarFixup$arch.dll" -Destination $MSIXFolder  | Out-Null
                    Copy-Item "$PsfBasePath\FileRedirectionFixup$arch.dll" -Destination $MSIXFolder  | Out-Null
                    Copy-Item "$PsfBasePath\MFRFixup$arch.dll" -Destination $MSIXFolder -ea SilentlyContinue | Out-Null
                    Copy-Item "$PsfBasePath\TraceFixup$arch.dll" -Destination $MSIXFolder  | Out-Null
                    Copy-Item "$PsfBasePath\RegLegacyFixups$arch.dll" -Destination $MSIXFolder  | Out-Null
                    Copy-Item "$PsfBasePath\StartingScriptWrapper.ps1" -Destination $MSIXFolder  | Out-Null
                    Copy-Item "$PsfBasePath\StartMenuCmdScriptWrapper.ps1" -Destination $MSIXFolder  -ea SilentlyContinue | Out-Null
                    Copy-Item "$PsfBasePath\StartMenuShellLaunchWrapperScript.ps1" -Destination $MSIXFolder  -ea SilentlyContinue | Out-Null
    
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


