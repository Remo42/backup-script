[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

$ApplicationForm = New-Object System.Windows.Forms.Form
$ApplicationForm.StartPosition = "CenterScreen"
$ApplicationForm.Size = "250,200"
$ApplicationForm.FormBorderStyle = 'Fixed3D'
$ApplicationForm.MinimizeBox = $true
$ApplicationForm.MaximizeBox = $false
$ApplicationForm.Text = "Nigeria prince toolbox"
$ApplicationForm.Topmost = $true

# Variables
$networkFolderPath = "\\192.168.10.198\f\testing"
$vhdxFilesPath = "C:\Users\Public\Documents\Hyper-V\Virtual hard disks"
$mainBackupFolderPath = Join-Path $networkFolderPath "MainBackup"

# label
$Tab1_label1 = New-Object System.Windows.Forms.Label
$Tab1_label1.Location = New-Object System.Drawing.Point(20, 50)
$Tab1_label1.Font = New-Object System.Drawing.Font('verdana', 16)
$Tab1_label1.AutoSize = $true
$Tab1_label1.ForeColor = "#000000"
$Tab1_label1.Text = ("Hyper-V Backup")
$ApplicationForm.Controls.Add($Tab1_label1)

# Button a
$Tab1_appbutton1 = New-Object System.Windows.Forms.Button
$Tab1_appbutton1.Location = New-Object System.Drawing.Point(20, 100)
$Tab1_appbutton1.Size = New-Object System.Drawing.Size(100, 25)
$Tab1_appbutton1.Text = "BACKUP"
$Tab1_appbutton1.Add_Click({ Backup })
$ApplicationForm.Controls.Add($Tab1_appbutton1)

# Button b
$Tab1_appbutton2 = New-Object System.Windows.Forms.Button
$Tab1_appbutton2.Location = New-Object System.Drawing.Point(120, 100)
$Tab1_appbutton2.Size = New-Object System.Drawing.Size(100, 25)
$Tab1_appbutton2.Text = "RESTORE"
$Tab1_appbutton2.Add_Click({ Restore })
$ApplicationForm.Controls.Add($Tab1_appbutton2)

# Button c
$Tab1_appbutton3 = New-Object System.Windows.Forms.Button
$Tab1_appbutton3.Location = New-Object System.Drawing.Point(75, 125)
$Tab1_appbutton3.Size = New-Object System.Drawing.Size(100, 25)
$Tab1_appbutton3.Text = "Backup Location"
$Tab1_appbutton3.Add_Click({ explorer.exe $networkFolderPath })
$ApplicationForm.Controls.Add($Tab1_appbutton3)

$ApplicationForm.Add_Shown({ $ApplicationForm.Activate() })
[void] $ApplicationForm.ShowDialog()

function Backup {
    $networkFolderPath = "\\192.168.10.198\f\testing"
    $mainBackupFolderPath = Join-Path $networkFolderPath "MainBackup"
    $mainBackupFolderPath = Join-Path $networkFolderPath "MainBackup"
    $dateFolderPath = Join-Path $mainBackupFolderPath (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
    
    # Check if the network folder is accessible
    if (Test-Path $networkFolderPath) {
        Write-Host "Backup script started"

        # Stop all virtual machines
        write-host "Stopping all Virtual Machines"
        Get-VM | Stop-VM -Force

        # Export the virtual machines to a temporary location
        $tempExportPath = Join-Path $networkFolderPath "TempExports"
        if (-not (Test-Path $tempExportPath)) {
            New-Item -ItemType Directory -Path $tempExportPath | Out-Null
        }
        Get-VM | Export-VM -Path $tempExportPath -Force

        # Zip the exported VM files using 7-Zip
        $archivePath = Join-Path $tempExportPath "backup.zip"
        & "C:\Program Files\7-Zip\7z.exe" a -tzip $archivePath $tempExportPath\*

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

        # Delete the archive from the host
        Remove-Item -Path $archivePath -Force

        # New script block to delete the oldest folder if there are more than 5 folders
        $folders = Get-ChildItem -Path $mainBackupFolderPath -Directory
        if ($folders.Count -gt 5) {
            $oldestFolder = $folders | Sort-Object CreationTime | Select-Object -First 1
            Write-Host "Deleting the oldest folder: $($oldestFolder.Name)"
            Remove-Item -Path $oldestFolder.FullName -Recurse -Force
        }
        else { Write-Host "There are 5 or fewer folders in MainBackup. No action taken." }
    }
    else { Write-Host "Network folder is not accessible." }
}


function Restore {
    $networkFolderPath = "\\192.168.10.198\f\testing"
    $vhdxFilesPath = "C:\Users\Public\Documents\Hyper-V\Virtual hard disks"
    $mainBackupFolderPath = Join-Path $networkFolderPath "MainBackup"
    $latestDateFolder = Get-ChildItem -Path $mainBackupFolderPath -Directory | Sort-Object CreationTime -Descending | Select-Object -First 1
    $latestDate = $latestDateFolder.Name
    $restoreFolderPath = Join-Path $mainBackupFolderPath $latestDate
    $backupFile = Join-Path $restoreFolderPath "backup.zip"

    # Check if the network folder is accessible
    if (Test-Path $networkFolderPath) {
        Write-Host "Restore script started"

        # Stop all virtual machines
        write-host "Stopping all Virtual Machines"
        Get-VM | Stop-VM -Force

        # Extract the backup files using 7-Zip
        $tempExtractionPath = Join-Path $vhdxFilesPath "tempExtraction"
        if (-not (Test-Path $tempExtractionPath)) {
            New-Item -ItemType Directory -Path $tempExtractionPath | Out-Null
        }
        & "C:\Program Files\7-Zip\7z.exe" x -o$tempExtractionPath $backupFile

        # Copy the extracted VHDX files back to the original location
        Get-ChildItem -Path $tempExtractionPath -Filter "*.vhdx" | ForEach-Object {
            $destinationPath = Join-Path $vhdxFilesPath $_.Name
            Copy-Item -Path $_.FullName -Destination $destinationPath -Force
        }

        # Delete the temporary extraction folder
        Remove-Item -Path $tempExtractionPath -Recurse -Force

        # Start all virtual machines
        write-host "Starting all Virtual Machines"
        Get-VM | Start-VM

        Write-Host "Restore completed successfully."
    }
    else { Write-Host "Network folder is not accessible." }
}
