Add-Type -Path "$PSScriptRoot\NITIconLib.dll"

$a = New-Object NIT.IconLib.IconExtractor 'C:\Program Files\WinRAR\WinRAR.exe'
$b = $a.GetIcon(1)

$c = [NIT.IconLib.IconUtil]::ResizeImage($a.GetIcon(1), [System.Drawing.Size]::new(164,64), $false)

$c.Save("$env:USERPROFILE\desktop\test.bmp", [System.Drawing.Imaging.ImageFormat]::Bmp)


