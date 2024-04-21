function New-MSIXAppAttachVHD {
    param (
        [string]$AppParentFolder,
        [string]$VhdFullPath,
        [string]$PackageName,
        [string]$MsixPath
    )

    throw "Not implemented"

    # calculate the VHDX Size from MSIX Size
    $VhdSize = (Get-Item $MsixPath | Select-Object -ExpandProperty Length) / 1024 * 1.5
    


    # example
    #$VhdSize = 1300
    #$AppParentFolder = "AdobeReaderDC"
    #$VhdFullPath = "C:\msix\avd\vhdx\$AppParentFolder.vhdx"
    #$PackageName = "AdobeReaderDC_1.0.1.0_x64__kz5d2ck10dqg4"
    #$MsixPath = "C:\msix\avd\msix\AdobeReaderDC_1.0.1.0_x64__kz5d2ck10dqg4_1.msix"


    # Expand the MSIX to VHDX
    cd "C:\msix\avd\msixmgr\x64\"
    .\msixmgr.exe -Unpack -packagePath $MsixPath `
        -destination $VhdFullPath `
        -applyacls -create -vhdsize $VhdSize -filetype "vhdx" -rootDirectory $AppParentFolder

        

}
