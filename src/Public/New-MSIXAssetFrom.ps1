function New-MSIXAssetFrom {
<#
.SYNOPSIS
    Generates the six standard MSIX VisualElements PNGs from an .exe / .ico / image.

.DESCRIPTION
    Auto-detects the source type by extension:
      .exe / .dll      - extracts the icon group at -IconIndex (default 0) and
                         picks the largest embedded frame (PNG-aware).
      .ico             - loads as Icon and uses the largest embedded frame.
      .png/.jpg/.bmp/.gif - loads as Bitmap directly.

    Output files are written to <MSIXFolder>\Assets:
      <AssetId>-Square44x44Logo.png    (44x44)
      <AssetId>-Square71x71Logo.png    (71x71)
      <AssetId>-Square150x150Logo.png  (150x150)
      <AssetId>-Square310x310Logo.png  (310x310)
      <AssetId>-Wide310x150Logo.png    (310x150, letterboxed)
      <AssetId>-StoreLogo.png          (50x50)

.PARAMETER MSIXFolder
    Path to the expanded MSIX package folder.

.PARAMETER SourcePath
    Source file: .exe / .dll / .ico / .png / .jpg / .bmp / .gif.

.PARAMETER AssetId
    Filename prefix for the generated PNGs. Defaults to a sanitised form of the
    source's base name.

.PARAMETER IconIndex
    Icon index inside the PE file (only meaningful for .exe / .dll). Default 0.

.EXAMPLE
    $a = New-MSIXAssetFrom -MSIXFolder $pkg -SourcePath "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe"
    Add-MSIXApplication -MSIXFolder $pkg -Executable 'NITTracer.ps1' -AssetId $a.AssetId

.NOTES
    https://www.nick-it.de
    Andreas Nick, 2026
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.IO.DirectoryInfo] $MSIXFolder,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.IO.FileInfo] $SourcePath,

        [string] $AssetId,

        [int] $IconIndex = 0,

        # Also overwrites Assets\StoreLogo.png so the package-level Logo
        # (shown by AppInstaller) matches the generated icon.
        [switch] $SetAsPackageLogo
    )

    process {
        if (-not (Test-Path $SourcePath.FullName)) {
            Write-Error "Source file not found: $($SourcePath.FullName)"
            return $null
        }
        if (-not (Test-Path $MSIXFolder.FullName)) {
            Write-Error "MSIX folder not found: $($MSIXFolder.FullName)"
            return $null
        }

        $assetsDir = Join-Path $MSIXFolder.FullName 'Assets'
        if (-not (Test-Path $assetsDir)) {
            New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
            Write-Verbose "Created Assets folder: $assetsDir"
        }

        # Derive AssetId from filename if not given
        if ([string]::IsNullOrEmpty($AssetId)) {
            $base = [IO.Path]::GetFileNameWithoutExtension($SourcePath.Name)
            $sanitised = ($base -replace '[^A-Za-z0-9]', '')
            if ($sanitised.Length -eq 0) {
                Write-Error "Could not derive AssetId from '$($SourcePath.Name)'. Provide -AssetId explicitly."
                return $null
            }
            $AssetId = $sanitised
            Write-Verbose "Derived AssetId: $AssetId"
        }

        # Lazy-load the icon helper module
        $libPath = Join-Path $Script:ScriptPath 'Libs\SymbolModIconLib.psm1'
        if (-not (Test-Path $libPath)) {
            Write-Error "SymbolModIconLib.psm1 not found at: $libPath"
            return $null
        }
        Import-Module $libPath -Force -Verbose:$false

        # Resolve source to a Bitmap (high-quality)
        $ext = $SourcePath.Extension.ToLowerInvariant()
        Write-Verbose "Source type detected: $ext"

        $sourceBitmap = $null
        try {
            switch ($ext) {
                { $_ -in '.exe', '.dll' } {
                    # Reads RT_GROUP_ICON resources directly so PNG-encoded frames
                    # are preserved with full alpha (ported from SymbolModIconLib.dll).
                    $sourceBitmap = Get-SymbolModBitmapAtSize -FileName $SourcePath.FullName -GroupIndex $IconIndex
                    if ($null -eq $sourceBitmap) {
                        Write-Error "No icon at group index $IconIndex in '$($SourcePath.FullName)'."
                        return $null
                    }
                    Write-Verbose "Extracted icon as bitmap: $($sourceBitmap.Width)x$($sourceBitmap.Height)"
                    break
                }
                '.ico' {
                    $icon = New-Object System.Drawing.Icon($SourcePath.FullName)
                    $frames = Split-SymbolModIcon -Icon $icon
                    $largest = $frames | Sort-Object { [int]$_.Width } -Descending | Select-Object -First 1
                    Write-Verbose "Largest .ico frame: $($largest.Width)x$($largest.Height)"
                    $sourceBitmap = ConvertTo-SymbolModIconBitmap -Icon $largest
                    $icon.Dispose()
                    foreach ($f in $frames) { $f.Dispose() }
                    break
                }
                { $_ -in '.png', '.jpg', '.jpeg', '.bmp', '.gif' } {
                    $sourceBitmap = New-Object System.Drawing.Bitmap($SourcePath.FullName)
                    Write-Verbose "Loaded image: $($sourceBitmap.Width)x$($sourceBitmap.Height)"
                    break
                }
                default {
                    Write-Error "Unsupported source extension '$ext'. Use .exe/.dll/.ico/.png/.jpg/.bmp/.gif."
                    return $null
                }
            }
        }
        catch {
            Write-Error "Failed to load source '$($SourcePath.FullName)': $_"
            return $null
        }

        if ($null -eq $sourceBitmap) {
            Write-Error "Source bitmap could not be produced."
            return $null
        }

        # Target sizes: name -> [width, height]
        $targets = [ordered]@{
            "$AssetId-Square44x44Logo.png"   = @(44,  44)
            "$AssetId-Square71x71Logo.png"   = @(71,  71)
            "$AssetId-Square150x150Logo.png" = @(150, 150)
            "$AssetId-Square310x310Logo.png" = @(310, 310)
            "$AssetId-Wide310x150Logo.png"   = @(310, 150)
            "$AssetId-StoreLogo.png"         = @(50,  50)
        }

        $written = New-Object 'System.Collections.Generic.List[string]'
        try {
            foreach ($pair in $targets.GetEnumerator()) {
                $w = $pair.Value[0]
                $h = $pair.Value[1]
                $outPath = Join-Path $assetsDir $pair.Key

                # Letterbox: fit source aspect-preserved onto a transparent canvas of (w,h)
                $canvas = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
                $g = [System.Drawing.Graphics]::FromImage($canvas)
                try {
                    $g.Clear([System.Drawing.Color]::Transparent)
                    $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                    $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

                    $ratio = [Math]::Min([double]$w / $sourceBitmap.Width, [double]$h / $sourceBitmap.Height)
                    $rw = [int]([Math]::Round($sourceBitmap.Width  * $ratio))
                    $rh = [int]([Math]::Round($sourceBitmap.Height * $ratio))
                    $rx = [int](($w - $rw) / 2)
                    $ry = [int](($h - $rh) / 2)
                    $g.DrawImage($sourceBitmap, $rx, $ry, $rw, $rh)
                }
                finally {
                    $g.Dispose()
                }
                $canvas.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
                $canvas.Dispose()
                $written.Add($outPath) | Out-Null
                Write-Verbose "Wrote $outPath ($w x $h)"
            }
        }
        catch {
            Write-Error "Failed while writing assets: $_"
            return $null
        }
        finally {
            $sourceBitmap.Dispose()
        }

        if ($SetAsPackageLogo) {
            $assetStoreLogo   = Join-Path $assetsDir "$AssetId-StoreLogo.png"
            $packageStoreLogo = Join-Path $assetsDir 'StoreLogo.png'
            Copy-Item -LiteralPath $assetStoreLogo -Destination $packageStoreLogo -Force
            Write-Verbose "Replaced Assets\StoreLogo.png with the generated $AssetId-StoreLogo.png"
        }

        return [PSCustomObject]@{
            AssetId   = $AssetId
            Source    = $SourcePath.FullName
            Files     = $written.ToArray()
            StoreLogo = "Assets\$AssetId-StoreLogo.png"
        }
    }
}
