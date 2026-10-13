
function Add-MSIXFixLibreOffice {
<#
.SYNOPSIS
    Applies LibreOffice-specific fixes to an MSIX package.

.DESCRIPTION
    Applies three fixes to a LibreOffice MSIX package:
    1. InstalledLocationVirtualization
    2. SharedFonts
    3. Start Menu folder grouping via VisualGroup (Windows 11)
    Optionally sets the publisher subject if -Subject is provided.

.PARAMETER MsixFile
    Path to the source MSIX file.

.PARAMETER MSIXFolder
    Temporary extraction folder. Defaults to a unique path under %TEMP%.

.PARAMETER Force
    Overwrites existing files in the extraction folder without prompting.

.PARAMETER OutputFilePath
    Path for the repackaged MSIX. Defaults to overwriting the source file.

.PARAMETER Subject
    Publisher subject string (CN=...). When provided, Set-MSIXPublisher is called
    to align the manifest publisher with the signing certificate.

.PARAMETER VisualGroup
    Start Menu folder name for all applications in the package (Windows 11). Defaults to "LibreOffice".
    Set to an empty string to skip this fix.

.EXAMPLE
    Add-MSIXLibreOfficeFix -MsixFile "C:\Packages\LibreOffice.msix" -OutputFilePath "C:\Packages\LibreOffice_fixed.msix"

.EXAMPLE
    Add-MSIXLibreOfficeFix `
        -MsixFile         "C:\Packages\LibreOffice.msix" `
        -OutputFilePath   "C:\Packages\LibreOffice_fixed.msix" `
        -Subject          "CN=Contoso, O=Contoso, C=DE" `
        -VisualGroup      "LibreOffice" `
        -Verbose

.NOTES
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
        [System.IO.DirectoryInfo] $MSIXFolder = ($env:Temp + "\MSIX_TEMP_" + [System.Guid]::NewGuid().ToString()),
        [System.IO.FileInfo] $OutputFilePath = $null,
        [String] $Subject = "",
        [String] $VisualGroup = "LibreOffice",
        [Switch] $Force
    )

    if ($null -eq $MsixFile) {
        Write-Error "MsixFile parameter is required."
        return
    }

    if ($null -eq $OutputFilePath -or $OutputFilePath -eq "") {
        $OutputFilePath = $MsixFile
    }

    try {
        Write-Verbose "Opening MSIX package: $($MsixFile.FullName)"
        $null = Open-MSIXPackage -MsixFile $MsixFile -Force:$Force -MSIXFolder $MSIXFolder

        if ($Subject -ne "") {
            Write-Verbose "Setting publisher subject: $Subject"
            Set-MSIXPublisher -MSIXFolder $MSIXFolder -PublisherSubject $Subject
        }

        # Fix 1: InstalledLocationVirtualization
        Write-Verbose "Applying InstalledLocationVirtualization (all keep)"
        Add-MSIXInstalledLocationVirtualization `
            -MSIXFolderPath $MSIXFolder `
            -ModifiedItems  "keep" `
            -AddedItems     "keep" `
            -DeletedItems   "keep"

        # Fix 2: SharedFonts - registers all TTF/OTF files in the package
        Write-Verbose "Applying SharedFonts fix"
        Add-MSIXSharedFonts -MSIXFolderPath $MSIXFolder

        # Fix 3: Start Menu folder grouping (Windows 11)
        if ($VisualGroup -ne "") {
            Write-Verbose "Setting Start Menu folder: $VisualGroup"
            Set-MSIXApplicationVisualElements -MSIXFolderPath $MSIXFolder -VisualGroup $VisualGroup
        }

        Write-Verbose "Repackaging to: $($OutputFilePath)"
        Close-MSIXPackage -MSIXFolder $MSIXFolder -MSIXFile $OutputFilePath
    }
    catch {
        Write-Error "Error applying LibreOffice fix: $_"
    }
}
