function Add-MSIXPSFMFRFixup {
<#
.SYNOPSIS
    Adds MFRFixup, a fix from Tim Mangan, to an MSIX package.

.DESCRIPTION
    Writes an MFRFixup entry into config.json.xml. MFRFixup (Modern File
    Redirection) is a Tim Mangan PSF component that intercepts 30+ Windows
    file-system APIs and handles Copy-on-Write redirection more efficiently
    than the standard FileRedirectionFixup.
    Do not combine MFRFixup with FileRedirectionFixup on the same process entry.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain config.json.xml).

.PARAMETER Executable
    Regex pattern for the process entry. Default: ".*" (all processes).

.PARAMETER IlvAware
    Controls InstalledLocationVirtualization (ILV) awareness.
    "true"  — assumes the ILV extension is present in AppxManifest; ILV
              handles Copy-on-Write, MFRFixup provides path interception only.
    "false" — MFRFixup handles all Copy-on-Write internally (no ILV required).
    Default: "true".

.PARAMETER OverrideCOW
    Controls Copy-on-Write override behaviour. Default: "default".

.EXAMPLE
    Add-MSIXPSFMFRFixup -MSIXFolder "C:\MSIXTemp\MyApp"

.EXAMPLE
    Add-MSIXPSFMFRFixup -MSIXFolder "C:\MSIXTemp\MyApp" -IlvAware "false"

.NOTES
    Tim Mangan MFRFixup: https://github.com/TimMangan/MSIX-PackageSupportFramework/wiki/Fixup:-MfrFixup
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [String] $Executable = '.*',

        [ValidateSet('true', 'false')]
        [String] $IlvAware = 'true',

        [String] $OverrideCOW = 'default'
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

        if ($Script:PsfBasePath -notlike '*TimMangan*') {
            Write-Error "MFRFixup requires Tim Mangan PSF. Run Set-MSIXActivePSFFramework -version TimManganPSF first."
            return
        }

        $configXmlPath = Join-Path $MSIXFolder 'config.json.xml'
        if (-not (Test-Path $configXmlPath)) {
            Write-Warning "config.json.xml not found in: $($MSIXFolder.FullName)"
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

        # Skip if MFRFixup already present
        $existing = $processNode.SelectSingleNode("fixups/fixup/dll[text()='MFRFixup.dll']")
        if ($null -ne $existing) {
            Write-Verbose "MFRFixup already configured for '$Executable' — skipped."
            return
        }

        if ($null -eq $processNode.SelectSingleNode('fixups')) {
            $processNode.AppendChild($conxml.CreateElement('fixups')) | Out-Null
        }

        $fixup   = $conxml.CreateElement('fixup')
        $dllEl   = $conxml.CreateElement('dll')
        $dllEl.InnerText = 'MFRFixup.dll'
        $fixup.AppendChild($dllEl) | Out-Null

        $cfgEl  = $conxml.CreateElement('config')
        $ilvEl  = $conxml.CreateElement('ilvAware')
        $ilvEl.InnerText = $IlvAware
        $cowEl  = $conxml.CreateElement('overrideCOW')
        $cowEl.InnerText = $OverrideCOW
        $cfgEl.AppendChild($ilvEl) | Out-Null
        $cfgEl.AppendChild($cowEl) | Out-Null
        $fixup.AppendChild($cfgEl) | Out-Null

        $processNode.SelectSingleNode('fixups').AppendChild($fixup) | Out-Null

        $conxml.PreserveWhiteSpace = $false
        $conxml.Save($configXmlPath)
        Write-Verbose "MFRFixup.dll added for executable: $Executable (ilvAware=$IlvAware, overrideCOW=$OverrideCOW)"
    }
}
