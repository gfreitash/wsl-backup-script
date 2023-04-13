param (
    [Parameter(Mandatory = $true)]
    [string]$DistroName,
    [Parameter(Mandatory = $true)]
    [string]$UserName,
    [Parameter(Mandatory = $true)]
    [string]$OutputFolder,
    [string]$RegexFilters,
    [bool]$SavePreviousBackup = $false,
    [Int16] $MaxBackupCount = 7,
    [string] $IfBackupFull = "deleteOldest"
)
#.\backup_wsl.ps1 Manjaro gfreitash c:\backups +projects.* 1 10 deleteRandom
#.\backup_wsl.ps1 -DistroName Manjaro -UserName gfreitash -OutputFolder c:\backups -RegexFilters "+projects.*" -SavePreviousBackup $true -MaxBackupCount -IfBackupFull deleteOlder

$ifBackupFullBehaviors = @(
    "deleteOldest" # Delete the oldest backup
    "deleteRandom" # Delete a random backup that is not the oldest nor the newest
    "doNothing" # Do nothing
)

if ($ifBackupFull -notin $ifBackupFullBehaviors) {
    Write-Host -ForegroundColor Red -Message "Invalid value for ifBackupFull parameter. Valid values are: $($ifBackupFullBehaviors -join ', ')"
    exit 0
}

# Set UTF-8 encoding to enable special characters in file names
# Also, this fixes an encoding issue with the output of the wsl.exe command
$env:WSL_UTF8 = 1

 # Set the PowerShell execution policy to unrestricted
$VerbosePreference = 'Continue'
$line = "-" * $host.UI.RawUI.WindowSize.Width
Write-Host -ForegroundColor Yellow -Message $line

 # Get the current date and time for the backup file name
$DateTime = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
Write-Host -ForegroundColor Yellow -Message "Starting backup at $dateTime"
Write-Host -ForegroundColor Yellow -Message "Distro name: $distroName"
Write-Host -ForegroundColor Yellow -Message "User name: $userName"
Write-Host -ForegroundColor Yellow -Message "Output folder: $outputFolder"
Write-Host -ForegroundColor Yellow -Message "Regex filters: $RegexFilters"
Write-Host -ForegroundColor Yellow -Message "Save previous backup: $savePreviousBackup"
Write-Host -ForegroundColor Yellow -Message $line

 # Check if the WSL distro is running and start it if it's not
$DistroStatus = wsl.exe --list --running | Select-String -Pattern $DistroName -Quiet
if (!$DistroStatus) {
    Write-Host -ForegroundColor Cyan -Message "Starting WSL distro '$distroName'..."
    wsl.exe --distribution $DistroName --exec bash -c "echo 'Distro started'"
    Write-Host -ForegroundColor Green -Message "WSL distro '$distroName' started!`n"
} else {
    Write-Host -ForegroundColor Green -Message "WSL distro '$distroName' is already running!`n"
}

 # Set the output path and file name
$Outputs = Join-Path -Path "$OutputFolder/$DistroName/home" -ChildPath $UserName
$ZipFileName = "bkp_$DistroName-home-$UserName`_$DateTime.zip"

 # Compress previous backups if requested
$CompressedBackupFolder = Join-Path -Path $OutputFolder -ChildPath "previous-backups"
if ($SavePreviousBackup -and (Test-Path $Outputs) -and (Get-ChildItem -Path $Outputs | Measure-Object).Count -gt 0) {
    $FilesToCompress = Get-ChildItem -Path $Outputs -Exclude "bkp_*.zip"
    
    # If there are files to compress
    if ($FilesToCompress.Count -gt 0) {
        #Check if the backup folder is full
        $isBackupFull = (Get-ChildItem -Path $CompressedBackupFolder -Filter "bkp_*.zip" | Measure-Object).Count -ge $maxBackupCount

        # If the backup folder is full, delete the oldest or a random backup(s) or do nothing
        if ($isBackupFull) {
            Write-Host -ForegroundColor Yellow -Message "Compressed previous backups folder is full!"
            $files = Get-ChildItem -Path $CompressedBackupFolder -Filter "bkp_*.zip" | Sort-Object -Property LastWriteTime -Descending
            Write-Host -ForegroundColor Yellow -Message "Max backup count: $maxBackupCount"

            switch ($ifBackupFull) {
                "deleteOldest" {
                    Write-Host -ForegroundColor Cyan -Message "Deleting oldest $(($files | Measure-Object).Count - $maxBackupCount + 1) backup(s)..."
                    
                    # Delete the oldest backup(s) until the backup folder is not full anymore
                    while (($files | Measure-Object).Count -ge $maxBackupCount) {
                        $oldestBackup = $files | Select-Object -Last 1
                        Write-Host -ForegroundColor Cyan -Message "Deleting oldest backup '$($oldestBackup.FullName)'..."
                        Remove-Item -Path $oldestBackup.FullName -Force

                        if ($?) {
                            Write-Host -ForegroundColor Green -Message "Oldest backup deleted successfully!"
                            $isBackupFull = $false
                            $files = Get-ChildItem -Path $CompressedBackupFolder -Filter "bkp_*.zip" | Sort-Object -Property LastWriteTime -Descending
                        } else {
                            Write-Host -ForegroundColor Red -Message "Oldest backup deletion failed!"
                            $files = Get-ChildItem -Path $CompressedBackupFolder -Filter "bkp_*.zip" | Sort-Object -Property LastWriteTime -Descending | Select-Object -Skip 1
                        }

                        Write-Host -ForegroundColor Cyan -Message "Deletions remaining: $(($files | Measure-Object).Count - $maxBackupCount + 1)`n"
                    }
                }

                "deleteRandom" {
                    Write-Host -ForegroundColor Cyan -Message "Deleting $(($files | Measure-Object).Count - $maxBackupCount + 1) random backup(s)..."

                    while (($files | Measure-Object).Count -ge $maxBackupCount) {
                        $randomBackup = $files | Select-Object -Skip 1 | Get-Random

                        Write-Host -ForegroundColor Yellow -Message "Deleting random backup '$($randomBackup.FullName)'..."
                        Remove-Item -Path $randomBackup.FullName -Force
                        if ($?) {
                            Write-Host -ForegroundColor Green -Message "Random backup deleted successfully!"
                            $isBackupFull = $false
                            $files = Get-ChildItem -Path $CompressedBackupFolder -Filter "bkp_*.zip" | Sort-Object -Property LastWriteTime -Descending
                        } else {
                            Write-Host -ForegroundColor Red -Message "Random backup deletion failed!"
                            $files = Get-ChildItem -Path $CompressedBackupFolder -Filter "bkp_*.zip" | Sort-Object -Property LastWriteTime -Descending | Select-Object -Skip 1
                        }

                        Write-Host -ForegroundColor Cyan -Message "Deletions remaining: $(($files | Measure-Object).Count - $maxBackupCount + 1)"
                    }
                }

                "doNothing" {
                    Write-Host -ForegroundColor Yellow -Message "Nothing to do..."
                }
            }
        }
        
        if (!$isBackupFull) {
            Write-Host -ForegroundColor Cyan -Message "Compressing previous backups to '$compressedBackupFolder/$zipFileName'..."
            if (!(Test-Path $CompressedBackupFolder)) {
                New-Item -ItemType Directory -Path $CompressedBackupFolder | Out-Null
            }
            $FilesToCompress | Compress-Archive -DestinationPath "$CompressedBackupFolder/$ZipFileName" -Force
            if ($?) {
                Write-Host -ForegroundColor Green -Message "Previous backup compressed successfully!`n"
            } else {
                Write-Host -ForegroundColor Red -Message "Previous backup compression failed!`n"
            }
        }

    } else {
        Write-Host -ForegroundColor Yellow -Message "No previous backups found!`n"
    }
} else {
    Write-Host -ForegroundColor Cyan -Message "Backup folder is empty or previous backups will not be saved!`n"
}
 # Replace backslashes and colons in output paths
$Outputs = $Outputs -replace "\\", "/" -replace ":", ""
# Sync the home folder to the output folder using rjrssync with regex filters
if ($RegexFilters) {
    $FilterArgs = $RegexFilters.Split(";") | ForEach-Object {
        $Filter = $_
        $FilterType = $Filter.Substring(0, 1)
        $FilterRegex = $Filter.Substring(1, $Filter.Length - 1)
        if ($FilterType -eq "+") {
            "--filter '+$FilterRegex'"
        } elseif ($FilterType -eq "-") {
            "--filter '-$FilterRegex'"
        } else {
            ""
        }
    } | Where-Object { $_ -ne "" } | ForEach-Object { "$_" }
    $FilterArgs = "$($FilterArgs -join " ")"
    Write-Host -ForegroundColor Cyan -Message "Syncing home folder to '$Outputs' with filters '$($RegexFilters -join ';')'..."
    wsl.exe -d $DistroName -e zsh -c "source /home/$UserName/.zshrc; rjrssync /home/$UserName/ /mnt/$Outputs/ $FilterArgs"
} else {
    Write-Host -ForegroundColor Cyan -Message "Syncing home folder to '$Outputs'..."
    wsl.exe -d $DistroName -e zsh -c "source /home/$UserName/.zshrc; rjrssync /home/$UserName/ /mnt/$Outputs/ --filter '-.*\.gnupg'"
}
 if ($?) {
    Write-Host -ForegroundColor Green -Message "Backup completed successfully!"
} else {
    Write-Host -ForegroundColor Red -Message "Backup failed!"
}
