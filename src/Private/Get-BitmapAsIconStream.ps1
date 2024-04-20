
function Get-BitmapAsIconStream {
    <#
        .SYNOPSIS
        Helper funtions. Icons are not supportet from a dotnet class    
      
        .DESCRIPTION
        Helper funtions. Icons are not supportet from a dotnet class   
      
        .PARAMETER SourceBitmap
        A Bitmap Image
      
        .PARAMETER Fs
        fs [System.IO.MemoryStream
      
        .NOTES
        https://stackoverflow.com/questions/11434673/bitmap-save-to-save-an-icon-actually-saves-a-png
      #>
      
    param (
      [Parameter( Position = 0, Mandatory = $true, ValueFromPipelineByPropertyName = $True)] 
      [System.Drawing.Bitmap] $SourceBitmap, 
      [Parameter( Position = 1, Mandatory = $true, ValueFromPipelineByPropertyName = $True)] 
      [System.IO.MemoryStream] $Fs
    )
      
    # ICO header
    $Fs.WriteByte(0)
    $Fs.WriteByte(0)
    $Fs.WriteByte(1) 
    $Fs.WriteByte(0)
    $Fs.WriteByte(1) 
    $Fs.WriteByte(0)
  
    # Image size
    $Fs.WriteByte([byte] $SourceBitmap.Width)
      
    $Fs.WriteByte([byte] $SourceBitmap.Height)
    # Palette
    $Fs.WriteByte(0)
    # Reserved
    $Fs.WriteByte(0)
    # Number of color planes
    $Fs.WriteByte(0)
    $Fs.WriteByte(0)
    # Bits per pixel
    $Fs.WriteByte(32)
    $Fs.WriteByte(0)
  
    # Data size, will be written after the data
    $Fs.WriteByte(0)
    $Fs.WriteByte(0)
    $Fs.WriteByte(0)
    $Fs.WriteByte(0)
  
    # Offset to image data, fixed at 22
    $Fs.WriteByte(22)
    $Fs.WriteByte(0)
    $Fs.WriteByte(0)
    $Fs.WriteByte(0)
  
    # Writing actual data
    $null = $SourceBitmap.Save($Fs, [System.Drawing.Imaging.ImageFormat]::png)
  
    # Getting data length (file length minus header)
    [long] $Len = $FS.Length - 22
  
    # Write it in the correct place
    $null = $Fs.Seek(14, [System.IO.SeekOrigin]::Begin)
    $Fs.WriteByte([byte] ($Len -band 0x00ff))
    $Fs.WriteByte([byte] ($Len -shr 8))
    $Fs.WriteByte([byte] ($Len -shr 16))
    $Fs.WriteByte([byte] ($Len -shr 25))
  
    #$Fs.Close()
  }
  