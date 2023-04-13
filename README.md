# WSL Backup Script
This script allows you to create backups of your Windows Subsystem for Linux (WSL) home directory to a Windows location with custom filter options, deletion methods, and backup storage management. It uses the  [rjrssync](https://github.com/Robert-Hughes/rjrssync) utility for faster file synchronization.

**Important**: Although this script uses rjrssync, it __can not__ perform backups to a remote location. It is only meant to be used for local backups. As a workaround you can use rjrssync to sync the backup output folder to a remote location.

## Features
- Back up your WSL home directory from a specific distribution and user.
- Specify output folders and regex filters for customization.
- Manage previous backups by compressing, deleting oldest or random backups, based on settings.
- Utilizes `rjrssync` for improved performance even using `/mnt/` and to preserve symlinks properly

## Prerequisites
- Windows Subsystem for Linux (WSL) installed and configured with a desired Linux distribution.
- PowerShell 5.0 or later.
- rjrssync installed and sourced in your shell (https://github.com/Robert-Hughes/rjrssync).

## Usage
1. Copy the  `backup_wsl.ps1`  script to a desired location on your Windows machine.
2. Open PowerShell and navigate to the script location.
3. Run the script and provide the required parameters.
Examples:

# Using the script with inline parameters
```.\backup_wsl.ps1 Ubuntu user c:\backups +projects.* 1 10 deleteRandom```

 # Using the script with named parameters and values
```\backup_wsl.ps1 -DistroName Ubuntu -UserName user -OutputFolder c:\backups -RegexFilters "+projects.*" -SavePreviousBackup $true -MaxBackupCount 10 -IfBackupFull deleteOlder```

Parameters:
 -  `-DistroName` : The name of the WSL distribution you want to create a backup of.
-  `-UserName` : The user whose home directory you want to back up.
-  `-OutputFolder` : The folder where the backup will be stored.
-  `-RegexFilters` : Regular expression filters for files and folders you want to include or exclude from the backup. Each filter is a '+' or '-' character followed by a [regular expression](https://docs.rs/regex/latest/regex/#syntax). The '+'/'-' indicates if this filter includes (+) or excludes (-) matching entries. Separate multiple filters with a semicolon. If the first filter is an include (+), then only those entries matching this filter will be synced. If the first filter is an exclude (-), then entries matching this filter will *not* be synced. Further filters can then override this decision.

    The regexes are matched against a 'normalized' path relative to the root path of the source/dest:

    * Forward slashes are always used as directory separators, even on Windows platforms

    * There are never any trailing slashes

    * Matches are done against the entire normalized path - a substring match is not sufficient

    * `'+.*\.txt;-subfolder'`  Syncs all files with the extension .txt, but not inside `subfolder`
-  `-SavePreviousBackup` : Whether to save previous backups by compressing them. Set  `$true`  to save,  `$false`  to discard previous backups.
-  `-maxBackupCount` : Maximum number of compressed backups to be stored.
-  `-ifBackupFull` : What to do when the backup folder is full. Valid values are "deleteOldest", "deleteRandom", and "doNothing".
 **Note**: When using the "deleteRandom" option, the script will never delete the oldest backup.
 ## Important Notes
 - rjrssync is known to be faster when used on remote connections, but it will still be more performant than alternative tools using the usual mounting methods like `\mnt\`.
- Ensure that rjrssync is installed and sourced within your shell before running the script.