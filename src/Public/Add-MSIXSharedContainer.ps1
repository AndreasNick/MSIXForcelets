function Add-MSIXSharedContainer {
<#
.SYNOPSIS
    Creates a Windows shared package container by name, accepting wildcard
    patterns or literal PackageFamilyNames.

.DESCRIPTION
    Convenience wrapper around the Appx Add-AppSharedPackageContainer cmdlet.
    Builds the required AppSharedPackageContainer XML on the fly from the given
    package list, writes it to a temp file, and forwards it together with the
    optional -Force / -ForceApplicationShutdown / -Merge switches.

    Each entry in -Package is handled as follows:
      - Wildcard pattern (contains "*" or "?") — resolved against installed
        Appx packages by matching either the Name or the PackageFamilyName.
      - Anything else — taken as a literal PackageFamilyName.

    Shared package containers require Windows Server 2025 or Windows 11 24H2+.

.PARAMETER Name
    Name of the shared package container (becomes the AppSharedPackageContainer/@Name
    attribute, e.g. "JavaContainer").

.PARAMETER Package
    One or more package identifiers
    A container requires at least two distinct PackageFamilyNames!
    

.PARAMETER Force
    Forwarded to Add-AppSharedPackageContainer. Replaces an existing container
    with the same name.

.PARAMETER ForceApplicationShutdown
    Forwarded to Add-AppSharedPackageContainer. Terminates running app
    processes that block the container operation.

.PARAMETER Merge
    Forwarded to Add-AppSharedPackageContainer. Merges into an existing
    container instead of creating a new one.

.PARAMETER ExportXml
    Writes the generated AppSharedPackageContainer XML to the given path and
    returns — does NOT call Add-AppSharedPackageContainer. Useful for building
    the XML on one machine and importing it later (e.g. with
    `Add-AppSharedPackageContainer -Path …` on a target system). When this is
    set, -Force / -ForceApplicationShutdown / -Merge are ignored and the
    availability of the underlying Appx cmdlet is not required.

.EXAMPLE
    Add-MSIXSharedContainer -Name 'JavaContainer' -Package '*java*','*Freecol*'

    Resolves both wildcard patterns against installed packages and groups all
    matches into a new container named JavaContainer.

.EXAMPLE
    Add-MSIXSharedContainer -Name 'JavaContainer' `
        -Package 'Freecol_0cfjrh7p5ggd2','openjdkjre_0cfjrh7p5ggd2' -Force

    Uses literal PFNs and replaces any existing JavaContainer.

.EXAMPLE
    Add-MSIXSharedContainer 'OfficeBundle' '*Word*','*Excel*','Acme.Helper_8wekyb3d8bbwe' -Merge

    Mixes wildcards and a literal PFN, merges into an existing OfficeBundle.

.EXAMPLE
    Add-MSIXSharedContainer -Name 'JavaContainer' `
        -Package 'Freecol_0cfjrh7p5ggd2','openjdkjre_0cfjrh7p5ggd2' `
        -ExportXml 'C:\Deploy\JavaContainer.xml'

    Builds only the XML config and saves it to disk for later import on a
    target machine; nothing is registered locally.

.NOTES
    https://learn.microsoft.com/en-us/powershell/module/appx/add-appsharedpackagecontainer
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name,

        [Parameter(Mandatory = $true, Position = 1)]
        [string[]] $Package,

        [switch] $Force,
        [switch] $ForceApplicationShutdown,
        [switch] $Merge,

        [System.IO.FileInfo] $ExportXml
    )

    process {
        # When -ExportXml is set we just build the XML and write it to disk,
        # so the underlying Appx cmdlet does not have to be present.
        $exportOnly = $PSBoundParameters.ContainsKey('ExportXml')

        if (-not $exportOnly) {
            if (-not (Get-Command Add-AppSharedPackageContainer -ErrorAction SilentlyContinue)) {
                Write-Error "Add-AppSharedPackageContainer is not available on this system. Requires Windows Server 2025 or Windows 11 24H2+."
                return
            }
        }
        elseif ($Force -or $ForceApplicationShutdown -or $Merge) {
            Write-Warning "-ExportXml is set; -Force / -ForceApplicationShutdown / -Merge are ignored (only relevant when registering the container)."
        }

        # Resolve every input entry to a list of PackageFamilyNames
        $pfnList = New-Object 'System.Collections.Generic.List[string]'
        foreach ($entry in $Package) {
            if ($entry -match '[\*\?]') {
                $matched = Get-AppxPackage -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like $entry -or $_.PackageFamilyName -like $entry }

                if ($null -eq $matched -or @($matched).Count -eq 0) {
                    Write-Warning "No installed package matches pattern '$entry'"
                    continue
                }

                foreach ($pkg in @($matched)) {
                    Write-Verbose "Pattern '$entry' resolved to PFN '$($pkg.PackageFamilyName)' (Name=$($pkg.Name))"
                    $pfnList.Add($pkg.PackageFamilyName)
                }
            }
            else {
                # Literal PFN — pass through as-is
                $pfnList.Add($entry)
            }
        }

        # Keep the -Package order: in a shared package container the order is the priority
        # (first = highest). Select-Object -Unique de-duplicates while preserving that order;
        # Sort-Object -Unique would re-sort alphabetically and silently break the priority.
        $uniquePfns = @($pfnList | Select-Object -Unique)

        if ($uniquePfns.Count -lt 2) {
            Write-Error "A shared package container needs at least 2 distinct PackageFamilyNames. Got $($uniquePfns.Count) after pattern resolution and de-duplication."
            return
        }

        # Build the AppSharedPackageContainer XML
        $xml  = New-Object System.Xml.XmlDocument
        $decl = $xml.CreateXmlDeclaration('1.0', 'utf-8', $null)
        $null = $xml.AppendChild($decl)

        $root = $xml.CreateElement('AppSharedPackageContainer')
        $null = $root.SetAttribute('Name', $Name)
        foreach ($pfn in $uniquePfns) {
            $elem = $xml.CreateElement('PackageFamily')
            $null = $elem.SetAttribute('Name', $pfn)
            $null = $root.AppendChild($elem)
        }
        $null = $xml.AppendChild($root)

        Write-Verbose ("Container '$Name' members:`r`n" + (($uniquePfns | ForEach-Object { '  ' + $_ }) -join "`r`n"))

        if ($exportOnly) {
            # Ensure parent directory exists, then save the XML where the caller asked
            $exportDir = Split-Path -Parent $ExportXml.FullName
            if ($exportDir -and -not (Test-Path $exportDir)) {
                $null = New-Item -ItemType Directory -Path $exportDir -Force
            }
            $xml.Save($ExportXml.FullName)
            Write-Verbose "Container XML exported to $($ExportXml.FullName)"
            return
        }

        $tempXml = Join-Path $env:Temp ("MSIXSharedContainer_" + [System.Guid]::NewGuid().ToString() + ".xml")
        $xml.Save($tempXml)
        Write-Verbose "Container XML written to $tempXml"

        try {
            $params = @{ Path = $tempXml }
            if ($Force)                    { $params.Force = $true }
            if ($ForceApplicationShutdown) { $params.ForceApplicationShutdown = $true }
            if ($Merge)                    { $params.Merge = $true }
            Add-AppSharedPackageContainer @params
        }
        finally {
            Remove-Item $tempXml -Force -ErrorAction SilentlyContinue
        }
    }
}
