function Stop-MSIXTracing {
<#
.SYNOPSIS
    Stops the MSIX ETW trace session and converts the ETL to a readable log.

.DESCRIPTION
    Stops the MsixTrace logman session, locates the ETL file, and — unless
    -SkipParsing is set — converts it to readable text using tracerpt.
    Events with severity Warning or higher are also written to a separate
    warnings file.

    Returns a PSCustomObject with the paths to the generated files:
      EtlPath      - path to the raw ETL file
      LogPath      - path to the parsed log (empty when -SkipParsing)
      WarningsPath - path to the warnings-only log (empty when none or -SkipParsing)

.PARAMETER LogPath
    Path for the parsed output log file.
    Defaults to %TEMP%\MSIXTrace_<timestamp>.log.

.PARAMETER SkipParsing
    When set, the ETL file is kept as-is and no text log is generated.
    Useful when you want to open the ETL in a tool like WPA or ETLViewer.

.EXAMPLE
    Stop-MSIXTracing

.EXAMPLE
    Stop-MSIXTracing -LogPath "C:\Logs\myapp.log"

.EXAMPLE
    Stop-MSIXTracing -SkipParsing

.NOTES
    Requires elevation (Administrator).
    Andreas Nick, 2024
#>

    [CmdletBinding()]
    param(
        [string] $LogPath = (Join-Path $env:TEMP ("MSIXTrace_{0}.log" -f [datetime]::Now.ToString("yyyy-MM-dd_HHmmss"))),
        [switch] $SkipParsing
    )

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        throw "Stop-MSIXTracing must be run as Administrator."
    }

    # Verify the session exists before trying to stop it.
    $query = logman query MsixTrace 2>$null
    if ($null -eq $query -or $query.Count -lt 4) {
        throw "No active MsixTrace session found. Start tracing first with Start-MSIXTracing."
    }

    Write-Verbose "Stopping MSIX trace session..."
    try {
        $result = logman stop MsixTrace 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "logman stop failed: $result"
        }
    }
    catch {
        Write-Error "Failed to stop MSIX tracing: $_"
        throw
    }

    # Locate the ETL file from logman query output.
    $etlPath = $null
    $query = logman query MsixTrace 2>$null
    foreach ($line in $query) {
        if ($line -and $line.TrimEnd().EndsWith(".etl")) {
            $tokens = $line.Trim().Split()
            $etlPath = $tokens[$tokens.Count - 1]
        }
    }

    if (-not $etlPath -or -not (Test-Path $etlPath)) {
        Write-Warning "ETL file not found via logman query. Raw trace may be at the path specified during Start-MSIXTracing."
        return [PSCustomObject]@{ EtlPath = $etlPath; LogPath = ''; WarningsPath = '' }
    }

    Write-Host "Raw ETL: $etlPath"

    if ($SkipParsing) {
        Write-Verbose "Skipping log parsing (-SkipParsing specified)."
        return [PSCustomObject]@{ EtlPath = $etlPath; LogPath = ''; WarningsPath = '' }
    }

    # Convert ETL -> XML with tracerpt, then parse XML into readable text.
    $now         = [datetime]::Now.ToString("yyyy-MM-dd_HHmmss")
    $tempXmlPath = Join-Path $env:TEMP ("MSIXTrace_{0}.xml" -f $now)
    $warningsPath = [System.IO.Path]::ChangeExtension($LogPath, $null).TrimEnd('.') + "_warnings.log"

    try {
        Write-Verbose "Converting ETL to XML via tracerpt..."
        $result = tracerpt -l $etlPath -o $tempXmlPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "tracerpt failed: $result"
        }

        if (-not (Test-Path $tempXmlPath)) {
            throw "tracerpt produced no output file at $tempXmlPath"
        }

        Write-Verbose "Parsing XML events..."
        $xmlData = New-Object System.Xml.XmlDocument
        $xmlData.Load($tempXmlPath)

        $logLines     = [System.Collections.Generic.List[string]]::new()
        $warningLines = [System.Collections.Generic.List[string]]::new()

        # Event 0 is the header record — start from index 1.
        for ($i = 1; $i -lt $xmlData.Events.Event.Count; $i++) {
            $event  = $xmlData.Events.Event[$i]
            $level  = [int]$event.System.Level

            $levelLabel = switch ($level) {
                1 { 'Fatal'   }
                2 { 'Error'   }
                3 { 'Warning' }
                4 { 'Info'    }
                5 { 'Verbose' }
                default { "Level $level" }
            }

            $line  = $event.System.TimeCreated.SystemTime
            $line += ", $levelLabel"
            $line += ", " + $event.RenderingInfo.Task

            foreach ($data in $event.EventData.Data) {
                if ($null -eq $data) { continue }

                $name = $data.Name.ToString()
                $line += ", $name"

                if ($name.ToUpper() -eq 'HR') {
                    # Display HResults as hex.
                    $line += ': ' + ('0x{0:x}' -f [System.Convert]::ToInt32($data.'#text'))
                } elseif ($data.'#text') {
                    $line += ': ' + $data.'#text'.Trim()
                } else {
                    $line += ': <null>'
                }
            }

            $logLines.Add($line)

            # Level < 4 means Fatal / Error / Warning.
            if ($level -lt 4) {
                $warningLines.Add($line)
            }
        }

        $logLines | Set-Content -Path $LogPath -Encoding UTF8
        Write-Host "Parsed log:    $LogPath"

        $actualWarningsPath = ''
        if ($warningLines.Count -gt 0) {
            $warningLines | Set-Content -Path $warningsPath -Encoding UTF8
            Write-Host "Warnings log:  $warningsPath"
            $actualWarningsPath = $warningsPath
        }

        return [PSCustomObject]@{
            EtlPath      = $etlPath
            LogPath      = $LogPath
            WarningsPath = $actualWarningsPath
        }
    }
    catch {
        Write-Error "Failed to parse MSIX trace: $_"
        throw
    }
    finally {
        if (Test-Path $tempXmlPath) {
            Remove-Item $tempXmlPath -Force -ErrorAction SilentlyContinue
        }
    }
}
