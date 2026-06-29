#
# Module manifest for module 'MSIXForcelets'
# Andreas Nick
#

@{
    RootModule           = 'MSIXForcelets.psm1'
    ModuleVersion        = '1.0.5'
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
        'Add-MSIXPSFShim',
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
    AliasesToExport   = @('Add-MSXIXPSFShim')

    PrivateData = @{
        PSData = @{
            Tags         = @('MSIX', 'AppX', 'PSF', 'PackageSupportFramework', 'Packaging',
                             'WindowsApps', 'MSIXPackagingTool', 'CodeSigning', 'Signing',
                             'Manifest', 'AppAttach', 'AVD', 'AzureVirtualDesktop',
                             'Repackaging', 'desktop7', 'AppV')
            LicenseUri   = 'https://github.com/AndreasNick/MSIXForcelets/blob/master/LICENSE'
            ProjectUri   = 'https://msixforcelets.nick-it.de'
            IconUri      = 'https://raw.githubusercontent.com/AndreasNick/MSIXForcelets/master/Images/f64x64.ico'
            ReleaseNotes = 'v1.0.5 - PSF reliability fixes (config.json booleans, backslash path escaping) plus application-variant and configuration improvements. Renamed misspelled Add-MSXIXPSFShim -> Add-MSIXPSFShim and -MISXAppID -> -MSIXAppID (old names kept as aliases). Full changelog: https://msixforcelets.nick-it.de/changelog.html'
        }
    }
}
