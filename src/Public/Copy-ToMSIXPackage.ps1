function Copy-ToMSIXPackage {

    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 2)]
        [string] $Path,
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 3)]
        [ArgumentCompleter( { 'VFS\LocalAppData\Vendor\MyScript.ps1', 'MyScript.ps1' })]
        [string] $DestinaltionRootRelative,
        [switch] $Force
    )

    process {
        if (-not (Test-Path (Join-Path $MSIXFolder -ChildPath "config.json.xml") )) {
            Write-Warning "[ERROR] The MSIX config.json.xml not exist. Cannot copy file $Path"
            return $null
        }
        else {
            Copy-Item -Path $Path -Destination (Join-Path $MSIXFolder -ChildPath  $DestinaltionRootRelative) -Force:$Force
        }

    }
}


