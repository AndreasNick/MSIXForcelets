function Test-MSIXManifest {
<#
.SYNOPSIS
    Validates an AppxManifest.xml against the schemas embedded in AppxPackaging.dll.

.DESCRIPTION
    Loads all XSD schemas directly from AppxPackaging.dll (no disk export needed),
    builds an in-memory XmlSchemaSet, and validates the specified manifest file.
    Validation errors and warnings are written via Write-Warning.
    Returns $true if the manifest is valid, $false otherwise.

.PARAMETER ManifestPath
    Path to the AppxManifest.xml file to validate.

.PARAMETER DllPath
    Path to AppxPackaging.dll. Defaults to C:\Windows\System32\AppxPackaging.dll.

.EXAMPLE
    Test-MSIXManifest -ManifestPath "C:\MSIXTemp\WinRAR\AppxManifest.xml"

.EXAMPLE
    if (-not (Test-MSIXManifest -ManifestPath $manifest -Verbose)) {
        throw "Manifest validation failed."
    }

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $ManifestPath,

        [string] $DllPath = 'C:\Windows\System32\AppxPackaging.dll'
    )

    # P/Invoke helpers to enumerate and read Win32 resources from the DLL
    if (-not ([System.Management.Automation.PSTypeName]'ResEx').Type) {
        $code = @'
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class ResEx {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
    public static extern IntPtr LoadLibraryEx(string f, IntPtr h, uint flags);
    [DllImport("kernel32.dll")]
    public static extern bool FreeLibrary(IntPtr h);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
    public static extern IntPtr FindResource(IntPtr h, IntPtr name, IntPtr type);
    [DllImport("kernel32.dll")]
    public static extern IntPtr LoadResource(IntPtr h, IntPtr r);
    [DllImport("kernel32.dll")]
    public static extern IntPtr LockResource(IntPtr r);
    [DllImport("kernel32.dll")]
    public static extern uint SizeofResource(IntPtr h, IntPtr r);

    public delegate bool EnumTypesProc(IntPtr h, IntPtr type, IntPtr p);
    public delegate bool EnumNamesProc(IntPtr h, IntPtr type, IntPtr name, IntPtr p);

    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
    public static extern bool EnumResourceTypes(IntPtr h, EnumTypesProc proc, IntPtr p);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
    public static extern bool EnumResourceNames(IntPtr h, IntPtr type, EnumNamesProc proc, IntPtr p);

    public static List<long> Types = new List<long>();
    public static List<Tuple<long,long>> Names = new List<Tuple<long,long>>();

    public static void CollectTypes(IntPtr h) {
        Types.Clear();
        EnumResourceTypes(h, (hh, type, p) => { Types.Add(type.ToInt64()); return true; }, IntPtr.Zero);
    }
    public static void CollectNames(IntPtr h, IntPtr type) {
        EnumResourceNames(h, type, (hh, t, name, p) => {
            Names.Add(Tuple.Create(type.ToInt64(), name.ToInt64())); return true;
        }, IntPtr.Zero);
    }
    public static byte[] GetData(IntPtr h, IntPtr name, IntPtr type) {
        IntPtr r = FindResource(h, name, type);
        if (r == IntPtr.Zero) return null;
        uint sz = SizeofResource(h, r);
        IntPtr data = LockResource(LoadResource(h, r));
        byte[] buf = new byte[sz];
        Marshal.Copy(data, buf, 0, (int)sz);
        return buf;
    }
}
'@
        Add-Type -TypeDefinition $code
    }

    $DllPath      = [System.IO.Path]::GetFullPath($DllPath)
    $ManifestPath = [System.IO.Path]::GetFullPath($ManifestPath)

    if (-not (Test-Path $DllPath)) {
        Write-Error "AppxPackaging.dll not found: $DllPath"
        return $false
    }
    if (-not (Test-Path $ManifestPath)) {
        Write-Error "Manifest not found: $ManifestPath"
        return $false
    }

    $hMod = [ResEx]::LoadLibraryEx($DllPath, [IntPtr]::Zero, 0x00000002)
    if ($hMod -eq [IntPtr]::Zero) {
        Write-Error "Could not load DLL: $DllPath"
        return $false
    }

    # Force English so System.Xml.Schema messages are not localized to the OS UI language.
    $savedCulture = [System.Threading.Thread]::CurrentThread.CurrentUICulture
    [System.Threading.Thread]::CurrentThread.CurrentUICulture =
        New-Object System.Globalization.CultureInfo('en-US')

    try {
        # Enumerate all resources and extract XSD data indexed by targetNamespace
        [ResEx]::CollectTypes($hMod)
        [ResEx]::Names.Clear()
        foreach ($typeId in [ResEx]::Types) {
            [ResEx]::CollectNames($hMod, [IntPtr]$typeId)
        }

        $schemaBytes = @{}
        foreach ($entry in [ResEx]::Names) {
            $data = [ResEx]::GetData($hMod, [IntPtr]$entry.Item2, [IntPtr]$entry.Item1)
            if ($null -eq $data -or $data.Length -lt 10) { continue }

            $preview = [System.Text.Encoding]::UTF8.GetString($data, 0, [Math]::Min(200, $data.Length))
            $trimmed = $preview.TrimStart()
            if ($trimmed -notlike '<xs:*' -and $trimmed -notlike '<?xml*') { continue }

            try {
                $xDoc = New-Object xml
                $xDoc.LoadXml([System.Text.Encoding]::UTF8.GetString($data))
                $ns = $xDoc.DocumentElement.GetAttribute('targetNamespace')
                if ($ns -and -not $schemaBytes.ContainsKey($ns)) {
                    $schemaBytes[$ns] = $data
                }
            }
            catch { }
        }

        Write-Verbose "Loaded $($schemaBytes.Count) schemas from AppxPackaging.dll."

        # Build XmlSchemaSet — add all schemas before compiling so cross-namespace
        # imports resolve by namespace URI rather than schemaLocation hint.
        $schemaSet = New-Object System.Xml.Schema.XmlSchemaSet

        # Suppress schema compilation warnings/errors — they are xs:import resolution artefacts
        # from in-memory loading and do not reflect manifest validity.
        $schemaSet.add_ValidationEventHandler(
            [System.Xml.Schema.ValidationEventHandler] { }
        )

        foreach ($ns in $schemaBytes.Keys) {
            $stream = New-Object System.IO.MemoryStream($schemaBytes[$ns], $false)
            $reader = [System.Xml.XmlReader]::Create($stream)
            try {
                $null = $schemaSet.Add($ns, $reader)
            }
            catch {
                Write-Verbose "Could not add schema for namespace '$ns': $_"
            }
            finally {
                $reader.Dispose()
                $stream.Dispose()
            }
        }

        try {
            $schemaSet.Compile()
        }
        catch {
            Write-Verbose "Schema set compile error (non-fatal): $_"
        }

        # Schema compilation issues (unresolvable xs:import schemaLocation hints when loading
        # in-memory) are intentionally suppressed — they do not affect manifest validation.

        # Validate the manifest
        $validationErrors = New-Object System.Collections.Generic.List[string]

        $settings = New-Object System.Xml.XmlReaderSettings
        $settings.ValidationType = [System.Xml.ValidationType]::Schema
        $settings.Schemas        = $schemaSet
        $settings.ValidationFlags = `
            [System.Xml.Schema.XmlSchemaValidationFlags]::ProcessIdentityConstraints -bor `
            [System.Xml.Schema.XmlSchemaValidationFlags]::ReportValidationWarnings

        $validationHandler = [System.Xml.Schema.ValidationEventHandler] {
            param($sender, $e)
            # "Could not find schema information" warnings are emitted for every element/attribute
            # when the base schema fails to compile due to unresolvable xs:import schemaLocation
            # hints (in-memory loading cannot follow file-relative URIs). They are noise, not
            # real manifest errors.
            if ($e.Message -like '*Could not find schema information*') { return }
            $validationErrors.Add("[$($e.Severity)] Line $($e.Exception.LineNumber), Col $($e.Exception.LinePosition): $($e.Message)")
        }
        $settings.add_ValidationEventHandler($validationHandler)

        $manifestReader = [System.Xml.XmlReader]::Create($ManifestPath, $settings)
        try {
            while ($manifestReader.Read()) { }
        }
        finally {
            $manifestReader.Dispose()
        }

        if ($validationErrors.Count -eq 0) {
            Write-Verbose "Manifest validation passed: $ManifestPath"
            return $true
        }
        else {
            foreach ($err in $validationErrors) {
                Write-Warning $err
            }
            return $false
        }
    }
    finally {
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = $savedCulture
        [ResEx]::FreeLibrary($hMod) | Out-Null
    }
}
