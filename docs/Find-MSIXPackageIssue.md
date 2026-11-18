# Find-MSIXPackageIssue

Analyses an expanded MSIX package, lists the problems it is likely to have and names the
Forcelets commands that fix them. Optionally writes a fix script that applies everything that
can be fixed automatically.

The rule set follows the package analysis of the MSIX Editor and is meant to grow. New rules are
added to the catalog below (see [Adding a rule](#adding-a-rule)).

- Source: [src/Public/Find-MSIXPackageIssue.ps1](../src/Public/Find-MSIXPackageIssue.ps1)
- Runs on Windows PowerShell 5.1 and PowerShell 7.x
- Read-only: the package folder is not changed; the registry hives are opened read-only
  (`RegLoadAppKey`, no administrative rights needed) and released afterwards

---

## Usage

```powershell
Import-Module MSIXForcelets

$Package = Open-MSIXPackage -MsixFile C:\Packages\MyApp.msix -Force

# Findings as objects
$findings = Find-MSIXPackageIssue -MSIXFolder $Package
$findings | Format-Table Severity, Category, Title, AutoFix -Wrap

# Store them
$findings | Export-Clixml C:\Temp\MyApp.findings.xml
$findings | ConvertTo-Json -Depth 4 | Set-Content C:\Temp\MyApp.findings.json

# Generate a fix script, review it, run it
Find-MSIXPackageIssue -MSIXFolder $Package -FixScriptPath C:\Temp\Fix-MyApp.ps1 | Out-Null
C:\Temp\Fix-MyApp.ps1 -MsixFile C:\Packages\MyApp.msix -OutputFile C:\Packages\MyApp_fixed.msix `
    -PfxFile C:\Certs\Contoso.pfx -PfxPassword (Read-Host -AsSecureString)
```

| Parameter        | Description                                                                 |
|------------------|-----------------------------------------------------------------------------|
| `-MSIXFolder`    | Expanded package folder (output of `Open-MSIXPackage`). Accepts pipeline input. |
| `-FixScriptPath` | Optional. Path of the fix script to write (UTF-8 with BOM).                 |
| `-ForcePSF`      | Optional. Adds the PSF (launcher, MFRFixup, RegLegacy defaults) even when no rule asks for it. |

---

## Output

One `PSCustomObject` per finding, sorted by severity (Error, Warning, Info), category and title.

| Property         | Content                                                                     |
|------------------|-----------------------------------------------------------------------------|
| `Severity`       | `Error`, `Warning` or `Info` (see below)                                    |
| `Category`       | `Known application`, `Package`, `Files`, `Runtime`, `Manifest`, `PSF`, `Services`, `Registry`, `Shell`, `COM`, `Analysis` |
| `Title`          | Short description                                                           |
| `Detail`         | Why it is a problem in the container                                        |
| `Recommendation` | What to do                                                                  |
| `Command`        | Forcelets commands for the fix script (string array, may be empty). Commands starting with `#` are suggestions only. |
| `AutoFix`        | `$true` when the commands are safe to run without a decision                |
| `Locations`      | Files, manifest entries or registry keys that triggered the finding         |

### Severity

| Severity  | Meaning                                                                     |
|-----------|-----------------------------------------------------------------------------|
| `Error`   | The application or the deployment fails, or a feature cannot work in MSIX. |
| `Warning` | Likely to fail or to behave differently than the installed application.    |
| `Info`    | Worth knowing; act only if the application shows the problem.              |

A rule that throws does not stop the analysis. It produces an `Error` finding in the category
`Analysis` ("Rule '...' failed"), so a missing check is never silent. The same applies to a hive
that cannot be loaded.

---

## Fix script

The generated script has these parameters:

| Parameter           | Description                                                              |
|---------------------|--------------------------------------------------------------------------|
| `-MsixFile`         | Original package (mandatory)                                             |
| `-OutputFile`       | Fixed package; default `<name>_fixed.msix`                                |
| `-PfxFile`          | Optional; signs the output with `Set-MSIXSignature`                       |
| `-PfxPassword`      | `SecureString` for the PFX                                                |
| `-Win16RuntimePath` | Only present when 16-bit applications were found: folder with `otvdm.exe` |

Flow: `Open-MSIXPackage` → commands → `Close-MSIXPackage` → optional `Set-MSIXSignature`.

Rules for the commands:

- Every finding is written as a comment block (`# [Severity] Title` and the recommendation).
- Commands of findings with `AutoFix = $true` are active; all others are commented out and need
  a decision or manual work.
- Commands are ordered by **stage**, active commands before commented ones within a stage.
  The same command is written only once.
- Commands refer to the package folder as `$Package`.
- Runtime DLLs are copied from the machine that **runs** the script (System32 / SysWOW64).
- Registry writes to the package hives stay commented out: they need an elevated PowerShell
  (see `Set-MSIXVirtualRegistryKey`).

| Stage | Content                                                         |
|-------|-----------------------------------------------------------------|
| 0     | Known application: ready-made `Add-MSIXFix*` function           |
| 1     | Files (delete, copy runtimes, cleanup)                          |
| 2     | Manifest (capabilities, extensions, aliases, shortcuts)         |
| 3     | Registry (package hives)                                        |
| 4     | PSF (framework files, launcher, fixups)                         |
| 9     | Analysis errors (no commands)                                   |

**Known application:** when a stage-0 finding exists, the script calls only the matching
`Add-MSIXFix*` function. That function opens, fixes and repacks the package itself; the generic
findings are added as comments for reference.

---

## Rule catalog

Columns: **Sev** = severity, **Auto** = AutoFix (active in the fix script), **Fix** = command
written to the script.

### Known applications (stage 0)

| Detected file          | Fix                                       | Sev  | Auto |
|------------------------|-------------------------------------------|------|------|
| `WinRAR.exe`           | `Add-MSIXFixWinRAR` (modern menu: `Add-MSIXFixWinRARModernShell`) | Info | yes |
| `notepad++.exe`        | `Add-MSIXFixNotepadPlusPlus`              | Info | yes  |
| `soffice.exe` / `.bin` | `Add-MSIXFixLibreOffice`                  | Info | yes  |
| `AcroRd32.exe`         | `Add-MSIXFixAcrobatReaderDC`              | Info | yes  |
| `gimp-<version>.exe`   | `Add-MSIXFixGimp`                         | Info | yes  |
| `SumatraPDF.exe`       | `Add-MSIXFixSumatraPDF`                   | Info | yes  |
| `Ssms.exe`             | `Add-MSIXFixSSMS22` (file version 21+), otherwise `Add-MSIXFixSSMS` | Info | yes |

The file must lie in the folder of a manifest application. A bundled copy deeper in the package
(e.g. the SumatraPDF viewer inside RStudio) is not a match.

### Package errors

| Rule | Trigger | Sev | Auto | Fix |
|------|---------|-----|------|-----|
| Empty executables | `.exe` / `.dll` with 0 bytes | Error | - | none (capture again) |
| Win16 executables | NE header | Warning | yes, if a manifest app is Win16 | copy OTVDM from `-Win16RuntimePath` to `VFS\ProgramFilesX86\otvdm`, `Add-MSIXPsfFrameworkFiles`, `Add-MSIXPSFShim -PSFArchitektur x64 -LauncherExecutable ...\otvdm.exe -Arguments <exe> -WorkingDirectory <dir>` |
| DOS executables | MZ without PE/NE header | Warning | - | hint: DOSBox / vDos via `Add-MSIXPSFShim -LauncherExecutable` |
| Missing files | `Executable` attributes and logos that do not exist (scale/targetsize qualifiers are resolved) | Error | - | hint: `Set-MSIXApplication -Executable`, `New-MSIXAssetFrom` |
| Architecture vs. VFS folder | x86 app in `ProgramFilesX64` or x64 app in `ProgramFilesX86` (manifest apps only) | Warning | - | none |

### Files

| Rule | Trigger | Sev | Auto | Fix |
|------|---------|-----|------|-----|
| Installer / uninstaller | `unins*.exe`, `uninstall*.exe`, `setup.exe`, `install.exe`, `_isres*`, `autorun.inf`, `setup.msi` | Warning | - | `Remove-Item` (commented) |
| Updaters | `*update(r).exe`, `updatesvc`, `sparkle`, `squirrel`, `googleupdate`, `edgeupdate`, `omaha`, `autoupdate`, `maintenanceservice`, task XML files (not the Squirrel `Update.exe`) | Info | - | `Remove-Item` (commented) |
| Desktop shortcuts | `.lnk` in a desktop folder | Warning | yes | `Remove-Item`; `Add-MSIXDesktop7Shortcut` (commented) |
| Internet shortcuts | `.url` in the VFS | Info | - | none |
| Nested packages | `.msix`, `.appx`, `.msixbundle`, `.appxbundle` | Warning | - | `Import-MSIXSparseShellExtension` (commented) |
| App Installer file | `*.appinstaller` | Info | yes | `Remove-Item` |
| Fonts | `.ttf` / `.otf` / `.ttc` without `windows.sharedFonts` | Info | yes, if in `VFS\Fonts` | `Add-MSIXSharedFonts` |
| Certificates | `.cer` / `.crt` without `windows.certificates` | Info | - | none |
| Cleanup | `VFS\Windows\Installer`, `VFS\Windows\Temp`, `*.pdb`, `*.tmp` | Info | yes | `Invoke-MSIXCleanup -RemoveShortcutExtensions $false` |
| Duplicate DLLs | same DLL name in several folders (outside `VFS\System*`) | Info | - | hint: `Add-MSIXloaderSearchPathOverride`, `Add-MSIXPSFDynamicLibraryFixup` |

### Runtimes

Imports are read from the PE import table of every `.exe` / `.dll` (PSF files excluded). A
runtime counts as missing when an imported DLL name does not exist anywhere in the package.

| Rule | Trigger | Sev | Auto | Fix |
|------|---------|-----|------|-----|
| Visual C++ 2015-2022 | `vcruntime140*`, `msvcp140*`, `concrt140`, `vccorlib140`, `mfc140*`, `vcomp140`; skipped with a `Microsoft.VCLibs.140.00` dependency | Warning | yes | copy per architecture to `VFS\SystemX64` / `VFS\SystemX86`; alternative as comment: `Microsoft.VCLibs.140.00.UWPDesktop` as `PackageDependency` |
| Imported DLLs outside the search path | an `.exe` imports a DLL that exists in the package, but not in its own folder, `VFS\System*` or a declared `LoaderSearchPathEntry` (same architecture only) | Warning | yes, up to 5 folders | `Add-MSIXloaderSearchPathOverride -FolderPaths <folders of the DLLs>` |
| Visual C++ 2010-2013 | `msvcr1x0`, `msvcp1x0`, `mfc1x0*`, `vcomp1x0` | Warning | yes | as above |
| Visual Basic 6 | `msvbvm60.dll` | Warning | yes | as above |
| Visual C++ 2005/2008 | `msvcr80/90`, `msvcp80/90`, `mfc80/90*` (side-by-side) | Warning | - | hint: redistributable or DLLs plus `Microsoft.VC*.CRT` manifest folder |
| .NET framework-dependent | `*.runtimeconfig.json` without `hostfxr.dll` next to it | Warning | - | hint: install runtime or publish self-contained |
| .NET Framework 3.5 | `*.exe.config` supports only v2.0 | Warning | - | hint: enable `NetFx3` |
| .NET self-contained | `hostfxr.dll` | Info | - | none |
| Java | `*\bin\java.exe` | Info | - | `Add-MSIXPSFRegLegacyFixup -JavaBlocker` (commented) |
| Python | `python3*.dll` | Info | - | none |
| WebView2 | `WebView2Loader.dll`, `Microsoft.Web.WebView2.Core.dll` | Info | - | hint: runtime on Windows 10 |
| Electron | `resources\app.asar` | Info | - | `Add-MSIXPSFEnvVarFixup ELECTRON_DISABLE_SANDBOX=1` (commented, lowers protection) |

### Executables and manifest

| Rule | Trigger | Sev | Auto | Fix |
|------|---------|-----|------|-----|
| Elevation (apps) | embedded manifest of a manifest app requests `requireAdministrator` / `highestAvailable`, no `allowElevation` | Warning | yes | `Add-MSIXCapabilities allowElevation` |
| Elevation (helpers) | only helper executables request elevation | Info | - | same command, commented |
| uiAccess | `uiAccess="true"` | Error | - | none (vendor rebuild) |
| Network capabilities | imports `wininet`/`winhttp`/`ws2_32`, `wsock32`, `fwpuclnt` and the package has **no** `runFullTrust` | Warning | yes | `Add-MSIXCapabilities internetClient` / `internetClientServer` / `privateNetworkClientServer` |
| Camera / microphone | imports `avicap32`, `mfsensorgroup`, `mfreadwrite`, no `webcam` capability | Info | - | `Add-MSIXCapabilities webcam, microphone` (commented) |
| Upper-case GUIDs | GUIDs with `A-F` in attributes (build metadata ignored) | Info | yes | inline regex: lower-case all GUIDs in `AppxManifest.xml` |
| IoT / mobile namespaces | `xmlns:*` pointing to `/iot/` or `/mobile/` | Info | - | none |
| Package integrity | `PackageIntegrity` element in the manifest | Warning | yes | `Remove-MSIXPackageIntegrity` |
| Installed location virtualization | no `InstalledLocationVirtualization` in the manifest (every package) | Info | yes | `Add-MSIXInstalledLocationVirtualization` |
| desktop7 Startup shortcut | `[{Startup}]` / `[{Common Startup}]` | Error | yes | `Remove-MSIXDesktop7Shortcut` |
| desktop7 all-users Start menu | `[{Common Programs}]` | Info | yes | `Repair-MSIXDesktop7Shortcut` |
| Declared services | `Get-MSIXServices` returns entries | Warning | - | `Remove-MSIXServices` (commented) |

### Layouts of other installers and packaging tools

| Rule | Trigger | Sev | Auto | Fix |
|------|---------|-----|------|-----|
| PortableApps | `App\AppInfo\appinfo.ini` | Warning | yes, if `ProgramExecutable` resolves | `Set-MSIXApplication -Executable <real exe>` for `*Portable.exe` apps |
| Squirrel | `Update.exe` next to `app-<version>` folders | Warning | yes, if a main exe is found | `Set-MSIXApplication -Executable <newest app-x\largest exe>`, `Remove-Item Update.exe`; older `app-*` folders (commented) |

### PSF

The PSF is only proposed when a rule finds a reason for it, or with `-ForcePSF`. All rules are
skipped when the package already contains the PSF (`config.json(.xml)` or a `PsfLauncher` entry).
Win16 apps are excluded (they get their own launcher entry).

| Rule | Trigger | Sev | Auto | Fix |
|------|---------|-----|------|-----|
| Writes to the install folder | `*.log`, `*.tmp`, `*.cache`, `settings.*`, `user.*`, `state.*` next to an app executable | Warning | yes | `Add-MSIXPsfFrameworkFiles -MFFixup -RegLegacyFixup`, `Add-MSIXPSFShim` per app, `Add-MSIXPSFMFRFixup`, `Add-MSIXPSFDefaultRegLegacy` |
| Working directory | config files (`.ini .cfg .config .txt .dat .xml .json`) next to an app executable | Warning | yes | same PSF block with `-WorkingDirectory`; `Set-MSIXApplication -UAP11WorkingDirectory` (commented, Windows 11) |
| PSF on request | `-ForcePSF` | Info | yes | same PSF block |

Not counted as config files for the working-directory rule: `*.exe.config`, `*.dll.config`,
`*.deps.json`, `*.runtimeconfig.json`, XML documentation next to a DLL of the same name, and
license/readme/changelog files. Apps with `uap11:CurrentDirectoryPath` are skipped.

### Registry (package hives)

Read from `Registry.dat` (HKLM, HKCU branch), `User.dat` and `UserClasses.dat`, including
`WOW6432Node`. Entries already declared in the manifest are skipped.

| Rule | Trigger | Sev | Auto | Fix |
|------|---------|-----|------|-----|
| Services | `SYSTEM\*ControlSet*\Services\*` with `ImagePath`, not declared as `windows.service` | Warning | - | `Remove-MSIXVirtualRegistryKey` (commented, elevated) |
| Run keys | `...\CurrentVersion\Run`, no `windows.startupTask` | Info | yes, if the target exe is in the package | `Set-MSIXApplication -Autostart $true -AutostartExecutable` |
| RunOnce | `...\CurrentVersion\RunOnce` | Info | - | none |
| Uninstall keys | `...\CurrentVersion\Uninstall\*` | Warning | - | `Remove-MSIXVirtualRegistryKey` (commented, elevated) |
| App Paths alias | `App Paths\<alias>` pointing into the package, no matching alias | Info | yes | `Add-MSIXAppExecutionAlias` |
| App Paths search path | `App Paths\<alias>\Path` with package folders | Warning | yes | `Add-MSIXloaderSearchPathOverride` (max. 5 folders) |
| Firewall rules | `FirewallRules` allow rule for a package exe | Warning | yes, for one numeric TCP/UDP port | `Add-MSIXFirewallRule` |
| File type associations | `.<ext>` with `shell\open\command` to a package exe | Warning | yes | `Add-MSIXFileTypeAssociation` (grouped per ProgId) |
| URL protocols | class key with `URL Protocol` value | Warning | - | hint: `windows.protocol` |
| Shell extensions | `ContextMenu`, `DragDrop`, `PropertySheet`, `CopyHook` handlers on `*`, `Directory`, `Folder`, `Drive`, ... | Error | - | hint: desktop9 handler, ready-made fixes, `Import-MSIXSparseShellExtension` |
| Shell verbs | `<target>\shell\<verb>` with `command` (Warning) or `ExplorerCommandHandler` (Error) | Warning / Error | - | hint: `desktop4:FileExplorerContextMenus` / desktop9 |
| Preview / thumbnail handlers | `.<ext>\shellex\{8895b1c6...}` / `{e357fccd...}` | Warning | - | hint: declare in the FTA |
| Icon / drop handlers | `<ProgId>\shellex\IconHandler` / `DropHandler` | Warning | - | none (no MSIX equivalent) |
| Property handlers | `PropertySystem\PropertyHandlers\<ext>` | Warning | - | hint: `desktop2:DesktopPropertyHandler` |
| COM servers | `CLSID\*\InProcServer32` / `LocalServer32` pointing into the package | Info | - | hint: `com:Extension` only for out-of-process consumers |
| 8.3 short paths | string values like `PROGRA~1` (max. 30000 keys / 30 hits) | Warning | - | hint: `Set-MSIXVirtualRegistryKey` (elevated) |

---

## Adding a rule

Rules are script blocks in the ordered hashtable `$rules` inside the `process` block. Each rule
returns zero or more findings created with `Write-Finding`; the analysis loop collects them,
catches exceptions and sorts the result.

```powershell
$rules['My rule'] = {
    $hits = @($files | Where-Object { $_.Name -like '*.foo' } | ForEach-Object Path)
    if ($hits.Count -gt 0) {
        Write-Finding Warning 'Files' 'Foo files in the package' `
            'Why this breaks in the container.' `
            'What to do.' `
            -Command @("Remove-Item -LiteralPath (Join-Path `$Package $(ConvertTo-Literal $hits[0])) -Force") `
            -AutoFix $false -Locations $hits -Stage 1
    }
}
```

### Available data and helpers

| Name | Content |
|------|---------|
| `$root` | Package folder (full path) |
| `$files` | All files: `Path` (relative), `Name`, `FullName`, `Length` |
| `$shippedNames` | Hashtable of all file names in lower case |
| `$manifest` / `$manifestText` | `AppxManifest.xml` as `XmlDocument` / string |
| `& $mentions 'text'` | Case-insensitive search in the manifest text |
| `$apps`, `$primaryApp` | Manifest applications (`Id`, `Executable`) |
| `$appTargets` | Apps whose executable exists in the package (no PSF launcher, no Win16) |
| `& $appForExe 'path'` | App for an executable, falls back to the primary app |
| `$hasPsf` | Package already contains the PSF |
| `& $getPE` | Hashtable `path -> (Kind, Machine, Imports)` of all exe/dll files, read once |
| `Get-ExeManifestInfo` | Requested execution level and uiAccess of an exe |
| `$softwareRoots`, `$classRoots` | Registry roots as `(hive, path, display prefix)` |
| `& $subKeys`, `& $valueNames`, `& $regValue` | Short registry reads (open and close the key) |
| `& $openKey` | Keeps the key open; disposed at the end of the analysis |
| `Resolve-VfsToken` | `[{ProgramFilesX64}]\x.exe` → `VFS\ProgramFilesX64\x.exe` |
| `Split-CommandLine` | Command line → executable and arguments |
| `ConvertTo-Literal` | Value → single-quoted PowerShell literal for the fix script |
| `Get-RuntimeCopyCommand` | Fix-script line that copies a system DLL into `VFS\SystemX64/X86` |

### Conventions

- Use existing Forcelets cmdlets in `Command`; do not add new cmdlets for a rule.
- `AutoFix = $true` only when the command is safe without a decision and does not need
  elevation. Everything else is written commented out (prefix `#`).
- Choose the stage by what the command changes (files 1, manifest 2, registry 3, PSF 4).
- Skip what the manifest already declares (`& $mentions`), to avoid repeating fixed findings.
- Keep the analysis read-only and dispose every registry key; an open handle locks the hive.
- Keep the rule fast: use `$files` and `& $getPE` instead of reading the disk again.
- Update the [rule catalog](#rule-catalog) in this document.

---

## Test status

Verified on Windows PowerShell 5.1 and PowerShell 7 (identical results):

| Package                  | Findings before | AutoFix | Findings after fix script |
|--------------------------|-----------------|---------|---------------------------|
| HelloWorld               | 0               | 0       | 0                         |
| Paint.NET 5.1.12 (x64)   | 8               | 3       | 5 (no AutoFix left)       |
| Metal Heart (ILV, x86)   | 0               | 0       | 0                         |

Analysis time: 1-2 seconds per package. The hives stay unlocked after the analysis.

Rules not yet exercised by a real package: runtime DLL copy (VC++, VB6), firewall rules, file
type associations, Run keys, PortableApps, Squirrel, Win16/OTVDM, Electron.

---

## Known limitations

- Static analysis only: dynamically loaded DLLs (`LoadLibrary`), runtime file writes and
  registry access are not seen. Use `Add-MSIXPSFTracing` or Process Monitor for those.
- Runtime detection relies on the import table; delay-loaded DLLs are not covered.
- The working-directory and install-folder rules are heuristics based on files next to the
  executable.
- Registry fixes need an elevated PowerShell and are therefore never active in the fix script.
