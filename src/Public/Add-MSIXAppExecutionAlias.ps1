
function Add-MSIXAppExecutionAlias {
<#
.SYNOPSIS
    Adds an App Execution Alias to an MSIX application.

.DESCRIPTION
    Adds an App Execution Alias extension to an application entry in AppxManifest.xml.
    The alias lets users invoke the application by name from a Run dialog or command prompt.

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder (must contain AppxManifest.xml).

.PARAMETER MSIXAppID
    Application/@Id value as it appears in AppxManifest.xml.

.PARAMETER CommandlineAlias
    The alias name users type to launch the application (e.g. "WinRAR.exe").

.PARAMETER Executable
    Package-relative path to the executable activated by the alias
    (e.g. "VFS\ProgramFilesX64\WinRAR\WinRAR.exe"). When specified, it is written
    as the Executable attribute on the uap5:Extension element so Windows knows
    which process to start. Important when the Application's own Executable
    attribute already points to a PSF launcher.

.EXAMPLE
    Add-MSIXAppExecutionAlias -MSIXFolder "C:\MyApp" -MSIXAppID "MyAppID" -CommandlineAlias "myapp.exe"

.EXAMPLE
    Add-MSIXAppExecutionAlias -MSIXFolder "C:\MSIXTemp\WinRAR" -MSIXAppID "WinRAR" `
        -CommandlineAlias "WinRAR.exe" `
        -Executable "VFS\ProgramFilesX64\WinRAR\WinRAR.exe"

.NOTES
    Author: Andreas Nick
    Date: 01/10/2022
    https://www.nick-it.de
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [Alias('Id', 'MISXAppID')]
        [String] $MSIXAppID,

        [Parameter(Mandatory = $true)]
        [String] $CommandlineAlias,

        [String] $Executable = ''
    )

    process {
        $manifestPath = Join-Path $MSIXFolder 'AppxManifest.xml'
        if (-not (Test-Path $manifestPath)) {
            Write-Error "AppxManifest.xml not found in: $($MSIXFolder.FullName)"
            return
        }

        $manifest = New-Object xml
        $nsmgr = New-Object System.Xml.XmlNamespaceManager $manifest.NameTable
        $AppXNamespaces.GetEnumerator() | ForEach-Object {
            $nsmgr.AddNamespace($_.Key, $_.Value)
        }
        $manifest.Load($manifestPath)

        $appNode = $manifest.SelectSingleNode(
            "//ns:Package/ns:Applications/ns:Application[@Id='$MSIXAppID']", $nsmgr)
        if ($null -eq $appNode) {
            Write-Error "Application '$MSIXAppID' not found in AppxManifest.xml."
            return
        }

        # Create Extensions element if the application has none.
        $extensionsNode = $appNode.SelectSingleNode('ns:Extensions', $nsmgr)
        if ($null -eq $extensionsNode) {
            $extensionsNode = $manifest.CreateElement('Extensions', $AppXNamespaces['ns'])
            $null = $appNode.AppendChild($extensionsNode)
        }

        # uap5 is the correct namespace for windows.appExecutionAlias per the MSIX schema.
        $nsUap5 = 'http://schemas.microsoft.com/appx/manifest/uap/windows10/5'
        $nsmgr.AddNamespace('uap5check', $nsUap5)

        $existingAlias = $extensionsNode.SelectSingleNode(
            ".//uap5check:Extension[@Category='windows.appExecutionAlias']", $nsmgr)
        if ($null -ne $existingAlias) {
            Write-Verbose "Execution alias already present for '$MSIXAppID' - skipped."
            return
        }

        Add-MSIXManifestNamespace -Manifest $manifest -Prefixes 'uap5'

        Write-Verbose "Adding execution alias '$CommandlineAlias' to Application '$MSIXAppID'."

        # Structure per MSIX schema: uap5:Extension / uap5:AppExecutionAlias / uap5:ExecutionAlias
        $extensionNode = $manifest.CreateElement('uap5', 'Extension', $nsUap5)
        $null = $extensionNode.SetAttribute('Category', 'windows.appExecutionAlias')
        $null = $extensionNode.SetAttribute('EntryPoint', 'Windows.FullTrustApplication')
        if ($Executable -ne '') {
            $null = $extensionNode.SetAttribute('Executable', $Executable)
        }
        $null = $extensionsNode.AppendChild($extensionNode)

        $aliasContainerNode = $manifest.CreateElement('uap5', 'AppExecutionAlias', $nsUap5)
        $null = $extensionNode.AppendChild($aliasContainerNode)

        $executionAliasNode = $manifest.CreateElement('uap5', 'ExecutionAlias', $nsUap5)
        $null = $executionAliasNode.SetAttribute('Alias', $CommandlineAlias)
        $null = $aliasContainerNode.AppendChild($executionAliasNode)

        $manifest.PreserveWhitespace = $false
        $manifest.Save($manifestPath)
    }
}
