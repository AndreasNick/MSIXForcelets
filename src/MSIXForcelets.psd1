#
# Module manifest for module 'MSIXForcelets'
# Andreas Nick
#

@{
    RootModule           = 'MSIXForcelets.psm1'
    ModuleVersion        = '1.0.3'
    GUID                 = '799e7b14-d939-43b3-845e-6cf1be49c36b'
    Author               = 'Andreas Nick'
    CompanyName          = 'Andreas Nick'
    Copyright            = 'Copyright (c) 2020-2026 Andreas Nick'
    Description          = 'PowerShell framework for MSIX/AppX packaging and Package Support Framework (PSF) injection: edit captured packages, add/repair PSF fixups, manage shortcuts/services/dependencies, generate assets, sign and publish. Docs: https://msixforcelets.nick-it.de — Source on GitHub: https://github.com/AndreasNick/MSIXForcelets'

    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    FunctionsToExport = @(
        'Add-MSIXAppExecutionAlias',
        'Add-MSIXApplication',
        'Add-MSIXCapabilities',
        'Add-MSIXDesktop7Shortcut',
        'Add-MSIXDisableWriteVirtualization',
        'Add-MSIXFirewallRule',
        'Add-MSIXFixAcrobatReaderDC',
        'Add-MSIXFixGimp',
        'Add-MSIXFixLibreOffice',
        'Add-MSIXFixNotepadPlusPlus',
        'Add-MSIXFIXSSMS',
        'Add-MSIXFixWinRAR',
        'Add-MSIXFixWinRARModernShell',
        'Add-MSIXFlexibleVirtualization',
        'Add-MSIXInstalledLocationVirtualization',
        'Add-MSIXloaderSearchPathOverride',
        'Add-MSIXPSFDefaultFRF',
        'Add-MSIXPSFDefaultRegLegacy',
        'Add-MSIXPSFDynamicLibraryFixup',
        'Add-MSIXPSFEnvVarFixup',
        'Add-MSIXPSFFileRedirectionFixup',
        'Add-MSIXPsfFrameworkFiles',
        'Add-MSIXPSFFtaCom',
        'Add-MSIXPSFMFRFixup',
        'Add-MSIXPSFMonitor',
        'Add-MSIXPSFPowerShellScript',
        'Add-MSIXPSFRegLegacyFixup',
        'Add-MSIXPSFTracing',
        'Add-MSIXRegAccessFix',
        'Add-MSIXSharedContainer',
        'Add-MSIXSharedFonts',
        'Add-MSXIXPSFShim',
        'Backup-MSIXManifest',
        'Close-MSIXPackage',
        'Convert-MSIXClassicContextMenuToVerbs',
        'Copy-ToMSIXPackage',
        'Find-MSIXFonts',
        'Get-MSIXFileTypeAssociation',
        'Add-MSIXFileTypeAssociation',
        'Set-MSIXFileTypeAssociation',
        'Remove-MSIXFileTypeAssociation',
        'Get-AppXManifestInfo',
        'Get-MSIXAppExeDetailInfo',
        'Get-MSIXApplications',
        'Get-MSIXAppMachineType',
        'Get-MSIXDependencies',
        'Get-MSIXDesktop7Shortcut',
        'Get-MSIXForceletsConfiguration',
        'Get-MSIXPackageVersion',
        'Get-MSIXPSFFrameworkPath',
        'Get-MSIXServices',
        'Get-MSIXVirtualProcess',
        'Import-MSIXSparseShellExtension',
        'Invoke-MSIXCleanup',
        'New-MSIXAppInstallerConfiguration',
        'New-MSIXApplicationVariant',
        'New-MSIXAssetFrom',
        'New-MSIXPackage',
        'New-MSIXPortalPage',
        'New-MSIXSelfSigningCert',
        'Open-MSIXPackage',
        'Remove-MSIXApplications',
        'Remove-MSIXClassicShellExtension',
        'Remove-MSIXDependencies',
        'Remove-MSIXDesktop7Shortcut',
        'Remove-MSIXPackageIntegrity',
        'Remove-MSIXPSFFiles',
        'Remove-MSIXPSFMonitorFiles',
        'Remove-MSIXServices',
        'Repair-MSIXDesktop7Shortcut',
        'Set-MSIXActivePSFFramework',
        'Set-MSIXApplicationIcon',
        'Set-MSIXApplicationVisualElements',
        'Set-MSIXApplication',
        'Set-MSIXCore',
        'Set-MSIXForceletsConfiguration',
        'Set-MSIXPackageVersion',
        'Set-MSIXPublisher',
        'Set-MSIXSignature',
        'Start-MSIXTracing',
        'Stop-MSIXTracing',
        'Test-MSIXManifest',
        'Test-MSIXSignature',
        'Install-MSIXForceletsAllRequirements',
        'Update-MSIXMicrosoftPSF',
        'Update-MSIXTMPSF',
        'Update-MSIXTooling',
        'Wait-MSIXTracing'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('MSIX', 'AppX', 'PSF', 'PackageSupportFramework', 'Packaging',
                             'WindowsApps', 'MSIXPackagingTool', 'CodeSigning', 'Signing',
                             'Manifest', 'AppAttach', 'AVD', 'AzureVirtualDesktop',
                             'Repackaging', 'desktop7', 'AppV')
            LicenseUri   = 'https://github.com/AndreasNick/MSIXForcelets/blob/master/LICENSE'
            ProjectUri   = 'https://msixforcelets.nick-it.de'
            IconUri      = 'https://raw.githubusercontent.com/AndreasNick/MSIXForcelets/master/Images/f64x64.ico'
            ReleaseNotes = @'
1.0.3 - File type associations, application editing, icon repair, packaging refinements.

New cmdlets:
- Add/Get/Set/Remove-MSIXFileTypeAssociation: manage windows.fileTypeAssociation (FTA)
  entries (extensions, verbs, logo) per application.
- Set-MSIXApplication: edit Application entries - rename Id (-NewId), change the launcher
  (-Executable), set working directory and default parameters (uap11:CurrentDirectoryPath /
  uap11:Parameters) and toggle autostart (windows.startupTask) via -Autostart.
- Set-MSIXApplicationIcon: regenerate transparent icon assets (incl. unplated target sizes)
  and wire them into an Application's VisualElements in one call - fixes boxed/plated
  Start-menu and taskbar icons.

Improvements:
- New-MSIXAssetFrom -IncludeUnplatedTargetSizes: emits Square44x44Logo.targetsize-*_altform-unplated
  so Windows shows the icon unplated on the taskbar / Start app list.
- Close-MSIXPackage: -PrettyPrint (readable AppxManifest.xml) and -RegenerateResource
  (rebuild resources.pri via makepri after asset changes).
- Add-MSIXFlexibleVirtualization reworked into Disable / Directory / Registry parameter sets;
  selective HKCU-key and AppData-folder exclusions via -RegistryKey and -KnownFolder/-Folder
  (no arrays, no %ENV% strings).
- Add-MSIXDesktop7Shortcut -SubFolder; Get-/Remove-MSIXDesktop7Shortcut now also handle
  package-level shortcuts.
- Set-MSIXSignature -NoTimestamp plus a clearer signing-failure message.
- Add-MSIXloaderSearchPathOverride enforces the 5-path schema limit.
- Open-MSIXPackage resolves a relative -MsixFile against the current location.
- Get-MSIXApplications also returns UAP11 working directory/parameters and autostart state.

Breaking change:
- Add-MSIXDisableVREGOrRegistryWrite renamed to Add-MSIXDisableWriteVirtualization (clearer
  name; covers file-system AND registry write virtualization).

1.0.2 - Tags, Update-MSIXTMPSF format fix, umbrella Update cmdlet.

- Update-MSIXTMPSF now handles BOTH Tim Mangan PSF release formats: the legacy single
  ZipRelease*.zip wrapper AND the newer DebugPsf.zip + ReleasePsf.zip pair (introduced
  in v2026.05.01). Without this fix the cmdlet silently fell back to the previous
  release that still shipped the wrapper.
- Expanded PSGallery tags for discoverability: CodeSigning, Signing, Manifest,
  AppAttach, AVD, AzureVirtualDesktop, Repackaging, desktop7, AppV.
- New umbrella cmdlet Install-MSIXForceletsAllRequirements: downloads/updates MSIX
  Tooling (MSIX Core + SDK Packaging Tools), Tim Mangan's PSF AND the Microsoft PSF
  in one call. Use -Skip* switches to opt out of individual parts; -Force re-downloads
  existing components (= update path).

1.0.0 - Initial PowerShell Gallery release.

Highlights:
- Full MSIX/AppX package edit workflow: Open-MSIXPackage / Close-MSIXPackage,
  Set-MSIXPublisher, Set-MSIXSignature, Set-MSIXPackageVersion, Test-MSIXSignature.
- Package Support Framework (PSF) integration: Add-MSIXPsfFrameworkFiles, Add-MSXIXPSFShim,
  MFRFixup, RegLegacyFixups, FileRedirectionFixup, DynamicLibraryFixup, EnvVarFixup,
  PSF PowerShell scripts, FTA/COM, monitor/tracing helpers.
- desktop7:Shortcut management (Add/Get/Remove/Repair-MSIXDesktop7Shortcut) with
  per-user-location defaults and custom icon support.
- Ready-made fixes for common applications: Acrobat Reader DC, GIMP, LibreOffice,
  Notepad++, SSMS, WinRAR (incl. modern shell), and more.
- Asset generation (New-MSIXAssetFrom), application variants (New-MSIXApplicationVariant),
  capabilities, services, dependencies, App Attach (New-MSIXAppAttachImage,
  New-MSIXDynamicAppAttachDisk), self-signing certificates.
- Tooling helpers: Update-MSIXTooling, Update-MSIXTMPSF, Update-MSIXMicrosoftPSF.
  Note: large binaries (MSIX SDK, PSF redistributables) are downloaded on demand by
  these cmdlets and are NOT shipped in this package.

Compatible with Windows PowerShell 5.1 and PowerShell 7.x on Windows.

Docs:    https://msixforcelets.nick-it.de
Source:  https://github.com/AndreasNick/MSIXForcelets
'@
        }
    }
}
