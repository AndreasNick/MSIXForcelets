function New-MSIXPackage {
    param (
        [String] $MSIXFileNamePath,
        $TempFolder = "$ENV:Temp\MSIXTempFolder"
    )

    throw "not implemented yet"

    if (!(Test-Path $TempFolder )) {
        Write-Error "Packagefolder $TempFolder not exist" 

    }
    else {
        makeappx pack /d $TempFolder /p $MSIXFileNamePath
    }
}
