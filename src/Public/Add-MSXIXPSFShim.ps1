
function Add-MSXIXPSFShim {
<#
.SYNOPSIS
    Wires an MSIX application entry through the PSF launcher.

.DESCRIPTION
    Adds a PSF (Package Support Framework) shim to one application entry inside
    an expanded MSIX package. The function:

      1. Detects the application architecture from the PE header when
         -PSFArchitektur is not specified (uses PSFDefaultArchitecture from
         module configuration, default: Auto).
      2. Copies PsfLauncher64.exe or PsfLauncher32.exe as a uniquely named
         file following best practice: <AppId>_PsfLauncherA.exe,
         <AppId>_PsfLauncherB.exe, etc.  The next available letter is found
         by counting existing *_PsfLauncher?.exe files in the package root.
      3. Renames the Application/@Id attribute in AppxManifest.xml to
         <OriginalId>PsfLauncher<Letter> (e.g. WinRARPsfLauncherA) and
         redirects Application/@Executable to the renamed launcher.
      4. Creates or updates config.json.xml so that the PSF launcher knows
         which real executable to start, using the renamed Application Id.
      5. When the active PSF framework is from Tim Mangan
         (Set-MSIXActivePSFFramework points to a TimManganPSF path), the
         enableReportError and debugLevel properties are added to the top-level
         configuration element (debugLevel from PSFTimManganDebugLevel config).

    The processes section (exclusion entries + catch-all) is managed by fixup
    functions such as Add-MSIXPSFFileRedirectionFixup and Add-MSIXPSFTracing.
    Use Set-MSIXForceletsConfiguration to control which exclusions are added.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain AppxManifest.xml).

.PARAMETER MISXAppID
    Application/@Id value as it appears in AppxManifest.xml.

.PARAMETER WorkingDirectory
    Optional working directory passed through to config.json.

.PARAMETER Arguments
    Optional command-line arguments passed through to config.json.

.PARAMETER PSFArchitektur
    Architecture of the PSF launcher to use: Auto, x64, or x86.
    When omitted, the module configuration value PSFDefaultArchitecture is used
    (default: Auto — the PE machine type of the executable is auto-detected).

.PARAMETER PreventMultipleInstances
    Prevents more than one instance of the application from running simultaneously.
    Tim Mangan PSF only. Always written to config.json when Tim Mangan PSF is active (default: $false).

.PARAMETER TerminateChildren
    Terminates child processes when the main application exits.
    Tim Mangan PSF only. Always written to config.json when Tim Mangan PSF is active (default: $false).

.EXAMPLE
    Add-MSXIXPSFShim -MSIXFolder "C:\MSIXTemp\WinRAR" -MISXAppID "WinRAR"

.EXAMPLE
    Add-MSXIXPSFShim -MSIXFolder "C:\MSIXTemp\App" -MISXAppID "App" `
        -PSFArchitektur x64 -WorkingDirectory "VFS\ProgramFilesX64\App" `
        -Arguments "--mode compat" -Verbose

.OUTPUTS
    System.String
    The new Application Id assigned to the shimmed entry (e.g. "WinRARPsfLauncherA").
    Capture this to pass the correct Id to subsequent cmdlets such as
    Add-MSIXAppExecutionAlias.

.NOTES
    Requires an active PSF framework set via Set-MSIXActivePSFFramework.
    https://www.nick-it.de
    Andreas Nick, 2024
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [Alias('Id')]
        [String] $MISXAppID,

        [String] $WorkingDirectory = '',

        [String] $Arguments = '',

        # Valid values: Auto | x64 | x86. When omitted, PSFDefaultArchitecture from module config is used.
        [ValidateSet('Auto', 'x64', 'x86')]
        [String] $PSFArchitektur,

        # Tim Mangan PSF only — always written to config.json (default: $false).
        [bool] $PreventMultipleInstances = $false,
        [bool] $TerminateChildren = $false
    )

    process {
        if ([string]::IsNullOrWhiteSpace($MISXAppID)) {
            Write-Error "-MISXAppID must not be empty or whitespace."
            return
        }

        if ($PSBoundParameters.ContainsKey('WorkingDirectory') -and $WorkingDirectory -ne '') {
            if ($WorkingDirectory -match '/') {
                Write-Warning "-WorkingDirectory '$WorkingDirectory' contains a forward slash. Use backslash for VFS paths, e.g. 'VFS\ProgramFilesX64\App'."
            }
        }

        $manifestPath = Join-Path $MSIXFolder 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "AppxManifest.xml not found in: $($MSIXFolder.FullName)"
            return
        }

        Write-Verbose "Adding PSF shim for application: $MISXAppID"

        # --- Load AppxManifest and locate the application node ---
        $manifest = New-Object xml
        $manifest.Load($manifestPath)
        $ns = New-Object System.Xml.XmlNamespaceManager $manifest.NameTable
        $ns.AddNamespace('ns', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
        $appNode = $manifest.SelectSingleNode("//ns:Application[@Id='$MISXAppID']", $ns)

        if ($null -eq $appNode) {
            Write-Warning "Application '$MISXAppID' not found in AppxManifest.xml."
            return
        }

        $originalExecutable = $appNode.Executable

        # --- Determine architecture ---
        # If caller did not pass -PSFArchitektur, honour module config; otherwise use the explicit value.
        if ($PSBoundParameters.ContainsKey('PSFArchitektur')) {
            $resolvedArch = $PSFArchitektur
        } else {
            $resolvedArch = $Script:MSIXForceletsConfig.PSFDefaultArchitecture
        }

        if ($resolvedArch -eq 'Auto') {
            $resolvedArch = 'x64'
            $exePath = Join-Path $MSIXFolder.FullName $originalExecutable
            if (Test-Path $exePath) {
                if ((Get-MSIXAppMachineType -FilePathName $exePath) -eq 'I386') {
                    $resolvedArch = 'x86'
                }
            } else {
                Write-Warning "Executable '$originalExecutable' not found in MSIX folder, using x64."
            }
            Write-Verbose "Auto-detected architecture: $resolvedArch"
        }

        $sourceLauncher = if ($resolvedArch -eq 'x64') { 'PsfLauncher64.exe' } else { 'PsfLauncher32.exe' }

        # --- Find or assign a renamed launcher for this AppId ---
        $existingLauncher = Get-ChildItem -Path $MSIXFolder.FullName -Filter "$($MISXAppID)_PsfLauncher?.exe" -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($null -ne $existingLauncher) {
            $launcherName    = $existingLauncher.Name
            $launcherLetter  = $existingLauncher.BaseName[-1]
            $newAppId        = $MISXAppID + 'PsfLauncher' + $launcherLetter
            Write-Verbose "Reusing existing launcher: $launcherName"
        }
        else {
            $allRenamed   = @(Get-ChildItem -Path $MSIXFolder.FullName -Filter '*_PsfLauncher?.exe' -ErrorAction SilentlyContinue)
            $nextLetter   = [char]([int][char]'A' + $allRenamed.Count)
            $launcherName = "$($MISXAppID)_PsfLauncher$($nextLetter).exe"
            $newAppId     = $MISXAppID + 'PsfLauncher' + $nextLetter

            $srcPath = Join-Path $MSIXFolder.FullName $sourceLauncher
            if (Test-Path $srcPath) {
                Copy-Item $srcPath -Destination (Join-Path $MSIXFolder.FullName $launcherName) -Force
                Write-Verbose "Copied $sourceLauncher -> $launcherName"
            }
            else {
                Write-Warning "$sourceLauncher not found in MSIX folder. The manifest will reference a missing file."
            }
        }

        # --- Update AppxManifest: rename Application Id and redirect Executable ---
        $null = $appNode.SetAttribute('Id', $newAppId)
        $appNode.Executable = $launcherName
        $manifest.Save($manifestPath)
        Write-Verbose "AppxManifest updated: Id = $newAppId, Executable = $launcherName"

        # --- Load or create config.json.xml ---
        $configXmlPath = Join-Path $MSIXFolder 'config.json.xml'
        $conxml = New-Object xml

        if (Test-Path $configXmlPath) {
            $conxml.Load($configXmlPath)
        }
        else {
            $conxml = [xml] '<configuration><applications></applications></configuration>'
        }

        # --- Tim Mangan extras: enableReportError and debugLevel ---
        $isTimMangan = $Script:PsfBasePath -like '*TimMangan*'
        if ($isTimMangan) {
            $configRoot = $conxml.SelectSingleNode('/configuration')
            $appsEl     = $conxml.SelectSingleNode('/configuration/applications')

            $erNode = $conxml.SelectSingleNode('/configuration/enableReportError')
            if ($null -eq $erNode) {
                $erEl = $conxml.CreateElement('enableReportError')
                $erEl.InnerText = 'false'
                $configRoot.InsertBefore($erEl, $appsEl) | Out-Null
            }

            # Always update debugLevel so Set-MSIXForceletsConfiguration takes effect on rebuild
            $dlNode = $conxml.SelectSingleNode('/configuration/debugLevel')
            if ($null -eq $dlNode) {
                $dlNode = $conxml.CreateElement('debugLevel')
                $configRoot.InsertBefore($dlNode, $appsEl) | Out-Null
            }
            $dlNode.InnerText = $Script:MSIXForceletsConfig.PSFTimManganDebugLevel.ToString()

            Write-Verbose "Tim Mangan: enableReportError=false, debugLevel=$($Script:MSIXForceletsConfig.PSFTimManganDebugLevel)"
        }

        # --- Add application entry to config.json.xml if not yet present ---
        $existingEntry = $conxml.SelectSingleNode("//application/id[text()='$newAppId']")
        if ($null -eq $existingEntry) {
            Write-Verbose "Adding application entry to config.json.xml: $newAppId"
            $appRoot = $conxml.SelectSingleNode('//applications')

            $r = $conxml.CreateElement('application')

            $idEl = $conxml.CreateElement('id')
            $idEl.InnerText = $newAppId
            $r.AppendChild($idEl) | Out-Null

            $exeEl = $conxml.CreateElement('executable')
            $exeEl.InnerText = $originalExecutable -replace '\\', '\\'
            $r.AppendChild($exeEl) | Out-Null

            $argEl = $conxml.CreateElement('arguments')
            $argEl.InnerText = $Arguments
            $r.AppendChild($argEl) | Out-Null

            $wdEl = $conxml.CreateElement('workingDirectory')
            $wdEl.InnerText = $WorkingDirectory
            $r.AppendChild($wdEl) | Out-Null

            if ($isTimMangan) {
                $pmiEl = $conxml.CreateElement('preventMultipleInstances')
                $pmiEl.InnerText = $PreventMultipleInstances.ToString().ToLower()
                $r.AppendChild($pmiEl) | Out-Null

                $tcEl = $conxml.CreateElement('terminateChildren')
                $tcEl.InnerText = $TerminateChildren.ToString().ToLower()
                $r.AppendChild($tcEl) | Out-Null
            }

            $appRoot.AppendChild($r) | Out-Null
        }
        else {
            Write-Verbose "Application entry '$newAppId' already present in config.json.xml — skipped."
        }

        $conxml.PreserveWhiteSpace = $false
        $conxml.Save($configXmlPath)
        Write-Output $newAppId
    }
}
