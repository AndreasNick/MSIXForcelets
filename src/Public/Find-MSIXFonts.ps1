function Find-MSIXFonts {
    <#
    .SYNOPSIS
    This function checks for font files within an unpacked MSIX package directory.

    .DESCRIPTION
    The Find-MSIXFonts function recursively searches through an unpacked MSIX package directory for font files.
    Font files are identified by their extensions, such as .ttf, .otf, .woff, and .woff2.

    .PARAMETER MSIXFolderPath
    Specifies the path to the unpacked MSIX package.

    .EXAMPLE
    Find-MSIXFonts -MSIXFolderPath "C:\MyUnpackedMSIX"

    This example searches the folder "C:\MyUnpackedMSIX" for any font files and outputs the paths of found fonts.

    .NOTES
    Author: Your Name
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo] $MSIXFolderPath
    )

    # Define a list of font file extensions
    $fontExtensions = @("*.ttf", "*.otf") #, "*.woff", "*.woff2")

    # Get all font files recursively in the directory
    $fontFiles = @()
    foreach ($ext in $fontExtensions) {
        $fontFiles += Get-ChildItem -Path $MSIXFolderPath.FullName -Recurse -Filter $ext -ErrorAction SilentlyContinue
    }

    if ($fontFiles.Count -eq 0) {
        Write-Host "No font files found in the MSIX package."
    } else {
        Write-Host "Found the following font files in the MSIX package:"
        $fontFiles | ForEach-Object { Write-Output $_.FullName }
    }

    # Return the list of font files
    return $fontFiles
}
