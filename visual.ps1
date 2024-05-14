#1. Variables
$sourceFolder = "C:\Users\Public\Documents\Hyper-V"
$vhdxFiles = Get-ChildItem -Path $sourceFolder -Filter "*.vhdx" -File
$networkPath = "Z:\Backup\"
$folders = Get-ChildItem -Path $directory -Directory
$mainBackupFolder = "Z:\Backup"
$directory = "C:\Users\Public\Documents\Hyper-V"
$dateFolderName = Get-Date -Format "yyyy-MM-dd"
$dateFolderPath = Join-Path -Path $mainBackupFolder -ChildPath $dateFolderName
$backupFolder = "Z:\Backup\"
$backupFolder = Get-ChildItem -Path $backupFolder -Directory
$currentDate = Get-Date -Format "yyyy-MM-dd"
$mainBackupFolder = "Z:\Backup\$currentDate"
$backupPath = "Z:\Backup"

if ($vhdxFiles.Count -gt 0) {
    foreach ($file in $vhdxFiles) {
        try {
            $destinationPath = Join-Path -Path $networkPath -ChildPath $file.Name
            Copy-Item -Path $file.FullName -Destination $destinationPath -Force -ErrorAction Stop
            Write-Host "Copied $($file.Name) to $destinationPath"
        }
        catch { Write-Host "Failed to copy $($file.Name) to $destinationPath. Error: $_" }
    }
    Write-Host "All VHDX files copied successfully to $networkPath"
}
else { Write-Host "No VHDX files found in $sourceFolder" }

# date making variable
#$kuupaev = Get-Date -Format "MM/dd/yyyy-HH:mm"

#2. Stop all VMs
Get-VM | Stop-VM -Force
Write-Output "Stopping all Virtual Machines"
$vms = Get-VM
foreach ($vm in $vms) {
    Stop-VM -VM $vm
}
Write-Host "All virtual machines stopped successfully."

#3. Hash all folders with md5sum
$hashes = @()
foreach ($folder in $folders) {
    $hash = Get-FileHash -Path $folder.FullName -Algorithm MD5
    Write-Host "Folder: $($folder.Name), MD5 Hash: $($hash.Hash)"
}
    
#4. store hashes in array

if (-not (Test-Path $networkPath)) {
    Write-Host "Network path does not exist."
    Exit}
foreach ($file in Get-ChildItem -Path "C:\hyperv" -File) {
    $destinationPath = Join-Path $networkPath $file.Name
    Copy-Item -Path $file.FullName -Destination $destinationPath -Force
    Write-Host "Copied $($file.Name) to $($destinationPath)"}

#5. make main backup folder if not exist

if (-not (Test-Path -Path $mainBackupFolder -PathType Container)) {
    New-Item -Path $mainBackupFolder -ItemType Directory -Force
}
foreach ($folder in $folders) {
    $hash = Get-FileHash -Path $folder.FullName -Algorithm MD5
    $hashes += @{
        FolderName = $folder.Name
        MD5Hash    = $hash.Hash}}

#6. make folder by the name of the date inside the main backup folder
$dateFolder = Join-Path -Path $networkPath -ChildPath (Get-Date -Format "yyyy-MM-dd")
New-Item -ItemType Directory -Path $dateFolder -Force

foreach ($file in Get-ChildItem -Path "C:\hyperv" -File) {
    $destinationPath = Join-Path -Path $dateFolder -ChildPath $file.Name
    Copy-Item -Path $file.FullName -Destination $destinationPath -Force
    Write-Host "Copied $($file.Name) to $($destinationPath)"
}

#7. copy all vm disks in that dated folder

if (-not (Test-Path -Path $dateFolderPath)) {
    New-Item -Path $dateFolderPath -ItemType Directory -Force
}
    
$vmDisks = Get-ChildItem -Path "C:\hyperv" -Filter "*.vhdx" -File
foreach ($disk in $vmDisks) {
    $destinationPath = Join-Path -Path $dateFolderPath -ChildPath $disk.Name
    Copy-Item -Path $disk.FullName -Destination $destinationPath -Force
}
#8. Check hash of all folders from hash array from before
foreach ($folderPath in $hashArray.Keys) {
    if (Test-Path $folderPath -PathType Container) {
        $folderHash = Get-ChildItem -Path $folderPath -Recurse -File | Get-FileHash -Algorithm MD5 | ForEach-Object { $_.Hash }         
        if ($hashArray[$folderPath] -eq $folderHash) { Write-Host "Hash match for folder: $folderPath" } 
        else { Write-Host "Hash mismatch for folder: $folderPath" }
    }
    else { Write-Host "Folder not found: $folderPath" }
}
#9. give user popup SUCCESS!!!!!! or CRITICAL FAILIURE, YOUR SYSTEM IS CORRUPDED AND WILL BE DELETED ON NEXT BOOT
Add-Type -AssemblyName System.Windows.Forms
foreach ($folder in $backupFolders) {
    $storedHash = $hashes | Where-Object { $_.FolderName -eq $folder.Name } | Select-Object -ExpandProperty MD5Hash
    $currentHash = Get-FileHash -Path $folder.FullName -Algorithm MD5 | Select-Object -ExpandProperty Hash
}
if ($currentHash -eq $storedHash) {Write-Host "Hash matches for $($folder.Name)"}
else {Write-Host "Hash does not match for $($folder.Name)"}

# Get all VHDX files in the source folder

if ($vhdxFiles.Count -gt 0) {
       
    foreach ($file in $vhdxFiles) {
        $destinationPath = Join-Path $networkPath $file.Name
        try { Write-Host "Copied $($file.Name) to $destinationPath" }
        catch { Write-Host "Failed to copy $($file.Name) to $destinationPath. Error: $_" }
    }
    Write-Host "All VHDX files copied successfully to $networkPath"
}
else { Write-Host "No VHDX files found in $sourceFolder" }
   

if (-not (Test-Path -Path $mainBackupFolder -PathType Container)) {
    # Create the new backup folder if it doesn't exist
    New-Item -Path $mainBackupFolder -ItemType Directory
}
Copy-Item -Recurse -Path "C:\Users\Public\Documents\Hyper-V" -Destination $mainBackupFolder -Force

#Restore
# Step 1: Get the latest backup folder from Z:\Backup
# Step 1: Get the newest backup folder
$newestBackupFolder = Get-ChildItem -Path "Z:\Backup" -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($null -eq $newestBackupFolder) {
    Write-Host "No backup folders found."
    Exit
}

# Step 2: Get the VHDX files from the newest backup folder
$vhdxFiles = Get-ChildItem -Path $newestBackupFolder.FullName -Recurse -Filter "*.vhdx" -File

if ($vhdxFiles.Count -gt 0) {
    # Step 3: Copy VHDX files to the destination
    $destinationPath = "C:\xd"
    foreach ($file in $vhdxFiles) {
        $destinationFile = Join-Path -Path $destinationPath -ChildPath $file.Name
        try {
            Copy-Item -Path $file.FullName -Destination $destinationFile -Force -ErrorAction Stop
            Write-Host "Copied $($file.Name) to $destinationFile"
        }
        catch { Write-Host "Failed to copy $($file.Name) to $destinationFile. Error: $_" }
    }
    Write-Host "All VHDX files copied successfully to $destinationPath"
}
else { Write-Host "No VHDX files found in $($newestBackupFolder.FullName)" }

#if (more than 6 folder) {
#then
#delete oldest folder 
#}



# Define paths and settings
$backupFolders = Get-ChildItem -Path $backupPath -Directory | Sort-Object CreationTime
$oldBackupFolders = $backupFolders | Select-Object -First ($backupFolders.Count - 5)

# Delete old backup folders if there are more than 5
if ($backupFolders.Count -gt 5) {
    $oldBackupFolders | ForEach-Object {
        Remove-Item -Path $_.FullName -Recurse -Force
        Write-Host "Deleted old backup folder: $($_.FullName)"
    }
}
Write-Host "finished" >> c:\log.log