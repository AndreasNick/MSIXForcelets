function Set-MSIXApplication {
<#
.SYNOPSIS
    Updates Application-level settings in AppxManifest.xml: working directory, default
    parameters (uap11) and autostart (windows.startupTask).
.DESCRIPTION
    General editor for the Application node. Only parameters that are explicitly passed are
    acted upon; everything else is left unchanged. Pipeline-friendly from Get-MSIXApplications.

    VisualElements (logos, tile, AppListEntry, VisualGroup) are NOT handled here - use the
    dedicated Set-MSIXApplicationVisualElements for those.
.PARAMETER MSIXFolderPath
    Expanded MSIX package folder. Pipeline by property name.
.PARAMETER AppId
    Application Id to update. Binds from Get-MSIXApplications (Id). Omit to update all applications.
.PARAMETER NewId
    Renames Application/@Id to this value. Requires -AppId (single target). WARNING: changing
    the Id changes the package AUMID and can break existing shortcuts, jump lists and Start pins.
.PARAMETER Executable
    New launch executable (Application/@Executable), e.g. to repoint at a different .exe or launcher.
.PARAMETER UAP11WorkingDirectory
    Initial working directory (uap11:CurrentDirectoryPath). Supports macros such as
    $(package.effectivePath). Requires a recent Windows 11 build; ignored on older builds.
.PARAMETER UAP11Parameters
    Default command-line parameters (uap11:Parameters); also supports macros.
.PARAMETER Autostart
    $true creates/enables a windows.startupTask so the app runs at sign-in; $false disables
    an existing task (Enabled="false"). TaskId/DisplayName/Executable default to the app's values.
.PARAMETER AutostartTaskId
    Optional startup TaskId (default: the AppId). Must be unique within the package.
.PARAMETER AutostartDisplayName
    Optional startup display name shown under Task Manager > Startup apps (default: the AppId).
.PARAMETER AutostartExecutable
    Optional executable the startup task launches (default: the application's Executable).
.EXAMPLE
    Get-MSIXApplications -MSIXFolder $pkg |
        Set-MSIXApplication -UAP11WorkingDirectory '$(package.effectivePath)\VFS\ProgramFilesX64\PuTTY'
.EXAMPLE
    Set-MSIXApplication -MSIXFolderPath $pkg -AppId PUTTY -Autostart $true
.EXAMPLE
    Set-MSIXApplication -MSIXFolderPath $pkg -AppId PUTTY -Executable 'PsfLauncher64.exe' -NewId PUTTYMain
.NOTES
    Andreas Nick, 2026
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [Alias('MSIXFolder')]
        [System.IO.DirectoryInfo] $MSIXFolderPath,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string] $AppId,

        [string] $NewId,
        [string] $Executable,

        [string] $UAP11WorkingDirectory,
        [string] $UAP11Parameters,

        [bool]   $Autostart,
        [string] $AutostartTaskId,
        [string] $AutostartDisplayName,
        [string] $AutostartExecutable
    )

    process {
        $doNewId  = $PSBoundParameters.ContainsKey('NewId')
        $doExe    = $PSBoundParameters.ContainsKey('Executable')
        $doWD     = $PSBoundParameters.ContainsKey('UAP11WorkingDirectory')
        $doParams = $PSBoundParameters.ContainsKey('UAP11Parameters')
        $doAuto   = $PSBoundParameters.ContainsKey('Autostart')

        if (-not ($doNewId -or $doExe -or $doWD -or $doParams -or $doAuto)) {
            Write-Warning "No settings specified - nothing to do."
            return
        }
        if ($doWD -and $UAP11WorkingDirectory -match '[<>|?*]') {
            Write-Error "UAP11WorkingDirectory must not contain any of: < > | ? *"
            return
        }
        if ($doNewId) {
            if (-not $AppId) {
                Write-Error "Renaming requires -AppId to identify the single application to rename."
                return
            }
            if ([string]::IsNullOrWhiteSpace($NewId)) {
                Write-Error "NewId must not be empty."
                return
            }
        }

        $manifestPath = Join-Path $MSIXFolderPath 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "AppxManifest.xml not found in: $($MSIXFolderPath.FullName)"
            return
        }

        $manifest = New-Object System.Xml.XmlDocument
        $manifest.Load($manifestPath)

        $prefixes = @()
        if ($doWD -or $doParams) { $prefixes += 'uap11' }
        if ($doAuto)             { $prefixes += 'desktop' }
        if ($prefixes.Count -gt 0) {
            Add-MSIXManifestNamespace -Manifest $manifest -Prefixes $prefixes
        }

        $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
        $AppXNamespaces.GetEnumerator() | ForEach-Object { $null = $nsmgr.AddNamespace($_.Key, $_.Value) }
        $nsUri      = $AppXNamespaces['ns']
        $uap11Uri   = $AppXNamespaces['uap11']
        $desktopUri = $AppXNamespaces['desktop']

        $apps = @($manifest.SelectNodes('//ns:Package/ns:Applications/ns:Application', $nsmgr))
        $changed = $false

        foreach ($app in $apps) {
            $thisId = $app.GetAttribute('Id')
            if ($AppId -and $thisId -ne $AppId) { continue }
            if (-not $PSCmdlet.ShouldProcess($thisId, 'Update Application settings')) { continue }

            if ($doExe) {
                $null = $app.SetAttribute('Executable', $Executable)
                Write-Verbose "Set Executable '$Executable' on '$thisId'."
            }

            if ($doWD)     { $null = $app.SetAttribute('CurrentDirectoryPath', $uap11Uri, $UAP11WorkingDirectory) }
            if ($doParams) { $null = $app.SetAttribute('Parameters',           $uap11Uri, $UAP11Parameters) }

            if ($doAuto) {
                $ext = $app.SelectSingleNode('ns:Extensions', $nsmgr)
                $startNode = $null
                if ($null -ne $ext) {
                    $startNode = $ext.SelectSingleNode("desktop:Extension[@Category='windows.startupTask']/desktop:StartupTask", $nsmgr)
                }

                if ($Autostart) {
                    if ($null -eq $ext) {
                        $ext = $manifest.CreateElement('Extensions', $nsUri)
                        $null = $app.AppendChild($ext)
                    }
                    $taskId  = if ($AutostartTaskId)      { $AutostartTaskId }      else { $thisId }
                    $display = if ($AutostartDisplayName) { $AutostartDisplayName } else { $thisId }

                    if ($null -eq $startNode) {
                        $exe = if ($AutostartExecutable) { $AutostartExecutable } else { $app.GetAttribute('Executable') }
                        $stExt = $manifest.CreateElement('desktop:Extension', $desktopUri)
                        $null = $stExt.SetAttribute('Category', 'windows.startupTask')
                        $null = $stExt.SetAttribute('Executable', $exe)
                        $null = $stExt.SetAttribute('EntryPoint', 'Windows.FullTrustApplication')
                        $startNode = $manifest.CreateElement('desktop:StartupTask', $desktopUri)
                        $null = $startNode.SetAttribute('TaskId', $taskId)
                        $null = $startNode.SetAttribute('Enabled', 'true')
                        $null = $startNode.SetAttribute('DisplayName', $display)
                        $null = $stExt.AppendChild($startNode)
                        $null = $ext.AppendChild($stExt)
                        Write-Verbose "Created startup task '$taskId' on '$thisId'."
                    }
                    else {
                        $null = $startNode.SetAttribute('Enabled', 'true')
                        if ($AutostartTaskId)      { $null = $startNode.SetAttribute('TaskId', $AutostartTaskId) }
                        if ($AutostartDisplayName) { $null = $startNode.SetAttribute('DisplayName', $AutostartDisplayName) }
                        if ($AutostartExecutable)  { $null = $startNode.ParentNode.SetAttribute('Executable', $AutostartExecutable) }
                        Write-Verbose "Enabled startup task on '$thisId'."
                    }
                }
                else {
                    if ($null -ne $startNode) {
                        $null = $startNode.SetAttribute('Enabled', 'false')
                        Write-Verbose "Disabled startup task on '$thisId'."
                    }
                    else {
                        Write-Verbose "No startup task on '$thisId' to disable."
                    }
                }
            }

            if ($doNewId) {
                $clash = $manifest.SelectSingleNode("//ns:Package/ns:Applications/ns:Application[@Id='$NewId']", $nsmgr)
                if ($null -ne $clash -and -not [object]::ReferenceEquals($clash, $app)) {
                    Write-Error "Another Application already uses Id '$NewId' - rename skipped."
                }
                else {
                    $null = $app.SetAttribute('Id', $NewId)
                    Write-Warning "Renamed Application Id '$thisId' -> '$NewId'. This changes the AUMID and can break existing shortcuts, jump lists and Start pins."
                }
            }

            $changed = $true
        }

        if ($changed) {
            $manifest.Save($manifestPath)
            Write-Verbose "Saved $manifestPath"
        }
        else {
            Write-Warning "No matching Application found to update."
        }
    }
}
