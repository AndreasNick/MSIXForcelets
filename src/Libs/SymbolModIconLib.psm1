<#
.SYNOPSIS
    SymbolMod icon extraction and bitmap utilities.

.DESCRIPTION
    Reads icon resources directly from PE files via LoadLibraryEx +
    EnumResourceNames + LoadResource so PNG-encoded 256x256 frames are
    preserved exactly as stored. Bitmap conversion goes through the
    Image.FromStream(saved-ico-bytes) trick which keeps full alpha gradients.

    Public functions:
      Get-SymbolModIconCount         - Number of icon groups in a PE file
      Get-SymbolModIconRawData       - Raw .ico file bytes per icon group
      Get-SymbolModIcon              - Icon at a given group index
      Get-SymbolModAllIcons          - All icons
      Get-SymbolModIconAtSize        - Pick the highest-quality frame (or by index)
      Get-SymbolModBitmapAtSize      - Same as Get-SymbolModIconAtSize but returns Bitmap
      Split-SymbolModIcon            - Split a multi-size icon into single-size icons
      Get-SymbolModIconBitCount      - Bits-per-pixel of an icon's first frame
      ConvertTo-SymbolModIconBitmap  - Convert icon to bitmap, alpha preserved
      Resize-SymbolModImage          - Resize an image with HighQualityBicubic

.NOTES
    (c) Andreas Nickel, 2024
    https://www.nick-it.de
#>

Add-Type -AssemblyName System.Drawing

# C# is needed only for the EnumResourceNames callback: a delegate invoked

if (-not ('SymbolMod.IconLib.IconReader' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;

namespace SymbolMod.IconLib {
    [UnmanagedFunctionPointer(CallingConvention.Winapi, SetLastError = true, CharSet = CharSet.Unicode)]
    internal delegate bool ResNameProc(IntPtr m, IntPtr t, IntPtr n, IntPtr p);

    public static class IconReader {
        const  uint   LOAD_AS_DATA = 0x2;
        static readonly IntPtr RT_ICON = (IntPtr)3, RT_GROUP = (IntPtr)14;

        [DllImport("kernel32", CharSet = CharSet.Unicode)] static extern IntPtr LoadLibraryEx(string f, IntPtr h, uint d);
        [DllImport("kernel32")] static extern bool   FreeLibrary(IntPtr m);
        [DllImport("kernel32", CharSet = CharSet.Unicode)] static extern bool   EnumResourceNames(IntPtr m, IntPtr t, ResNameProc c, IntPtr p);
        [DllImport("kernel32", CharSet = CharSet.Unicode)] static extern IntPtr FindResource(IntPtr m, IntPtr n, IntPtr t);
        [DllImport("kernel32")] static extern IntPtr LoadResource(IntPtr m, IntPtr r);
        [DllImport("kernel32")] static extern IntPtr LockResource(IntPtr r);
        [DllImport("kernel32")] static extern uint   SizeofResource(IntPtr m, IntPtr r);

        static byte[] ReadRes(IntPtr m, IntPtr t, IntPtr n) {
            var info = FindResource(m, n, t);
            if (info == IntPtr.Zero) throw new Win32Exception();
            var len  = (int)SizeofResource(m, info);
            var buf  = new byte[len];
            Marshal.Copy(LockResource(LoadResource(m, info)), buf, 0, len);
            return buf;
        }

        static byte[] BuildIco(IntPtr m, IntPtr name) {
            var dir   = ReadRes(m, RT_GROUP, name);
            var count = BitConverter.ToUInt16(dir, 4);
            var total = 6 + 16 * count;
            for (int i = 0; i < count; i++) total += BitConverter.ToInt32(dir, 6 + 14 * i + 8);

            using (var ms = new MemoryStream(total))
            using (var bw = new BinaryWriter(ms)) {
                bw.Write(dir, 0, 6);
                int off = 6 + 16 * count;
                for (int i = 0; i < count; i++) {
                    ushort id = BitConverter.ToUInt16(dir, 6 + 14 * i + 12);
                    var    pic = ReadRes(m, RT_ICON, (IntPtr)id);
                    bw.Seek(6 + 16 * i, SeekOrigin.Begin);
                    bw.Write(dir, 6 + 14 * i, 8);
                    bw.Write(pic.Length);
                    bw.Write(off);
                    bw.Seek(off, SeekOrigin.Begin);
                    bw.Write(pic, 0, pic.Length);
                    off += pic.Length;
                }
                return ms.ToArray();
            }
        }

        public static byte[][] Read(string fileName) {
            var m = LoadLibraryEx(fileName, IntPtr.Zero, LOAD_AS_DATA);
            if (m == IntPtr.Zero) throw new Win32Exception();
            try {
                var icos = new List<byte[]>();
                EnumResourceNames(m, RT_GROUP, (h, t, n, p) => {
                    icos.Add(BuildIco(h, n));
                    return true;
                }, IntPtr.Zero);
                return icos.ToArray();
            }
            finally { if (m != IntPtr.Zero) FreeLibrary(m); }
        }
    }
}
'@ -Language CSharp
}

# --- Internal PowerShell helper ---------------------------------------------

# Reflects on the private Icon.iconData field so Save() preserves the original
# bytes (PNG frames in particular). Falls back to Save when the field is null
# (e.g. for icons created from HICON via FromHandle).
function Get-SymbolModIconDataInternal {
    param([Parameter(Mandatory)] [System.Drawing.Icon] $Icon)
    $fi = [System.Drawing.Icon].GetField('iconData',
        [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    if ($null -ne $fi) {
        $data = $fi.GetValue($Icon)
        if ($null -ne $data) { return , [byte[]]$data }
    }
    $ms = New-Object System.IO.MemoryStream
    try {
        $Icon.Save($ms)
        return , $ms.ToArray()
    }
    finally {
        $ms.Dispose()
    }
}

# --- Public functions --------------------------------------------------------

function Get-SymbolModIconCount {
<#
.SYNOPSIS
    Returns the number of icon groups (RT_GROUP_ICON) in a PE file.
#>
    [CmdletBinding()]
    [OutputType([int])]
    param([Parameter(Mandatory = $true, Position = 0)] [string] $FileName)

    if (-not (Test-Path $FileName)) {
        Write-Error "File not found: $FileName"
        return 0
    }
    try {
        return [SymbolMod.IconLib.IconReader]::Read($FileName).Length
    }
    catch {
        Write-Error "Failed to read icons from '$FileName': $_"
        return 0
    }
}

function Get-SymbolModIconRawData {
<#
.SYNOPSIS
    Returns raw .ico bytes for one icon group from a PE file.
#>
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory = $true, Position = 0)] [string] $FileName,
        [Parameter(Position = 1)] [int] $Index = 0
    )
    if (-not (Test-Path $FileName)) {
        Write-Error "File not found: $FileName"
        return $null
    }
    try {
        $all = [SymbolMod.IconLib.IconReader]::Read($FileName)
        if ($Index -lt 0 -or $Index -ge $all.Length) {
            Write-Error "Index $Index is out of range (count=$($all.Length))."
            return $null
        }
        return , $all[$Index]
    }
    catch {
        Write-Error "Failed to extract raw icon data: $_"
        return $null
    }
}

function Get-SymbolModIcon {
<#
.SYNOPSIS
    Extracts one icon group from a PE file as a System.Drawing.Icon.
#>
    [CmdletBinding()]
    [OutputType([System.Drawing.Icon])]
    param(
        [Parameter(Mandatory = $true, Position = 0)] [string] $FileName,
        [Parameter(Position = 1)] [int] $Index = 0
    )
    $bytes = Get-SymbolModIconRawData -FileName $FileName -Index $Index
    if ($null -eq $bytes) { return $null }

    $ms = New-Object System.IO.MemoryStream(, $bytes)
    try {
        Write-Verbose "Built Icon from group index $Index of '$FileName'"
        return New-Object System.Drawing.Icon($ms)
    }
    finally {
        $ms.Dispose()
    }
}

function Get-SymbolModAllIcons {
<#
.SYNOPSIS
    Extracts every icon group from a PE file.
#>
    [CmdletBinding()]
    [OutputType([System.Drawing.Icon[]])]
    param([Parameter(Mandatory = $true, Position = 0)] [string] $FileName)

    if (-not (Test-Path $FileName)) {
        Write-Error "File not found: $FileName"
        return @()
    }
    try {
        $all = [SymbolMod.IconLib.IconReader]::Read($FileName)
        $result = New-Object 'System.Collections.Generic.List[System.Drawing.Icon]'
        foreach ($bytes in $all) {
            $ms = New-Object System.IO.MemoryStream(, $bytes)
            try   { $result.Add((New-Object System.Drawing.Icon($ms))) | Out-Null }
            finally { $ms.Dispose() }
        }
        return , $result.ToArray()
    }
    catch {
        Write-Error "Failed to extract icons: $_"
        return @()
    }
}

function Split-SymbolModIcon {
<#
.SYNOPSIS
    Splits a multi-size icon into individual single-size icons.
#>
    [CmdletBinding()]
    [OutputType([System.Drawing.Icon[]])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.Drawing.Icon] $Icon
    )
    process {
        try {
            $src = Get-SymbolModIconDataInternal -Icon $Icon
            $count = [BitConverter]::ToUInt16($src, 4)
            $result = New-Object 'System.Collections.Generic.List[System.Drawing.Icon]'

            for ($i = 0; $i -lt $count; $i++) {
                $length = [BitConverter]::ToInt32($src, 6 + 16 * $i + 8)
                $offset = [BitConverter]::ToInt32($src, 6 + 16 * $i + 12)

                $ms = New-Object System.IO.MemoryStream(6 + 16 + $length)
                $bw = New-Object System.IO.BinaryWriter($ms)
                try {
                    $bw.Write($src, 0, 4)                  # reserved + type
                    $bw.Write([UInt16]1)                   # count = 1
                    $bw.Write($src, 6 + 16 * $i, 12)       # ICONDIRENTRY (no offset)
                    $bw.Write([Int32]22)                   # dwImageOffset
                    $bw.Write($src, $offset, $length)      # payload
                    $ms.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
                    $result.Add((New-Object System.Drawing.Icon($ms))) | Out-Null
                }
                finally {
                    $bw.Dispose()
                }
            }
            return , $result.ToArray()
        }
        catch {
            Write-Error "Split failed: $_"
            return @()
        }
    }
}

function Get-SymbolModIconBitCount {
<#
.SYNOPSIS
    Returns bits-per-pixel of an icon's first frame (PNG-aware).
#>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.Drawing.Icon] $Icon
    )
    process {
        try {
            $data = Get-SymbolModIconDataInternal -Icon $Icon

            # Detect a PNG payload at offset 22 (signature 89 50 4E 47 0D 0A 1A 0A
            # followed by IHDR chunk header 00 00 00 0D 49 48 44 52).
            if ($data.Length -ge 51 -and
                $data[22] -eq 0x89 -and $data[23] -eq 0x50 -and $data[24] -eq 0x4E -and $data[25] -eq 0x47 -and
                $data[26] -eq 0x0D -and $data[27] -eq 0x0A -and $data[28] -eq 0x1A -and $data[29] -eq 0x0A -and
                $data[30] -eq 0x00 -and $data[31] -eq 0x00 -and $data[32] -eq 0x00 -and $data[33] -eq 0x0D -and
                $data[34] -eq 0x49 -and $data[35] -eq 0x48 -and $data[36] -eq 0x44 -and $data[37] -eq 0x52) {

                # IHDR: bit depth at byte 46, colour type at 47.
                switch ($data[47]) {
                    0       { return $data[46] }
                    2       { return $data[46] * 3 }
                    3       { return $data[46] }
                    4       { return $data[46] * 2 }
                    6       { return $data[46] * 4 }
                }
            }
            # ICONDIRENTRY.wBitCount at file offset 12.
            return [BitConverter]::ToUInt16($data, 12)
        }
        catch {
            Write-Error "GetBitCount failed: $_"
            return 0
        }
    }
}

function ConvertTo-SymbolModIconBitmap {
<#
.SYNOPSIS
    Converts an Icon to a Bitmap, preserving the alpha channel.
.DESCRIPTION
    Saves the icon to a memory stream and re-decodes it via Image.FromStream.
    Works correctly for PNG-encoded large frames and 32bpp DIBs as long as the
    Icon was constructed from raw .ico bytes (Get-SymbolModIcon does this).
#>
    [CmdletBinding()]
    [OutputType([System.Drawing.Bitmap])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.Drawing.Icon] $Icon
    )
    process {
        $ms = New-Object System.IO.MemoryStream
        try {
            $Icon.Save($ms)
            $img = [System.Drawing.Image]::FromStream($ms)
            try   { return New-Object System.Drawing.Bitmap($img) }
            finally { $img.Dispose() }
        }
        catch {
            Write-Error "ToBitmap failed: $_"
            return $null
        }
        finally {
            $ms.Dispose()
        }
    }
}

function Resize-SymbolModImage {
<#
.SYNOPSIS
    Resizes an image using HighQualityBicubic interpolation.
#>
    [CmdletBinding()]
    [OutputType([System.Drawing.Bitmap])]
    param(
        [Parameter(Mandatory = $true, Position = 0)] [System.Drawing.Image] $Image,
        [Parameter(Mandatory = $true, Position = 1)] [System.Drawing.Size]  $Size,
        [Parameter(Position = 2)] [bool] $PreserveAspectRatio = $true
    )
    if ($PreserveAspectRatio) {
        $ratio = [Math]::Min(
            [double]$Size.Width  / $Image.Width,
            [double]$Size.Height / $Image.Height)
        $w = [int][Math]::Round($Image.Width  * $ratio)
        $h = [int][Math]::Round($Image.Height * $ratio)
    } else {
        $w = $Size.Width
        $h = $Size.Height
    }

    $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $g.DrawImage($Image, 0, 0, $w, $h)
    }
    finally {
        $g.Dispose()
    }
    return $bmp
}

function Get-SymbolModIconAtSize {
<#
.SYNOPSIS
    Picks the largest frame from an icon group, or one at a specific frame index.
#>
    [CmdletBinding()]
    [OutputType([System.Drawing.Icon])]
    param(
        [Parameter(Mandatory = $true, Position = 0)] [string] $FileName,
        [Parameter(Position = 1)] [int] $GroupIndex = 0,
        [int] $FrameIndex = -1
    )
    $icon = Get-SymbolModIcon -FileName $FileName -Index $GroupIndex
    if ($null -eq $icon) { return $null }

    $frames = Split-SymbolModIcon -Icon $icon
    if ($null -eq $frames -or $frames.Count -eq 0) {
        Write-Verbose "No splittable frames - returning the original icon."
        return $icon
    }

    if ($FrameIndex -ge 0) {
        if ($FrameIndex -ge $frames.Count) {
            Write-Error "FrameIndex $FrameIndex exceeds frame count $($frames.Count)."
            return $null
        }
        return $frames[$FrameIndex]
    }

    $best = $frames | Sort-Object { [int]$_.Width } -Descending | Select-Object -First 1
    Write-Verbose "Selected largest frame: $($best.Width)x$($best.Height)"
    return $best
}

function Get-SymbolModBitmapAtSize {
<#
.SYNOPSIS
    Same as Get-SymbolModIconAtSize but returns the result already converted to Bitmap.
#>
    [CmdletBinding()]
    [OutputType([System.Drawing.Bitmap])]
    param(
        [Parameter(Mandatory = $true, Position = 0)] [string] $FileName,
        [Parameter(Position = 1)] [int] $GroupIndex = 0,
        [int] $FrameIndex = -1
    )
    $icon = Get-SymbolModIconAtSize -FileName $FileName -GroupIndex $GroupIndex -FrameIndex $FrameIndex
    if ($null -eq $icon) { return $null }
    try {
        return ConvertTo-SymbolModIconBitmap -Icon $icon
    }
    finally {
        $icon.Dispose()
    }
}

Export-ModuleMember -Function @(
    'Get-SymbolModIconCount',
    'Get-SymbolModIconRawData',
    'Get-SymbolModIcon',
    'Get-SymbolModAllIcons',
    'Get-SymbolModIconAtSize',
    'Get-SymbolModBitmapAtSize',
    'Split-SymbolModIcon',
    'Get-SymbolModIconBitCount',
    'ConvertTo-SymbolModIconBitmap',
    'Resize-SymbolModImage'
)
