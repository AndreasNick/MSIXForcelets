function Add-MSIXFixSumatraPDF {
<#
.SYNOPSIS
    Applies the SumatraPDF fix to an MSIX package: settings file in the real %LOCALAPPDATA%.

.DESCRIPTION
    Excludes %LOCALAPPDATA%\SumatraPDF from file system write virtualization, so
    SumatraPDF-settings.txt is written to the real LocalAppData. Otherwise the external editor
    opened via "Advanced Options" cannot find the file inside the container. -Subject sets the
    publisher when it differs from the signing certificate. The package is not signed - sign it
    afterwards with Set-MSIXSignature.

.EXAMPLE
    Add-MSIXFixSumatraPDF -MsixFile 'C:\Packages\SumatraPDF.msix' -OutputFilePath 'C:\Packages\SumatraPDF_fixed.msix' -Verbose

.NOTES
    Flexible virtualization (ExcludedDirectory) requires Windows 10 build 20348+ / Windows 11.
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

        [switch] $Force,
        [switch] $KeepMSIXFolder
    )

    process {
        if ($null -eq $OutputFilePath) {
            $OutputFilePath = $MsixFile
        }

        try {
            $package = Open-MSIXPackage -MsixFile $MsixFile -MSIXFolder $MSIXFolder -ClearOutputFolder $true -Force:$Force -ErrorAction Stop
            if (-not $package) {
                throw "Failed to open MSIX package: $($MsixFile.FullName)"
            }

            if ($Subject -ne '') {
                Set-MSIXPublisher -MSIXFolder $MSIXFolder -PublisherSubject $Subject
            }

            Add-MSIXFlexibleVirtualization -MSIXFolder $MSIXFolder -KnownFolder LocalAppData -Folder 'SumatraPDF'

            Close-MSIXPackage -MSIXFolder $MSIXFolder -MSIXFile $OutputFilePath -Force:$Force -KeepMSIXFolder:$KeepMSIXFolder -ErrorAction Stop
            "SumatraPDF fix applied: $OutputFilePath"
        }
        catch {
            $failure = $_
            # Do not leave the extracted package behind in %TEMP%: remove the default temporary
            # folder unless it should be kept. A folder passed via -MSIXFolder stays.
            if ($PSBoundParameters.ContainsKey('KeepMSIXFolder')) { $keepFolder = $KeepMSIXFolder.IsPresent }
            else { $keepFolder = [bool]$Script:MSIXForceletsConfig.KeepTempFolder }
            if (-not $keepFolder -and -not $PSBoundParameters.ContainsKey('MSIXFolder') -and (Test-Path -LiteralPath $MSIXFolder.FullName)) {
                Remove-Item -LiteralPath $MSIXFolder.FullName -Recurse -Force -ErrorAction SilentlyContinue
                if (Test-Path -LiteralPath $MSIXFolder.FullName) { & cmd.exe /C rmdir /S /Q "$($MSIXFolder.FullName)" 2>$null }
                Write-Verbose "Removed extraction folder after the error: $($MSIXFolder.FullName)"
            }
            throw (New-Object System.Exception ("Error applying SumatraPDF fix: $($failure.Exception.Message)", $failure.Exception))
        }
    }
}
