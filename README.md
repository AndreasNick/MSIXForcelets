# MSIXForcelets

PowerShell module for modifying, repackaging, and PSF-patching MSIX packages.
Provides a complete toolkit for opening, analysing, patching, and repacking MSIX files — including full Package Support Framework (PSF) integration.

> **Status:** Working beta. Actively used in production packaging workflows.

---

## Requirements

- Windows PowerShell 5.1 (Windows 10 / 11)
- No additional modules required

---

## Import

Clone or copy the repository, then import the `.psm1` directly:

```powershell
Import-Module "C:\Tools\MSIXForcelets\src\MSIXForcelets.psm1" -Force
```

For persistent availability, add the import to your PowerShell profile (`$PROFILE`).

---

## Initial Setup

### 1 — Download packaging tools

Downloads `makeappx.exe`, `signtool.exe`, and `msixmgr.exe` from the official Microsoft
GitHub releases into the module's `Libs\` folder. Only downloads when a newer version is
available.

```powershell
Update-MSIXTooling
```

### 2 — Download a PSF framework

**Microsoft PSF** (from NuGet):

```powershell
Update-MSIXMicrosoftPSF
```

**Tim Mangan PSF** (recommended — includes MFRFixup, FtaCom, RegLegacyFixup):

```powershell
Update-MSIXTMPSF
```

Both commands place the files under `<module>\MSIXPSF\` in a versioned subfolder.

---

## PSF Framework Selection

The module automatically selects the **latest Tim Mangan release** on import, falling back
to the latest Microsoft PSF if no Tim Mangan build is present.

```powershell
# Show all available PSF installations and the active one (marked with *)
Set-MSIXActivePSFFramework -List

# Switch to a specific framework
Set-MSIXActivePSFFramework -Framework MicrosoftPSF
Set-MSIXActivePSFFramework -Framework 'TimManganPSF\2026-2-22_release'
```

The `-Framework` parameter supports tab-completion.

---

## Module Configuration

```powershell
# Show current settings
Get-MSIXForceletsConfiguration

# Change default architecture (Auto | x64 | x86)
Set-MSIXForceletsConfiguration -PSFDefaultArchitecture x64
```

---

## Examples

### Analyse a package

```powershell
Import-Module "C:\Tools\MSIXForcelets\src\MSIXForcelets.psm1" -Force

Get-AppXManifestInfo "C:\Packages\MyApp.msix"
Get-MSIXApplications  "C:\Packages\MyApp.msix"
```

---

### Basic workflow — open, modify, repack, sign

```powershell
$cert     = 'CN=Contoso'
$pfxPath  = "$env:USERPROFILE\Desktop\Contoso.pfx"
$pfxPass  = 'MyPass' | ConvertTo-SecureString -Force -AsPlainText
$msixIn   = "$env:USERPROFILE\Desktop\MyApp_1.0.msix"
$msixOut  = "$env:USERPROFILE\Desktop\MyApp_1.0_patched.msix"

# Extract
$pkg = Open-MSIXPackage -MsixFile $msixIn -Force

# Adjust publisher to match signing certificate
Set-MSIXPublisher -MSIXFolder $pkg -PublisherSubject $cert

# Repack
Close-MSIXPackage -MSIXFolder $pkg -MSIXFile $msixOut

# Sign
Set-MSIXSignature -MSIXFile $msixOut -PfxCert $pfxPath -CertPassword $pfxPass
```

---

### Inject PSF — basic shim

Redirects all application entries through `PsfLauncher64.exe` and writes `config.json`.

```powershell
Set-MSIXActivePSFFramework -Framework 'TimManganPSF\2026-2-22_release'

$pkg = Open-MSIXPackage -MsixFile "C:\Packages\MyApp.msix" -Force

Add-MSIXPsfFrameworkFiles -MSIXFolder $pkg

Get-MSIXApplications -MSIXFolder $pkg |
    ForEach-Object { Add-MSXIXPSFShim -MSIXFolder $pkg -MISXAppID $_.Id -PSFArchitektur x64 }

Close-MSIXPackage -MSIXFolder $pkg -MSIXFile "C:\Packages\MyApp_PSF.msix"
```

---

### PSF — file redirection

```powershell
# Redirect all writes to .txt files (package-relative base)
Add-MSIXPSFFileRedirectionFixup -MSIXFolder $pkg `
    -Executable '.*' `
    -PackageRelative `
    -Patterns '.*\.txt'

# Redirect writes below a specific folder to a known folder
Add-MSIXPSFFileRedirectionFixup -MSIXFolder $pkg `
    -Executable 'MyApp$' `
    -KnownFolder 'LocalAppData' `
    -Patterns '.*\.log' `
    -RedirectTargetBase 'MyApp\Logs\'
```

---

### PSF — registry fixups (Microsoft PSF and Tim Mangan PSF)

```powershell
# Default HKCU/HKLM access normalisation rules — works with both PSF variants
Add-MSIXPSFDefaultRegLegacy -MSIXFolder $pkg
```

---

### PSF — MFR and DLL fixups (Tim Mangan PSF only)

```powershell
# Modern file redirection fixup (replaces FileRedirectionFixup)
# Use -IlvAware 'true' when Add-MSIXInstalledLocationVirtualization is also active
Add-MSIXPSFMFRFixup -MSIXFolder $pkg -IlvAware 'true'

# Register all package DLLs so PSF can resolve load requests
Add-MSIXPSFDynamicLibraryFixup -MSIXFolder $pkg
```

---

### PSF — tracing

Captures PSF trace output to the debugger or a file. Useful during packaging to identify
which fixups are needed.

```powershell
Add-MSIXPSFTracing -MSIXFolder $pkg `
    -Executable 'MyApp$' `
    -PSFArchitektur x64 `
    -TraceMethod outputDebugString `
    -TraceLevel allFailures

# View live output (requires DebugView or similar)
Start-MSIXPSFMonitor
```

---

### Full application fixes

Ready-made fix functions are available for several applications. Each function handles
all necessary steps — open, patch, repack — in one call.

| Function | Application | Notes |
|---|---|---|
| `Add-MSIXFixAcrobatReaderDC` | Acrobat Reader DC | Registry access fix + virtual key |
| `Add-MSIXFixGimp` | GIMP 2.x | DLL search path, disables update check, removes TWAIN plug-ins |
| `Add-MSIXFixLibreOffice` | LibreOffice | ILV, shared fonts, Start Menu grouping |
| `Add-MSIXFixSSMS` | SQL Server Management Studio | SSMS 20 and earlier only; newer versions are not supported |
| `Add-MSIXFixWinRAR` | WinRAR | Classic shell extensions are replaced by static verbs; dynamic menu labels ("Add to 'archive.rar'") are not possible |

---

### GIMP — complete fix

Corrects DLL loading, disables the built-in update check, and removes the TWAIN
plug-in folder that causes crashes in the MSIX container.

```powershell
$pfxPass = 'MyPass' | ConvertTo-SecureString -Force -AsPlainText

Add-MSIXFixGimp `
    -MsixFile       "$env:USERPROFILE\Desktop\gimp-2.10.36-x64.msix" `
    -OutputFilePath "$env:USERPROFILE\Desktop\gimp-2.10.36-x64_fixed.msix" `
    -Subject        'CN=Contoso' `
    -Force `
    -Verbose

Set-MSIXSignature `
    -MSIXFile   "$env:USERPROFILE\Desktop\gimp-2.10.36-x64_fixed.msix" `
    -PfxCert    "$env:USERPROFILE\Desktop\Contoso.pfx" `
    -CertPassword $pfxPass
```

---

### Manifest — add capabilities and virtualization

```powershell
# Add capability declarations
Add-MSIXCapabilities -MSIXFolder $pkg -Capabilities 'internetClient'

# Enable installed location virtualization (ILV)
Add-MSIXInstalledLocationVirtualization -MSIXFolderPath $pkg

# Override DLL search path
Add-MSIXloaderSearchPathOverride -MSIXFolderPath $pkg -FolderPaths 'VFS\ProgramFilesX64\MyApp'
```

---

### Cleanup and validation

```powershell
# Remove desktop7 shortcuts, temp files, empty folders
Invoke-MSIXCleanup -MSIXFolder $pkg

# Validate AppxManifest.xml against the MSIX schema
Test-MSIXManifest -MSIXFolder $pkg
```

---

## Links

- [Tim Mangan PSF](https://www.tmurgent.com/TmBlog/?p=3774)
- [Microsoft PSF](https://github.com/microsoft/MSIX-PackageSupportFramework)
- [MSIX Toolkit](https://github.com/microsoft/MSIX-Toolkit)
- [nick-it.de](https://www.nick-it.de)
