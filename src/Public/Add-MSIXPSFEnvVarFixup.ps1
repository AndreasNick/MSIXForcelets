function Add-MSIXPSFEnvVarFixup {
<#
.SYNOPSIS
    Adds an EnvVarFixup entry to an MSIX package PSF configuration.

.DESCRIPTION
    Writes an EnvVarFixup entry into config.json.xml for the specified process.
    EnvVarFixup injects or overrides environment variables at process startup,
    before the application reads them.

    Call this function once per variable. Multiple calls accumulate variables
    under the same process entry. If the variable name already exists for the
    process, its value is replaced.

    The PSF launcher selects the correct architecture-specific DLL at runtime;
    config.json always references EnvVarFixup.dll without an architecture suffix.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain config.json.xml).

.PARAMETER Executable
    Regex pattern matching the process entry to configure. Default: ".*" (all processes).

.PARAMETER Name
    Name of the environment variable to set or override.

.PARAMETER Value
    Value for the environment variable. Supports standard Windows environment
    variable expansion (e.g. "%APPDATA%\MyApp").

.EXAMPLE
    Add-MSIXPSFEnvVarFixup -MSIXFolder "C:\MSIXTemp\MyApp" -Name "MY_VAR" -Value "C:\Data"

.EXAMPLE
    Add-MSIXPSFEnvVarFixup -MSIXFolder "C:\MSIXTemp\MyApp" -Executable "myapp$" `
        -Name "APPDATA_PATH" -Value "%MsixWritablePackageRoot%\VFS\LocalAppData\MyApp"

.EXAMPLE
    # Set multiple variables
    $pkg = Open-MSIXPackage -MsixFile "C:\Packages\MyApp.msix" -Force
    Add-MSIXPSFEnvVarFixup -MSIXFolder $pkg -Name "HOME"    -Value "%MsixWritablePackageRoot%"
    Add-MSIXPSFEnvVarFixup -MSIXFolder $pkg -Name "TMPDIR"  -Value "%TEMP%"

.NOTES
    EnvVarFixup source: https://github.com/microsoft/MSIX-PackageSupportFramework
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [String] $Executable = '.*',

        [Parameter(Mandatory = $true)]
        [String] $Name,

        [Parameter(Mandatory = $true)]
        [String] $Value
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

        $configXmlPath = Join-Path $MSIXFolder 'config.json.xml'
        if (-not (Test-Path $configXmlPath)) {
            Write-Warning "config.json.xml not found in: $($MSIXFolder.FullName). Run Add-MSXIXPSFShim first."
            return
        }

        $conxml = New-Object xml
        $conxml.Load($configXmlPath)

        Initialize-MSIXPSFProcessSection -ConXml $conxml

        # Locate or create the target process node
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

        # Find or create the EnvVarFixup entry for this process
        $fixupNode = $processNode.SelectSingleNode("fixups/fixup/dll[text()='EnvVarFixup.dll']")
        if ($null -eq $fixupNode) {
            $fixup  = $conxml.CreateElement('fixup')
            $dllEl  = $conxml.CreateElement('dll')
            $dllEl.InnerText = 'EnvVarFixup.dll'
            $fixup.AppendChild($dllEl) | Out-Null

            $cfgEl  = $conxml.CreateElement('config')
            $varsEl = $conxml.CreateElement('envVariables')
            $cfgEl.AppendChild($varsEl) | Out-Null
            $fixup.AppendChild($cfgEl) | Out-Null

            $processNode.SelectSingleNode('fixups').AppendChild($fixup) | Out-Null
            $fixupNode = $processNode.SelectSingleNode("fixups/fixup/dll[text()='EnvVarFixup.dll']")
        }

        $fixupEl  = $fixupNode.ParentNode
        $varsNode = $fixupEl.SelectSingleNode('config/envVariables')

        # Replace existing entry with same name (idempotency)
        $existing = $varsNode.SelectSingleNode("envVariable[name='$Name']")
        if ($null -ne $existing) {
            $existing.SelectSingleNode('value').InnerText = $Value
            Write-Verbose "Updated EnvVarFixup: $Name = $Value (executable: $Executable)"
        }
        else {
            $varEl   = $conxml.CreateElement('envVariable')
            $nameEl  = $conxml.CreateElement('name')
            $valueEl = $conxml.CreateElement('value')
            $nameEl.InnerText  = $Name
            $valueEl.InnerText = $Value
            $varEl.AppendChild($nameEl)  | Out-Null
            $varEl.AppendChild($valueEl) | Out-Null
            $varsNode.AppendChild($varEl) | Out-Null
            Write-Verbose "Added EnvVarFixup: $Name = $Value (executable: $Executable)"
        }

        $conxml.PreserveWhiteSpace = $false
        $conxml.Save($configXmlPath)
    }
}
