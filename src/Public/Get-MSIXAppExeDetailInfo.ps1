
function Get-MSIXAppExeDetailInfo {

    <#
    .SYNOPSIS
        Retrieves detailed information about the executable file.
    
    .DESCRIPTION
        The Get-MSIXAppExeDetailInfo function reads the DOS header of an executable file and returns the header information.
    
    .PARAMETER filePath
        Specifies the path to the executable file.
    
    .EXAMPLE
        Get-MSIXAppExeDetailInfo -filePath "C:\Path\To\File.exe"
        Retrieves the DOS header information of the specified executable file.
        c++ Source base https://stackoverflow.com/questions/197951/how-can-i-determine-for-which-platform-an-executable-is-compiled
        https://www.nick-it.de
        Andreas Nick, 2024
    #>   
        param (
            [string]$filePath
        )
        
        $typeDefinition = @"
                using System;
                using System.Runtime.InteropServices;
        
                public struct IMAGE_DOS_HEADER {  // DOS .EXE header
                    public UInt16 e_magic;              // Magic number
                    public UInt16 e_cblp;               // Bytes on last page of file
                    public UInt16 e_cp;                 // Pages in file
                    public UInt16 e_crlc;               // Relocations
                    public UInt16 e_cparhdr;            // Size of header in paragraphs
                    public UInt16 e_minalloc;           // Minimum extra paragraphs needed
                    public UInt16 e_maxalloc;           // Maximum extra paragraphs needed
                    public UInt16 e_ss;                 // Initial (relative) SS value
                    public UInt16 e_sp;                 // Initial SP value
                    public UInt16 e_csum;               // Checksum
                    public UInt16 e_ip;                 // Initial IP value
                    public UInt16 e_cs;                 // Initial (relative) CS value
                    public UInt16 e_lfarlc;             // File address of relocation table
                    public UInt16 e_ovno;               // Overlay number
                    public UInt16 e_res1;               // Reserved words
                    public UInt16 e_res2;               // Reserved words
                    public UInt16 e_res3;               // Reserved words
                    public UInt16 e_res4;               // Reserved words
                    public UInt32 e_oemid;              // OEM identifier (for e_oeminfo)
                    public UInt32 e_oeminfo;            // OEM information; e_oemid specific
                    public UInt16 e_res20;              // Reserved words
                    public UInt16 e_res21;              // Reserved words
                    public UInt16 e_res22;              // Reserved words
                    public UInt16 e_res23;              // Reserved words
                    public UInt32 e_lfanew;             // File address of new exe header
                }
"@
        Add-Type -TypeDefinition $typeDefinition -Language CSharp
        
        try {
            $fileStream = [System.IO.File]::OpenRead($filePath)
            $binaryReader = New-Object System.IO.BinaryReader($fileStream)
                
            # Read the DOS header
            $dosHeader = New-Object -TypeName PSObject -Property @{
                e_magic    = $binaryReader.ReadUInt16()
                e_cblp     = $binaryReader.ReadUInt16()
                e_cp       = $binaryReader.ReadUInt16()
                e_crlc     = $binaryReader.ReadUInt16()
                e_cparhdr  = $binaryReader.ReadUInt16()
                e_minalloc = $binaryReader.ReadUInt16()
                e_maxalloc = $binaryReader.ReadUInt16()
                e_ss       = $binaryReader.ReadUInt16()
                e_sp       = $binaryReader.ReadUInt16()
                e_csum     = $binaryReader.ReadUInt16()
                e_ip       = $binaryReader.ReadUInt16()
                e_cs       = $binaryReader.ReadUInt16()
                e_lfarlc   = $binaryReader.ReadUInt16()
                e_ovno     = $binaryReader.ReadUInt16()
                # Skipping reserved words
                e_oemid    = $binaryReader.ReadUInt32()
                e_oeminfo  = $binaryReader.ReadUInt32()
                # More reserved words
                e_lfanew   = $binaryReader.ReadUInt32()
            }
            return $dosHeader
        }
        finally {
            $binaryReader.Close()
            $fileStream.Close()
        }
    }
    