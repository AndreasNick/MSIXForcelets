function Add-MSIXFixNotepadPlusPlus {
<#
.SYNOPSIS
    Applies PSF and shell extension fixes to a Notepad++ MSIX package.

.DESCRIPTION
    Merges the inner NppShell.msix sparse shell extension into the main manifest,
    corrects the NppShell.dll package-relative path, and applies the Package Support
    Framework (PSF) with RegLegacyFixup, FileRedirectionFixup, and InstalledLocationVirtualization.


.PARAMETER MsixFile
    Path to the Notepad++ MSIX file to modify.

.PARAMETER MSIXFolder
    Temporary extraction folder. Defaults to a unique path under %TEMP%.

.PARAMETER OutputFilePath
    Path for the repackaged MSIX. Defaults to overwriting the source file.

.PARAMETER Subject
    Publisher subject string (CN=...). When provided, Set-MSIXPublisher is called.

.PARAMETER Version
    Package version to set (e.g. '8.9.4.0').

.PARAMETER Force
    Overwrites existing files in the extraction folder without prompting.

.PARAMETER KeepMSIXFolder
    Keeps the temporary extraction folder after packing.

.EXAMPLE
    Add-MSIXFixNotepadPlusPlus -MsixFile "C:\Packages\NotepadPlusPlus.msix" -Verbose

.EXAMPLE
    Add-MSIXFixNotepadPlusPlus `
        -MsixFile       "C:\Packages\NotepadPlusPlus.msix" -force -verbose

.NOTES
    Requires an active PSF framework set via Set-MSIXActivePSFFramework.
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [System.IO.FileInfo] $MsixFile,

        [System.IO.DirectoryInfo] $MSIXFolder = ($env:Temp + '\MSIX_TEMP_' + [System.Guid]::NewGuid().ToString()),

        [System.IO.FileInfo] $OutputFilePath = $null,

        [string] $Subject = '',
        [string] $Version = '',

        [switch] $Force,
        [switch] $KeepMSIXFolder
    )

    process {
        if ($null -eq $OutputFilePath) {
            $OutputFilePath = $MsixFile
        }

        try {
            $null = Open-MSIXPackage -MsixFile $MsixFile -Force:$Force -MSIXFolder $MSIXFolder

            if ($Subject -ne '') {
                Set-MSIXPublisher -MSIXFolder $MSIXFolder -PublisherSubject $Subject
            }

            if ($Version -ne '') {
                Set-MSIXPackageVersion -MSIXFolder $MSIXFolder -MSVersion $Version
                Write-Verbose "Package version set to $Version"
            }

            Invoke-MSIXCleanup -MSIXFolder $MSIXFolder

            # Merge NppShell.msix (IExplorerCommand + com:SurrogateServer) into the main manifest.
            # The sparse package cannot be deployed inside a full MSIX container because the
            # WindowsApps path is read-only; merging avoids that runtime failure.
            Import-MSIXSparseShellExtension -MSIXFolder $MSIXFolder `
                -SparsePackagePath 'VFS\ProgramFilesX64\Notepad++\contextMenu\NppShell.msix' `
                -Verbose:($PSBoundParameters['Verbose'] -eq $true)

            # The sparse manifest declares Path="NppShell.dll" relative to its own root.
            # After merging into the main package the path must be package-relative so that
            # the COM surrogate host (dllhost.exe) can locate the DLL inside the VFS.
            $manifestPath = Join-Path $MSIXFolder.FullName 'AppxManifest.xml'
            $xml = New-Object System.Xml.XmlDocument
            $xml.Load($manifestPath)
            $nppDllPath = 'VFS\ProgramFilesX64\Notepad++\contextMenu\NppShell.dll'
            foreach ($classNode in @($xml.SelectNodes("//*[local-name()='Class' and @Path='NppShell.dll']"))) {
                $classNode.SetAttribute('Path', $nppDllPath)
                Write-Verbose "Updated com:Class Path to: $nppDllPath"
            }
            $xml.Save($manifestPath)

            Add-MSIXInstalledLocationVirtualization -MSIXFolderPath $MSIXFolder

            Add-MSIXPsfFrameworkFiles -MSIXFolder $MSIXFolder

            $apps = Get-MSIXApplications -MSIXFolder $MSIXFolder
            if ($null -eq $apps -or $apps.Count -eq 0) {
                Write-Warning "No application entries found in AppxManifest.xml."
            }
            else {
                foreach ($app in $apps) {
                    Write-Verbose "Adding PSF shim for application: $($app.Id)"
                    $null = Add-MSXIXPSFShim -MSIXFolder $MSIXFolder -MISXAppID $app.Id
                }
            }

            Add-MSIXPSFDefaultRegLegacy -MSIXFolder $MSIXFolder
            Add-MSIXPSFDefaultFRF -MSIXFolder $MSIXFolder

            Close-MSIXPackage -MSIXFolder $MSIXFolder -MSIXFile $OutputFilePath -Force:$Force -KeepMSIXFolder:$KeepMSIXFolder
            "Notepad++ fix applied: $OutputFilePath"
        }
        catch {
            Write-Error "Error applying Notepad++ fix: $_"
        }
    }
}
