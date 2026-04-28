function Set-MSIXApplicationVisualElements {
<#
.SYNOPSIS
    Sets or removes visual element attributes on Application entries in AppxManifest.xml.

.DESCRIPTION
    Modifies the uap3:VisualElements element for one or more Application entries.
    Only parameters that are explicitly passed are acted upon:

      - Passed with a value  -> attribute is created or updated
      - Passed as $null      -> attribute is removed
      - Not passed at all    -> attribute is left unchanged

    When VisualGroup is set the function ensures the element uses the uap3 namespace
    (required for VisualGroup support). If the existing element is uap:VisualElements
    it is replaced by uap3:VisualElements while preserving all existing attributes and
    child nodes. The uap3 namespace declaration and IgnorableNamespaces entry are
    added to the root Package element automatically.

    The function can be used standalone or via pipeline from Get-MSIXApplications:

        # All applications
        Set-MSIXApplicationVisualElements -MSIXFolderPath $folder -VisualGroup "LibreOffice"

        # Only selected applications
        Get-MSIXApplications -MSIXFolder $folder |
            Where-Object { $_.Id -ne "StartCenter" } |
            Set-MSIXApplicationVisualElements -VisualGroup "LibreOffice"

    The manifest is saved once per folder after all pipeline objects are processed.

.PARAMETER MSIXFolderPath
    Path to the unpacked MSIX package directory containing AppxManifest.xml.
    Accepts pipeline input by property name (supplied automatically by
    Get-MSIXApplications).

.PARAMETER Id
    Application Id to update. Accepted from pipeline. When omitted all applications
    in the folder are updated.

.PARAMETER DisplayName
    Friendly display name shown to the user. Pass $null to remove the attribute.

.PARAMETER Description
    Short description of the application. Pass $null to remove the attribute.

.PARAMETER BackgroundColor
    Tile background color: a hex value preceded by "#" (e.g. "#336699") or a named
    color (e.g. "transparent"). Pass $null to remove the attribute.

.PARAMETER AppListEntry
    Controls visibility in the Start menu All Apps list.
    "default" = visible (normal), "none" = hidden (e.g. for helper processes).
    Pass $null to remove the attribute.

.PARAMETER VisualGroup
    Start Menu folder name (Windows 11). All applications with the same value are
    grouped under one folder. Pass $null to remove the attribute.
    Must not contain backslashes or spaces.

.EXAMPLE
    Set-MSIXApplicationVisualElements -MSIXFolderPath "C:\MSIXTemp\LibreOffice" -VisualGroup "LibreOffice"

.EXAMPLE
    Get-MSIXApplications -MSIXFolder "C:\MSIXTemp\LibreOffice" |
        Set-MSIXApplicationVisualElements -VisualGroup "LibreOffice" -BackgroundColor "transparent"

.EXAMPLE
    # Remove VisualGroup from all applications
    Set-MSIXApplicationVisualElements -MSIXFolderPath $folder -VisualGroup $null

.NOTES
    VisualGroup requires Windows 11.
    https://learn.microsoft.com/en-us/uwp/schemas/appxpackage/uapmanifestschema/element-uap3-visualelements
    Andreas Nick, 2026
#>
    [CmdletBinding(DefaultParameterSetName = 'Direct')]
    Param(
        [Parameter(ParameterSetName = 'Direct',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'Pipeline', Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.IO.DirectoryInfo] $MSIXFolderPath,

        [Parameter(ParameterSetName = 'Pipeline',
            ValueFromPipelineByPropertyName = $true)]
        [String] $Id,

        [Parameter()][AllowNull()][AllowEmptyString()]
        [String] $DisplayName,

        [Parameter()][AllowNull()][AllowEmptyString()]
        [String] $Description,

        [Parameter()][AllowNull()][AllowEmptyString()]
        [String] $BackgroundColor,

        [Parameter()][AllowNull()][AllowEmptyString()]
        [ValidateSet("default", "none")]
        [String] $AppListEntry,

        [Parameter()][AllowNull()][AllowEmptyString()]
        [String] $VisualGroup
    )

    begin {
        # Keyed by resolved folder path -> list of Application Ids to update (empty = all)
        $pending = @{}
    }

    process {
        $folderKey = ([System.IO.DirectoryInfo]$MSIXFolderPath).FullName

        if (-not $pending.ContainsKey($folderKey)) {
            $pending[$folderKey] = [System.Collections.Generic.List[string]]::new()
        }

        if ($PSCmdlet.ParameterSetName -eq 'Pipeline' -and $Id -ne "") {
            $pending[$folderKey].Add($Id)
        }
        # Direct parameter set: empty list signals "update all applications"
    }

    end {
        $uapNs  = "http://schemas.microsoft.com/appx/manifest/uap/windows10"
        $uap3Ns = "http://schemas.microsoft.com/appx/manifest/uap/windows10/3"

        # Determine which attributes were explicitly passed by the caller
        $passedAttrs = @('DisplayName', 'Description', 'BackgroundColor', 'AppListEntry', 'VisualGroup') |
            Where-Object { $PSBoundParameters.ContainsKey($_) }

        if ($passedAttrs.Count -eq 0) {
            Write-Warning “No attributes specified - nothing to do.”
            return
        }

        $needsUap3 = $PSBoundParameters.ContainsKey('VisualGroup') -and
                     ($null -ne $VisualGroup -and $VisualGroup -ne "")

        foreach ($folderPath in $pending.Keys) {
            $manifestPath = Join-Path $folderPath "AppxManifest.xml"
            if (-not (Test-Path $manifestPath)) {
                Write-Warning "Cannot open path: $manifestPath"
                continue
            }

            $manifest = New-Object xml
            $manifest.Load($manifestPath)

            $nsmgr = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
            $null = $nsmgr.AddNamespace("default", "http://schemas.microsoft.com/appx/manifest/foundation/windows10")
            $null = $nsmgr.AddNamespace("uap",  $uapNs)
            $null = $nsmgr.AddNamespace("uap3", $uap3Ns)

            if ($needsUap3) {
                $root = $manifest.DocumentElement
                if (-not $root.HasAttribute("xmlns:uap3")) {
                    $null = $root.SetAttribute("xmlns:uap3", $uap3Ns)
                }
                $ignorable = $root.GetAttribute("IgnorableNamespaces")
                if ($ignorable -notmatch "\buap3\b") {
                    $null = $root.SetAttribute("IgnorableNamespaces", "$ignorable uap3".Trim())
                }
            }

            $targetIds  = $pending[$folderPath]
            $applications = $manifest.SelectNodes(
                "//default:Package/default:Applications/default:Application", $nsmgr)

            foreach ($app in $applications) {
                $appId = $app.GetAttribute("Id")

                if ($targetIds.Count -gt 0 -and $targetIds -notcontains $appId) {
                    continue
                }

                # Find existing VisualElements (uap3 preferred, fall back to uap)
                $visualElements = $app.SelectSingleNode("uap3:VisualElements", $nsmgr)
                if ($null -eq $visualElements) {
                    $visualElements = $app.SelectSingleNode("uap:VisualElements", $nsmgr)
                }

                if ($null -eq $visualElements) {
                    Write-Warning "No VisualElements found for Application '$appId' - skipping."
                    continue
                }

                # Upgrade uap -> uap3 when VisualGroup is being set
                if ($needsUap3 -and $visualElements.NamespaceURI -ne $uap3Ns) {
                    $newElement = $manifest.CreateElement("uap3:VisualElements", $uap3Ns)

                    foreach ($attr in $visualElements.Attributes) {
                        if ($attr.Prefix -eq "xmlns" -or $attr.Name -eq "xmlns") {
                            continue
                        }
                        if ($attr.NamespaceURI -ne "" -and $null -ne $attr.NamespaceURI) {
                            $newAttr = $manifest.CreateAttribute($attr.Prefix, $attr.LocalName, $attr.NamespaceURI)
                        }
                        else {
                            $newAttr = $manifest.CreateAttribute($attr.LocalName)
                        }
                        $newAttr.Value = $attr.Value
                        $null = $newElement.Attributes.Append($newAttr)
                    }

                    while ($visualElements.HasChildNodes) {
                        $null = $newElement.AppendChild($visualElements.FirstChild)
                    }

                    $null = $app.ReplaceChild($newElement, $visualElements)
                    $visualElements = $newElement
                }

                # Apply the requested attribute changes
                foreach ($attrName in $passedAttrs) {
                    $attrValue = $PSBoundParameters[$attrName]
                    if ($null -eq $attrValue -or $attrValue -eq "") {
                        $visualElements.RemoveAttribute($attrName)
                        Write-Verbose "Removed attribute '$attrName' from Application '$appId'."
                    }
                    else {
                        $null = $visualElements.SetAttribute($attrName, $attrValue)
                        Write-Verbose "Set '$attrName' = '$attrValue' on Application '$appId'."
                    }
                }
            }

            $null = $manifest.Save($manifestPath)
        }
    }
}
