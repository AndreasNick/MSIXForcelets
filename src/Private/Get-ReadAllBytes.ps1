function Get-ReadAllBytes {
    <#
        .SYNOPSIS
        Short description
  
        .DESCRIPTION
        Long description
  
        .PARAMETER reader
        Parameter description
  
        .EXAMPLE
        $reader = [System.IO.BinaryReader]::new($stream)
        $bytes = Get-ReadAllBytes -reader $reader
  
        .NOTES
        https://www.nick-it.de
        Andreas Nick, 2019/2020/2024
    #>
    [CmdletBinding()]
    [Alias()]
    [OutputType([byte[]])]
    
    param(
      [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
      [System.IO.BinaryReader] $reader
    )
  
    Process {
      $bufferSize = 4096
      $ms = New-Object System.IO.MemoryStream
      $buffer = New-Object byte[] $bufferSize
      $count = 0
      do {
        $count = $reader.Read($buffer, 0, $buffer.Length)
        if ($count -gt 0) { 
          $ms.Write($buffer, 0, $count)
        }
      } while ($count -ne 0)
  
      $ms.Close()
      return $ms.ToArray()
    }
  }
  