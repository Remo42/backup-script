[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

# Variables
$networkFolderPath = "\\192.168.10.198\f\testing"

function Backup {
    $tempfolder = "C:\tempbackup"
    $networkFolderPath = "\\192.168.10.198\f\testing"
    $mainBackupFolderPath = Join-Path $networkFolderPath "MainBackup"
    $dateFolderPath = Join-Path $mainBackupFolderPath (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")

    if (Test-Path $networkFolderPath) {
        Write-Host "Backup script started"
        write-host "Stopping all Virtual Machines"
        Get-VM | Stop-VM -Force

        if (Test-Path $tempfolder) {
            Remove-Item -Force -Recurse $tempfolder
            mkdir C:\tempbackup
            Export-VM * $tempfolder
        }
    
        $archivePath = Join-Path $tempfolder "backup.zip"
        & "C:\Program Files\7-Zip\7z.exe" a -tzip $archivePath $tempfolder\*

        $archiveHash = Get-FileHash -Path $archivePath -Algorithm SHA256

        if (-not (Test-Path $mainBackupFolderPath)) {
            Write-Host "Making main backup folder"
            New-Item -ItemType Directory -Path $mainBackupFolderPath | Out-Null
            Write-Host "Main backup folder created."
        }
        else { Write-Host "Main backup folder already exists." }
        if (-not (Test-Path $dateFolderPath)) {
            New-Item -ItemType Directory -Path $dateFolderPath | Out-Null
            Write-Host "$dateFolderPath folder created."
        }
        else { Write-Host "$dateFolderPath folder already exists." }

        Copy-Item -Path $archivePath -Destination $dateFolderPath -Force -Verbose
        Write-Host "Archive copied to $networkFolderPath."

        $copiedArchiveHash = Get-FileHash -Path (Join-Path $dateFolderPath "backup.zip") -Algorithm SHA256
        if ($copiedArchiveHash.Hash -eq $archiveHash.Hash) { Write-Host "File integrity check passed for the archive." }
        else { Write-Host "File integrity check failed for the archive." }

        Remove-Item -Path $archivePath -Force
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
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "This will STOP all running VMs, DELETE existing VMs, and RESTORE from a backup. Continue?",
        "Restore Confirmation",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($confirm -eq "Yes") {
        $mainbackup = Join-Path $networkFolderPath "MainBackup"
        $backupFolders = Get-ChildItem -Path $mainbackup -Directory -ErrorAction SilentlyContinue
        if ($backupFolders.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Network folder is not accessible or no folders found.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return  # Exit the function if no folders found
        }

        Show-RestoreForm -BackupFolders $backupFolders
    }
}

function Show-RestoreForm {
    param ([System.IO.DirectoryInfo[]]$BackupFolders)

    # Create a new form for the restore functionality
    $RestoreForm = New-Object System.Windows.Forms.Form
    $RestoreForm.StartPosition = "CenterScreen"
    $RestoreForm.Size = "400,300"
    $RestoreForm.FormBorderStyle = 'FixedDialog'
    $RestoreForm.MaximizeBox = $false
    $RestoreForm.Text = "Restore from Backup"

    # Label
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(20, 10)
    $label.Size = New-Object System.Drawing.Size(300, 20)
    $label.Text = "Select a backup to restore:"
    $RestoreForm.Controls.Add($label)

    # ListBox to display available backup folders
    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(20, 40)
    $listBox.Size = New-Object System.Drawing.Size(300, 150)
    foreach ($folder in $BackupFolders) { $listBox.Items.Add($folder.Name) }
    $RestoreForm.Controls.Add($listBox)

    # OK Button
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(150, 200)
    $okButton.Size = New-Object System.Drawing.Size(75, 25)
    $okButton.Text = "OK"
    $okButton.Add_Click({
            $selectedFolder = $listBox.SelectedItem
            if ($selectedFolder) { RestoreFromFolder -folderName $selectedFolder }
            else { [System.Windows.Forms.MessageBox]::Show("Please select a backup folder.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) }
        })
    
    $RestoreForm.Controls.Add($okButton)

    # Cancel Button
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(250, 200)
    $cancelButton.Size = New-Object System.Drawing.Size(75, 25)
    $cancelButton.Text = "Cancel"
    $cancelButton.Add_Click({ $RestoreForm.Close() })
    $RestoreForm.Controls.Add($cancelButton)

    # Function to perform restore from selected folder
# Function to perform restore from selected folder
function RestoreFromFolder {
    param ([string]$folderName)

    $tempfolder = "C:\hyper-v"
    $selectedFolder = Join-Path $mainbackup $folderName
    $archivePath = Join-Path $selectedFolder "backup.zip"

    if (Test-Path $tempfolder) {
        Remove-Item -Force -Recurse $tempfolder
        mkdir $tempfolder
    }
    else { mkdir $tempfolder }

    Copy-Item $archivePath $tempfolder
    # Stop all VMs
    Get-VM | Stop-VM -Force
    Get-VM | Remove-VM -Force
    & "C:\Program Files\7-Zip\7z.exe" x "$tempfolder\backup.zip" "-o$tempfolder" -y

    # Get a list of VM configuration files (*.vmcx) in the Virtual Machines subfolders of the temporary folder
    $VMFiles = Get-ChildItem -Path "$tempfolder\*\Virtual Machines" -Filter *.vmcx -Recurse

    # Loop through each VM configuration file and import the VM
    foreach ($VMFile in $VMFiles) {
        Import-VM -Path $VMFile.FullName
    }

    [System.Windows.Forms.MessageBox]::Show("Restore completed successfully.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

    
    # Show the restore form
    [void]$RestoreForm.ShowDialog()
}


$App = New-Object System.Windows.Forms.Form
$App.StartPosition = "CenterScreen"
$App.Size = "500,500"
$App.FormBorderStyle = 'Fixed3D'
$App.MinimizeBox = $true
$App.MaximizeBox = $false
$App.Text = "Nigeria prince toolbox"

# label
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(20, 10)
$label.Font = New-Object System.Drawing.Font('verdana', 16)
$label.AutoSize = $true
$label.ForeColor = "#000000"
$label.Text = ("Hyper-V Backup")
$App.Controls.Add($label)

# Button a
$backup_button = New-Object System.Windows.Forms.Button
$backup_button.Location = New-Object System.Drawing.Point(20, 100)
$backup_button.Size = New-Object System.Drawing.Size(100, 25)
$backup_button.Text = "BACKUP"
$backup_button.Add_Click({ & { Backup } })
$App.Controls.Add($backup_button)

# Button b
$restore_button = New-Object System.Windows.Forms.Button
$restore_button.Location = New-Object System.Drawing.Point(120, 100)
$restore_button.Size = New-Object System.Drawing.Size(100, 25)
$restore_button.Text = "RESTORE"
$restore_button.Add_Click({ & { Restore -networkFolderPath $networkFolderPath -tempfolder $tempfolder } })
$App.Controls.Add($restore_button)

# Button c
$browse_button = New-Object System.Windows.Forms.Button
$browse_button.Location = New-Object System.Drawing.Point(75, 125)
$browse_button.Size = New-Object System.Drawing.Size(100, 25)
$browse_button.Text = "Backup Location"
$browse_button.Add_Click({ explorer.exe $networkFolderPath })
$App.Controls.Add($browse_button)

$App.Add_Shown({ $App.Activate() })
[void] $App.ShowDialog()
