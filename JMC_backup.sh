#!/bin/bash
#Script Owner: Kundan Singh

############# Local Backup Parameter ######################
l_start_time=$(date +"%T")
backup_start_time=$(date +%s)
host=$(hostname | cut -f1 -d ".")
ipaddr=$(hostname -I | awk '{print $1}')
# Location to place backups and logfile.
backup_date=$(date +%Y-%m-%d)
local_backup_dir="/backup/DB_Backup/$backup_date"
logfile="/opt/script/DailyBackup/TrueNAS/DBlog/pgsql_$backup_date.log"
bckreport="/opt/script/DailyBackup/TrueNAS/report.txt"
mkdir -p /backup/DB_Backup/
local_count=$(find "/backup/DB_Backup/" -mindepth 1 -type d | wc -l)
mkdir -p "$local_backup_dir"
last_backup_date=$(date --date="yesterday" "+%Y-%m-%d")
mkdir -p /opt/script/DailyBackup/TrueNAS/DBlog/
success_count=0
error_count=0
warning_count=0
error_messages=""
warning_messages=""
local_size=$(du -sh "/backup/DB_Backup/" | awk -F" " '{print $1}')
############# TrueNAS Backup Parameter ######################
mount_point="/backup/RemoteBackup"
umount -l "$mount_point" >>"$logfile"
type="HWLanding"
dbtype="Postgres"
backuptype="DailyBackup"
target_directory="$local_backup_dir"
server_address="NAS_IP"
share="/mnt/STR-STG-01/str-stg"
day_of_week=$(date +%w)
mkdir -p "$mount_point"
backup_dir="$mount_point/$type/$dbtype/$host/$backuptype/"
mkdir -p "$backup_dir"
jsonreport="/opt/script/DailyBackup/TrueNAS/report.json"
local_start_time=$(date +%s)
local_ss_time=$(date +"%T")
find /backup/DB_Backup/ -type d -mtime +1 -exec rm -rf {} \;
####################### Global Part ######################
echo "From: $host BackupAgent <noreply@notify.altametrics.com>
To: DC Team<dcteam@altametrics.com>, DB Team<dba@altametrics.com>
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
<tr align='center'><td><b>Schema Name</b></td><td><b>Time Taken</b></td><td><b>Backup Size</b></td><td><b>Error/Warning</b></td></tr>" >"$bckreport"
rm -rf "$jsonreport"
sl_time=$(date +%s)
echo "[" >> "$jsonreport"

################ Taking Local Backup #####################
find /backup/DB_Backup/ -type d -mtime +1 -exec rm -rf {} \;
find /opt/script/DailyBackup/TrueNAS/DBlog/ -type f -mtime +30 -exec rm {} \;
databases=$(sudo -u postgres psql -l -t | cut -d'|' -f1 | grep -w -v -e "template0" -e "template1" -e "pg_profile" -e "postgres" -e "jmc_ers" -e "jmc_hw" | sed -e 's/ //g' -e '/^$/d')
echo "$(date) Starting backup of databases $backup_date " >"$logfile"
for i in $databases; do
    ls_time=$(date +"%T")
    backupfile="$local_backup_dir/$i.$backup_date.sql.gz"

    echo Dumping $i to $backupfile
    s_time=$(date +%s)
    temp_err_file=$(mktemp)
    sudo -u postgres pg_dump -Z1 -Fc "$i" >"$backupfile" 2>"$temp_err_file"
    dump_exit_code=$?
    e_time=$(date +%s)
    echo "$(date) Backup and Vacuum complete on $backup_date for database: $i " >>"$logfile"
    t_taken=$(echo $((e_time - s_time)) | awk '{printf "%d:%02d:%02d", $1 / 3600, ($1 / 60) % 60, $1 % 60}')
    dumpsize=$(ls -ltr --block-size=M "$backupfile" | awk -F" " '{print $5}')
        dumpsize_json=$(du -b $backupfile | awk -F" " '{print $1}')
    if [ "$dump_exit_code" -eq 0 ]; then
        echo "<tr align=center><td>$i</td><td>$t_taken</td><td>$dumpsize</td><td>NA</td></tr>" >>"$bckreport"
    elif [ "$dump_exit_code" -eq 1 ]; then
        warning_count=$((warning_count + 1))
        warning_messages+="Warning for $i: $(cat "$temp_err_file")"$'\n'
        echo "<tr align=center><td>$i</td><td>$t_taken</td><td>$dumpsize</td><td>Warning Count: $warning_count, Warning: $warning_messages</td></tr>" >>"$bckreport"
    else
        error_count=$((error_count + 1))
        error_messages+="Error for $i: $(cat "$temp_err_file")"$'\n'
        echo "<tr align=center><td>$i</td><td>$t_taken</td><td>$dumpsize</td><td>Error Count: $error_count, Error: $error_messages</td></tr>" >>"$bckreport"
    fi
    le_time=$(date +"%T")

echo "{
   \"Local_DB_Name\": \"$host-$ipaddr\",
   \"Local_Backup_Start_Time\": \"$ls_time\",
   \"Local_Backup_Schema_Name\": \"$i\",
   \"Local_Backup_Schema_Size\": \"$dumpsize_json\",
   \"Local_Backup_End_Time\": \"$le_time\",
   \"Local_Backup_Date\": \"$backup_date\",
   \"Local_Backup_Time_Taken\": \"$t_taken\"
 }," >> $jsonreport

done

jmc_hw_obj_time=$(date +%s)
sudo -u postgres pg_dump  -Z1 -Fc -d jmc_hw -t pg_largeobject -t pg_largeobject_metadata > $local_backup_dir/jmc_hw.$backup_date.pg_largeobject_metadata_tables.sql.gz
jmc_hw_obj_etime=$(date +%s)
hwobjtotalTime=`echo $((jmc_hw_obj_etime - jmc_hw_obj_time)) | awk '{printf "%d:%02d:%02d", $1 / 3600, ($1 / 60) % 60, $1 % 60}'`

sudo -u postgres pg_dump -Z1 -Fc -d jmc_hw -t public.* > $local_backup_dir/jmc_hw.$backup_date.AllTables.sql.gz
jmc_hw_pub_time=$(date +%s)
hwpubtotalTime=`echo $((jmc_hw_pub_time - jmc_hw_obj_etime)) | awk '{printf "%d:%02d:%02d", $1 / 3600, ($1 / 60) % 60, $1 % 60}'`

sudo -u postgres pg_dump  -Z1 -Fc -d jmc_ers -t pg_largeobject -t pg_largeobject_metadata > $local_backup_dir/jmc_ers.$backup_date.pg_largeobject_metadata_tables.sql.gz
jmc_ers_obj_time=$(date +%s)
ersobjtotalTime=`echo $((jmc_ers_obj_time - jmc_hw_pub_time)) | awk '{printf "%d:%02d:%02d", $1 / 3600, ($1 / 60) % 60, $1 % 60}'

sudo -u postgres pg_dump -Z1 -Fc -d jmc_ers -t public.* > $local_backup_dir/jmc_ers.$backup_date.AllTables.sql.gz
jmc_ers_pub_time=$(date +%s)
erspubtotalTime=`echo $((jmc_ers_pub_time - jmc_ers_obj_time)) | awk '{printf "%d:%02d:%02d", $1 / 3600, ($1 / 60) % 60, $1 % 60}'

jmc_hw_pg_largeobject_size=$(du -sh "$local_backup_dir/jmc_hw.$backup_date.pg_largeobject_metadata_tables.sql.gz" | awk -F" " '{print $1}')
jmc_hw_public_size=$(du -sh "$local_backup_dir/jmc_hw.$backup_date.AllTables.sql.gz" | awk -F" " '{print $1}')
jmc_ers_pg_largeobject_size=$(du -sh "$local_backup_dir/jmc_ers.$backup_date.pg_largeobject_metadata_tables.sql.gz" | awk -F" " '{print $1}')
jmc_ers_public_size=$(du -sh "$local_backup_dir/jmc_ers.$backup_date.AllTables.sql.gz" | awk -F" " '{print $1}')


echo "<tr align=center><td>jmc_hw_pg_largeobject</td><td>$hwobjtotalTime</td><td>$jmc_hw_pg_largeobject_size</td><td>NA</td></tr>" >>"$bckreport"
echo "<tr align=center><td>jmc_hw_public</td><td>$hwpubtotalTime</td><td>$jmc_hw_public_size</td><td>NA</td></tr>" >>"$bckreport"
echo "<tr align=center><td>jmc_ers_pg_largeobject</td><td>$ersobjtotalTime</td><td>$jmc_ers_pg_largeobject_size</td><td>NA</td></tr>" >>"$bckreport"
echo "<tr align=center><td>jmc_ers_public</td><td>$erspubtotalTime</td><td>$jmc_ers_public_size</td><td>NA</td></tr>" >>"$bckreport"

totalSize=$(du -sh "$local_backup_dir" | awk -F" " '{print $1}')
el_time=$(date +%s)
totalTime=`echo $((el_time - sl_time)) | awk '{printf "%d:%02d:%02d", $1 / 3600, ($1 / 60) % 60, $1 % 60}'`
  totalSizenr=`du -b $local_backup_dir | awk -F" " '{print $1}'`
echo "$(date) Done backup of databases " >>"$logfile"
echo "<tr><td><b> Local Backup Total </b></td> <td align=center> <b> $totalTime </b></td><td align=center><b> $totalSize </b></td><td><b> Warning: $warning_count, Error: $error_count </b></td></tr>" >>"$bckreport"
local_ee_time=$(date +"%T")

echo "{
  \"Local_DB_Name\": \"$host-$ipaddr\",
  \"Local_DB_BackupStatus\": \"1\",
  \"Local_DB_start_time\": \"$local_ss_time\",
  \"Local_DB_End_Time\": \"$local_ee_time\",
  \"Local_DB_Backup_Date\": \"$backup_date\",
  \"Local_DB_Total_Size\": \"$totalSizenr\",
  \"Local_DB_TotalTimeTaken\": \"$totalTime\"
}," >> "$jsonreport"

################ Taking Remote Backup #####################
umount "$mount_point" >>"$logfile"
remote_s_time=$(date +"%T")
re_sl_time=$(date +%s)
mount -t nfs "$server_address:$share" "$mount_point"
if [ $? -eq 0 ]; then
    mkdir -p "$backup_dir"
    echo "$(date) TrueNAS share mounted successfully at $mount_point." >>"$logfile"
    weekly="$mount_point/$type/$dbtype/$host/WeeklyBackup/"
    mkdir -p "$weekly"

    if [ "$day_of_week" -eq 0 ]; then
        last_day_size=$(du -sh "$backup_dir$last_backup_date" | awk -F" " '{print $1}')
        last_day_size_numeric=$(echo "$last_day_size" | sed 's/[^0-9]*//g')
    elif [ "$day_of_week" -eq 1 ]; then
        last_day_size=$(du -sh "$weekly$last_backup_date" | awk -F" " '{print $1}')
        last_day_size_numeric=$(echo "$last_day_size" | sed 's/[^0-9]*//g')
    else
        last_day_size=$(du -sh "$backup_dir$last_backup_date" | awk -F" " '{print $1}')
        last_day_size_numeric=$(echo "$last_day_size" | sed 's/[^0-9]*//g')
    fi

    ############################################# If Sunday Then The below Code will execute ######################################################
    if [ "$day_of_week" -eq 0 ]; then
        echo "$(date) Today is Sunday. Skipping Daily Backup. Taking weekly backup $target_directory to Remote..." >>"$logfile"
        rsync -av "$target_directory" "$weekly"
        week_file=$backup_date
        week_size=$(du -sh "$weekly$backup_date" | awk -F" " '{print $1}')
        week_size_json=$(du -b "$weekly$backup_date" | awk -F" " '{print $1}')
        today_size_numeric=$(echo "$week_size" | sed 's/[^0-9]*//g')
        echo "Weekly backup copied to NAS Drive" >>"$logfile"
        week_to_delete=$(ls -t "$weekly" | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" | tail -n +6)
        if [ -z "$week_to_delete" ]; then
            deleted_week_size="NA"
            deleted_week_dirs="NA (Fewer Than 5 Copies Are Available)"
            directory_week_count=$(find "$weekly" -mindepth 1 -type d | wc -l)
            directory_daily_count=$(find "$backup_dir" -mindepth 1 -type d | wc -l)
            remote_week_size=$(du -sh "$weekly" | awk -F" " '{print $1}')
            remote_daily_size=$(du -sh "$backup_dir" | awk -F" " '{print $1}')
            totalSize_json=$(du -b $backup_dir$backup_date | awk -F" " '{print $1}')
        else
            echo "$(date) Deleting Older than 5 weeks backup from WeeklyBackup Directory" >>"$logfile"
            deleted_week_size=$(du -sh "$weekly$week_to_delete" | awk -F" " '{print $1}')
            deleted_week_dirs=$week_to_delete
            rm -rf "$weekly$week_to_delete"
            for week in $week_to_delete; do
                rm -rf "$weekly$week"
            done
            directory_week_count=$(find "$weekly" -mindepth 1 -type d | wc -l)
            directory_daily_count=$(find "$backup_dir" -mindepth 1 -type d | wc -l)
            remote_week_size=$(du -sh "$weekly" | awk -F" " '{print $1}')
            remote_daily_size=$(du -sh "$backup_dir" | awk -F" " '{print $1}')
        fi
        growth=$((today_size_numeric - last_day_size_numeric))
        disk_usage=$(df -h "$mount_point")
        total_disk_size=$(echo "$disk_usage" | awk 'NR==2 {print $2}')
        available_size=$(echo "$disk_usage" | awk 'NR==2 {print $4}')
        echo "<tr align=center><td colspan='4'><b>Retention Policy</b></td></tr>" >>"$bckreport"
        echo "<tr><td><b>Local Backup Count</b></td> <td align=center>$local_count</td><td><b>Local Backup Size</b></td> <td align=center>$local_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>Remote Count(Daily)</b></td> <td align=center>$directory_daily_count</td><td><b>Remote Backup Size(Daily)</b></td> <td align=center>$remote_daily_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>Remote Count(Weekly)</b></td> <td align=center>$directory_week_count</td><td><b>Remote Backup Size(Weekly)</b></td> <td align=center>$remote_week_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>Remote Disk Size</b></td> <td align=center>$total_disk_size</td><td><b>Remote Available Size</b></td> <td align=center>$available_size</td></tr>" >>"$bckreport"

        backup_end_time=$(date +%s)
        l_end_time=$(date +"%T")
        totalTimeTake=`echo $((backup_end_time - backup_start_time)) | awk '{printf "%d:%02d:%02d", $1 / 3600, ($1 / 60) % 60, $1 % 60}'`
        echo "<tr align=center><td colspan='4'><b>Summary</b></td></tr>" >>"$bckreport"
        echo "<tr><td><b>Start Time</b></td> <td align=center>$l_start_time</td><td><b>Previous Backup Size</b></td> <td align=center>$last_day_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>End Time</b></td> <td align=center>$l_end_time</td><td><b>Current Backup Size</b></td> <td align=center>$week_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>Duration</b></td> <td align=center>$totalTimeTake</td><td><b>Database Growth</b></td> <td align=center>$growth G</td></tr>" >>"$bckreport"
        echo "</table> </body> </html>" >>"$bckreport"
        /usr/sbin/sendmail -t <"$bckreport"
        echo "$(date) Done backup of databases " >>"$logfile"
        umount "$mount_point"
        rm -rf "$bckreport"
        find /backup/DB_Backup/ -type d -mtime +1 -exec rm -rf {} \;
                echo "{
  \"Remote_DB_Name\": \"$host-$ipaddr\",
  \"Remote_DB_BackupStatus\": \"1\",
  \"Remote_DB_start_time\": \"$remote_s_time\",
  \"Remote_DB_End_Time\": \"$l_end_time\",
  \"Remote_DB_TotalTimeTaken\": \"$remote_e_timeT\",
  \"Remote_Local_Total_Time\": \"$totalTimeTake\",
  \"Remote_DB_Backup_Date\": \"$backup_date\",
  \"Remote_DB_Total_Size\": \"$week_size_json\"
}
]" >> $jsonreport
    elif [ "$day_of_week" -ne 0 ]; then
        cp -r "$target_directory" "$backup_dir"
        daily_size=$(du -sh "$backup_dir$backup_date" | awk -F" " '{print $1}')
        totalSize_json=$(du -b "$backup_dir$backup_date" | awk -F" " '{print $1}')
        today_size_numeric=$(echo "$daily_size" | sed 's/[^0-9]*//g')
        echo "Daily backup copied to NAS Drive" >>"$logfile"
        daily_to_delete=$(ls -t "$backup_dir" | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" | tail -n +9)
        if [ -z "$daily_to_delete" ]; then
            deleted_daily_size="NA"
            deleted_daily_dirs="NA (Fewer Than 5 Copies Are Available)"
            directory_week_count=$(find "$weekly" -mindepth 1 -type d | wc -l)
            directory_daily_count=$(find "$backup_dir" -mindepth 1 -type d | wc -l)
            remote_week_size=$(du -sh "$weekly" | awk -F" " '{print $1}')
            remote_daily_size=$(du -sh "$backup_dir" | awk -F" " '{print $1}')
        else
            echo "$(date) Deleting Older than 8 day backup from dailyBackup Directory" >>"$logfile"
            deleted_daily_size=$(du -sh "$weekly$week_to_delete" | awk -F" " '{print $1}')
            deleted_daily_dirs=$daily_to_delete
            rm -rf "$backup_dir$daily_to_delete"
            for daily in $daily_to_delete; do
                rm -rf "$backup_dir$daily"
            done
            directory_week_count=$(find "$weekly" -mindepth 1 -type d | wc -l)
            directory_daily_count=$(find "$backup_dir" -mindepth 1 -type d | wc -l)
            remote_week_size=$(du -sh "$weekly" | awk -F" " '{print $1}')
            remote_daily_size=$(du -sh "$backup_dir" | awk -F" " '{print $1}')
            totalSize_json=$(du -b $backup_dir$backup_date | awk -F" " '{print $1}')
        fi
        growth=$((today_size_numeric - last_day_size_numeric))
        disk_usage=$(df -h "$mount_point")
        total_disk_size=$(echo "$disk_usage" | awk 'NR==2 {print $2}')
        available_size=$(echo "$disk_usage" | awk 'NR==2 {print $4}')
        echo "<tr align=center><td colspan='4'><b>Retention Policy</b></td></tr>" >>"$bckreport"
        echo "<tr><td><b>Local Backup Count</b></td> <td align=center>$local_count</td><td><b>Local Backup Size</b></td> <td align=center>$local_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>Remote Count(Daily)</b></td> <td align=center>$directory_daily_count</td><td><b>Remote Backup Size(Daily)</b></td> <td align=center>$remote_daily_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>Remote Count(Weekly)</b></td> <td align=center>$directory_week_count</td><td><b>Remote Backup Size(Weekly)</b></td> <td align=center>$remote_week_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>NAS Disk Size</b></td> <td align=center>$total_disk_size</td><td><b>NAS Available Disk</b></td> <td align=center>$available_size</td></tr>" >>"$bckreport"

        backup_end_time=$(date +%s)
        l_end_time=$(date +"%T")
        re_el_time=$(date +%s)
        totalTimeTake=`echo $((backup_end_time - backup_start_time)) | awk '{printf "%d:%02d:%02d", $1 / 3600, ($1 / 60) % 60, $1 % 60}'`
        echo "<tr align=center><td colspan='4'><b>Summary</b></td></tr>" >>"$bckreport"
        echo "<tr><td><b>Start Time</b></td> <td align=center>$l_start_time</td><td><b>Previous Backup Size</b></td> <td align=center>$last_day_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>End Time</b></td> <td align=center>$l_end_time</td><td><b>Current Backup Size</b></td> <td align=center>$daily_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>Duration</b></td> <td align=center>$totalTimeTake</td><td><b>Database Growth</b></td> <td align=center>$growth G</td></tr>" >>"$bckreport"
        echo "</table> </body> </html>" >>"$bckreport"
        /usr/sbin/sendmail -t <"$bckreport"
        echo "$(date) Done backup of databases " >>"$logfile"
        umount "$mount_point"
        rm -rf "$bckreport"
        find /backup/DB_Backup/ -type d -mtime +1 -exec rm -rf {} \;
remote_e_timeT=`echo $(($re_el_time - $re_sl_time)) | awk '{printf "%d:%02d:%02d", $1 / 3600, ($1 / 60) % 60, $1 % 60}'`
                                echo "{
  \"Remote_DB_Name\": \"$host-$ipaddr\",
  \"Remote_DB_BackupStatus\": \"1\",
  \"Remote_DB_start_time\": \"$remote_s_time\",
  \"Remote_DB_End_Time\": \"$l_end_time\",
  \"Remote_DB_TotalTimeTaken\": \"$remote_e_timeT\",
  \"Remote_Local_Total_Time\": \"$totalTimeTake\",
  \"Remote_DB_Backup_Date\": \"$backup_date\",
  \"Remote_DB_Total_Size\": \"$totalSize_json\"
}
]" >> $jsonreport
    else
echo "From: $host BackupAgent <noreply@notify.altametrics.com>
To: DC Team<dcteam@altametrics.com>, DB Team<dba@altametrics.com>
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
        remote_e_time=$(date +"%T")
        remotetotalTime="0"
        totalSize_json="0"
        echo "{
  \"Remote_DB_Name\": \"$host-$ipaddr\",
  \"Remote_DB_BackupStatus\": \"0\",
  \"Remote_DB_start_time\": \"$remote_s_time\",
  \"Remote_DB_End_Time\": \"$remote_e_time\",
  \"Remote_DB_TotalTimeTaken\": \"$remote_e_timeT\",
  \"Remote_DB_TotalTimeTaken\": \"$remotetotalTime\",
  \"Remote_DB_Backup_Date\": \"$backup_date\",
  \"Remote_DB_Total_Size\": \"$totalSize_json\"
}
]" >> $jsonreport
    fi
else
echo "From: $host BackupAgent <noreply@notify.altametrics.com>
To: DC Team<dcteam@altametrics.com>, DB Team<dba@altametrics.com>
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
    /usr/sbin/sendmail -t <"$bckreport"
    echo "$(date) Mounting the TrueNAS Drive failed." >>"$logfile"
    rm -rf "$bckreport"
                remote_e_time=$(date +"%T")
        remotetotalTime="0"
        totalSize_json="0"
        echo "{
  \"Remote_DB_Name\": \"$host-$ipaddr\",
  \"Remote_DB_BackupStatus\": \"0\",
  \"Remote_DB_start_time\": \"$remote_s_time\",
  \"Remote_DB_End_Time\": \"$remote_e_time\",
  \"Remote_DB_TotalTimeTaken\": \"$remote_e_timeT\",
  \"Remote_DB_Total_Time\": \"$remote_e_time\",
  \"Remote_DB_TotalTimeTaken\": \"$remotetotalTime\",
  \"Remote_DB_Backup_Date\": \"$backup_date\",
  \"Remote_DB_Total_Size\": \"$totalSize_json\"
}
]" >> $jsonreport
fi

exit 0