function Start-MSIXTracing {
<#
.SYNOPSIS
    Starts an ETW trace session for MSIX diagnostics.

.DESCRIPTION
    Creates and starts a logman ETW trace session named MsixTrace using the
    standard MSIX ETW provider GUIDs. If the session already exists it is
    reused. The resulting ETL file can later be processed by Stop-MSIXTracing.

.PARAMETER EtlPath
    Path where the raw ETL trace file will be written.
    Defaults to %TEMP%\MSIXTrace.etl.

.EXAMPLE
    Start-MSIXTracing

.EXAMPLE
    Start-MSIXTracing -EtlPath "C:\Logs\myapp.etl"

.NOTES
    Requires elevation (Administrator).
    ETW provider GUIDs:
      {033321d3-d599-48e0-868d-c59f15901637}  MSIX core
      {db5b779e-2dcf-41bc-ab0e-40a6e02f1438}  AppX deployment
    Andreas Nick, 2024
#>

    [CmdletBinding()]
    param(
        [string] $EtlPath = (Join-Path $env:TEMP "MSIXTrace.etl")
    )

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        throw "Start-MSIXTracing must be run as Administrator."
    }

    Write-Verbose "Starting MSIX trace session. ETL output: $EtlPath"

    try {
        # Check whether the session already exists (logman returns >= 4 lines when found).
        $query = logman query MsixTrace 2>$null
        if ($null -eq $query -or $query.Count -lt 4) {
            Write-Verbose "Creating trace session MsixTrace..."
            $result = logman create trace MsixTrace `
                -p "{033321d3-d599-48e0-868d-c59f15901637}" `
                -o $EtlPath 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "logman create failed: $result"
            }
        }

        # Always (re-)add the second provider so both are present.
        $result = logman update MsixTrace -p "{db5b779e-2dcf-41bc-ab0e-40a6e02f1438}" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "logman update failed: $result"
        }

        $result = logman start MsixTrace 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "logman start failed: $result"
        }

        Write-Host "MSIX tracing started. ETL: $EtlPath" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to start MSIX tracing: $_"
        throw
    }
}
