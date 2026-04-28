
function Get-MSIXAppMachineType {
    <#
.SYNOPSIS
    Retrieves the architecture type for a given executable file or dll.
.DESCRIPTION
    This function reads the PE (Portable Executable) header of an executable file and determines the machine type for which the file is compiled.
.PARAMETER FilePathName
    Specifies the path to the executable or DLL file.
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
    Get-MSIXAppMachineType -FilePathName "C:\Path\To\MyApp.exe"
    Retrieves the machine type for the specified executable file.
.NOTES
    c# Source https://stackoverflow.com/questions/197951/how-can-i-determine-for-which-platform-an-executable-is-compiled
    https://www.nick-it.de
    Andreas Nick, 2024
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.IO.FileInfo] $FilePathName
    )

    process {
        $PE_POINTER_OFFSET = 60
        $MACHINE_OFFSET = 4
        $BUFFER_SIZE = 4096
        $data = New-Object byte[] $BUFFER_SIZE

        $stream = [System.IO.File]::Open($FilePathName.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
        try {
            $null = $stream.Read($data, 0, $BUFFER_SIZE)

            # Validate that the DOS header magic bytes 'MZ' are present
            if ($data[0] -ne 0x4D -or $data[1] -ne 0x5A) {
                Write-Warning "$($FilePathName.Name) is not a valid PE file (missing MZ header)."
                "Unknown"
                return
            }

            $PE_HEADER_ADDR = [System.BitConverter]::ToInt32($data, $PE_POINTER_OFFSET)

            # Ensure the PE header and machine type field fit within the buffer
            $requiredBytes = $PE_HEADER_ADDR + $MACHINE_OFFSET + 2
            if ($PE_HEADER_ADDR -lt 0 -or $requiredBytes -gt $BUFFER_SIZE) {
                Write-Warning "$($FilePathName.Name) has a PE header offset outside the readable buffer."
                "Unknown"
                return
            }

            $machineUint = [System.BitConverter]::ToUInt16($data, $PE_HEADER_ADDR + $MACHINE_OFFSET)
            $architecture = switch ($machineUint) {
                0      { "Native" }
                0x014c { "I386" }
                0x0200 { "Itanium" }
                0x8664 { "x64" }
                0x01c0 { "ARM" }
                0xaa64 { "ARM64" }
                default { "Unknown" }
            }
            Write-Verbose "$($FilePathName.Name) architecture type: $architecture"
            $architecture
        }
        finally {
            $stream.Close()
        }
    }
}
