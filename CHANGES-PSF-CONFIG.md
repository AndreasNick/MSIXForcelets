# Change request: PSF config generation (config.json.xml -> config.json)

Three confirmed defects in how MSIXForcelets turns `config.json.xml` into `config.json`.
All three were reproduced with the module source (1.0.8) on 2026-11-16. Follow the rules in
`CLAUDE.md`: PowerShell 5.1 compatible, English comments and docs, minimal focused changes.

Scope: only these three defects. MSIXForcelets is a one-pass tool (open, apply fixes, close).
Do **not** add support for editing a package a second time: no detection of existing launchers,
no import of a foreign `config.json`. Do **not** change launcher naming, Application Id renaming,
process exclusions or the BOM in `config.json`. PSF accepts all of these as they are.

Relevant code:
- `src/Data/Format.xsl` is the XSLT used by `Close-MSIXPackage`. `FormatOriginal.xsl` is not used; leave it alone.
- `src/Private/Convert-MSIXPSFXML2JSON.ps1` runs the transform, then applies the backslash regex post-processing.
- `src/Public/Close-MSIXPackage.ps1` calls the converter.
- These functions write values into `config.json.xml`: `Add-MSIXPSFShim`, `Add-MSIXPSFEnvVarFixup`, `Add-MSIXPSFDynamicLibraryFixup`,
  `Add-MSIXPSFFileRedirectionFixup`, `Add-MSIXPSFDefaultFRF`, `Add-MSIXPSFPowerShellScript`, `Add-MSIXPSFMonitor`,
  `Add-MSIXPSFRegLegacyFixup`, `Add-MSIXPSFDefaultRegLegacy`, `Add-MSIXPSFMFRFixup`, `Add-MSIXPSFTracing`, `Add-MSIXPSFFtaCom`
  and the `src/Public/Fixes/*` functions. Grep for `config.json.xml` to find them all.

---

## 1. EnvVarFixup entries are ignored by PSF

**Symptom:** Variables added with `Add-MSIXPSFEnvVarFixup` have no effect at runtime. There is no error.

**Cause:** `Format.xsl` emits:

```json
"config": { "envVariables": [ { "name": "...", "value": "..." } ] }
```

Tim Mangan's PSF reads only `envVars`, and every entry needs `useregistry` as a **string**.
See `D:\Development\GithubProjekte\TM-PSF\fixups\EnvVarFixup\InitializeFixup.cpp`:
- line 73: `rootObject.try_get("envVars")`
- lines 86-90: `get("name")`, `get("value")`, `get("useregistry").as_string()`

`get()` throws when a key is missing, and the surrounding `try/catch` silently drops that entry.
The shipped `EnvVarFixup64.dll` contains the string `envVars` but not `envVariables`.

**Required output:**

```json
"config": { "envVars": [ { "name": "A", "value": "B", "useregistry": "false" } ] }
```

**Changes:**
- `Format.xsl`, EnvVarFixup block:
  - Write the key `"envVars"`.
  - Add `"useregistry": "<value>"` to every entry, always quoted as a string. Take the value from the
    child element `<useregistry>`; when that element is missing, write `"false"`.
- Keep the XML element names `config/envVariables/envVariable/{name,value,useregistry}`. Existing
  `config.json.xml` files use them, and so does the MSIX Editor, which already writes `<useregistry>`.
- `Add-MSIXPSFEnvVarFixup`:
  - Add a `[switch] $UseRegistry` that writes `<useregistry>true</useregistry>` or `<useregistry>false</useregistry>`.
  - When an existing variable is replaced, update `useregistry` too.
  - Document the semantics in the help (from the PSF readme): with `useregistry` true, the value is looked up in the
    container registry (HKCU, then HKLM) and falls back to `value`; the app's writes go to `HKCU\EnvironmentVariables`.

## 2. Double quotes in values break Close-MSIXPackage

**Symptom:** `Add-MSIXPSFShim -Arguments '"%1"'` makes `Close-MSIXPackage` fail with
`Conversion from JSON failed ... unexpected character ... Path 'applications[0].arguments'`.

**Cause:** `Add-MSIXPSFShim` pre-escapes `"` as `\"` in the XML (lines ~252-263). The regex in
`Convert-MSIXPSFXML2JSON` (`(\\\\)|\\([^\\])`) then doubles that backslash, which yields `\\"` and ends the
JSON string early. Values from other writers that contain a raw `"` produce invalid JSON as well.

## 3. `&`, `<`, `>` are written as XML entities

**Symptom:** `-Arguments '/a & /b'` ends up in `config.json` as `"/a &amp; /b"`.

**Cause:** `Format.xsl` uses the default output method (xml), so text nodes are entity-escaped.

## Fix for 2 and 3: escape in the XSL, store plain values in the XML

The real problem is that the XML has no clear escaping convention. Some writers store plain values
(`VFS\ProgramFilesX64\App`). Others store JSON-escaped values: `Add-MSIXPSFDefaultFRF` patterns `.*\\.[eE][xX][eE]$`,
`Add-MSIXPSFDynamicLibraryFixup` `$relPathDoubleSlash`, `Add-MSIXPSFShim`'s `\"`. The regex tries to serve both.
It cannot tell `\"` (an escaped quote) from a path ending in `\` followed by the closing quote.

Target design:

1. **`config.json.xml` stores plain values.** Example: the pattern `.*\.exe$`, the path `VFS\App\a.dll`, the argument `"%1"`.
2. **`Format.xsl`:**
   - Use `<xsl:output method="text" encoding="UTF-8"/>`. This fixes defect 3.
   - Add a named XSLT 1.0 template, for example `json-string`, that escapes `\` as `\\` and `"` as `\"`
     (recursive `substring-before`/`substring-after` replace). Escaping tab, CR and LF as `\t`, `\r`, `\n` is optional.
   - Call the template for every value written between quotes. Booleans and numbers stay unquoted, as today.
3. **`Convert-MSIXPSFXML2JSON`:** Remove the backslash regex post-processing. Keep the `ConvertFrom-Json | ConvertTo-Json`
   pretty-print step; it now also validates the output.
4. **Writers:**
   - Stop pre-escaping. Remove `.Replace('"', '\"')` in `Add-MSIXPSFShim`.
   - Store single backslashes: the `Add-MSIXPSFDefaultFRF` patterns and the `Add-MSIXPSFDynamicLibraryFixup` paths
     (drop `$relPathDoubleSlash`).
   - **User input stays backward compatible:** the docs and ArgumentCompleters tell users to pass JSON-style
     double backslashes (`'.*\\.txt'`, `'Contoso\\config'`). Today the regex keeps a `\\` pair, which means one
     literal backslash. So convert user-supplied patterns, bases and paths with `-replace '\\\\', '\'` (two backslashes
     to one) before storing. That gives exactly today's result for every input.
     Put this in one private helper and use it in every writer.
   - Update help texts and ArgumentCompleters to show single backslashes. Double backslashes still work through the helper.
5. **Old XML files.** Packages built by earlier versions carry `config.json.xml` in the old convention. Mark the new
   convention with an attribute on the root, `<configuration format="2">`, set by every writer that creates or saves the file.
   When `Convert-MSIXPSFXML2JSON` loads a file without `format="2"`, it first migrates every text node: `\\` → `\`, then `\"` → `"`.
   In an XML text node, `\"` can only come from pre-escaping, so this step is unambiguous. Then it transforms as usual.
   The MSIX Editor writes plain values without the attribute; this migration handles them correctly.

## Tests

The repository has no Pester tests yet. Add a test script in `Test\`, either Pester tests that run on Windows PowerShell 5.1,
or a plain script that throws on failure, matching the existing `Test\` scripts.

For each case, open `MSIXEditor\tests\MsixEditor.Tests\TestData\HelloWorld.msix` (or any small package), apply the fix,
run `Close-MSIXPackage -KeepMSIXFolder`, parse `config.json` with `ConvertFrom-Json` and compare values:

| Input | Expected in config.json |
|---|---|
| `Add-MSIXPSFEnvVarFixup -Name A -Value B` | `envVars[0]` = `{name:"A", value:"B", useregistry:"false"}` |
| `... -UseRegistry` | `useregistry` = `"true"` |
| `Add-MSIXPSFShim -Arguments '"%1"'` | `arguments` = `"%1"` (with the quotes) |
| `Add-MSIXPSFShim -Arguments '/a & /b <x>'` | `arguments` = `/a & /b <x>` |
| `-WorkingDirectory 'VFS\ProgramFilesX64\App\'` (trailing backslash) | same string |
| `Add-MSIXPSFDefaultFRF` | patterns `.*\.[eE][xX][eE]$` etc. (one backslash after JSON parsing), as today |
| `Add-MSIXPSFFileRedirectionFixup` with `'.*\\.txt'` and with `'.*\.txt'` | both give the pattern `.*\.txt` |
| `Add-MSIXPSFDynamicLibraryFixup` | `filepath` = `VFS\...\x.dll` (one backslash after parsing), as today |
| An old-format `config.json.xml` (no `format` attribute, containing `\\` and `\"`) | the same `config.json` as the current code produces for it; values containing `\"` are now valid and keep their quotes |

Also run the existing example and fix scripts (`Examples\Test-PSFExamples.ps1`, the `Add-MSIXFix*` functions) and compare
the generated `config.json` before and after the change. Apart from the envVars fix, nothing should change.

## Not part of this request

- The changelog entry and module version bump (1.0.9) follow the repository's usual process. Ask the owner.
- No commits or pushes unless the owner asks.
