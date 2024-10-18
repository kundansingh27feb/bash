#!/bin/bash

# Define source and destination directories
source_dir="/mnt/data/dbprod"
dest_dir="/mnt/USB-BACKUP-01"
backup_date=`date +%Y-%m-%d`
rm -rf $dest_dir/*
# Log file path
log_file="/root/alta-scripts/Logs/Complete-NAS-To-USB-Backup-$backup_date.log"

# Function to log messages with timestamps
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

# Initialize log file
echo "Backup Log" > "$log_file"
log_message "Removing contents of destination directory: $dest_dir"
rm -rf "$dest_dir"/*
mkdir "$csvn_dir"
mkdir "$git_dir"
# Iterate through client directories
for client_dir in "$source_dir"/*/; do
    client_name=$(basename "$client_dir")
    log_message "Starting backup for client: $client_name"
    
    # Iterate through database type directories
    for db_type_dir in "$client_dir"*/; do
        db_type=$(basename "$db_type_dir")
        
        # Iterate through server directories
        for server_dir in "$db_type_dir"*/; do
            server_name=$(basename "$server_dir")
            daily_backup_dir="$server_dir/DailyBackup"
            
            # Check if DailyBackup directory exists
            if [ -d "$daily_backup_dir" ]; then
                log_message "Backup for server: $server_name"
                
                # Find one-day-old backup directory
                one_day_ago=$(date -v -1d "+%Y-%m-%d")
                one_day_old_backup="$daily_backup_dir/$one_day_ago"
                
                # Check if the backup directory exists
                if [ -d "$one_day_old_backup" ]; then
                    # Create destination directory if it doesn't exist
                    dest_backup_dir="$dest_dir/$client_name/$db_type/$server_name"
                    mkdir -p "$dest_backup_dir"
                    
                    # Log start time for backup copy
                    backup_copy_start_time=$(date +'%Y-%m-%d %H:%M:%S')
                    log_message "Copying backup from $one_day_old_backup to $dest_backup_dir"
                    
                    # Copy one-day-old backup directory to destination
                    cp -r "$one_day_old_backup" "$dest_backup_dir/" >> "$log_file" 2>&1
                    
                    # Check if copy operation was successful
                    if [ $? -eq 0 ]; then
                        # Log end time for backup copy
                        backup_copy_end_time=$(date +'%Y-%m-%d %H:%M:%S')
                        log_message "Backup copied successfully to $dest_backup_dir"
                        log_message "Backup copy start time: $backup_copy_start_time, end time: $backup_copy_end_time"
                    else
                        log_message "Error occurred while copying backup to $dest_backup_dir"
                    fi
                else
                    log_message "One-day-old backup directory not found in $daily_backup_dir"
                fi
            else
                log_message "DailyBackup directory not found in $server_dir"
            fi
        done
    done
    log_message "Backup for client $client_name completed"
done
one_day=$(date -v -1d "+%Y-%m-%d")
csvn_dir=/mnt/USB-BACKUP-01/Code_Repos/Csvn/
git_dir=/mnt/USB-BACKUP-01/Code_Repos/Git/
mkdir "$csvn_dir"
mkdir "$git_dir"
cp -r /mnt/data/dbprod/Code_Repos/Csvn/Daily_Backup/"$one_day" "$csvn_dir"
cp -r /mnt/data/dbprod/Code_Repos/Git/Daily_Backup/"$one_day" "$git_dir"
# Log end time for the entire backup process
backup_end_time=$(date +'%Y-%m-%d %H:%M:%S')
log_message "Backup process completed. End time: $backup_end_time"
