$networkFolderPath = "\\192.168.10.198\f\testing"
$vhdxFilesPath = "C:\Users\Public\Documents\Hyper-V\Virtual hard disks"
$mainBackupFolderPath = Join-Path $networkFolderPath "MainBackup"
$dateFolderPath = Join-Path $mainBackupFolderPath (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")

# Check if the network folder is accessible
if (Test-Path $networkFolderPath) {
    Write-Host "Backup script started"

    # Stop all virtual machines
    write-host "Stopping all Virtual Machines"
    Get-VM | Stop-VM -Force

    # Zip the VHDX files using 7-Zip
    $archivePath = Join-Path $vhdxFilesPath "backup.zip"
    & "C:\Program Files\7-Zip\7z.exe" a -tzip $archivePath $vhdxFilesPath\*

    # Calculate the hash of the archive
    $archiveHash = Get-FileHash -Path $archivePath -Algorithm SHA256

    # Create main backup folder in network location if it doesn't exist
    if (-not (Test-Path $mainBackupFolderPath)) {
        Write-Host "Making main backup folder"
        New-Item -ItemType Directory -Path $mainBackupFolderPath | Out-Null
        Write-Host "Main backup folder created."
    }
    else { Write-Host "Main backup folder already exists." }

    # Create a folder with the name of the date
    if (-not (Test-Path $dateFolderPath)) {
        New-Item -ItemType Directory -Path $dateFolderPath | Out-Null
        Write-Host "$dateFolderPath folder created."
    }
    else { Write-Host "$dateFolderPath folder already exists." }

    # Copy the archive to the network location inside the folder with the date
    Copy-Item -Path $archivePath -Destination $dateFolderPath -Force -Verbose
    Write-Host "Archive copied to $networkFolderPath."

    # Check the hash of the copied archive
    $copiedArchiveHash = Get-FileHash -Path (Join-Path $dateFolderPath "backup.zip") -Algorithm SHA256
    if ($copiedArchiveHash.Hash -eq $archiveHash.Hash) { Write-Host "File integrity check passed for the archive." }
    else { Write-Host "File integrity check failed for the archive." }

    # Copy the archive to the network location inside the folder with the date
    Copy-Item -Path $archivePath -Destination $dateFolderPath -Force -Verbose
    Write-Host "Archive copied to $networkFolderPath."

    # Check the hash of the copied archive
    $copiedArchiveHash = Get-FileHash -Path (Join-Path $dateFolderPath "backup.zip") -Algorithm SHA256
    if ($copiedArchiveHash.Hash -eq $archiveHash.Hash) { Write-Host "File integrity check passed for the archive." }
    else { Write-Host "File integrity check failed for the archive." }

    # Delete the archive from the host
    Remove-Item -Path $archivePath -Force
    #Write-Host "Archive deleted from the host."

    # New script block to delete the oldest folder if there are more than 5 folders
    $folders = Get-ChildItem -Path $mainBackupFolderPath -Directory
    if ($folders.Count -gt 5) {
        $oldestFolder = $folders | Sort-Object CreationTime | Select-Object -First 1
        Write-Host "Deleting the oldest folder: $($oldestFolder.Name)"
        Remove-Item -Path $oldestFolder.FullName -Recurse -Force
    }
    else {
        Write-Host "There are 5 or fewer folders in MainBackup. No action taken."
    }





}
else { Write-Host "Network folder is not accessible." }
