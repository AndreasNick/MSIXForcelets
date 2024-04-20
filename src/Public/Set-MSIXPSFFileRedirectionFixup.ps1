function Set-MSIXPSFFileRedirectionFixup {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)] 
        [String] $Executable #Process name as "Regex": "MSEDGE" od "MSEdge$", we don't need a path!
    )

    throw "Not implemented"    
}
