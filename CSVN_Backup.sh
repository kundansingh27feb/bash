#!/bin/bash
#Script Owner : Kundan Singh
#umount $mount_point >> $logfile
host=`hostname|cut -f1 -d "."`
ipaddr=`hostname -I | awk '{print $1}'`
backup_date=`date +%Y-%m-%d`
day_of_week=$(date +%w)
last_backup_date=$(date --date="yesterday" "+%Y-%m-%d")
backup_old=$(date --date="yesterday" "+%Y-%m-%d")
logfile="/opt/script/DailyBackup/TrueNAS/Logs/DailyBackup_$(date +%Y%m%d).txt"
bkp="/mnt/CsvnBackup/Code_Repos/Csvn/DailyBackup"
bckreport="/opt/script/DailyBackup/TrueNAS/report.txt"
repos_daily="/mnt/CsvnBackup/Code_Repos/Csvn/DailyBackup/$backup_date/repositories"
conf_daily="/mnt/CsvnBackup/Code_Repos/Csvn/DailyBackup/$backup_date/conf"
one_day_ago=$(date --date="yesterday" +%Y%m%d)
mount_point="/mnt/CsvnBackup/"
server_address="10.120.11.241"
share="/mnt/data/dbprod"
mkdir -p $mount_point
target_directory="/mnt/CsvnBackup/Code_Repos/Csvn/DailyBackup/$backup_date"
umount $mount_point >> $logfile
mount -t nfs $server_address:$share $mount_point
if [ $? -eq 0 ]; then
mkdir -p $repos_daily
mkdir -p $conf_daily

rs_time=$(date +%s)
echo "$(date) TrueNAS share mounted successfully at $mount_point." >> $logfile
echo "Starting Configuration Backup Now" > $logfile
cp -rv /opt/csvn/data/conf/* $conf_daily/ >> $logfile
tar cvpf "$conf_daily.tar" "$conf_daily/"
rm -rf $conf_daily/
ce_time=$(date +%s)
conf_time=`echo $((ce_time-rs_time)) | awk '{printf "%d:%02d:%02d", $1/3600, ($1/60)%60, $1%60}'`
echo "Starting Repositories Backup" >> $logfile
cp -rv /opt/csvn/data/repositories/* $repos_daily/ >> $logfile
tar cvpf $repos_daily.tar $repos_daily/
rm -rf $repos_daily/
re_time=$(date +%s)
repo_time=`echo $((re_time-ce_time)) | awk '{printf "%d:%02d:%02d", $1/3600, ($1/60)%60, $1%60}'`

last_backup_repo=`du -sh $bkp/$backup_old/repositories | awk -F" " '{print $1}'`
last_backup_conf=`du -sh $bkp/$backup_old/conf | awk -F" " '{print $1}'`

directories_to_delete=$(find $bkp/ -type d -maxdepth 1 -mtime +6 -exec basename {} \;)
        if [ -z "$directories_to_delete" ]; then
                deleted_dirs="NA (Fewer Than 7 Copies Are Available)"
        else
                echo "$(date) Deleting 7+ day Old backup from DailyBackup Directory"  >> $logfile
                rm -rf $bkp/$directories_to_delete
        fi
today_backup_repo=`du -sh $repos_daily.tar.bz2 | awk -F" " '{print $1}'`
today_backup_conf=`du -sh $conf_daily.tar.bz2 | awk -F" " '{print $1}'`
end_time=$(date +%s)
directory_count=$(find $bkp -maxdepth 1 -type d | wc -l)
Total_time=`echo $((end_time-rs_time)) | awk '{printf "%d:%02d:%02d", $1/3600, ($1/60)%60, $1%60}'`
echo "From: $host BackupAgent <produtilalerts@ersaltametrics.com>
To: Kundan Singh <kundans@altametrics.com>
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
<tr align='center'><td><b>Backup Dir</b></td><td><b>Time Taken</b></td><td><b>Backup Size</b></td><td><b>Error/Warning</b></td></tr>" >"$bckreport"
echo "<tr align=center><td>Repositories</td><td>$repo_time</td><td>$today_backup_repo</td><td>0</td></tr>" >>$bckreport
echo "<tr align=center><td>Configuration</td><td>$conf_time</td><td>$today_backup_conf</td><td>0</td></tr>" >>$bckreport
echo "<tr align=center><td><b>Total</b></td><td>$Total_time</td><td>$today_backup_repo</td><td>0</td></tr>" >>$bckreport
echo "<tr align='center'><td colspan='4'><b>Retention Policy</b></td></tr>" >>$bckreport
echo "<tr align=center> <td><b>Local Backup Count</b></td> <td><b>$directory_count</b></td><td><b>Local Backup Size</b></td><td>$today_backup_repo</td></tr>" >>$bckreport
echo "<tr align=center> <td><b>Remote Count(Daily)</b></td> <td><b>$directory_count</b></td><td><b>Remote Backup Size</b></td><td>$today_backup_repo</td></tr>" >>$bckreport



############################################# If Friday Then The below Code will execute ######################################################
        if [ "$day_of_week" -eq 5 ] && [ -n "$target_directory" ]; then
                echo "$(date) Today is Friday. Taking weekly backup $target_directory as well to Remote..."  >> $logfile
                weekly="/mnt/CsvnBackup/Code_Repos/Csvn/WeeklyBackup/"
                cloud="/mnt/CsvnBackup/Code_Repos/Csvn/CloudBackup"
                mkdir -p $cloud
                mv $cloud/* $weekly
                cp -r  $target_directory $cloud/
                cloud_file=$backup_date
                cloud_size=$(du -sh $cloud/$backup_date | awk -F" " '{print $1}')
                echo "cloud backup copied to NAS Drive"  >> $logfile
                week_to_delete=$(find $weekly -type d -ctime +27 -exec basename {} \;)
                if [ -z "$week_to_delete" ]; then
                        deleted_week_size="NA"
                        deleted_week_dirs="NA (Fewer Than 4 Copies Are Available)"
                        directory_week_count=$(find "$weekly" -mindepth 1 -type d | wc -l)
                        find /mnt/CsvnBackup/Code_Repos/Csvn/WeeklyBackup/ -type d -mtime +27 -exec rm -rf {} \;
                else
                        echo "$(date) Deleting 27+ day Old backup from CloudBackup Directory"  >> $logfile
                        deleted_week_size=`du -sh $weekly$week_to_delete | awk -F" " '{print $1}'`
                        deleted_week_dirs=$week_to_delete
                        directory_week_count=$(find "$weekly" -mindepth 1 -type d | wc -l)
                        rm -rf $weekly$week_to_delete
                        find /mnt/CsvnBackup/Code_Repos/Csvn/WeeklyBackup/ -type d -mtime +28 -exec rm -rf {} \;
                fi

                echo "<tr bgcolor=#ff99ff align=center><td colspan="3"><b>Remote Weekly And Cloud Backup Status</b></td></tr>" >>$bckreport
                echo "<tr color='#3333ff'><td colspan="2"><b>Weekly Cloud Backup Upload</b></td> <td>$cloud_file</td></tr>" >>$bckreport
                echo "<tr color='#3333ff'><td colspan="2">Weekly Cloud Backup Size</td> <td>$cloud_size</td></tr>" >>$bckreport
                echo "<tr bgcolor=#ff99ff align=center><td colspan="3"><b>Remote Weekly Backup Retention</b></td></tr>" >>$bckreport
                echo "<tr color='#3333ff'><td colspan="2">Deleted Weekly Backup</td> <td>$deleted_week_dirs</td></tr>" >>$bckreport
                echo "<tr color='#3333ff'><td colspan="2">Deleted Weekly Backup Size</td> <td>$deleted_week_size</td></tr>" >>$bckreport
                echo "<tr color='#3333ff'><td colspan="2">Available Weekly Copies</td> <td>$directory_week_count</td></tr>" >>$bckreport
                echo "<tr align=center> <td><b>Remote Count(Weekly)</b></td> <td><b>$directory_week_count</b></td><td><b>Remote Backup Size</b></td><td>$cloud_size</td></tr>" >>$bckreport
       else
                week_file="NA($target_directory Not Found At Local)"
                week_size="NA"
        fi
echo "</table> </body> </html>" >> $bckreport
/usr/sbin/sendmail -t  <$bckreport
umount $mount_point
#umount -l $mount_point >> $logfile
rm -rf $bckreport

else
echo "From: $host BackupAgent <noreply@notify.altametrics.com>
To: Kundan Singh<kundans@altametrics.com>, DC Team<dcteam@altametrics.com>
Subject:Backup Failed: $host($ipaddr) on $backup_date To TrueNAS
Content-Type: text/html
</head>
<body>
<table width='80%' align='center' border='1'> <tr bgcolor=#ff99ff align=center>
<td><b>Description</b></td>
<td><b>Backup Status</b></td></tr>" > $bckreport
  echo "<tr color='#3333ff'> <td><b>Mounting the TrueNAS Drive failed.</b></td><td><center><span style=\"font-size: xx-larger;\">&#9888;</span> Failed</center></td></tr>" >>$bckreport
  echo "</table> </body> </html>" >> $bckreport
  /usr/sbin/sendmail -t  <$bckreport
  umount $mount_point
  rm -rf $bckreport
fi