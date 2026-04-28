function Add-MSIXPSFRegLegacyFixup {
<#
.SYNOPSIS
    Adds a RegLegacyFixups remediation entry to an MSIX package.

.DESCRIPTION
    Appends one remediation rule to the RegLegacyFixups configuration in
    config.json.xml. Call the function once per rule; multiple calls
    accumulate entries in the same remediation array.

    The DLL is always referenced as RegLegacyFixups.dll (no architecture
    suffix); the PSF launcher selects the correct 32- or 64-bit file at
    runtime.

    config.json structure produced:
        "config": [ { "remediation": [ ... ] } ]

    Parameter sets:
      -ModifyKeyAccess  Adjusts requested access rights on registry key opens.
                        Supported by Microsoft PSF and Tim Mangan PSF.
      -FakeDelete       Returns success for key deletions that fail with
                        ACCESS_DENIED. Both PSF versions.
      -DeletionMarker   Hides keys/values beneath a marked deletion point.
                        Both PSF versions.
      -HKLM2HKCU        Redirects HKLM writes to virtual HKCU.
                        Tim Mangan PSF only.
      -JavaBlocker      Blocks detection of Java versions above a threshold.
                        Tim Mangan PSF only.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain config.json.xml).

.PARAMETER Executable
    Regex pattern for the process entry. Default: ".*" (all processes).

.PARAMETER ModifyKeyAccess
    Selects the ModifyKeyAccess remediation type.

.PARAMETER FakeDelete
    Selects the FakeDelete remediation type.

.PARAMETER DeletionMarker
    Selects the DeletionMarker remediation type.

.PARAMETER HKLM2HKCU
    Selects the HKLM2HKCU remediation type (Tim Mangan PSF only).

.PARAMETER JavaBlocker
    Selects the JavaBlocker remediation type (Tim Mangan PSF only).

.PARAMETER Hive
    Registry hive: HKCU or HKLM.

.PARAMETER Patterns
    Array of regex patterns matching the registry key paths.

.PARAMETER Access
    Access transformation for ModifyKeyAccess.
    Full2MaxAllowed  Full access requested -> MAXIMUM_ALLOWED
    RW2MaxAllowed    ReadWrite requested   -> MAXIMUM_ALLOWED
    Full2R           Full access requested -> Read only
    RW2R             ReadWrite requested   -> Read only
    Full2RW          Full access requested -> ReadWrite (removes KEY_CREATE_LINK)

.PARAMETER Key
    Base key pattern for DeletionMarker (the root beneath which entries are hidden).

.PARAMETER MajorVersion
    Major Java version threshold for JavaBlocker.

.PARAMETER MinorVersion
    Minor Java version threshold for JavaBlocker. Default: 0.

.PARAMETER UpdateVersion
    Update Java version threshold for JavaBlocker. Default: 0.

.EXAMPLE
    Add-MSIXPSFRegLegacyFixup -MSIXFolder $f -ModifyKeyAccess -Hive HKCU -Patterns @('.*') -Access Full2MaxAllowed

.EXAMPLE
    Add-MSIXPSFRegLegacyFixup -MSIXFolder $f -FakeDelete -Hive HKCU -Patterns @('.*')

.EXAMPLE
    Add-MSIXPSFRegLegacyFixup -MSIXFolder $f -HKLM2HKCU -Hive HKLM

.EXAMPLE
    Add-MSIXPSFRegLegacyFixup -MSIXFolder $f -JavaBlocker -MajorVersion '1' -MinorVersion '8' -UpdateVersion '133'

.NOTES
    Microsoft PSF: https://github.com/microsoft/MSIX-PackageSupportFramework/tree/main/fixups/RegLegacyFixups
    Tim Mangan PSF: https://github.com/TimMangan/MSIX-PackageSupportFramework/wiki/Fixup:-RegLegacyFixup
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding(DefaultParameterSetName = 'ModifyKeyAccess')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0,
            ParameterSetName = 'ModifyKeyAccess')]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0,
            ParameterSetName = 'FakeDelete')]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0,
            ParameterSetName = 'DeletionMarker')]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0,
            ParameterSetName = 'HKLM2HKCU')]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0,
            ParameterSetName = 'JavaBlocker')]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [Parameter(ParameterSetName = 'ModifyKeyAccess')]
        [Parameter(ParameterSetName = 'FakeDelete')]
        [Parameter(ParameterSetName = 'DeletionMarker')]
        [Parameter(ParameterSetName = 'HKLM2HKCU')]
        [Parameter(ParameterSetName = 'JavaBlocker')]
        [String] $Executable = '.*',

        # --- type discriminators ---
        [Parameter(ParameterSetName = 'ModifyKeyAccess', Mandatory = $true)]
        [Switch] $ModifyKeyAccess,

        [Parameter(ParameterSetName = 'FakeDelete', Mandatory = $true)]
        [Switch] $FakeDelete,

        [Parameter(ParameterSetName = 'DeletionMarker', Mandatory = $true)]
        [Switch] $DeletionMarker,

        [Parameter(ParameterSetName = 'HKLM2HKCU', Mandatory = $true)]
        [Switch] $HKLM2HKCU,

        [Parameter(ParameterSetName = 'JavaBlocker', Mandatory = $true)]
        [Switch] $JavaBlocker,

        # --- shared parameters ---
        [Parameter(ParameterSetName = 'ModifyKeyAccess', Mandatory = $true)]
        [Parameter(ParameterSetName = 'FakeDelete', Mandatory = $true)]
        [Parameter(ParameterSetName = 'DeletionMarker', Mandatory = $true)]
        [Parameter(ParameterSetName = 'HKLM2HKCU', Mandatory = $true)]
        [ValidateSet('HKCU', 'HKLM')]
        [String] $Hive,

        [Parameter(ParameterSetName = 'ModifyKeyAccess', Mandatory = $true)]
        [Parameter(ParameterSetName = 'FakeDelete', Mandatory = $true)]
        [Parameter(ParameterSetName = 'DeletionMarker')]
        [String[]] $Patterns,

        # --- ModifyKeyAccess ---
        [Parameter(ParameterSetName = 'ModifyKeyAccess', Mandatory = $true)]
        [ValidateSet('Full2MaxAllowed', 'RW2MaxAllowed', 'Full2R', 'RW2R', 'Full2RW')]
        [String] $Access,

        # --- DeletionMarker ---
        [Parameter(ParameterSetName = 'DeletionMarker', Mandatory = $true)]
        [String] $Key,

        # --- JavaBlocker (Tim Mangan only) ---
        [Parameter(ParameterSetName = 'JavaBlocker', Mandatory = $true)]
        [String] $MajorVersion,

        [Parameter(ParameterSetName = 'JavaBlocker')]
        [String] $MinorVersion = '0',

        [Parameter(ParameterSetName = 'JavaBlocker')]
        [String] $UpdateVersion = '0'
    )

    process {
        if (-not (Test-Path $MSIXFolder.FullName -PathType Container)) {
            Write-Error "MSIXFolder not found: $($MSIXFolder.FullName)"
            return
        }

        try { $null = [System.Text.RegularExpressions.Regex]::new($Executable) }
        catch {
            Write-Error "-Executable '$Executable' is not a valid regular expression: $_"
            return
        }

        if ($PSBoundParameters.ContainsKey('Patterns')) {
            foreach ($pat in $Patterns) {
                if ([string]::IsNullOrEmpty($pat)) {
                    Write-Warning "-Patterns contains an empty entry."
                    continue
                }
                try { $null = [System.Text.RegularExpressions.Regex]::new($pat) }
                catch { Write-Warning "-Patterns entry '$pat' is not a valid regular expression: $_" }
            }
        }

        if ($PSBoundParameters.ContainsKey('Key') -and [string]::IsNullOrWhiteSpace($Key)) {
            Write-Error "-Key must not be empty for DeletionMarker."
            return
        }

        # Tim Mangan-only feature guard
        if ($PSCmdlet.ParameterSetName -in @('HKLM2HKCU', 'JavaBlocker')) {
            if ($Script:PsfBasePath -notlike '*TimMangan*') {
                Write-Error "$($PSCmdlet.ParameterSetName) requires Tim Mangan PSF. Run Set-MSIXActivePSFFramework -version TimManganPSF first."
                return
            }
        }

        $configXmlPath = Join-Path $MSIXFolder 'config.json.xml'
        if (-not (Test-Path $configXmlPath)) {
            Write-Warning "config.json.xml not found in: $($MSIXFolder.FullName)"
            return
        }

        $conxml = New-Object xml
        $conxml.Load($configXmlPath)

        Initialize-MSIXPSFProcessSection -ConXml $conxml

        # Find or create the target process node
        $execNode = $conxml.SelectSingleNode("//processes/process/executable[text()='$Executable']")
        if (-not $execNode) {
            $proc = $conxml.CreateElement('process')
            $exec = $conxml.CreateElement('executable')
            $exec.InnerText = $Executable
            $proc.AppendChild($exec) | Out-Null
            $conxml.SelectSingleNode('//processes').AppendChild($proc) | Out-Null
            $execNode = $conxml.SelectSingleNode("//processes/process/executable[text()='$Executable']")
        }
        $processNode = $execNode.ParentNode

        if ($null -eq $processNode.SelectSingleNode('fixups')) {
            $processNode.AppendChild($conxml.CreateElement('fixups')) | Out-Null
        }

        # Find or create the RegLegacyFixups fixup element
        $dllNode = $processNode.SelectSingleNode("fixups/fixup/dll[text()='RegLegacyFixups.dll']")
        if ($null -eq $dllNode) {
            $fixup  = $conxml.CreateElement('fixup')
            $dllEl  = $conxml.CreateElement('dll')
            $dllEl.InnerText = 'RegLegacyFixups.dll'
            $fixup.AppendChild($dllEl) | Out-Null
            $cfgEl  = $conxml.CreateElement('config')
            $fixup.AppendChild($cfgEl) | Out-Null
            $rgEl   = $conxml.CreateElement('remediationGroup')
            $cfgEl.AppendChild($rgEl) | Out-Null
            $processNode.SelectSingleNode('fixups').AppendChild($fixup) | Out-Null
            $dllNode = $processNode.SelectSingleNode("fixups/fixup/dll[text()='RegLegacyFixups.dll']")
        }
        $remGroup = $dllNode.ParentNode.SelectSingleNode('config/remediationGroup')

        # Build the remediation element
        $rem    = $conxml.CreateElement('remediation')
        $typeEl = $conxml.CreateElement('type')
        $typeEl.InnerText = $PSCmdlet.ParameterSetName
        $rem.AppendChild($typeEl) | Out-Null

        if ($PSBoundParameters.ContainsKey('Hive')) {
            $hiveEl = $conxml.CreateElement('hive')
            $hiveEl.InnerText = $Hive
            $rem.AppendChild($hiveEl) | Out-Null
        }

        if ($PSBoundParameters.ContainsKey('Patterns') -and $Patterns.Count -gt 0) {
            $patsEl = $conxml.CreateElement('patterns')
            foreach ($p in $Patterns) {
                $patEl = $conxml.CreateElement('pattern')
                $patEl.InnerText = $p
                $patsEl.AppendChild($patEl) | Out-Null
            }
            $rem.AppendChild($patsEl) | Out-Null
        }

        if ($PSBoundParameters.ContainsKey('Access')) {
            $accEl = $conxml.CreateElement('access')
            $accEl.InnerText = $Access
            $rem.AppendChild($accEl) | Out-Null
        }

        if ($PSBoundParameters.ContainsKey('Key')) {
            $keyEl = $conxml.CreateElement('key')
            $keyEl.InnerText = $Key
            $rem.AppendChild($keyEl) | Out-Null
        }

        if ($PSCmdlet.ParameterSetName -eq 'JavaBlocker') {
            $majEl = $conxml.CreateElement('majorVersion'); $majEl.InnerText = $MajorVersion
            $minEl = $conxml.CreateElement('minorVersion'); $minEl.InnerText = $MinorVersion
            $updEl = $conxml.CreateElement('updateVersion'); $updEl.InnerText = $UpdateVersion
            $rem.AppendChild($majEl) | Out-Null
            $rem.AppendChild($minEl) | Out-Null
            $rem.AppendChild($updEl) | Out-Null
        }

        # Skip if an identical entry already exists (idempotent across repeated runs)
        $dupXPath = "remediation[type='" + $PSCmdlet.ParameterSetName + "'"
        if ($PSBoundParameters.ContainsKey('Hive'))   { $dupXPath += " and hive='" + $Hive + "'" }
        if ($PSBoundParameters.ContainsKey('Access')) { $dupXPath += " and access='" + $Access + "'" }
        $dupXPath += ']'
        if ($null -ne $remGroup.SelectSingleNode($dupXPath)) {
            Write-Verbose "RegLegacyFixups [$($PSCmdlet.ParameterSetName)] already present for '$Executable' — skipped."
            return
        }

        $remGroup.AppendChild($rem) | Out-Null

        $conxml.PreserveWhiteSpace = $false
        $conxml.Save($configXmlPath)
        Write-Verbose "RegLegacyFixups [$($PSCmdlet.ParameterSetName)] added for executable: $Executable"
    }
}
