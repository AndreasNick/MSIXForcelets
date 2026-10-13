

function Add-MSIXFixAcrobatReaderDC {
<#
.SYNOPSIS
    Adds a fix for Acrobat Reader DC to an MSIX package.

.DESCRIPTION
    This function adds a fix for Acrobat Reader DC to an MSIX package. 

.PARAMETER MsixFile
    Specifies the MSIX file to which the fix should be added. This parameter is mandatory.

.PARAMETER MSIXFolder
    Specifies the folder where the MSIX package will be extracted. If not provided, a temporary folder will be used.

.PARAMETER Force
    Indicates whether to force the operation. If specified, the operation will be performed even if it would overwrite existing files.

.PARAMETER OutputFilePath
    Specifies the path where the modified MSIX package should be saved. If not provided, the original MSIX file will be overwritten.

.PARAMETER Subject
    Specifies the publisher subject to set for the MSIX package.

.PARAMETER DisableFirstRunScreen
    # Suppresses the "Always open PDFs in Acrobat Reader" dialog.
.PARAMETER DisableAutoUpdate
    Disables automatic background downloads and the built-in updater

.PARAMETER SuppressDefaultHandlerDialog
    Suppresses the "Always open PDFs in Acrobat Reader" dialog. Inside an
    MSIX container the attempt to register as default handler causes a
    timeout and a Windows default-apps prompt. Defaults to $true.

.PARAMETER DisablePremiumTools
    Hides premium / subscription-only tools .

.PARAMETER DisableCloudServices
    Disables the Adobe Document Cloud integration

.PARAMETER DisableReaderMode
    Force Adobe Acrobat

.PARAMETER KeepSetupCache
    Keep Adobe's MSI repair cache (VFS\ProgramFilesCommonX64\Adobe\Acrobat\Setup,
    ~1.4 GB) in the package. Useless inside MSIX (no msiexec repair). Default $false.

.EXAMPLE
    Add-MSIXFixAcrobatReaderDC -MsixFile "C:\Path\To\Package.msix" -OutputFilePath "C:\Path\To\ModifiedPackage.msix" -Subject "CN=MyPublisher"

    This example adds a fix for Acrobat Reader DC to the specified MSIX package. It sets the publisher subject to "CN=MyPublisher" and saves the modified package to the specified output file path.

.NOTES
    source url's for the solution:
    https://techcommunity.microsoft.com/t5/modern-work-app-consult-blog/packaging-adobe-reader-dc-for-avd-msix-appattach/ba-p/3572098
    https://www.advancedinstaller.com/package-adobe-reader-dc-for-avd-msix-appattach.html
    >> someone has made a copy ;-)

    Reader-vs-Pro branding (unified app from v24+):
    https://community.adobe.com/t5/acrobat-reader-discussions/how-to-disable-new-acrobat-reader-using-regedit-or-gpo/td-p/14008678
    https://helpx.adobe.com/enterprise/kb/acrobat-64-bit-for-enterprises.html

    https://www.nick-it.de
    Andreas Nick, 2026
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
        [String] $Subject = "",

        [bool] $DisableFirstRunScreen = $true,

        [bool] $DisableAutoUpdate = $true,

        [bool] $SuppressDefaultHandlerDialog = $true,

        [bool] $DisablePremiumTools = $true,

        [bool] $DisableCloudServices = $true,

        [bool] $DisableReaderMode = $false,

        [bool] $KeepSetupCache = $false

    )
    if ($null -eq $OutputFilePath) {
        $OutputFilePath = $MsixFile
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warning "The Acrobat Reader DC MSIX Fix  must be run as an administrator! Stop"
        throw "The Acrobat Reader DC MSIX Fix  must be run as an administrator! Stop"
    }

    $Package = Open-MSIXPackage -MsixFile $MsixFile -Force:$force -MSIXFolder $MSIXFolder

    try {
        if ($Subject -ne "") {
            Set-MSIXPublisher -MSIXFolder $MsixFolder -PublisherSubject $Subject
        }

        $IsForce = $PSCmdlet.MyInvocation.BoundParameters["Force"].IsPresent -eq $true
        Add-MSIXRegAccessFix -MSIXFolder $MSIXFolder -force:$IsForce -Verbose

        # internetClient: required for Adobe license-activation roundtrip (Reader-vs-Pro
        # branding on v24+ unified app) and Document Cloud features.
        Add-MSIXCapabilities -MSIXFolder $MSIXFolder -Capabilities 'internetClient'

        if (-not $KeepSetupCache) {
            $setupCache = Join-Path $Package.FullName 'VFS\ProgramFilesCommonX64\Adobe\Acrobat\Setup'
            if (Test-Path $setupCache) {
                Remove-Item $setupCache -Recurse -Force
                Write-Verbose 'Removed Adobe MSI setup cache.'
            }
        }

        $registryDatPath = Join-Path $Package.FullName -ChildPath "Registry.dat"
        if (-not (Test-Path $registryDatPath)) {
            throw "Registry.dat not found in '$($Package.FullName)'. The package must contain a virtual HKLM hive."
        }

        # Policy paths -- written to both product names and WOW6432Node for full compatibility.
        # "Acrobat Reader" is the legacy path (pre-2024); "Adobe Acrobat" is required for v2024+.
        # WOW6432Node variants are needed for x86 packages running on x64 Windows.
        $policyPathAR  = "REGISTRY\MACHINE\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown"
        $policyPathAA  = "REGISTRY\MACHINE\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown"
        $policyPathARw = "REGISTRY\MACHINE\SOFTWARE\WOW6432Node\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown"
        $policyPathAAw = "REGISTRY\MACHINE\SOFTWARE\WOW6432Node\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown"

        # User-level preferences go into User.dat (virtual HKCU), not Registry.dat (HKLM).
        # The root of User.dat maps directly to HKCU, so paths start with "Software\...".
        $userDatPath = Join-Path $Package.FullName "User.dat"
        if (-not (Test-Path $userDatPath)) {
            Write-Warning "User.dat not found in '$($Package.FullName)' -- user preference keys cannot be set."
        }

        # Disable Protected Mode in User.dat so Adobe does not show the "Protected Mode incompatible"
        # dialog at first launch. In MSIX App Attach the container already provides isolation;
        # Adobe's own sandbox (Protected Mode) is not needed and often fails inside AppContainer.
        # x64 packages use "Adobe Acrobat" in the path; x86 packages use "Acrobat Reader" -- write both.
        if (Test-Path $userDatPath) {
            Set-MSIXVirtualRegistryKey -HiveFilePath $userDatPath -KeyPath "Software\Adobe\Adobe Acrobat\DC\Privileged"  -ValueName "bProtectedMode" -ValueData "0" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
            Set-MSIXVirtualRegistryKey -HiveFilePath $userDatPath -KeyPath "Software\Adobe\Acrobat Reader\DC\Privileged" -ValueName "bProtectedMode" -ValueData "0" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
        }

        # Set keys in the virtual HKLM hive (Registry.dat).
        # bEnableProtectedModeAppContainer=1 allows Acrobat Reader to run inside an AppContainer.
        Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $policyPathAR  -ValueName "bEnableProtectedModeAppContainer" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $policyPathARw -ValueName "bEnableProtectedModeAppContainer" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $policyPathAA  -ValueName "bEnableProtectedModeAppContainer" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $policyPathAAw -ValueName "bEnableProtectedModeAppContainer" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
        # bAcroSuppressUpsell=1 removes the "Free Trial" / upgrade button from the title bar.
        Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $policyPathAR  -ValueName "bAcroSuppressUpsell" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $policyPathARw -ValueName "bAcroSuppressUpsell" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $policyPathAA  -ValueName "bAcroSuppressUpsell" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $policyPathAAw -ValueName "bAcroSuppressUpsell" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)

        # bIsSCReducedModeEnforcedEx=1 forces Reader mode on the v24+ unified app —
        # without it the same binary boots as "Adobe Acrobat" (Pro trial) when the
        # license activation roundtrip is unavailable or fails inside the container.
        # Written to all four FeatureLockDown paths (Acrobat Reader / Adobe Acrobat,
        # native + WOW6432Node) so the policy applies regardless of how the package
        # was built or which architecture path the app reads.
        if (-not $DisableReaderMode) {
            Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $policyPathAR  -ValueName "bIsSCReducedModeEnforcedEx" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
            Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $policyPathARw -ValueName "bIsSCReducedModeEnforcedEx" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
            Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $policyPathAA  -ValueName "bIsSCReducedModeEnforcedEx" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
            Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $policyPathAAw -ValueName "bIsSCReducedModeEnforcedEx" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
        }

        # Both product-name variants are written to cover x86 ("Acrobat Reader") and x64 ("Adobe Acrobat").
        $userProductPaths = @('Software\Adobe\Adobe Acrobat\DC', 'Software\Adobe\Acrobat Reader\DC')

        if ($DisableFirstRunScreen) {
            if (Test-Path $userDatPath) {
                foreach ($base in $userProductPaths) {
                    # Hide the splash screen and accept the EULA.
                    Set-MSIXVirtualRegistryKey -HiveFilePath $userDatPath -KeyPath "$base\AVGeneral"   -ValueName "bShowSplash"                    -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
                    Set-MSIXVirtualRegistryKey -HiveFilePath $userDatPath -KeyPath "$base\AdobeViewer" -ValueName "EULA"                           -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
                    # Suppress "What's New" / "Try Acrobat Studio" promotional dialog on first launch.
                    Set-MSIXVirtualRegistryKey -HiveFilePath $userDatPath -KeyPath "$base\AVGeneral"   -ValueName "bShowWhatSNewExpContentAgain"    -ValueData "0" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
                    Set-MSIXVirtualRegistryKey -HiveFilePath $userDatPath -KeyPath "$base\AVGeneral"   -ValueName "bIsNewUser"                      -ValueData "0" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
                    Set-MSIXVirtualRegistryKey -HiveFilePath $userDatPath -KeyPath "$base\AVGeneral"   -ValueName "bappFirstLaunchForNotifications" -ValueData "0" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
                    # Suppress "Show me messages when I launch Adobe Acrobat" and "Don't show while viewing".
                    # IPM = In-Product Messaging panel.
                    Set-MSIXVirtualRegistryKey -HiveFilePath $userDatPath -KeyPath "$base\IPM"         -ValueName "bShowMsgAtLaunch"                -ValueData "0" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
                    Set-MSIXVirtualRegistryKey -HiveFilePath $userDatPath -KeyPath "$base\IPM"         -ValueName "bDontShowMsgWhenViewingDoc"      -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
                    # Suppress crash reporter dialog ("Ask Every Time" -> silent).
                    Set-MSIXVirtualRegistryKey -HiveFilePath $userDatPath -KeyPath "$base\AVGeneral"   -ValueName "bSCARdrCrashReporterEnabled"     -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
                }
            }
        }

        if ($SuppressDefaultHandlerDialog) {
            if (Test-Path $userDatPath) {
                foreach ($base in $userProductPaths) {
                    # Suppress "Always open PDFs in Acrobat Reader" dialog.
                    # AVGeneral key prevents the pop-up; AVAlert\cCheckbox keys permanently opt out
                    # of PDF ownership so Acrobat never re-raises the dialog on subsequent launches.
                    Set-MSIXVirtualRegistryKey -HiveFilePath $userDatPath -KeyPath "$base\AVGeneral"        -ValueName "bShowMsgBoxWhenNotDefaultPDF"         -ValueData "0" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
                    Set-MSIXVirtualRegistryKey -HiveFilePath $userDatPath -KeyPath "$base\AVAlert\cCheckbox" -ValueName "iAppDoNotTakePDFOwnershipAtLaunch"      -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
                    Set-MSIXVirtualRegistryKey -HiveFilePath $userDatPath -KeyPath "$base\AVAlert\cCheckbox" -ValueName "iAppDoNotTakePDFOwnershipAtLaunchWin10" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
                }
            }
        }

        if ($DisablePremiumTools) {
            # Hide premium / subscription-only tools from the Tools panel.
            # cAcroApp\cDisabled uses indexed REG_SZ values (a0, a1, ...) containing the tool identifier.
            # Tool names are defined by Adobe's AcroApps preference reference.
            $premiumTools = @(
                'PagesApp',             # Organize pages
                'CollectSignaturesApp', # Request e-signatures
                'PaperToPDFApp',        # Scan & OCR
                'ProtectApp',           # Protect a PDF
                'RedactApp',            # Redact a PDF
                'OptimizePDFApp',       # Compress a PDF
                'FormsApp',             # Prepare a form
                'CreatePDFApp',         # Create PDF
                'ExportPDFApp',         # Export PDF
                'EditPDFApp',           # Edit PDF text
                'CombineApp'            # Combine files
            )

            $cDisabledPathAR  = "$policyPathAR\cAcroApp\cDisabled"
            $cDisabledPathARw = "$policyPathARw\cAcroApp\cDisabled"
            $cDisabledPathAA  = "$policyPathAA\cAcroApp\cDisabled"
            $cDisabledPathAAw = "$policyPathAAw\cAcroApp\cDisabled"

            for ($i = 0; $i -lt $premiumTools.Count; $i++) {
                $indexName = "a$i"
                Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $cDisabledPathAR  -ValueName $indexName -ValueData $premiumTools[$i] -ValueType ([Microsoft.Win32.RegistryValueKind]::String)
                Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $cDisabledPathARw -ValueName $indexName -ValueData $premiumTools[$i] -ValueType ([Microsoft.Win32.RegistryValueKind]::String)
                Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $cDisabledPathAA  -ValueName $indexName -ValueData $premiumTools[$i] -ValueType ([Microsoft.Win32.RegistryValueKind]::String)
                Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $cDisabledPathAAw -ValueName $indexName -ValueData $premiumTools[$i] -ValueType ([Microsoft.Win32.RegistryValueKind]::String)
            }

            # bEnableGentech=0 disables the premium-features upsell messages (v2024+).
            Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $policyPathAR  -ValueName "bEnableGentech" -ValueData "0" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
            Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $policyPathARw -ValueName "bEnableGentech" -ValueData "0" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
            Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $policyPathAA  -ValueName "bEnableGentech" -ValueData "0" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
            Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $policyPathAAw -ValueName "bEnableGentech" -ValueData "0" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
        }

        if ($DisableAutoUpdate) {
            # Disable automatic background download and the built-in updater via Group Policy.
            foreach ($updatePath in @("$policyPathAR\cUpdate", "$policyPathARw\cUpdate", "$policyPathAA\cUpdate", "$policyPathAAw\cUpdate")) {
                Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $updatePath -ValueName "bAutoDownload" -ValueData "0" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
                Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $updatePath -ValueName "bUpdater"      -ValueData "0" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
            }
        }

        if ($DisableCloudServices) {
            # Disable Adobe Document Cloud integration -- prevents AcroCEF.exe (CEF-based online panel)
            # from launching. bToggleAdobeDocumentServices=1 locks out the entire Document Cloud feature set.
            # Disable web connectors (SharePoint, OneDrive, Box, Dropbox) -- stops AdobeCollabSync.exe.
            foreach ($cloudPath in @($policyPathAR, $policyPathARw, $policyPathAA, $policyPathAAw)) {
                Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $cloudPath -ValueName "bToggleAdobeDocumentServices" -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
                Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $cloudPath -ValueName "bToggleWebConnectors"         -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
                Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $cloudPath -ValueName "bTogglePrefsSync"             -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
                Set-MSIXVirtualRegistryKey -HiveFilePath $registryDatPath -KeyPath $cloudPath -ValueName "bToggleSignIn"                -ValueData "1" -ValueType ([Microsoft.Win32.RegistryValueKind]::DWord)
            }
        }
    }
    catch {
        Write-Error "Error adding AcrobatReader Fix: $_"
        throw
    }
    finally {
        Close-MSIXPackage -MSIXFolder $Package.FullName -MSIXFile $OutputFilePath
    }
}