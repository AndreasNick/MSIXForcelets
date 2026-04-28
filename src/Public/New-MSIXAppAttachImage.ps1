function New-MSIXAppAttachImage {
<#
.SYNOPSIS
    Unpacks an MSIX package into a VHD, VHDX or CIM App Attach image.

.DESCRIPTION
    Uses msixmgr.exe to unpack an MSIX package into a disk image suitable
    for Azure Virtual Desktop App Attach.

    Three parameter sets are available:

      Create (default)
        msixmgr creates a fixed-size VHD, VHDX or CIM image. Output path is
        specified explicitly via -VhdPath.

      ExistingDisk
        An empty, pre-formatted dynamic VHD or VHDX is provided via -DiskImage
        (e.g. from New-MSIXDynamicAppAttachDisk). The function mounts it,
        unpacks the MSIX and dismounts it. CIM is not supported here.

      OutputFolder
        Pipeline-friendly. One or more MSIX files are piped in. The image name
        is derived from each MSIX file name and written to -OutputFolder.

    Returns a FileInfo object for each created image.

.PARAMETER MsixFile
    Path to the source MSIX package. Accepts pipeline input in all parameter sets.

.PARAMETER VhdPath
    (Create) Full path of the image file to create, including file name and
    extension (.vhd, .vhdx or .cim).

.PARAMETER FileType
    (Create, OutputFolder) Image format: VHD, VHDX or CIM. Defaults to VHDX.
    For CIM the -SizeMB parameter is ignored — msixmgr determines the size.

.PARAMETER SizeMB
    (Create, OutputFolder, VHD/VHDX only) Disk size in megabytes. Defaults to 0
    (auto-calculate from uncompressed MSIX content plus 20 % overhead, min 50 MB).

.PARAMETER DiskImage
    (ExistingDisk) Path to a pre-created, empty, formatted VHD or VHDX produced
    by New-MSIXDynamicAppAttachDisk. Pre-created disks can grow dynamically.

.PARAMETER OutputFolder
    (OutputFolder) Folder where the images are written. The file name is derived
    from the MSIX base name plus the -FileType extension.

.PARAMETER AppFolderName
    Name of the root folder inside the image.
    Defaults to the MSIX file name without extension.

.EXAMPLE
    New-MSIXAppAttachImage -MsixFile "C:\Pkg\MyApp.msix" -VhdPath "C:\VHD\MyApp.vhdx"

    Creates MyApp.vhdx (fixed-size, auto-calculated) with msixmgr.

.EXAMPLE
    New-MSIXAppAttachImage -MsixFile "C:\Pkg\MyApp.msix" -VhdPath "C:\VHD\MyApp.vhd" `
        -FileType VHD -SizeMB 500

    Creates a fixed-size VHD of 500 MB.

.EXAMPLE
    New-MSIXAppAttachImage -MsixFile "C:\Pkg\MyApp.msix" -VhdPath "C:\VHD\MyApp.cim" `
        -FileType CIM

    Creates a CIM read-only image directly via msixmgr.

.EXAMPLE
    $disk = New-MSIXDynamicAppAttachDisk -Path "C:\VHD\MyApp" -SizeMB 500
    New-MSIXAppAttachImage -MsixFile "C:\Pkg\MyApp.msix" -DiskImage $disk

    Creates a dynamic VHDX first, then unpacks the MSIX into it.

.EXAMPLE
    Get-ChildItem "C:\Packages\*.msix" |
        New-MSIXAppAttachImage -OutputFolder "C:\VHD" -FileType VHDX

    Converts all MSIX packages in a folder to VHDX images in one pipeline.

.EXAMPLE
    Get-ChildItem "C:\Packages\*.msix" | ForEach-Object {
        $disk = New-MSIXDynamicAppAttachDisk -MsixFile $_ -OutputFolder "C:\VHD" -SizeMB 500
        New-MSIXAppAttachImage -MsixFile $_ -DiskImage $disk
    }

    Creates a dynamic VHDX per package (via Hyper-V) and then unpacks each
    MSIX into its disk. Use this when dynamic images are required instead of
    fixed-size images.

.NOTES
    Requires msixmgr.exe. Run Update-MSIXForcelets if it is missing.
    ExistingDisk mode requires elevation (Administrator) for Mount-DiskImage.
    msixmgr source: https://github.com/microsoft/msix-packaging
    Andreas Nick, 2024
#>

    [CmdletBinding(DefaultParameterSetName = 'Create')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, Position = 0,
            ParameterSetName = 'Create')]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, Position = 0,
            ParameterSetName = 'ExistingDisk')]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, Position = 0,
            ParameterSetName = 'OutputFolder')]
        [System.IO.FileInfo] $MsixFile,

        # --- Create ---
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'Create')]
        [string] $VhdPath,

        [Parameter(ParameterSetName = 'Create')]
        [Parameter(ParameterSetName = 'OutputFolder')]
        [ValidateSet('VHD', 'VHDX', 'CIM')]
        [string] $FileType = 'VHDX',

        [Parameter(ParameterSetName = 'Create')]
        [Parameter(ParameterSetName = 'OutputFolder')]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $SizeMB = 0,

        # --- ExistingDisk ---
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ExistingDisk')]
        [System.IO.FileInfo] $DiskImage,

        # --- OutputFolder ---
        [Parameter(Mandatory = $true, ParameterSetName = 'OutputFolder')]
        [string] $OutputFolder,

        # --- Shared ---
        [Parameter(ParameterSetName = 'Create')]
        [Parameter(ParameterSetName = 'ExistingDisk')]
        [Parameter(ParameterSetName = 'OutputFolder')]
        [string] $AppFolderName
    )

    begin {
        $msixmgrExe = $Script:MSIXMgrPath
        if ([string]::IsNullOrEmpty($msixmgrExe) -or -not (Test-Path $msixmgrExe)) {
            throw "msixmgr.exe not found. Run Update-MSIXForcelets to download MSIX Core."
        }

        if ($PSCmdlet.ParameterSetName -eq 'OutputFolder' -and -not (Test-Path $OutputFolder)) {
            New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
        }
    }

    process {
        if (-not (Test-Path $MsixFile.FullName)) {
            Write-Error "MSIX file not found: $($MsixFile.FullName)"
            return
        }

        $effectiveAppFolder = if ([string]::IsNullOrEmpty($AppFolderName)) {
            [System.IO.Path]::GetFileNameWithoutExtension($MsixFile.Name)
        } else { $AppFolderName }

        switch ($PSCmdlet.ParameterSetName) {

            'Create' {
                Invoke-MSIXCreateImage -MsixFile $MsixFile -ImagePath $VhdPath `
                    -FileType $FileType -SizeMB $SizeMB -AppFolderName $effectiveAppFolder `
                    -MsixmgrExe $msixmgrExe
            }

            'OutputFolder' {
                $imagePath = Join-Path $OutputFolder "$($MsixFile.BaseName).$($FileType.ToLower())"
                Invoke-MSIXCreateImage -MsixFile $MsixFile -ImagePath $imagePath `
                    -FileType $FileType -SizeMB $SizeMB -AppFolderName $effectiveAppFolder `
                    -MsixmgrExe $msixmgrExe
            }

            'ExistingDisk' {
                if (-not (Test-Path $DiskImage.FullName)) {
                    Write-Error "Disk image not found: $($DiskImage.FullName)"
                    return
                }

                Write-Verbose "Mounting disk image: $($DiskImage.FullName)"
                $image = $null
                try {
                    $image       = Mount-DiskImage -ImagePath $DiskImage.FullName -PassThru
                    $driveLetter = ($image | Get-Disk | Get-Partition |
                                    Where-Object { $_.DriveLetter } |
                                    Select-Object -First 1).DriveLetter

                    if ([string]::IsNullOrEmpty($driveLetter)) {
                        throw "Could not determine drive letter for mounted disk image '$($DiskImage.FullName)'."
                    }

                    Write-Verbose "Disk image mounted at $($driveLetter):"
                    Write-Verbose "App folder inside image: $effectiveAppFolder"

                    & $msixmgrExe -Unpack `
                        -packagePath $MsixFile.FullName `
                        -destination "$($driveLetter):\" `
                        -applyacls `
                        -rootDirectory $effectiveAppFolder

                    if ($LASTEXITCODE -ne 0) {
                        throw "msixmgr.exe exited with code $LASTEXITCODE"
                    }
                }
                catch {
                    Write-Error "Failed to unpack MSIX into existing disk image: $_"
                    throw
                }
                finally {
                    if ($null -ne $image) {
                        Write-Verbose "Dismounting disk image..."
                        Dismount-DiskImage -ImagePath $DiskImage.FullName | Out-Null
                    }
                }

                Write-Host "App Attach disk populated: $($DiskImage.FullName)" -ForegroundColor Green
                $DiskImage
            }
        }
    }
}

function Invoke-MSIXCreateImage {
    # Internal helper — creates a VHD, VHDX or CIM image via msixmgr.exe.
    param(
        [System.IO.FileInfo] $MsixFile,
        [string] $ImagePath,
        [string] $FileType,
        [int]    $SizeMB,
        [string] $AppFolderName,
        [string] $MsixmgrExe
    )

    $imageDir = Split-Path $ImagePath -Parent
    if (-not [string]::IsNullOrEmpty($imageDir) -and -not (Test-Path $imageDir)) {
        New-Item -Path $imageDir -ItemType Directory -Force | Out-Null
    }

    if ($FileType -eq 'CIM') {
        Write-Verbose "Creating CIM image: $ImagePath"
        try {
            & $MsixmgrExe -Unpack `
                -packagePath $MsixFile.FullName `
                -destination $ImagePath `
                -applyacls `
                -create `
                -filetype cim `
                -rootDirectory $AppFolderName

            if ($LASTEXITCODE -ne 0) { throw "msixmgr.exe exited with code $LASTEXITCODE" }
        }
        catch {
            Write-Error "Failed to create CIM image '$ImagePath': $_"
            throw
        }
        Write-Host "App Attach CIM created: $ImagePath" -ForegroundColor Green
    }
    else {
        # Auto-calculate size if not provided.
        if ($SizeMB -eq 0) {
            Write-Verbose "Calculating disk size from MSIX content..."
            $zip = [System.IO.Compression.ZipFile]::OpenRead($MsixFile.FullName)
            try {
                $uncompressedBytes = ($zip.Entries | Measure-Object -Property Length -Sum).Sum
            }
            finally { $zip.Dispose() }
            $SizeMB = [Math]::Max(50, [int][Math]::Ceiling($uncompressedBytes / 1MB * 1.2))
            Write-Verbose ("Uncompressed: {0:N1} MB  +20% overhead  -> {1} MB" -f ($uncompressedBytes / 1MB), $SizeMB)
        }

        Write-Verbose "Creating $FileType ($SizeMB MB): $ImagePath"
        try {
            & $MsixmgrExe -Unpack `
                -packagePath $MsixFile.FullName `
                -destination $ImagePath `
                -applyacls `
                -create `
                -vhdsize $SizeMB `
                -filetype $FileType.ToLower() `
                -rootDirectory $AppFolderName

            if ($LASTEXITCODE -ne 0) { throw "msixmgr.exe exited with code $LASTEXITCODE" }
        }
        catch {
            Write-Error "Failed to create $FileType image '$ImagePath': $_"
            throw
        }
        Write-Host "App Attach $FileType created: $ImagePath ($SizeMB MB)" -ForegroundColor Green
    }

    Get-Item $ImagePath
}
