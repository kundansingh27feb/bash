#!/bin/bash
mount_point="/var/opt/gitlab/backups/"
backup_date=`date +%Y-%m-%d`
last_backup_date=$(date --date="yesterday" "+%Y-%m-%d")
type="Git"
server_address="10.110.10.97"
share="/mnt/data/dbprod/Code_Repos/Git/"
mkdir -p $mount_point
bckreport="/opt/script/DailyBackup/TrueNAS/report.txt"
jsonreport="/opt/script/DailyBackup/TrueNAS/report.json"
day_of_week=$(date +%w)
logfile="/opt/script/DailyBackup/TrueNAS/Logs/GitLab_Backup_$backup_date.log"
host=`hostname|cut -f1 -d "."`
ipaddr=`hostname -I | awk '{print $1}'`
# Git Variables
PKGNAME=gitlab
PKGVER=`dpkg -l | grep -i gitlab | awk '{print $3}'`
GITLABCONFDIR=/etc/gitlab
GITLABBACKUPS=/var/opt/gitlab/backups
BACKUPDATE=`date '+%F'`
target_directory="$GITLABBACKUPS/DailyBackup/$backup_date"
mkdir -p /opt/script/DailyBackup/TrueNAS/Logs/
start_time=$(date +%s)
ss_time=$(date +"%T")
######################################################
echo "Starting Git Backup" > $logfile
umount $mount_point  >> $logfile
mount -t nfs $server_address:$share $mount_point
if [ $? -eq 0 ]; then
        echo "From: $host BackupAgent <produtilalerts@ersaltametrics.com>
To: DC Team<dcteam@altametrics.com>
Subject: Backup Success: $host($ipaddr) On $backup_date
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
<td align='center'>Success</td>
<td><b>Time</b></td>
<td align='center'>$(date +"%T")</td>
</tr>
<tr align='center'><td colspan='4'><b>Details</b></td></tr>
<tr align='center'><td><b>Gitlab Backup</b></td><td><b>Time Taken</b></td><td><b>Backup Size</b></td><td><b>Error/Warning</b></td></tr>" > $bckreport
        rm -rf "$jsonreport"
        echo "[" >> "$jsonreport"
        echo "$(date) TrueNAS share mounted successfully at $mount_point." >> $logfile
        # Cleanup old backups and wait a minute
        find $GITLABBACKUPS/ -type f -ctime +7 -exec rm -f {} \;
        a_start_time=$(date +%s)
        a_ss_time=$(date +"%T")
        sudo -u git -H gitlab-backup create
        #tar cvjpf $GITLABBACKUPS/$PKGNAME-$PKGVER-data-$BACKUPDATE.tar.bz2 $GITLABBACKUPS/*.tar
        mv $GITLABBACKUPS/*.tar $GITLABBACKUPS/$PKGNAME-$PKGVER-data-$BACKUPDATE.tar
        a_end_time=$(date +%s)
        a_ee_time=$(date +"%T")
        atime=`echo $((a_end_time-a_start_time)) | awk '{printf "%d:%02d:%02d", $1/3600, ($1/60)%60, $1%60}'`
        b_start_time=$(date +%s)
        b_ss_time=$(date +"%T")
        tar cvjpf $GITLABBACKUPS/$PKGNAME-$PKGVER-config-$BACKUPDATE.tar.bz2 $GITLABCONFDIR
        b_end_time=$(date +%s)
        b_ee_time=$(date +"%T")
        btime=`echo $((b_end_time-b_start_time)) | awk '{printf "%d:%02d:%02d", $1/3600, ($1/60)%60, $1%60}'`
        mkdir -p $GITLABBACKUPS/DailyBackup/$backup_date/
        mv $GITLABBACKUPS/$PKGNAME-$PKGVER-config-$BACKUPDATE.tar.bz2 $GITLABBACKUPS/DailyBackup/$backup_date/
        mv $GITLABBACKUPS/$PKGNAME-$PKGVER-data-$BACKUPDATE.tar $GITLABBACKUPS/DailyBackup/$backup_date/
        for file_path in $(ls -ltr --block-size=M $target_directory/* | awk -F" " '{print $9}');
        do

                file_name=$(basename "$file_path")
                #file_name_without_date="${file_name%%.*}"
                file_size=$(du -sh $file_path | awk -F" " '{print $1}')
                file_size_json=$(du -b $file_path | awk -F" " '{print $1}')
                ttime_var=0
                if [[ $file_name == *"data"* ]]; then
                        stime_var=$a_start_time
                        etime_var=$a_end_time
                        ttime_var=$atime
                        ss_time_var=$a_ss_time
                        ee_time_var=$a_ee_time
                fi
                if [[ $file_name == *"config"* ]]; then
                        stime_var=$b_start_time
                        etime_var=$b_end_time
                        ttime_var=$btime
                        ss_time_var=$b_ss_time
                        ee_time_var=$b_ee_time
                fi
                echo "<tr align=center><td>$file_name</td><td>$ttime_var</td><td>$file_size</td><td>NA</td></tr>" >>"$bckreport"
                echo "{
  \"Local_DB_Name\": \"$host-$ipaddr\",
  \"Local_Backup_Start_Time\": \"$ss_time_var\",
  \"Local_Backup_Schema_Name\": \"$file_name\",
  \"Local_Backup_Schema_Size\": \"$file_size_json\",
  \"Local_Backup_End_Time\": \"$ee_time_var\",
  \"Local_Backup_Date\": \"$backup_date\",
  \"Local_Backup_Time_Taken\": \"$ttime_var\"
}," >> $jsonreport
        done

        directories_to_delete=$(find $GITLABBACKUPS/DailyBackup/ -type d -mtime +6 -exec basename {} \;)
        if [ -z "$directories_to_delete" ]; then
                deleted_back_size="NA"
                deleted_dirs="NA (Fewer Than 7 Copies Are Available)"
        else
                echo "$(date) Deleting 7+ day Old backup from DailyBackup Directory"  >> $logfile
                deleted_back_size=`du -sh $GITLABBACKUPS/DailyBackup/$directories_to_delete | awk -F" " '{print $1}'`
                deleted_dirs=$directories_to_delete
                rm -rf $GITLABBACKUPS/DailyBackup/$directories_to_delete
        fi

        end_time=$(date +%s)
        directory_count=$(find "$GITLABBACKUPS/DailyBackup/" -mindepth 1 -type d | wc -l)
        totalSize=$(du -sh $target_directory | awk -F" " '{print $1}')
        totalSize_json=$(du -b $target_directory | awk -F" " '{print $1}')
        totalTime=`echo $((end_time-start_time)) | awk '{printf "%d:%02d:%02d", $1/3600, ($1/60)%60, $1%60}'`

        echo "$(date) Done backup of databases " >>"$logfile"
        echo "<tr><td><b> Backup Total </b></td> <td align=center> <b> $totalTime </b></td><td align=center><b> $totalSize </b></td><td align=center><b> NA </b></td></tr>" >>"$bckreport"
        ee_time=$(date +"%T")

        echo "{
  \"Local_DB_Name\": \"$host-$ipaddr\",
  \"Local_DB_BackupStatus\": \"1\",
  \"Local_DB_start_time\": \"$ss_time\",
  \"Local_DB_End_Time\": \"$ee_time\",
  \"Local_DB_Backup_Date\": \"$backup_date\",
  \"Local_DB_Total_Size\": \"$totalSize_json\",
  \"Local_DB_TotalTimeTaken\": \"$totalTime\"
}," >> "$jsonreport"

        rm -rf $GITLABBACKUPS/db
        rm -rf $GITLABBACKUPS/repositories
        rm -rf $GITLABBACKUPS/*.tar
        ############################################# If Friday Then The below Code will execute ######################################################
        if [ "$day_of_week" -eq 5 ]; then
                if [ -n "$target_directory" ]; then
                        echo "$(date) Today is Friday. Taking weekly backup $target_directory as well to Remote..."  >> $logfile
                        if [ -d "$GITLABBACKUPS/DailyBackup/$last_backup_date" ]; then
                                last_day_size=$(du -sh "$GITLABBACKUPS/DailyBackup/$last_backup_date" | awk -F" " '{print $1}')
                                last_day_size_bytes=$(du -b "$GITLABBACKUPS/DailyBackup/$last_backup_date" | awk -F" " '{print $1}')
                        else
                                last_day_size="0K"
                                last_day_size_bytes=0
                        fi
                        weekly="$GITLABBACKUPS/WeeklyBackup/"
                        mkdir -p $weekly
                        cloud="$GITLABBACKUPS/CloudBackup"
                        mkdir -p $cloud
                        mv $cloud/* $weekly &>> $logfile
                        cp -r  $target_directory $cloud
                        cloud_file=$backup_date
                        cloud_size=$(du -sh $cloud/$backup_date | awk -F" " '{print $1}')
                        echo "cloud backup copied to NAS Drive"  >> $logfile
                        week_to_delete=$(find $weekly -type d -ctime +27 -exec basename {} \;)
                        if [ -z "$week_to_delete" ]; then
                                deleted_week_size="NA"
                                deleted_week_dirs="NA (Fewer Than 4 Copies Are Available)"
                                find $GITLABBACKUPS/WeeklyBackup/ -type d -mtime +28 -exec rm -rf {} \;
                        else
                                echo "$(date) Deleting 27+ day Old backup from CloudBackup Directory"  >> $logfile
                                deleted_week_size=`du -sh $weekly$week_to_delete | awk -F" " '{print $1}'`
                                deleted_week_dirs=$week_to_delete
                                rm -rf $weekly$week_to_delete
                                find $GITLABBACKUPS/WeeklyBackup/ -type d -mtime +28 -exec rm -rf {} \;
                        fi

                        directory_week_count=$(find "$weekly" -mindepth 1 -type d | wc -l)
                        directory_daily_count=$(find "$GITLABBACKUPS/DailyBackup/" -mindepth 1 -type d | wc -l)
                        remote_week_size=$(du -sh "$weekly" | awk -F" " '{print $1}')
                        remote_daily_size=$(du -sh "$target_directory" | awk -F" " '{print $1}')

                        #growth=$((totalSize_json - last_day_size_bytes))
                        growth=$(awk "BEGIN {printf \"%.2f\",$totalSize_json-$last_day_size_bytes}" | numfmt --to=iec)
                        disk_usage=$(df -h "$mount_point")
                        total_disk_size=$(echo "$disk_usage" | awk 'NR==2 {print $2}')
                        available_size=$(echo "$disk_usage" | awk 'NR==2 {print $4}')

                        echo "<tr align=center><td colspan='4'><b>Retention Policy</b></td></tr>" >>"$bckreport"
                        echo "<tr><td><b>Weekly Cloud Backup Upload</b></td> <td align=center>$cloud_file</td><td><b>Weekly Cloud Backup Size</b></td> <td align=center>$cloud_size</td></tr>" >>"$bckreport"
                        echo "<tr><td><b>Remote Count(Daily)</b></td> <td align=center>$directory_daily_count</td><td><b>Remote Backup Size(Daily)</b></td> <td align=center>$remote_daily_size</td></tr>" >>"$bckreport"
                        echo "<tr><td><b>Remote Count(Weekly)</b></td> <td align=center>$directory_week_count</td><td><b>Remote Backup Size(Weekly)</b></td> <td align=center>$remote_week_size</td></tr>" >>"$bckreport"
                        echo "<tr><td><b>NAS Disk Size</b></td> <td align=center>$total_disk_size</td><td><b>NAS Available Disk</b></td> <td align=center>$available_size</td></tr>" >>"$bckreport"

                        end_time=$(date +%s)
                        ee_time=$(date +"%T")
                        totalTimeTaken=`echo $((end_time - start_time)) | awk '{printf "%d:%02d:%02d", $1 / 3600, ($1 / 60) % 60, $1 % 60}'`

                        echo "<tr align=center><td colspan='4'><b>Summary</b></td></tr>" >>"$bckreport"
                        echo "<tr><td><b>Start Time</b></td> <td align=center>$ss_time</td><td><b>Previous Backup Size</b></td> <td align=center>$last_day_size</td></tr>" >>"$bckreport"
                        echo "<tr><td><b>End Time</b></td> <td align=center>$ee_time</td><td><b>Current Backup Size</b></td> <td align=center>$remote_daily_size</td></tr>" >>"$bckreport"
                        echo "<tr><td><b>Duration</b></td> <td align=center>$totalTimeTaken</td><td><b>Database Growth</b></td> <td align=center>$growth</td></tr>" >>"$bckreport"
                        echo "</table> </body> </html>" >> $bckreport
                        /usr/sbin/sendmail -t  <$bckreport
                        echo "$(date) Done backup of databases " >> $logfile
                        umount $mount_point
                        rm -rf $bckreport

                        echo "{
  \"Remote_DB_Name\": \"$host-$ipaddr\",
  \"Remote_DB_BackupStatus\": \"1\",
  \"Remote_DB_start_time\": \"$ss_time\",
  \"Remote_DB_End_Time\": \"$ee_time\",
  \"Remote_DB_TotalTimeTaken\": \"$totalTime\",
  \"Remote_Local_Total_Time\": \"$totalTime\",
  \"Remote_DB_Backup_Date\": \"$backup_date\",
  \"Remote_DB_Total_Size\": \"$totalSize_json\"
}
]" >> $jsonreport
                else
                        echo "From: $host BackupAgent <produtilalerts@ersaltametrics.com>
        To: DC Team<dcteam@altametrics.com>
Subject: Backup Failed: $host($ipaddr) On $backup_date
Content-Type: text/html
</head><body>
<table align='center' border='1'>
<tr bgcolor=#ff6347><td><b>Backup Job</b></td>
<td align='center'>$host</td>
<td><b>Backup Date</b></td>
<td align='center'>$backup_date</td>
</tr>
<tr bgcolor=#ff6347>
<td><b>Status</b></td>
<td align='center'>Failed</td>
<td><b>Time</b></td>
<td align='center'>$(date +"%T")</td>
</tr>
    <tr align='center'><td colspan='4'><b>Details</b></td></tr>" >"$bckreport"
                        echo "$(date) Backup Not Found at Local Server($ipaddr) $target_directory" >>"$logfile"
                        echo "<tr color='#3333ff'> <td colspan='3'><b>Backup Not Found at Local Server($ipaddr) $target_directory.</b></td><td><span style=\"font-size: xx-larger;\">&#9888;</span></td></tr>" >>"$bckreport"
                        echo "</table> </body> </html>" >>"$bckreport"
                        /usr/sbin/sendmail -t <"$bckreport"
                        umount "$mount_point"
                        rm -rf "$bckreport"
                        end_time=$(date +%s)
                        ee_time=$(date +"%T")
                        remotetotalTime="0"
                        totalSize_json="0"
                        echo "{
  \"Remote_DB_Name\": \"$host-$ipaddr\",
  \"Remote_DB_BackupStatus\": \"0\",
  \"Remote_DB_start_time\": \"$ss_time\",
  \"Remote_DB_End_Time\": \"$ee_time\",
  \"Remote_DB_TotalTimeTaken\": \"$remotetotalTime\",
  \"Remote_Local_Total_Time\": \"$remotetotalTime\",
  \"Remote_DB_Backup_Date\": \"$backup_date\",
  \"Remote_DB_Total_Size\": \"$totalSize_json\"
}
]" >> $jsonreport
                fi
        else
                echo "</table> </body> </html>" >> $bckreport
                /usr/sbin/sendmail -t  <$bckreport
                umount $mount_point
                rm -rf $bckreport
                end_time=$(date +%s)
                ee_time=$(date +"%T")
                echo "{
  \"Remote_DB_Name\": \"$host-$ipaddr\",
  \"Remote_DB_BackupStatus\": \"1\",
  \"Remote_DB_start_time\": \"$ss_time\",
  \"Remote_DB_End_Time\": \"$ee_time\",
  \"Remote_DB_TotalTimeTaken\": \"$totalTime\",
  \"Remote_Local_Total_Time\": \"$totalTime\",
  \"Remote_DB_Backup_Date\": \"$backup_date\",
  \"Remote_DB_Total_Size\": \"$totalSize_json\"
}
]" >> $jsonreport
        fi
else
        echo "From: $host BackupAgent <noreply@notify.altametrics.com>
To: DC Team<dcteam@altametrics.com>
Subject: Backup Failed: $host($ipaddr) On $backup_date
Content-Type: text/html
</head><body>
<table align='center' border='1'>
<tr bgcolor=#ff6347><td><b>Backup Job</b></td>
<td align='center'>$host</td>
<td><b>Backup Date</b></td>
<td align='center'>$backup_date</td>
</tr>
<tr bgcolor=#ff6347>
<td><b>Status</b></td>
<td align='center'>Failed</td>
<td><b>Time</b></td>
<td align='center'>$(date +"%T")</td>
</tr>
    <tr align='center'><td colspan='4'><b>Details</b></td></tr>" >"$bckreport"
    echo "<tr color='#3333ff'> <td colspan='3'><b>Mounting the TrueNAS Drive failed.</b></td><td><center><span style=\"font-size: xx-larger;\">&#9888;</span></center></td></tr>" >>"$bckreport"
    echo "</table> </body> </html>" >>"$bckreport"
        /usr/sbin/sendmail -t  <$bckreport
        umount $mount_point
        echo "$(date) Mounting the TrueNAS Drive failed." >>"$logfile"
    rm -rf "$bckreport"
        end_time=$(date +%s)
        ee_time=$(date +"%T")
        totalTime=`echo $((end_time-start_time)) | awk '{printf "%d:%02d:%02d", $1/3600, ($1/60)%60, $1%60}'`
        remotetotalTime="0"
        totalSize_json="0"
        echo "{
  \"Remote_DB_Name\": \"$host-$ipaddr\",
  \"Remote_DB_BackupStatus\": \"0\",
  \"Remote_DB_start_time\": \"$ss_time\",
  \"Remote_DB_End_Time\": \"$ee_time\",
  \"Remote_DB_TotalTimeTaken\": \"$totalTime\",
  \"Remote_Local_Total_Time\": \"$remotetotalTime\",
  \"Remote_DB_Backup_Date\": \"$backup_date\",
  \"Remote_DB_Total_Size\": \"$totalSize_json\"
}
]" >> $jsonreport
fi
