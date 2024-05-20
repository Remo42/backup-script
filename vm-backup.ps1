
# Define CmdletBinding attribute to enable advanced cmdlet features
[CmdletBinding()]

# Define script parameters
param (
    [switch]$cli # Define a switch parameter to indicate if script is running from CLI
)

# Check if Hyper-V feature is installed
$hyperVInstalled = Get-WindowsFeature -Name Hyper-V | Where-Object { $_.Installed }
if (-not $hyperVInstalled) {
    Write-Host "Hyper-V is not installed. This script requires Hyper-V to be installed to run."
    Exit # Exit script if Hyper-V is not installed
}

# Load necessary assemblies for PowerShell Forms
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

# Define network folder path for backup
$networkFolderPath = "\\192.168.10.198\f\testing"

# Define temporary folder path for backup
$tempfolder = "C:\tempbackup"


# Define backup function
function Backup {

    # Define temporary folder for backup
    $tempfolder = "C:\tempbackup"

    # Check if network folder path is accessible
    if (Test-Path $networkFolderPath) {

        # Stop all virtual machines
        Write-Host "Backup script started"
        Write-Host "Stopping all Virtual Machines"
        Get-VM | Stop-VM -Force

        # Create or clear temporary export folder and export VMs
        if (Test-Path $tempfolder) {
            Get-VM | Stop-VM -Force
            Remove-Item -Force -Recurse $tempfolder
        }
        mkdir $tempfolder
        Export-VM * $tempfolder

        # Zip exported VMs
        $archivePath = Join-Path $tempfolder "backup.zip"
        & "C:\Program Files\7-Zip\7z.exe" a -tzip $archivePath $tempfolder\*

        # Hash the zip archive
        $archiveHash = Get-FileHash -Path $archivePath -Algorithm SHA256

        # Create main backup folder if it doesn't exist
        $mainBackupFolderPath = Join-Path $networkFolderPath "MainBackup"
        if (-not (Test-Path $mainBackupFolderPath)) {
            New-Item -ItemType Directory -Path $mainBackupFolderPath | Out-Null
        }

        # Create folder with current date and time
        $dateFolderPath = Join-Path $mainBackupFolderPath (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
        if (-not (Test-Path $dateFolderPath)) {
            New-Item -ItemType Directory -Path $dateFolderPath | Out-Null
        }

        # Copy archive to folder with current date and time
        Copy-Item -Path $archivePath -Destination $dateFolderPath -Force -Verbose
        Write-Host "Archive copied to $networkFolderPath."

        # Hash the copied archive
        $copiedArchiveHash = Get-FileHash -Path (Join-Path $dateFolderPath "backup.zip") -Algorithm SHA256

        # Compare hashes
        if ($copiedArchiveHash.Hash -eq $archiveHash.Hash) {
            Write-Host "File integrity check passed for the archive."
        }
        else {
            Write-Host "File integrity check failed for the archive."
        }

        # Remove oldest backup if there are more than 5 backups
        Remove-Item -Path $archivePath -Force
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
    else {
        Write-Host "Network folder is not accessible."
    }
}

# Define restore function
function Restore {
    
    # Define network folder path for backup
    $networkFolderPath = "\\192.168.10.198\f\testing"

    # Prompt user to confirm restore action
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "This will STOP all running VMs, DELETE existing VMs, and RESTORE from a backup. Continue?",
        "Restore Confirmation",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    # If user confirms, proceed with restore
    if ($confirm -eq "Yes") {
        $mainbackup = Join-Path $networkFolderPath "MainBackup"
        $backupFolders = Get-ChildItem -Path $mainbackup -Directory -ErrorAction SilentlyContinue
        if ($backupFolders.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Network folder is not accessible or no folders found.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        } 
        Show-RestoreForm -BackupFolders $backupFolders
    }
}

# Define function to display restore form
function Show-RestoreForm {
    param ([System.IO.DirectoryInfo[]]$BackupFolders)

    # Create a new form for the restore functionality
    $RestoreForm = New-Object System.Windows.Forms.Form
    $RestoreForm.StartPosition = "CenterScreen"
    $RestoreForm.Size = "400,300"
    $RestoreForm.FormBorderStyle = 'FixedDialog'
    $RestoreForm.MaximizeBox = $false
    $RestoreForm.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 31)
    $RestoreForm.Text = "Restore from Backup"

    # Label
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(20, 10)
    $label.Size = New-Object System.Drawing.Size(300, 20)
    $label.Text = "Select a backup to restore:"
    $label.ForeColor = [System.Drawing.Color]::White
    $RestoreForm.Controls.Add($label)

    # ListBox to display available backup folders
    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(20, 40)
    $listBox.Size = New-Object System.Drawing.Size(300, 150)
    $listBox.BackColor = [System.Drawing.Color]::FromArgb(51, 51, 51)
    $listBox.ForeColor = [System.Drawing.Color]::White
    foreach ($folder in $BackupFolders) { $listBox.Items.Add($folder.Name) }
    $RestoreForm.Controls.Add($listBox)

    # OK Button
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(150, 200)
    $okButton.Size = New-Object System.Drawing.Size(75, 25)
    $okButton.Text = "OK"
    $okButton.BackColor = [System.Drawing.Color]::FromArgb(51, 51, 51)
    $okButton.ForeColor = [System.Drawing.Color]::White
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
    $cancelButton.BackColor = [System.Drawing.Color]::FromArgb(51, 51, 51)
    $cancelButton.ForeColor = [System.Drawing.Color]::White
    $cancelButton.Add_Click({ $RestoreForm.Close() })
    $RestoreForm.Controls.Add($cancelButton)

    # Function to perform restore from selected folder
    function RestoreFromFolder {
        param ([string]$folderName)
    
        $tempfolder = "C:\hyper-v"
        $selectedFolder = Join-Path $mainbackup $folderName
        $archivePath = Join-Path $selectedFolder "backup.zip"
    
        # Stop all VMs
        Get-VM | Stop-VM -Force
        Get-VM | Remove-VM -Force


        if (Test-Path $tempfolder) {Remove-Item -Force -Recurse $tempfolder}
        mkdir $tempfolder

        Copy-Item $archivePath $tempfolder
        & "C:\Program Files\7-Zip\7z.exe" x "$tempfolder\backup.zip" "-o$tempfolder" -y
    
        # Get a list of VM configuration files (*.vmcx) in the Virtual Machines subfolders of the temporary folder
        $VMFiles = Get-ChildItem -Path "$tempfolder\*\Virtual Machines" -Filter *.vmcx -Recurse
    
        # Loop through each VM configuration file and import the VM
        echo "Importing VM-s"
        foreach ($VMFile in $VMFiles) {Import-VM -Path $VMFile.FullName}
        [System.Windows.Forms.MessageBox]::Show("Restore completed successfully.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    

    # Show the restore form
    [void]$RestoreForm.ShowDialog()
}

# If running from CLI with `-cli` flag, run only the backup function
if ($cli) { Backup }
else {
    # Create main application form
    $App = New-Object System.Windows.Forms.Form
    $App.StartPosition = "CenterScreen"
    $App.Size = "270,260"
    $App.FormBorderStyle = 'Fixed3D'
    $App.MinimizeBox = $false
    $App.MaximizeBox = $false
    $App.BackColor = [System.Drawing.Color]::FromArgb(31, 31, 31)
    $App.Text = "Hyper-V Backup" # Set application title

    # Label
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(25, 25)
    $label.Font = New-Object System.Drawing.Font('verdana', 16)
    $label.AutoSize = $true
    $label.ForeColor = [System.Drawing.Color]::White
    $label.Text = "Hyper-V Backup" # Set label text
    $App.Controls.Add($label)

    # Backup Button
    $backup_button = New-Object System.Windows.Forms.Button
    $backup_button.Location = New-Object System.Drawing.Point(25, 100)
    $backup_button.Size = New-Object System.Drawing.Size(200, 25)
    $backup_button.Text = "BACKUP" # Set button text
    $backup_button.BackColor = [System.Drawing.Color]::FromArgb(51, 51, 51)
    $backup_button.ForeColor = [System.Drawing.Color]::White
    $backup_button.Add_Click({ & { Backup } }) # Define button click action
    $App.Controls.Add($backup_button)

    # Restore Button
    $restore_button = New-Object System.Windows.Forms.Button
    $restore_button.Location = New-Object System.Drawing.Point(25, 125)
    $restore_button.Size = New-Object System.Drawing.Size(200, 25)
    $restore_button.Text = "RESTORE" # Set button text
    $restore_button.BackColor = [System.Drawing.Color]::FromArgb(51, 51, 51)
    $restore_button.ForeColor = [System.Drawing.Color]::White
    $restore_button.Add_Click({ & { Restore } }) # Define button click action
    $App.Controls.Add($restore_button)

    # Browse Button
    $browse_button = New-Object System.Windows.Forms.Button
    $browse_button.Location = New-Object System.Drawing.Point(25, 150)
    $browse_button.Size = New-Object System.Drawing.Size(200, 25)
    $browse_button.Text = "BROWSE BACKUPS" # Set button text
    $browse_button.BackColor = [System.Drawing.Color]::FromArgb(51, 51, 51)
    $browse_button.ForeColor = [System.Drawing.Color]::White
    $browse_button.Add_Click({ explorer.exe $networkFolderPath }) # Define button click action
    $App.Controls.Add($browse_button)

    # Browse Button
    $browse_button2 = New-Object System.Windows.Forms.Button
    $browse_button2.Location = New-Object System.Drawing.Point(25, 175)
    $browse_button2.Size = New-Object System.Drawing.Size(200, 25)
    $browse_button2.Text = "BROWSE TEMPORARY FILES" # Set button text
    $browse_button2.BackColor = [System.Drawing.Color]::FromArgb(51, 51, 51)
    $browse_button2.ForeColor = [System.Drawing.Color]::White
    $browse_button2.Add_Click({ explorer.exe $tempfolder }) # Define button click action
    $App.Controls.Add($browse_button2)

    # Show the application form
    $App.Add_Shown({ $App.Activate() })
    [void] $App.ShowDialog()
}
