
function Get-MSIXAppExeArchitectureType {
    <#
.SYNOPSIS
    Retrieves the architecture type for a given executable file or dll.
.DESCRIPTION
    This function reads the PE (Portable Executable) header of an executable file and determines the machine type for which the file is compiled.
.PARAMETER filePathName
    Specifies the path to the executable file.
.OUTPUTS
    System.String
    The machine type for the executable file. Possible values are:
    - "Native": The file is a native executable.
    - "I386": The file is compiled for the x86 architecture.
    - "Itanium": The file is compiled for the Itanium architecture.
    - "x64": The file is compiled for the x64 architecture.
    - "ARM": The file is compiled for the ARM architecture.
    - "ARM64": The file is compiled for the ARM64 architecture.
    - "Unknown": The machine type is unknown or unsupported.
.EXAMPLE
    Get-MSIXAppMachineType -fileName "C:\Path\To\MyApp.exe"
    Retrieves the machine type for the specified executable file.
.NOTES
    c# Source https://stackoverflow.com/questions/197951/how-can-i-determine-for-which-platform-an-executable-is-compiled
    https://www.nick-it.de
    Andreas Nick, 2024
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.IO.FileInfo] $filePathName
    )

    process {
        $PE_POINTER_OFFSET = 60
        $MACHINE_OFFSET = 4
        $data = New-Object byte[] 4096 

        $stream = [System.IO.File]::Open($filePathName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
        try {
            $null = $stream.Read($data, 0, 4096)
            $PE_HEADER_ADDR = [System.BitConverter]::ToInt32($data, $PE_POINTER_OFFSET)
            $machineUint = [System.BitConverter]::ToUInt16($data, $PE_HEADER_ADDR + $MACHINE_OFFSET)
            $architecture = switch ($machineUint) {
                0 { "Native" }
                0x014c { "I386" }
                0x0200 { "Itanium" }
                0x8664 { "x64" }
                0x01c0 { "ARM" }
                0xaa64 { "ARM64" }
                default { "Unknown" }
            }
            Write-Verbose "$($filePathName.Name) hat architecture type: $architecture"
            return $architecture

        }
        finally {
            $stream.Close()
        }
    }
}
