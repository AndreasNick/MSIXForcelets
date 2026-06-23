function Set-MSIXApplicationWorkingDirectory {
<#
.SYNOPSIS
    Sets the working directory (uap11:CurrentDirectoryPath) on Application entries.
.DESCRIPTION
    Writes uap11:CurrentDirectoryPath - and optionally uap11:Parameters - on one or all
    Application entries so the packaged process starts in the given directory instead of
    System32. The value supports manifest macros such as $(package.effectivePath).

    Requires a recent Windows 11 build; Microsoft does not document an exact minimum build
    for this attribute, so test on the target system. On older builds the attribute is
    ignored (it lives in an ignorable namespace) and the app falls back to the default
    working directory.
.PARAMETER MSIXFolderPath
    Expanded MSIX package folder. Pipeline by property name (e.g. from Get-MSIXApplications).
.PARAMETER AppId
    Application Id to update. Binds from Get-MSIXApplications (Id). Omit to update all applications.
.PARAMETER WorkingDirectory
    The initial directory, e.g. '$(package.effectivePath)\VFS\ProgramFilesX64\App'.
.PARAMETER Parameters
    Optional default command-line parameters (uap11:Parameters); also supports macros.
.EXAMPLE
    Get-MSIXApplications -MSIXFolder $pkg |
        Set-MSIXApplicationWorkingDirectory -WorkingDirectory '$(package.effectivePath)\VFS\ProgramFilesX64\PuTTY'
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

        [Parameter(Mandatory = $true, Position = 1)]
        [string] $WorkingDirectory,

        [string] $Parameters
    )

    process {
        # uap11:CurrentDirectoryPath forbids these characters (macros use $ ( ) which are allowed).
        if ($WorkingDirectory -match '[<>|?*]') {
            Write-Error "WorkingDirectory must not contain any of: < > | ? *"
            return
        }

        $manifestPath = Join-Path $MSIXFolderPath 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "AppxManifest.xml not found in: $($MSIXFolderPath.FullName)"
            return
        }

        $manifest = New-Object System.Xml.XmlDocument
        $manifest.Load($manifestPath)

        Add-MSIXManifestNamespace -Manifest $manifest -Prefixes 'uap11'

        $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
        $AppXNamespaces.GetEnumerator() | ForEach-Object { $null = $nsmgr.AddNamespace($_.Key, $_.Value) }
        $uap11Uri = $AppXNamespaces['uap11']

        $apps = @($manifest.SelectNodes('//ns:Package/ns:Applications/ns:Application', $nsmgr))
        $changed = $false

        foreach ($app in $apps) {
            $thisId = $app.GetAttribute('Id')
            if ($AppId -and $thisId -ne $AppId) { continue }
            if (-not $PSCmdlet.ShouldProcess($thisId, "Set working directory '$WorkingDirectory'")) { continue }

            $null = $app.SetAttribute('CurrentDirectoryPath', $uap11Uri, $WorkingDirectory)
            if ($PSBoundParameters.ContainsKey('Parameters')) {
                $null = $app.SetAttribute('Parameters', $uap11Uri, $Parameters)
            }
            $changed = $true
            Write-Verbose "Set uap11:CurrentDirectoryPath on '$thisId'."
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
