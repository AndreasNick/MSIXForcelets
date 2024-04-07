function Set-ActivePSFFramework {
    <#
    .SYNOPSIS
    Sets the active PSF (Package Support Framework) framework.
    
    .DESCRIPTION
    This function sets the active PSF framework for MSIX packaging.
    
    .PARAMETER Framework
    The name of the PSF framework to set as active.
    
    .EXAMPLE
    Set-ActivePSFFramework -Framework "MicrosoftPSF"
    
    This example sets the PSF framework "MicrosoftPSF" as the active framework.
    #>
    
        param (
            [Parameter(Mandatory = $true)]
            [ValidateSet("MicrosoftPSF", "TimManganPSF")]
            [string] $version
            
        )
    
        $Script:PSFVersion = $version
    
        $Script:PsfBasePath = (Join-Path $MSIXPSFPath -childPath "$PSFVersion")
        if(-not (Test-Path $PsfBasePath)){
            Write-Warning "MSIX PSF not exist in $($PsfBasePath) - please Download" 
        }
    }