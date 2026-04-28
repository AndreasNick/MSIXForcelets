function Initialize-MSIXPSFProcessSection {
<#
.SYNOPSIS
    Ensures the processes section in config.json.xml has the standard exclusion entries.

.DESCRIPTION
    Creates the <processes> node if missing and inserts the configured exclusion
    entries (PsfLauncher, PsfFtaCom, PowerShell) before the catch-all ".*" entry.
    The ".*" catch-all itself is also created if absent so fixup functions can
    append their DLLs to it.

    Which exclusion entries are added is controlled by the module configuration
    (Set-MSIXForceletsConfiguration / PSFProcessEntryLauncher etc.).

    Called by fixup functions (Add-MSIXPSFFileRedirectionFixup,
    Add-MSIXPSFTracing, etc.) after they have loaded config.json.xml.

.PARAMETER ConXml
    The loaded config.json.xml XmlDocument to update in place.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [xml] $ConXml
    )

    # Create <processes> if not present
    $processesRoot = $ConXml.SelectSingleNode('/configuration/processes')
    if ($null -eq $processesRoot) {
        $processesRoot = $ConXml.CreateElement('processes')
        $ConXml.SelectSingleNode('/configuration').AppendChild($processesRoot) | Out-Null
        Write-Verbose "Created <processes> node in config.json.xml"
    }

    # Locate the catch-all ".*" process node (must stay last)
    $catchAllExec = $processesRoot.SelectSingleNode("process/executable[text()='.*']")
    $catchAllProc = if ($null -ne $catchAllExec) { $catchAllExec.ParentNode } else { $null }

    # Build the ordered list of exclusion entries from module config
    $exclusions = [System.Collections.ArrayList]@()
    if ($Script:MSIXForceletsConfig.PSFProcessEntryLauncher)   { [void]$exclusions.Add('.*_PsfLauncher.*') }
    if ($Script:MSIXForceletsConfig.PSFProcessEntryFtaCom)     { [void]$exclusions.Add('.*_PsfFtaCom.*') }
    if ($Script:MSIXForceletsConfig.PSFProcessEntryPowershell) { [void]$exclusions.Add('^[Pp]ower[Ss]hell.*') }

    foreach ($pattern in $exclusions) {
        $exists = $processesRoot.SelectSingleNode("process/executable[text()='$pattern']")
        if ($null -eq $exists) {
            $proc = $ConXml.CreateElement('process')
            $exec = $ConXml.CreateElement('executable')
            $exec.InnerText = $pattern
            $proc.AppendChild($exec) | Out-Null

            if ($null -ne $catchAllProc) {
                $processesRoot.InsertBefore($proc, $catchAllProc) | Out-Null
            }
            else {
                $processesRoot.AppendChild($proc) | Out-Null
            }
            Write-Verbose "Added PSF process exclusion: $pattern"
        }
    }

    # Ensure the catch-all ".*" exists at the end for fixup functions to populate
    if ($null -eq $catchAllExec) {
        $proc = $ConXml.CreateElement('process')
        $exec = $ConXml.CreateElement('executable')
        $exec.InnerText = '.*'
        $proc.AppendChild($exec) | Out-Null
        $processesRoot.AppendChild($proc) | Out-Null
        Write-Verbose "Added catch-all process entry: .*"
    }
}
