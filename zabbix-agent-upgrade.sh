#!/bin/bash
# Download the Zabbix Agent 2 package for Ubuntu 22.04
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix/zabbix-agent2_7.0.1-1%2Bubuntu24.04_amd64.deb
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix/zabbix-agent2_7.0.1-1%2Bubuntu22.04_amd64.deb
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix/zabbix-agent2_7.0.1-1%2Bubuntu20.04_amd64.deb
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix/zabbix-agent2_7.0.1-1%2Bubuntu18.04_amd64.deb
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix/zabbix-agent_7.0.1-1%2Bubuntu16.04_amd64.deb
# Stop the Zabbix Agent 2 service
sudo systemctl stop zabbix-agent2.service
# Remove the existing Zabbix Agent 2 package
sudo apt-get remove zabbix-agent2 -y
# Install the downloaded Zabbix Agent 2 package

sudo dpkg -i zabbix-agent2_7.0.1-1+ubuntu24.04_amd64.deb
sudo dpkg -i zabbix-agent2_7.0.1-1+ubuntu22.04_amd64.deb
sudo dpkg -i zabbix-agent2_7.0.1-1+ubuntu20.04_amd64.deb
sudo dpkg -i  zabbix-agent2_7.0.1-1+ubuntu18.04_amd64.deb
sudo dpkg -i  zabbix-agent_7.0.1-1+ubuntu16.04_amd64.deb
sudo apt-get install -f -y  # To fix any dependency issues
# Modify the Zabbix Agent 2 configuration file
sudo sed -i 's/Server=127.0.0.1/Server=10.110.10.219/' /etc/zabbix/zabbix_agent2.conf; sudo sed -i 's/ServerActive=127.0.0.1/ServerActive=10.110.10.219/' /etc/zabbix/zabbix_agent2.conf; sudo sed -i 's/^Hostname=Zabbix server/#Hostname=Zabbix server/' /etc/zabbix/zabbix_agent2.conf; sudo sed -i 's/^# HostnameItem=system.hostname/HostnameItem=system.hostname/' /etc/zabbix/zabbix_agent2.conf; sudo systemctl unmask zabbix-agent2.service; sudo systemctl start zabbix-agent2.service; sudo systemctl enable zabbix-agent2.service; sudo systemctl restart zabbix-agent2.service; sudo systemctl status zabbix-agent2.service; zabbix_agent2 -V | grep zabbix_agent2
