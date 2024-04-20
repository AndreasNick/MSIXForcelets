
function Remove-MSIXPsfFiles {
<#
.SYNOPSIS
Removes MSIX PSF files.

.DESCRIPTION
This function is used to remove MSIX PSF files from the specified location.

.PARAMETER MSIXFolder
Specifies the path where the expanded MSIX Package  are located.

.EXAMPLE
Remove-MSIXPsfFiles -MSIXFolder "C:\MSIXPSF"
This example removes all MSIX PSF files from the expanded MSIX  directory "C:\MSIXPSF".

.NOTES
Make sure to run this function with administrative privileges.
https://www.nick-it.de
Andreas Nick, 2022

#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo] $MSIXFolder
    )

    $psfFiles = @(
        "PsfLauncher*",
        "PsfRunDll*",
        "PsfRuntime*",
        "DynamicLibraryFixup*.dll",
        "EnvVarFixup*.dll",
        "FileRedirectionFixup*.dll",
        "Microsoft.Diagnostics.FastSerialization.dll",
        "Microsoft.Diagnostics.Tracing.TraceEvent.dll",
        "KernelTraceControl.dll",
        #"msdia140.dll",
        #"msvcp140.dll",
        "MFRFixup*.dll",
        "OSExtensions.dll",
        "ucrtbased.dll",
        "TraceFixup*.dll",
        "RegLegacyFixups*.dll",
        "StartMenuCmdScriptWrapper.ps1",
        "StartingScriptWrapper.ps1",
        "StartMenuShellLaunchWrapperScript.ps1",
        "PSFMonitor*"
    )

    Write-Verbose "Removing PSF files from: $($MSIXFolder.FullName)"
    foreach ($filePattern in $psfFiles) {
        $files = Get-ChildItem -Path $MSIXFolder -Filter $filePattern -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            Write-Verbose "Removing psf file: $($file.FullName)"
            Remove-Item $file.FullName -Force 
        }
    }
}