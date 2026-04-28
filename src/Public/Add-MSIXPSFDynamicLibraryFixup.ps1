function Add-MSIXPSFDynamicLibraryFixup {
<#
.SYNOPSIS
    Adds a DynamicLibraryFixup configuration entry for all package DLLs to config.json.xml.

.DESCRIPTION
    Scans the expanded MSIX package for application DLLs and registers them in
    config.json.xml under a DynamicLibraryFixup.dll fixup entry. This allows
    the PSF to resolve DLL load requests to the correct package-relative path,
    preventing failures when the application searches system paths for DLLs
    that only exist inside the MSIX container.

    PSF infrastructure DLLs (fixup DLLs, launchers, VC++ runtimes, Windows API
    sets) and DLLs located in VFS\SystemX64 / VFS\SystemX86 are excluded
    automatically.

    Architecture is inferred per DLL and written only when Tim Mangan PSF is
    active. The Microsoft PSF DynamicLibraryFixup does not support the
    architecture field; it uses only name and filepath.
      - Filename contains "32" or path contains ProgramFilesX86  -> x86
      - Filename contains "64" or path contains ProgramFilesX64  -> x64
      - Otherwise the value of -DefaultArchitecture is used (default: x64)

    The filepath is stored with double backslashes so that the PSF XML-to-JSON
    converter produces valid JSON output ("VFS\\...").

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain config.json.xml).

.PARAMETER Executable
    Regex pattern for the process entry in config.json.xml.
    Default: ".*" (catch-all for all processes).

.PARAMETER ExcludeNames
    Additional DLL filenames (with .dll extension) to exclude from the scan,
    e.g. @('MyHelper.dll').

.PARAMETER ExcludeFolders
    Package-relative folder paths whose DLLs are skipped entirely.
    Default: VFS\SystemX64 and VFS\SystemX86 (OS-managed DLLs).

.PARAMETER DefaultArchitecture
    Architecture written to entries whose architecture cannot be inferred from
    the filename or path. Valid values: x64 (default), x86.

.EXAMPLE
    Add-MSIXPSFDynamicLibraryFixup -MSIXFolder "C:\MSIXTemp\WinRAR"

.EXAMPLE
    Add-MSIXPSFDynamicLibraryFixup -MSIXFolder "C:\MSIXTemp\App" `
        -ExcludeNames @('LegacyHelper.dll') `
        -DefaultArchitecture x64 `
        -Verbose

.NOTES
    Requires Tim Mangan PSF DynamicLibraryFixup.dll to be present in the package.
    Run Add-MSIXPsfFrameworkFiles before this function.
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [String] $Executable = '.*',

        [String[]] $ExcludeNames = @(),

        [String[]] $ExcludeFolders = @('VFS\SystemX64', 'VFS\SystemX86'),

        [ValidateSet('x64', 'x86')]
        [String] $DefaultArchitecture = 'x64'
    )

    process {
        if (-not (Test-Path $MSIXFolder.FullName -PathType Container)) {
            Write-Error "MSIXFolder not found: $($MSIXFolder.FullName)"
            return
        }

        $configXmlPath = Join-Path $MSIXFolder.FullName 'config.json.xml'
        if (-not (Test-Path $configXmlPath)) {
            Write-Error "config.json.xml not found in '$($MSIXFolder.FullName)'. Run Add-MSXIXPSFShim or another fixup function first."
            return
        }

        # PSF infrastructure DLL basename patterns (checked without extension)
        $psfExcludePatterns = @(
            '^DynamicLibraryFixup',
            '^FileRedirectionFixup',
            '^RegLegacyFixups',
            '^EnvVarFixup',
            '^TraceFixup',
            '^MFRFixup',
            '^PsfRuntime',
            '^PsfRunDll',
            '^PsfLauncher',
            '^msvcp',
            '^vcruntime',
            '^api-ms-win-',
            '^ucrtbase',
            '^concrt140'
        )

        $msixRoot = $MSIXFolder.FullName.TrimEnd('\')

        # Build absolute excluded folder prefixes for fast comparison
        $excludedPrefixes = $ExcludeFolders | ForEach-Object {
            (Join-Path $msixRoot $_).TrimEnd('\') + '\'
        }

        $allDlls = Get-ChildItem -Path $msixRoot -Filter '*.dll' -Recurse -File

        $pathEntries = New-Object System.Collections.ArrayList

        foreach ($dll in $allDlls) {
            $fullPath  = $dll.FullName
            $fileName  = $dll.Name
            $baseName  = [System.IO.Path]::GetFileNameWithoutExtension($fileName)

            # Skip DLLs in excluded folders
            $skip = $false
            foreach ($prefix in $excludedPrefixes) {
                if ($fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $skip = $true
                    break
                }
            }
            if ($skip) {
                Write-Verbose "Skipping (excluded folder): $fileName"
                continue
            }

            # Skip PSF infrastructure DLLs
            $isPsf = $false
            foreach ($pat in $psfExcludePatterns) {
                if ($baseName -match $pat) {
                    $isPsf = $true
                    break
                }
            }
            if ($isPsf) {
                Write-Verbose "Skipping (PSF infrastructure): $fileName"
                continue
            }

            # Skip user-specified names (match with or without extension)
            $userExcluded = $false
            foreach ($excl in $ExcludeNames) {
                if ($excl -eq $fileName -or $excl -eq $baseName) {
                    $userExcluded = $true
                    break
                }
            }
            if ($userExcluded) {
                Write-Verbose "Skipping (user excluded): $fileName"
                continue
            }

            # Package-relative path with double backslashes for JSON compatibility.
            # Use String.Replace (not -replace regex) so each \ becomes \\.
            $relPath  = $fullPath.Substring($msixRoot.Length + 1)
            $relPathDoubleSlash = $relPath.Replace('\', '\\')

            # Infer architecture from filename, then from path
            $arch = $DefaultArchitecture
            if ($baseName -match '32') {
                $arch = 'x86'
            }
            elseif ($baseName -match '64') {
                $arch = 'x64'
            }
            elseif ($relPath -match '\\ProgramFilesX86\\') {
                $arch = 'x86'
            }
            elseif ($relPath -match '\\ProgramFilesX64\\') {
                $arch = 'x64'
            }

            $null = $pathEntries.Add([PSCustomObject]@{
                Name     = $fileName
                FilePath = $relPathDoubleSlash
                Arch     = $arch
            })
            Write-Verbose "Found DLL ($arch): $fileName -> $relPath"
        }

        if ($pathEntries.Count -eq 0) {
            Write-Warning "No application DLLs found in '$($MSIXFolder.FullName)'. No DynamicLibraryFixup entry added."
            return
        }

        # architecture field is Tim Mangan PSF-only; Microsoft PSF only supports name + filepath
        $writeArchitecture = $Script:PsfBasePath -like '*TimMangan*'

        Write-Verbose "Adding DynamicLibraryFixup for $($pathEntries.Count) DLL(s) to process '$Executable'."

        $conxml = New-Object xml
        $conxml.Load($configXmlPath)

        Initialize-MSIXPSFProcessSection -ConXml $conxml

        # Find or create the target process node
        $procExecNode = $conxml.SelectSingleNode(
            "//processes/process/executable[text()='$Executable']")
        if ($null -eq $procExecNode) {
            $proc = $conxml.CreateElement('process')
            $exec = $conxml.CreateElement('executable')
            $exec.InnerText = $Executable
            $null = $proc.AppendChild($exec)
            $null = $conxml.SelectSingleNode('//processes').AppendChild($proc)
            $procExecNode = $conxml.SelectSingleNode(
                "//processes/process/executable[text()='$Executable']")
        }
        $procNode = $procExecNode.ParentNode

        # Ensure <fixups> element exists on the process node
        $fixupsNode = $procNode.SelectSingleNode('fixups')
        if ($null -eq $fixupsNode) {
            $fixupsNode = $conxml.CreateElement('fixups')
            $null = $procNode.AppendChild($fixupsNode)
        }

        # Find existing DynamicLibraryFixup.dll entry or create a new one
        $existingDllNode = $fixupsNode.SelectSingleNode(
            "fixup/dll[text()='DynamicLibraryFixup.dll']")

        if ($null -ne $existingDllNode) {
            $fixupParent = $existingDllNode.ParentNode

            # Repair incomplete entries left by previous runs (e.g. dll-only without config)
            $configNode = $fixupParent.SelectSingleNode('config')
            if ($null -eq $configNode) {
                $configNode = $conxml.CreateElement('config')
                $forceEl2 = $conxml.CreateElement('forcePackageDllUse')
                $forceEl2.InnerText = 'true'
                $null = $configNode.AppendChild($forceEl2)
                $null = $fixupParent.AppendChild($configNode)
                Write-Verbose "Repaired existing DynamicLibraryFixup entry: added missing <config>."
            }

            $relativeDllPathsNode = $configNode.SelectSingleNode('relativeDllPaths')
            if ($null -eq $relativeDllPathsNode) {
                $relativeDllPathsNode = $conxml.CreateElement('relativeDllPaths')
                $null = $configNode.AppendChild($relativeDllPathsNode)
                Write-Verbose "Repaired existing DynamicLibraryFixup entry: added missing <relativeDllPaths>."
            }
        }
        else {
            $fixupEl = $conxml.CreateElement('fixup')

            $dllEl = $conxml.CreateElement('dll')
            $dllEl.InnerText = 'DynamicLibraryFixup.dll'
            $null = $fixupEl.AppendChild($dllEl)

            $configEl = $conxml.CreateElement('config')

            $forceEl = $conxml.CreateElement('forcePackageDllUse')
            $forceEl.InnerText = 'true'
            $null = $configEl.AppendChild($forceEl)

            $relativeDllPathsNode = $conxml.CreateElement('relativeDllPaths')
            $null = $configEl.AppendChild($relativeDllPathsNode)

            $null = $fixupEl.AppendChild($configEl)
            $null = $fixupsNode.AppendChild($fixupEl)
        }

        foreach ($entry in $pathEntries) {
            # Idempotent: skip if this DLL name is already registered
            $existing = $relativeDllPathsNode.SelectSingleNode(
                "relativeDllPath/name[text()='$($entry.Name)']")
            if ($null -ne $existing) {
                Write-Verbose "DLL already in config: $($entry.Name)"
                continue
            }

            $pathEl = $conxml.CreateElement('relativeDllPath')

            $nameEl = $conxml.CreateElement('name')
            $nameEl.InnerText = $entry.Name
            $null = $pathEl.AppendChild($nameEl)

            $fileEl = $conxml.CreateElement('filepath')
            $fileEl.InnerText = $entry.FilePath
            $null = $pathEl.AppendChild($fileEl)

            if ($writeArchitecture) {
                $archEl = $conxml.CreateElement('architecture')
                $archEl.InnerText = $entry.Arch
                $null = $pathEl.AppendChild($archEl)
            }

            $null = $relativeDllPathsNode.AppendChild($pathEl)
        }

        $conxml.PreserveWhiteSpace = $false
        $conxml.Save($configXmlPath)

        Write-Verbose "DynamicLibraryFixup configured: $($pathEntries.Count) DLL path(s) written to config.json.xml."
    }
}
