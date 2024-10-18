#!/bin/bash
# Define variables
SOURCE_DIR1="/App/JenkinsWorkspace"
SOURCE_DIR2="/app/config"
BACKUP_DIR="/mnt/Backup/Configuration_Backup/Jenkins/altamt01/DailyBackup"
LOG_DIR="/opt/script/DailyBackup/TrueNAS/BackupLog/"
DATE=$(date +%Y%m%d)
TIME=$(date +%H%M%S)
backup_date=$(date +%Y-%m-%d)
FILENAME="Backup_$DATE.tar.gz"
DEST="$BACKUP_DIR/$FILENAME"
mount_point="/mnt/Backup"
server_address="10.110.10.166"
share="/mnt/stg-str/stg-bkp"

# Ensure the log directory exists
mkdir -p "$LOG_DIR"
mkdir -p $mount_point
mkdir -p $LOG_DIR
LOG_FILE="$LOG_DIR/backup_$DATE.log"

mount -t nfs "$server_address:$share" "$mount_point"
if [ $? -eq 0 ]; then
    new_dest="$BACKUP_DIR/$backup_date"
    mkdir -p $new_dest
    cmp_dest="$new_dest/$FILENAME"

    # Start logging
    {
        echo "Backup started at $(date)"

        start_time=$(date +%s)

        # Create the compressed tar file including both source directories
        if tar -czf "$cmp_dest" -C "$SOURCE_DIR1" . -C "$SOURCE_DIR2" .; then
            echo "Backup successfully created at $cmp_dest"
            backup_status="Success"
        else
            echo "Backup failed"
            backup_status="Failed"
            exit 1
        fi

        end_time=$(date +%s)
        t_taken=$((end_time - start_time))
        dumpsize=$(du -sh "$cmp_dest" | awk '{print $1}')
        warning_count=0
        warning_messages="None"

        # Maintain only the latest 7 copies of backups
        cd "$BACKUP_DIR" || exit
        if ls -t Backup_*.tar.gz | sed -e '1,7d' | xargs -d '\n' rm -f; then
            echo "Old backups successfully deleted, keeping only the latest 7 backups."
        else
            echo "Failed to delete old backups."
        fi

        # Maintain only the latest 7 days of logs
        cd "$LOG_DIR" || exit
        if ls -t backup_*.log | sed -e '1,7d' | xargs -d '\n' rm -f; then
            echo "Old logs successfully deleted, keeping only the latest 7 days of logs."
        else
            echo "Failed to delete old logs."
        fi

        echo "Backup finished at $(date)"

        # Generate email report
        echo "From: $host Jenkins Backup <kundans@altametrics.com>
        To: DC Team<dcteam@altametrics.com>, DB Team<dba@altametrics.com>
        Subject: Backup $backup_status: $host($ipaddr) On $backup_date
        Content-Type: text/html
        </head><body>
        <table align='center' border='1'>
        <tr bgcolor=#98FB98><td><b>Backup Job</b></td>
        <td align='center'>$host</td>
        <td><b>Backup Date</b></td>
        <td align='center'>$backup_date</td>
        </tr>
        <tr bgcolor=#98FB98>
        <td><b>Status</b></td>
        <td align='center'>$backup_status</td>
        <td><b>Time</b></td>
        <td align='center'>$(date +"%T")</td>
        </tr>
        <tr align='center'><td colspan='4'><b>Details</b></td></tr>
        <tr align='center'><td><b>Directory Name</b></td><td><b>Time Taken</b></td><td><b>Backup Size</b></td><td><b>Error/Warning</b></td></tr>
        <tr align=center><td>$SOURCE_DIR1</td><td>${t_taken}s</td><td>$dumpsize</td><td>Warning Count: $warning_count, Warning: $warning_messages</td></tr>
        <tr align=center><td>$SOURCE_DIR2</td><td>${t_taken}s</td><td>$dumpsize</td><td>Warning Count: $warning_count, Warning: $warning_messages</td></tr>
        </table>
        </body>
        </html>" >"$bckreport"

        /usr/sbin/sendmail -t <"$bckreport"

    else
        echo "From: $host BackupAgent <kundans@altametrics.com>
        To: Kundan Singh <kundans@altametrics.com>
        Subject: Backup Failed: $host($ipaddr) on $backup_date To TrueNAS
        Content-Type: text/html
        </head>
        <body>
        <table width='80%' align='center' border='1'> <tr bgcolor=#ff99ff align=center>
        <td><b>Description</b></td>
        <td><b>Backup Status</b></td></tr>" >"$bckreport"
        echo "<tr color='#3333ff'> <td><b>Mounting the TrueNAS Drive failed.</b></td><td><center><span style=\"font-size: xx-larger;\">&#9888;</span> Failed</center></td></tr>" >>"$bckreport"
        echo "</table> </body> </html>" >>"$bckreport"
        /usr/sbin/sendmail -t <"$bckreport"
        echo "$(date) Mounting the TrueNAS Drive failed." >>"$logfile"
        rm -rf "$bckreport"
    fi
} >> "$LOG_FILE" 2>&1
