function Add-MSIXSharedFonts {
    <#
    .SYNOPSIS
    Adds found font files to the AppxManifest.xml under the uap7:SharedFonts section.

    .DESCRIPTION
    This function searches for font files in an unpacked MSIX package and adds them to the
    AppxManifest.xml file under the <uap7:SharedFonts> section of an <Extensions> node.

    .PARAMETER MSIXFolderPath
    Specifies the path to the unpacked MSIX package directory.

    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo] $MSIXFolderPath
    )

    [System.IO.DirectoryInfo] $ManifestPath = Join-Path -Path  $MSIXFolderPath -ChildPath 'AppxManifest.xml'

    # Define a list of font file extensions
    $fontExtensions = @("*.ttf", "*.otf")

    # Recursively search for font files in the MSIX folder
    $fontFiles = @()
    foreach ($ext in $fontExtensions) {
        $fontFiles += Get-ChildItem -Path $MSIXFolderPath.FullName -Recurse -Filter $ext -ErrorAction SilentlyContinue
    }

    # Load existing AppxManifest.xml
    if (-not (Test-Path $ManifestPath)) {
        Write-Error "AppxManifest.xml not found at $ManifestPath"
        return
    }

    [xml]$manifest = Get-Content $ManifestPath.FullName

    # Create namespace manager for handling XML namespaces
    $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
    $null = $nsmgr.AddNamespace("default", "http://schemas.microsoft.com/appx/manifest/foundation/windows10")
    $null = $nsmgr.AddNamespace("uap7", "http://schemas.microsoft.com/appx/manifest/uap/windows10/7")
    $null = $nsmgr.AddNamespace("uap4", "http://schemas.microsoft.com/appx/manifest/uap/windows10/4")


    $root = $manifest.DocumentElement
    if (-not $root.HasAttribute("xmlns:uap7")) {
        $null = $root.SetAttribute("xmlns:uap7", "http://schemas.microsoft.com/appx/manifest/uap/windows10/7")
    }
    if (-not $root.HasAttribute("xmlns:uap4")) {
        $null = $root.SetAttribute("xmlns:uap4", "http://schemas.microsoft.com/appx/manifest/uap/windows10/4")
    }

    # Ensure uap7 and uap4 are included in IgnorableNamespaces
    $ignorable = $root.GetAttribute("IgnorableNamespaces")
    
    if ($ignorable -notmatch "\buap7\b") {
        # Append uap7 if not present
        $null = $root.SetAttribute("IgnorableNamespaces", "$ignorable uap7")
    }

    if ($ignorable -notmatch "\buap4\b") {
        # Append uap4 if not present
        $null = $root.SetAttribute("IgnorableNamespaces", "$ignorable uap4")
    }

    # Check if <Extensions> node exists
    $extensionsNode = $manifest.SelectSingleNode("//default:Package/default:Extensions", $nsmgr)
    
    if ($extensionsNode -eq $null) {
        # Create Extensions node if it doesn't exist
        $extensionsNode = $manifest.CreateElement("Extensions", $manifest.DocumentElement.NamespaceURI)
        
        # Insert Extensions node before the Applications node
        $applicationsNode = $manifest.SelectSingleNode("//default:Package/default:Applications", $nsmgr)
        $null = $manifest.DocumentElement.InsertAfter($extensionsNode, $applicationsNode)
    }

    # Check if <uap7:Extension> with SharedFonts category already exists
    $uap7ExtensionNode = $manifest.SelectSingleNode("//default:Package/default:Extensions/uap7:Extension[@Category='windows.sharedFonts']", $nsmgr)

    if ($uap7ExtensionNode -eq $null) {
        # Create the uap7:Extension node with Category="windows.sharedFonts"
        $uap7ExtensionNode = $manifest.CreateElement("uap7:Extension", 'http://schemas.microsoft.com/appx/manifest/uap/windows10/7')
        $categoryAttribute = $manifest.CreateAttribute("Category")
        $categoryAttribute.Value = "windows.sharedFonts"
        $null = $uap7ExtensionNode.Attributes.Append($categoryAttribute)

        # Create the uap7:SharedFonts node
        $sharedFontsNode = $manifest.CreateElement("uap7:SharedFonts", 'http://schemas.microsoft.com/appx/manifest/uap/windows10/7')
        $null = $uap7ExtensionNode.AppendChild($sharedFontsNode)

        # Append the uap7:Extension node to the Extensions node
        $null = $extensionsNode.AppendChild($uap7ExtensionNode)
    } else {
        # If the node already exists, get the existing SharedFonts node
        $sharedFontsNode = $uap7ExtensionNode.SelectSingleNode("uap7:SharedFonts", $nsmgr)
    }

    # Add fonts to the SharedFonts node
    foreach ($font in $fontFiles) {
        # Create the uap4:Font node with the Font file path (without adding xmlns every time)
        $fontNode = $manifest.CreateElement("uap4:Font", 'http://schemas.microsoft.com/appx/manifest/uap/windows10/4')
        $fileAttribute = $manifest.CreateAttribute("File")
        $fileAttribute.Value = ($font.FullName -replace [regex]::Escape($MSIXFolderPath.FullName), '').TrimStart("\")
        $null = $fontNode.Attributes.Append($fileAttribute)

        # Append the Font node to the SharedFonts node
        $null = $sharedFontsNode.AppendChild($fontNode)
        Write-Verbose "Added font file $($font.FullName) to the AppxManifest.xml."
    }

    # Save the modified manifest
    $null = $manifest.Save($ManifestPath.FullName)

    Write-Verbose "Fonts added to the AppxManifest.xml."
}
