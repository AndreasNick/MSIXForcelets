function Add-MSIXFixSSMS22 {
<#
.SYNOPSIS
    Fixes "Error opening the connection dialog - Element not found (0x80070490)" in an SSMS 21/22 MSIX package.

.DESCRIPTION
    SSMS 21/22 is based on the Visual Studio shell. The connection dialog calls
    ISetupConfiguration2.GetInstanceForCurrentProcess() (VS Setup API), which reads
    %ProgramData%\Microsoft\VisualStudio\Packages\_Instances\<id>\state.json and checks that
    SSMS.exe lies below its installationPath. In a captured package this file is missing or points to
    the installation folder of the packaging machine.

    The fix:
      - creates VFS\Common AppData\Microsoft\VisualStudio\Packages\_Instances\<id>\state.json with
        installationPath = -InstallationRoot (default 'C:\Program Files\WindowsApps', matches every
        version/publisher)
      - removes the NGEN native images of the packaging machine (VFS\Windows\assembly\NativeImages_*)
      - removes the Microsoft.WindowsAppRuntime package dependency (not used by SSMS) unless
        -KeepWindowsAppRuntimeDependency is set
      - removes the captured services (VSInstallerElevationService, VSStandardCollectorService150)
        incl. their COM server and service capabilities unless -NotRemoveServices is set
      - removes the Visual Studio Installer application and its Start menu shortcut
      - removes the captured account stores (VFS\Local AppData\.IdentityService)
      - removes the VS Installer payload (VFS\Common AppData\Package Cache and ...\VisualStudio\Packages)
      - removes the .NETFramework machine keys (incl. Wow6432Node) from Registry.dat

    For SSMS 20 and earlier use Add-MSIXFixSSMS.

.EXAMPLE
    Add-MSIXFixSSMS22 -MsixFile .\SSMS22-x64.msix -OutputFilePath .\SSMS22-x64_fixed.msix -Force -Verbose

.NOTES
    Writing to Registry.dat usually requires an elevated PowerShell.
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.FileInfo] $MsixFile,

        [System.IO.FileInfo] $OutputFilePath = $null,

        [System.IO.DirectoryInfo] $MSIXFolder = ($env:Temp + '\MSIX_TEMP_' + [System.Guid]::NewGuid().ToString()),

        [string] $Subject = '',
        [string] $Version = '',

        [string] $InstallationRoot = 'C:\Program Files\WindowsApps',

        [switch] $KeepWindowsAppRuntimeDependency,
        [switch] $NotRemoveServices,
        [switch] $Force,
        [switch] $KeepMSIXFolder
    )

    process {
        if ($null -eq $OutputFilePath) {
            $OutputFilePath = $MsixFile
        }

        try {
            $package = Open-MSIXPackage -MsixFile $MsixFile -Force:$Force -MSIXFolder $MSIXFolder -ErrorAction Stop
            if (-not $package) {
                throw "Failed to open MSIX package: $($MsixFile.FullName)"
            }
            $root = $MSIXFolder.FullName

            if ($Subject -ne '') {
                Set-MSIXPublisher -MSIXFolder $MSIXFolder -PublisherSubject $Subject
            }
            if ($Version -ne '') {
                Set-MSIXPackageVersion -MSIXFolder $MSIXFolder -MSVersion $Version
            }

            # NGEN native images of the packaging machine (~1 GB, never used in the container)
            foreach ($ni in @(Get-ChildItem -LiteralPath (Join-Path $root 'VFS\Windows\assembly') -Directory -Filter 'NativeImages_*' -ErrorAction SilentlyContinue)) {
                Remove-Item -LiteralPath $ni.FullName -Recurse -Force
                Write-Verbose "Removed native images: $($ni.Name)"
            }

            # WindowsAppRuntime dependency (added by the VS Installer during capture)
            if (-not $KeepWindowsAppRuntimeDependency -and
                (Get-MSIXDependencies -MSIXFolder $MSIXFolder | Where-Object Name -like 'Microsoft.WindowsAppRuntime*')) {
                Remove-MSIXDependencies -MSIXFolderPath $MSIXFolder -Name 'Microsoft.WindowsAppRuntime*'
            }

            # Services captured with the VS Installer (installer elevation, diagnostics collector) -
            # not needed by SSMS in the container.
            if (-not $NotRemoveServices) {
                $services = @(Get-MSIXServices -MSIXFolder $MSIXFolder)
                if ($services.Count -gt 0) {
                    $services | Remove-MSIXServices
                }
            }

            # The captured VS Installer (setup.exe) must not show up in the Start menu: drop its
            # desktop7 shortcut (incl. the .lnk) and the application entry itself.
            $installerApps = @(Get-MSIXApplications -MSIXFolder $MSIXFolder |
                Where-Object { $_.Executable -like '*\Microsoft Visual Studio\Installer\setup.exe' })
            foreach ($installerApp in $installerApps) {
                Get-MSIXDesktop7Shortcut -MSIXFolder $MSIXFolder |
                    Where-Object ApplicationId -eq $installerApp.Id |
                    Remove-MSIXDesktop7Shortcut
                Remove-MSIXApplications -MSIXFolder $MSIXFolder -MSIXAppID $installerApp.Id
                Write-Verbose "Removed the Visual Studio Installer application '$($installerApp.Id)'."
            }

            # Account stores of the user who captured the package
            $identityService = Join-Path $root 'VFS\Local AppData\.IdentityService'
            if (Test-Path -LiteralPath $identityService) {
                Remove-Item -LiteralPath $identityService -Recurse -Force
                Write-Verbose 'Removed VFS\Local AppData\.IdentityService'
            }

            # Installer payload of the VS Installer (several GB, not needed in the container).
            # The VS Setup instance is created again below.
            foreach ($rel in @('VFS\Common AppData\Package Cache',
                               'VFS\Common AppData\Microsoft\VisualStudio\Packages')) {
                $p = Join-Path $root $rel
                if (Test-Path -LiteralPath $p) {
                    $sizeMB = [Math]::Round(((Get-ChildItem -LiteralPath $p -Recurse -File -ErrorAction SilentlyContinue |
                                              Measure-Object -Property Length -Sum).Sum / 1MB), 1)
                    Remove-Item -LiteralPath $p -Recurse -Force
                    Write-Verbose ("Removed {0} ({1} MB)" -f $rel, $sizeMB)
                }
            }

            # .NETFramework machine keys: NGEN data of the packaging machine would hide the real
            # values of the target system.
            $registryDat = Join-Path $root 'Registry.dat'
            foreach ($key in @('REGISTRY\MACHINE\SOFTWARE\Microsoft\.NETFramework',
                               'REGISTRY\MACHINE\SOFTWARE\Wow6432Node\Microsoft\.NETFramework')) {
                Remove-MSIXVirtualRegistryKey -HiveFilePath $registryDat -KeyPath $key -Recurse
            }

            # VS Setup instance (state.json)
            $vsPackages  = Join-Path $root 'VFS\Local AppData\Microsoft\VisualStudio\Packages'
            # @(...)[0] instead of Select-Object -First 1: on Windows PowerShell 5.1 that reports a
            # StopUpstreamCommandsException to a caller's -ErrorVariable.
            $instanceDir = @(Get-ChildItem -LiteralPath (Join-Path $vsPackages '_Instances') -Directory -ErrorAction SilentlyContinue)[0]
            $channelDir  = @(Get-ChildItem -LiteralPath (Join-Path $vsPackages '_Channels') -Directory -ErrorAction SilentlyContinue)[0]
            if ($null -eq $instanceDir -or $null -eq $channelDir) {
                throw "No captured VS setup instance/channel found under $vsPackages"
            }

            $channelManifest = Get-Content -LiteralPath (Join-Path $channelDir.FullName 'channelManifest.json') -Raw | ConvertFrom-Json
            $product         = @($channelManifest.channelItems | Where-Object { $_.type -eq 'ChannelProduct' })[0]

            # Only catalog.info is needed: a flat object at the start of the ~18 MB catalog.json.
            # Read the first 64 KB instead of parsing the whole file; fall back to a full parse.
            $catalogPath = Join-Path $channelDir.FullName 'catalog.json'
            $catalogInfo = $null
            $reader = New-Object System.IO.StreamReader $catalogPath
            try {
                $buffer = New-Object char[] 65536
                $head   = [string]::new($buffer, 0, $reader.Read($buffer, 0, $buffer.Length))
            }
            finally {
                $reader.Dispose()
            }
            if ($head -match '"info"\s*:\s*(\{[^{}]*\})') {
                try { $catalogInfo = $Matches[1] | ConvertFrom-Json } catch { $catalogInfo = $null }
            }
            if ($null -eq $catalogInfo) {
                $catalogInfo = (Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json).info
            }
            if ($null -eq $product) {
                throw "No ChannelProduct entry in $(Join-Path $channelDir.FullName 'channelManifest.json')"
            }
            $now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [System.Globalization.CultureInfo]::InvariantCulture)

            $state = [ordered]@{
                installationName    = $catalogInfo.id
                installationPath    = $InstallationRoot
                launchParams        = [ordered]@{ fileName = 'Common7\IDE\SSMS.exe'; arguments = '' }
                installationVersion = $product.version
                installDate         = $now
                updateDate          = $now
                layoutPath          = $null
                channelId           = $channelManifest.info.manifestName
                channelPath         = "$env:ProgramData\Microsoft\VisualStudio\Packages\_Channels\$($channelDir.Name)\catalog.json"
                channelUri          = $channelManifest.updateUri
                installChannelUri   = $channelManifest.updateUri
                localizedResources  = @([ordered]@{ language = 'en-us'; title = "$($catalogInfo.productName) $($catalogInfo.productLineVersion)"; description = ''; license = '' })
                product             = [ordered]@{ id = $product.id; version = $product.version; chip = 'x64'; type = 'Product'; isExtension = $false }
                selectedPackages    = @([ordered]@{ id = $product.id; version = $product.version; chip = 'x64'; type = 'Product'; selectedState = 'IndividuallySelected'; userSelected = $true })
                catalogInfo         = $catalogInfo
                properties          = [ordered]@{
                    channelManifestId   = $channelManifest.info.id
                    nickname            = ''
                    setupEngineFilePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe"
                }
            }

            $stateFile = Join-Path $root "VFS\Common AppData\Microsoft\VisualStudio\Packages\_Instances\$($instanceDir.Name)\state.json"
            $null = New-Item -ItemType Directory -Force -Path (Split-Path $stateFile)
            [System.IO.File]::WriteAllText($stateFile, ($state | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding $false))
            Write-Verbose "Created state.json for instance $($instanceDir.Name), installationPath: $InstallationRoot"

            Close-MSIXPackage -MSIXFolder $MSIXFolder -MSIXFile $OutputFilePath -Force:$Force -KeepMSIXFolder:$KeepMSIXFolder -ErrorAction Stop
            "SSMS 21/22 fix applied: $OutputFilePath"
        }
        catch {
            $failure = $_
            # Do not leave the extracted package (several GB) behind in %TEMP%: remove the default
            # temporary folder unless it should be kept. A folder passed via -MSIXFolder stays.
            if ($PSBoundParameters.ContainsKey('KeepMSIXFolder')) { $keepFolder = $KeepMSIXFolder.IsPresent }
            else { $keepFolder = [bool]$Script:MSIXForceletsConfig.KeepTempFolder }
            if (-not $keepFolder -and -not $PSBoundParameters.ContainsKey('MSIXFolder') -and (Test-Path -LiteralPath $MSIXFolder.FullName)) {
                Remove-Item -LiteralPath $MSIXFolder.FullName -Recurse -Force -ErrorAction SilentlyContinue
                if (Test-Path -LiteralPath $MSIXFolder.FullName) { & cmd.exe /C rmdir /S /Q "$($MSIXFolder.FullName)" 2>$null }
                Write-Verbose "Removed extraction folder after the error: $($MSIXFolder.FullName)"
            }
            throw (New-Object System.Exception ("Error applying SSMS 21/22 fix: $($failure.Exception.Message)", $failure.Exception))
        }
    }
}
