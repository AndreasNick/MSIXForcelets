function New-MSIXDynamicAppAttachDisk {
<#
.SYNOPSIS
    Creates an empty, formatted, dynamic VHD or VHDX disk image for App Attach.

.DESCRIPTION
    Creates a dynamically expanding VHD or VHDX file using New-VHD from the
    Hyper-V PowerShell module, initialises it, creates a primary NTFS partition
    and returns the unmounted disk image ready to be filled by
    New-MSIXAppAttachImage -DiskImage.

    Two parameter sets are available:

      SinglePath (default)
        Provide the full output path explicitly via -Path.

      OutputFolder
        Pipe one or more MSIX files. The disk image name is derived from each
        MSIX file name and written to -OutputFolder. The volume label defaults
        to the MSIX base name.

    The Hyper-V hypervisor role does not need to be active. Installing the
    Hyper-V Management Tools feature is sufficient.

    CIM images are not supported here — use New-MSIXAppAttachImage -FileType CIM
    to create a CIM image directly via msixmgr.exe.

    Returns a FileInfo object for each created disk image.

.PARAMETER Path
    (SinglePath) Full path of the disk image to create, without extension.
    The correct extension (.vhd or .vhdx) is appended based on -FileType.

.PARAMETER MsixFile
    (OutputFolder) One or more MSIX packages piped in. The disk image is named
    after each package and written to -OutputFolder.

.PARAMETER OutputFolder
    (OutputFolder) Folder where the disk images are created.

.PARAMETER SizeMB
    Maximum disk size in megabytes for the dynamic image.

.PARAMETER FileType
    Disk image format: VHD or VHDX. Defaults to VHDX.

.PARAMETER Label
    NTFS volume label. In OutputFolder mode defaults to the MSIX base name.
    In SinglePath mode defaults to "AppAttach".

.EXAMPLE
    New-MSIXDynamicAppAttachDisk -Path "C:\VHD\MyApp" -SizeMB 500

    Creates C:\VHD\MyApp.vhdx (dynamic, up to 500 MB).

.EXAMPLE
    New-MSIXDynamicAppAttachDisk -Path "C:\VHD\MyApp" -SizeMB 500 -FileType VHD

    Creates C:\VHD\MyApp.vhd (dynamic, up to 500 MB).

.EXAMPLE
    Get-ChildItem "C:\Packages\*.msix" |
        New-MSIXDynamicAppAttachDisk -OutputFolder "C:\VHD" -SizeMB 500

    Creates one VHDX per MSIX package, named after the package.

.NOTES
    Requires elevation (Administrator).
    Requires the Hyper-V Management Tools (PowerShell module):
      Windows 10/11: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell
      Windows Server: Install-WindowsFeature -Name Hyper-V-PowerShell
    Andreas Nick, 2024
#>

    [CmdletBinding(DefaultParameterSetName = 'SinglePath')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SinglePath')]
        [string] $Path,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, ParameterSetName = 'OutputFolder')]
        [System.IO.FileInfo] $MsixFile,

        [Parameter(Mandatory = $true, ParameterSetName = 'OutputFolder')]
        [string] $OutputFolder,

        [Parameter(Mandatory = $true)]
        [ValidateRange(10, [int]::MaxValue)]
        [int] $SizeMB,

        [ValidateSet('VHD', 'VHDX')]
        [string] $FileType = 'VHDX',

        [string] $Label
    )

    begin {
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            throw "New-MSIXDynamicAppAttachDisk must be run as Administrator."
        }

        if (-not (Get-Module -ListAvailable -Name Hyper-V)) {
            throw "The Hyper-V PowerShell module is not available. " +
                  "Install the Hyper-V Management Tools: " +
                  "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell"
        }

        if ($PSCmdlet.ParameterSetName -eq 'OutputFolder' -and -not (Test-Path $OutputFolder)) {
            New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
        }
    }

    process {
        # Resolve output path and label for this item.
        if ($PSCmdlet.ParameterSetName -eq 'OutputFolder') {
            if (-not (Test-Path $MsixFile.FullName)) {
                Write-Error "MSIX file not found: $($MsixFile.FullName)"
                return
            }
            $baseName    = $MsixFile.BaseName
            $fullPath    = Join-Path $OutputFolder "$baseName.$($FileType.ToLower())"
            $effectiveLabel = if ([string]::IsNullOrEmpty($Label)) { $baseName } else { $Label }
        }
        else {
            $basePath    = [System.IO.Path]::ChangeExtension($Path, $null).TrimEnd('.')
            $fullPath    = "$basePath.$($FileType.ToLower())"
            $effectiveLabel = if ([string]::IsNullOrEmpty($Label)) { 'AppAttach' } else { $Label }
        }

        if (Test-Path $fullPath) {
            Write-Error "Disk image already exists at '$fullPath'. Remove it first or choose a different path."
            return
        }

        $diskDir = Split-Path $fullPath -Parent
        if (-not [string]::IsNullOrEmpty($diskDir) -and -not (Test-Path $diskDir)) {
            New-Item -Path $diskDir -ItemType Directory -Force | Out-Null
        }

        Write-Verbose "Creating dynamic $FileType via New-VHD: $fullPath ($SizeMB MB)"
        New-VHD -Path $fullPath -SizeBytes ($SizeMB * 1MB) -Dynamic | Out-Null

        # Mount, initialise, partition, format, dismount.
        Write-Verbose "Mounting disk image for formatting..."
        $image = $null
        try {
            $image = Mount-DiskImage -ImagePath $fullPath -PassThru
            $disk  = $image | Get-Disk

            # Safety checks — abort if the disk looks like anything other than our
            # freshly mounted, empty virtual disk.
            if ($disk.IsBoot -or $disk.IsSystem) {
                throw "Safety check failed: disk $($disk.Number) is flagged as boot or system disk. Aborting to prevent data loss."
            }
            if ($disk.IsReadOnly) {
                throw "Safety check failed: disk $($disk.Number) is read-only."
            }
            if ($disk.PartitionStyle -ne 'RAW') {
                throw "Safety check failed: disk $($disk.Number) already has a partition table ($($disk.PartitionStyle)). Expected a blank disk."
            }
            if ($disk.Location -and $disk.Location -ne $fullPath) {
                throw "Safety check failed: disk location '$($disk.Location)' does not match expected path '$fullPath'."
            }

            $partition = Initialize-Disk -Number $disk.Number -PartitionStyle MBR -PassThru |
                         New-Partition -UseMaximumSize -AssignDriveLetter

            if ($partition.DiskNumber -ne $disk.Number) {
                throw "Safety check failed: partition disk number ($($partition.DiskNumber)) does not match expected disk ($($disk.Number))."
            }
            $systemDriveLetter = $env:SystemDrive.TrimEnd(':')
            if ($partition.DriveLetter -eq $systemDriveLetter) {
                throw "Safety check failed: assigned drive letter '$($partition.DriveLetter):' is the system drive. Aborting."
            }
            $volume = Get-Volume -Partition $partition -ErrorAction SilentlyContinue
            if ($volume -and $volume.FileSystemType -ne 'Unknown' -and $volume.FileSystemType -ne 'RAW') {
                throw "Safety check failed: partition already has file system '$($volume.FileSystemType)'. Expected unformatted."
            }

            Write-Verbose "Formatting drive $($partition.DriveLetter): on disk $($disk.Number) ($([Math]::Round($partition.Size / 1MB)) MB) label '$effectiveLabel'"

            Format-Volume -DriveLetter $partition.DriveLetter `
                -FileSystem NTFS `
                -NewFileSystemLabel $effectiveLabel `
                -Confirm:$false | Out-Null
        }
        catch {
            Write-Error "Failed to initialise or format disk image '$fullPath': $_"
            throw
        }
        finally {
            if ($null -ne $image) {
                Dismount-DiskImage -ImagePath $fullPath | Out-Null
            }
        }

        Write-Host "Dynamic $FileType created: $fullPath ($SizeMB MB)" -ForegroundColor Green
        Get-Item $fullPath
    }
}
