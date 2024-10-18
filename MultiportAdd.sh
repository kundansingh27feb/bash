#!/bin/bash

# Path to the file containing the ports
PORTS_FILE="ports.txt"

# Check if the file exists
if [ ! -f "$PORTS_FILE" ]; then
    echo "File not found: $PORTS_FILE"
    exit 1
fi

# Read the file content into a variable
PORTS=$(cat "$PORTS_FILE")

# Convert the space-separated list into an array
IFS=' ' read -ra ADDR <<< "$PORTS"

# Iterate over the array and add each port to ufw
for port in "${ADDR[@]}"; do
    echo "Adding rule for: $port"
    sudo ufw allow "$port"
done

echo "All rules have been added."