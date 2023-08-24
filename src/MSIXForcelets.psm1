# root path
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path

# load binaries
Add-Type -AssemblyName System.IO
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# stop ansi colours in ps7.2+
if ($PSVersionTable.PSVersion -ge [version]'7.2.0') {
    $PSStyle.OutputRendering = 'PlainText'
}

# load private functions
Get-ChildItem "$($root)/Private/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

#List of existing Functions
$sysfuncs = Get-ChildItem Function:

# load public functions
Get-ChildItem "$($root)/Public/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

# get functions from memory and compare to existing to find new functions added
$funcs = Get-ChildItem Function: | Where-Object { $sysfuncs -notcontains $_ }

# export the module's public functions
Export-ModuleMember -Function ($funcs.Name)

$Script:MSIXToolkitPath = "$PSScriptRoot\MSIX-Toolkit\WindowsSDK\11\10.0.22000.0\x64"
Write-Verbose "Use Toolkit Path $($Script:MSIXToolkitPath)" 
$Script:MSIXPSFPath = "$PSScriptRoot\MSIXPSF"
Write-Verbose "Use PSF Path $($Script:MSIXPSFPath)" 

Get-MSIXToolkit

#Set Default PSF
Set-ActivePSFFramework -version "MicrosoftPSF"

