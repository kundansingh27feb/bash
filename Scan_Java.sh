#!/bin/bash
#Owner: Kundan Singh
get_java_info() {
    local java_path=$1
    if [ -x "$java_path/bin/java" ]; then
        java_version=$($java_path/bin/java -version 2>&1 | awk -F[\"_] '/version/ {print $2}')
        if [[ $($java_path/bin/java -version 2>&1) == *"OpenJDK"* ]]; then
            java_type="OpenJDK"
        elif [[ $($java_path/bin/java -version 2>&1) == *"Java(TM)"* ]]; then
            java_type="Oracle JDK"
        else
            java_type="Unknown"
        fi
    else
        java_version="NA"
        java_type="NA"
    fi
}
create_html_row() {
    local dir=$1
    get_java_info "$dir"
    if [ "$java_version" != "NA" ]; then
        echo "<tr><td>$dir</td><td>$java_version</td><td>$java_type</td><td>$dir</td></tr>" >> "$output_file"
    fi
}
hostname=$(hostname)
server_ip=$(hostname -I | awk '{print $1}')
output_file="java_details.html"

# Directories to scan
directories=(
    "/app/java"
    "/app/altautils"
    "/opt"
)
# Additional directories to scan can be added here
# directories+=("/new/dir")
cat <<EOF > "$output_file"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Java Details</title>
    <style>
        table {
            width: 100%;
            border-collapse: collapse;
        }
        table, th, td {
            border: 1px solid black;
        }
        th, td {
            padding: 10px;
            text-align: left;
        }
    </style>
</head>
<body>
    <h2>Java Installation Details</h2>
    <p><strong>Host:</strong> $hostname</p>
    <p><strong>Server IP:</strong> $server_ip</p>
    <table>
        <tr>
            <th>Location</th>
            <th>Installed Java Version</th>
            <th>Type</th>
            <th>Location</th>
        </tr>
EOF
create_html_row "/usr"
for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        create_html_row "$dir"
        # Check subdirectories
        for sub_dir in $(find "$dir" -maxdepth 1 -type d); do
            if [ "$sub_dir" != "$dir" ]; then
                create_html_row "$sub_dir"
            fi
        done
    fi
done
cat <<EOF >> "$output_file"
    </table>
</body>
</html>
EOF
echo "Java details have been written to $output_file"
