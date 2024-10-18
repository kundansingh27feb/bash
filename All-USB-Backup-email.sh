#!/bin/bash
#
# Define source and destination directories
source_dir="/mnt/data/dbprod"
dest_dir="/mnt/USB-BACKUP-01"
backup_date=$(date +%Y-%m-%d)
log_file="/root/alta-scripts/Logs/Complete-NAS-To-USB-Backup-$backup_date.log"
one_day=$(date -v -1d "+%Y-%m-%d")
csvn_dir="/mnt/USB-BACKUP-01/Code_Repos/Csvn/"
git_dir="/mnt/USB-BACKUP-01/Code_Repos/Git/"
email_recipient="kundans@altametrics.com"

# Function to log messages with timestamps
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

# Function to send email with HTML table
send_email() {
    local table_content=$1
    local subject="TrueNAS Backup Status - $backup_date"
    local email_body="<html><body><h2>TrueNAS Backup Status</h2><p>Backup process completed.</p><table border='1'><tr><th>Server Name</th><th>db Type</th><th>Backup Dir Name</th><th>Backup Size</th></tr>$table_content</table></body></html>"
    
    echo "$email_body" | mail -a "Content-Type: text/html" -s "$subject" "$email_recipient"
}

# Initialize log file
echo "Backup Log" > "$log_file"
log_message "Removing contents of destination directory: $dest_dir"
rm -rf "$dest_dir"/*
mkdir -p "$csvn_dir" "$git_dir"

# Backup function
backup_data() {
    local client_name=$1
    local db_type=$2
    local server_name=$3
    local daily_backup_dir="$server_dir/DailyBackup"
    local one_day_old_backup="$daily_backup_dir/$one_day"
    local dest_backup_dir="$dest_dir/$client_name/$db_type/$server_name"

    if [ -d "$one_day_old_backup" ]; then
        log_message "Copying backup from $one_day_old_backup to $dest_backup_dir"
        cp -r "$one_day_old_backup" "$dest_backup_dir/" >> "$log_file" 2>&1
        if [ $? -eq 0 ]; then
            log_message "Backup copied successfully to $dest_backup_dir"
            log_message "Backup copy start time: $backup_copy_start_time, end time: $(date +'%Y-%m-%d %H:%M:%S')"
            local copy_dir_size=$(du -sh "$dest_backup_dir" | awk '{print $1}')
            # Format for HTML table row
            echo "<tr><td>$server_name</td><td>$db_type</td><td>$dest_backup_dir</td><td>$copy_dir_size</td></tr>"
        else
            log_message "Error occurred while copying backup to $dest_backup_dir"
        fi
    else
        log_message "One-day-old backup directory not found in $daily_backup_dir"
    fi
}

# HTML table content
html_table_content=""

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
            
            if [ -d "$daily_backup_dir" ]; then
                log_message "Backup for server: $server_name"
                dest_backup_dir="$dest_dir/$client_name/$db_type/$server_name"
                mkdir -p "$dest_backup_dir"
                backup_copy_start_time=$(date +'%Y-%m-%d %H:%M:%S')
                table_row=$(backup_data "$client_name" "$db_type" "$server_name")
                html_table_content+="$table_row"
            else
                log_message "DailyBackup directory not found in $server_dir"
            fi
        done
    done
    log_message "Backup for client $client_name completed"
done

# Additional Data Backup
log_message "Copying additional data to $csvn_dir"
cp -r "/mnt/data/dbprod/Code_Repos/Csvn/Daily_Backup/$one_day" "$csvn_dir" >> "$log_file" 2>&1
if [ $? -eq 0 ]; then
    log_message "Additional data copied successfully to $csvn_dir"
else
    log_message "Error occurred while copying additional data to $csvn_dir"
fi

log_message "Copying additional data to $git_dir"
cp -r "/mnt/data/dbprod/Code_Repos/Git/Daily_Backup/$one_day" "$git_dir" >> "$log_file" 2>&1
if [ $? -eq 0 ]; then
    log_message "Additional data copied successfully to $git_dir"
else
    log_message "Error occurred while copying additional data to $git_dir"
fi

# Generate and send email with HTML table
send_email "$html_table_content"

# Log end time for the entire backup process
log_message "Backup process completed. End time: $(date +'%Y-%m-%d %H:%M:%S')"
