function Wait-MSIXTracing {
<#
.SYNOPSIS
    Starts MSIX tracing, waits for user input, then stops and parses the trace.

.DESCRIPTION
    Convenience wrapper that calls Start-MSIXTracing, pauses until the user
    presses Enter, then calls Stop-MSIXTracing. Useful for capturing a
    single reproducible scenario without manually invoking the two functions.

    Returns the same PSCustomObject as Stop-MSIXTracing:
      EtlPath      - path to the raw ETL file
      LogPath      - path to the parsed log (empty when -SkipParsing)
      WarningsPath - path to the warnings-only log (empty when none or -SkipParsing)

.PARAMETER EtlPath
    Path where the raw ETL file will be written during capture.
    Defaults to %TEMP%\MSIXTrace.etl.

.PARAMETER LogPath
    Path for the parsed output log file.
    Defaults to %TEMP%\MSIXTrace_<timestamp>.log.

.PARAMETER SkipParsing
    When set, the ETL is kept as-is and no text log is generated.

.EXAMPLE
    Wait-MSIXTracing

.EXAMPLE
    Wait-MSIXTracing -LogPath "C:\Logs\myapp.log"

.EXAMPLE
    Wait-MSIXTracing -SkipParsing

.NOTES
    Requires elevation (Administrator).
    Andreas Nick, 2024
#>

    [CmdletBinding()]
    param(
        [string] $EtlPath  = (Join-Path $env:TEMP "MSIXTrace.etl"),
        [string] $LogPath  = (Join-Path $env:TEMP ("MSIXTrace_{0}.log" -f [datetime]::Now.ToString("yyyy-MM-dd_HHmmss"))),
        [switch] $SkipParsing
    )

    Start-MSIXTracing -EtlPath $EtlPath

    Read-Host "Tracing is active. Reproduce the issue, then press Enter to stop"

    Stop-MSIXTracing -LogPath $LogPath -SkipParsing:$SkipParsing
}
