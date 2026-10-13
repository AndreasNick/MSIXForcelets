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
GitHub releases into the tooling folder (see [Tooling location](#tooling-location)). Only
downloads when a newer version is available.

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

Both commands place the files under `<tooling>\MSIXPSF\` in a versioned subfolder.

### Tooling location

The downloaded tooling is kept in the module root **next to** the version folders, so
`Update-Module` does not trigger a new download, and every installation (AllUsers and
CurrentUser) keeps its own tooling:

```
C:\Program Files\WindowsPowerShell\Modules\MSIXForcelets\
    1.0.5\
    1.0.6\
    Tooling\        <- MSIXPSF\, Libs\MSIXPackaging\, Libs\MSIXCore\
```

On import the module uses the first match:

1. `$env:MSIXFORCELETS_TOOLING`, if set (e.g. a shared folder)
2. the module folder itself, if it already contains the tooling (source checkout, versions up to 1.0.5)
3. `<module root>\Tooling` when the module is loaded from a version folder — for an `-Scope AllUsers` installation under Program Files, downloads need an elevated PowerShell
4. `%LOCALAPPDATA%\MSIXForceletsTooling` otherwise (source checkout without tooling, build stage folder)

The import banner shows the active folder (`Tooling : ...`). After updating from 1.0.5 or
older, the banner points out that the tooling still sits in the old version folder. Take it
over without downloading, then remove the old versions:

```powershell
Update-Module MSIXForcelets
Import-Module MSIXForcelets -Force   # load the new version; the banner shows the hint
Copy-MSIXTooling                     # no download; elevated PowerShell for AllUsers
Import-Module MSIXForcelets -Force   # activate the copied tooling
Get-InstalledModule MSIXForcelets -AllVersions | Where-Object Version -ne (Get-Module MSIXForcelets).Version | Uninstall-Module
```

Alternatively download everything fresh with `Install-MSIXForceletsAllRequirements`.

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
    ForEach-Object { Add-MSIXPSFShim -MSIXFolder $pkg -MSIXAppID $_.Id -PSFArchitektur x64 }

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
# Use -IlvAware $true when Add-MSIXInstalledLocationVirtualization is also active
Add-MSIXPSFMFRFixup -MSIXFolder $pkg -IlvAware $true

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
| `Add-MSIXFixSSMS` | SQL Server Management Studio | SSMS 20 and earlier only; for 21/22 use `Add-MSIXFixSSMS22` |
| `Add-MSIXFixSSMS22` | SQL Server Management Studio 21/22 | Fixes the connection dialog (0x80070490) with a VS setup instance (state.json); removes NGEN images, VS Installer payload, captured services (`-NotRemoveServices` keeps them) and account stores; removes the Visual Studio Installer app and its Start menu entry |
| `Add-MSIXFixSumatraPDF` | SumatraPDF | Settings file in the real %LOCALAPPDATA% (flexible virtualization, Windows 11) so "Advanced Options" can edit it |
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
