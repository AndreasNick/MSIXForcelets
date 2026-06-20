function Install-MSIXForceletsAllRequirements {
<#
.SYNOPSIS
    Installs (or updates) all external binaries needed by MSIXForcelets in one call:
    MSIX Core, Windows SDK Packaging Tools and Tim Mangan's PSF (optionally also
    the Microsoft PSF).
.DESCRIPTION
    Convenience wrapper that runs Update-MSIXTooling, Update-MSIXTMPSF and (when
    -IncludeMicrosoftPSF is set) Update-MSIXMicrosoftPSF in sequence. A failure
    in one step does not abort the others; a summary table is printed at the end.

    Without -Force the cmdlet installs MISSING components and leaves existing ones
    untouched (each sub-cmdlet asks Y/N when needed). With -Force every component
    is re-downloaded - that is the "update" path.

    Sub-cmdlet switches (-Force, -CopyVCRuntime) are forwarded.
.PARAMETER SkipTooling
    Skip Update-MSIXTooling (MSIX Core + Windows SDK Packaging Tools).
.PARAMETER SkipTimManganPSF
    Skip Update-MSIXTMPSF (Tim Mangan PSF).
.PARAMETER SkipMicrosoftPSF
    Skip Update-MSIXMicrosoftPSF (Microsoft PSF). By default the Microsoft PSF is
    installed alongside Tim Mangan's PSF.
.PARAMETER Force
    Skip per-step confirmation prompts and re-download existing components
    (= the "update everything" path).
.PARAMETER CopyVCRuntime
    Copy the local Windows VC++ runtime DLLs into the PSF folders so they don't have to
    be redistributed separately. Defaults to $true. Use -CopyVCRuntime:$false to disable.
.EXAMPLE
    Install-MSIXForceletsAllRequirements
.EXAMPLE
    Install-MSIXForceletsAllRequirements -Force
.EXAMPLE
    Install-MSIXForceletsAllRequirements -SkipMicrosoftPSF -Force
.EXAMPLE
    Install-MSIXForceletsAllRequirements -Confirm:$false
    # Non-interactive equivalent of -Force: skips the Y/N prompts of the sub-cmdlets.
.NOTES
    Andreas Nick, 2026
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '',
        Justification = 'Name describes the action: install all (plural) external requirements in one call.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '',
        Justification = 'SupportsShouldProcess is declared only to make -Confirm:$false a valid parameter; the actual Y/N prompts live inside the sub-cmdlets and are bypassed via -Force.')]
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [switch] $SkipTooling,
        [switch] $SkipTimManganPSF,
        [switch] $SkipMicrosoftPSF,
        [switch] $Force,
        [bool]   $CopyVCRuntime = $true
    )

    # The Y/N prompts inside Update-MSIXTooling / Update-MSIXTMPSF / Update-MSIXMicrosoftPSF
    # are Read-Host based and ignore $ConfirmPreference - only -Force bypasses them.
    # Map an explicit -Confirm:$false to an implicit -Force so the umbrella cmdlet honors
    # the "be non-interactive" intent.
    $confirmFalse   = $PSBoundParameters.ContainsKey('Confirm') -and -not $PSBoundParameters['Confirm']
    $effectiveForce = [bool]$Force -or $confirmFalse

    $results = @()

    if (-not $SkipTooling) {
        Write-Verbose '=== Updating: MSIX Tooling (Core + SDK) ===' -Verbose
        try {
            Update-MSIXTooling -Force:$effectiveForce
            $results += [PSCustomObject]@{ Step = 'MSIX Tooling';   Status = 'OK' }
        }
        catch {
            $results += [PSCustomObject]@{ Step = 'MSIX Tooling';   Status = "FAILED: $($_.Exception.Message)" }
            Write-Warning "MSIX Tooling update failed: $($_.Exception.Message)"
        }
    }

    if (-not $SkipTimManganPSF) {
        Write-Verbose '=== Updating: Tim Mangan PSF ===' -Verbose
        try {
            $a = @{}
            if ($effectiveForce) { $a.Force = $true }
            $a.CopyVCRuntime = $CopyVCRuntime
            Update-MSIXTMPSF @a
            $results += [PSCustomObject]@{ Step = 'Tim Mangan PSF'; Status = 'OK' }
        }
        catch {
            $results += [PSCustomObject]@{ Step = 'Tim Mangan PSF'; Status = "FAILED: $($_.Exception.Message)" }
            Write-Warning "Tim Mangan PSF update failed: $($_.Exception.Message)"
        }
    }

    if (-not $SkipMicrosoftPSF) {
        Write-Verbose '=== Updating: Microsoft PSF ===' -Verbose
        try {
            $a = @{}
            if ($effectiveForce) { $a.Force = $true }
            $a.CopyVCRuntime = $CopyVCRuntime
            Update-MSIXMicrosoftPSF @a
            $results += [PSCustomObject]@{ Step = 'Microsoft PSF';  Status = 'OK' }
        }
        catch {
            $results += [PSCustomObject]@{ Step = 'Microsoft PSF';  Status = "FAILED: $($_.Exception.Message)" }
            Write-Warning "Microsoft PSF update failed: $($_.Exception.Message)"
        }
    }

    Write-Output ''
    Write-Output 'Install-MSIXForceletsAllRequirements results:'
    $results | Format-Table -AutoSize
}
