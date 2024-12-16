#!/bin/bash

set -e 

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install cifs-utils samba-client -y

echo "Run autoremove? (y/n)"
read -r auto
if [ "$auto" = "y" ] || [ "$auto" = "Y" ]; then
  sudo apt-get autoremove -y
fi


credentials_file="$HOME/.smbcredentials"

if [ ! -f "$credentials_file" ]; then
  echo "Enter SMB Username: "
  read -r uname

  echo "Enter SMB Password: "
  stty -echo
  read -r pass
  stty echo
  echo

  echo "Creating .smbcredentials file..."
  echo "username=$uname" | tee -a "$credentials_file" > /dev/null
  echo "password=$pass" | tee -a "$credentials_file" > /dev/null
  chmod 600 "$credentials_file"
else
  echo ".smbcredentials file already exists. Skipping creation."
fi

echo "Enter file share address (e.g., //192.168.1.100/Music): "
read -r server

echo "Checking if the share $server is accessible..."
smbclient -L "$server" -A "$credentials_file" > smbclient_output.txt 2>&1

if [ $? -eq 0 ]; then
  echo "Server $server is accessible. Proceeding."

  echo "Enter the share folder name (e.g., 'nas'): "
  read -r folder
  
  echo "Is /media/$USER/$folder the correct location? (y/n): "
  read -r confirm_folder

  while [ "$confirm_folder" != "y" ] && [ "$confirm_folder" != "Y" ]; do
    echo "Please enter the correct share folder: "
    read -r folder
    echo "Is /media/$USER/$folder the correct location? (y/n): "
    read -r confirm_folder
  done

  sudo mkdir -pv /media/$USER

  sudo chown -R $USER:$USER /media/$USER

  mkdir -pv /media/$USER/$folder

  sudo chown -R $USER:$USER /media/$USER/$folder

  echo "Adding share to /etc/fstab..."
  echo "${server} /media/$USER/$folder cifs credentials=$HOME/.smbcredentials,uid=$USER,gid=$USER,nofail 0 0" | sudo tee -a /etc/fstab > /dev/null

  echo "Share successfully added to /etc/fstab."

  if [ -d "$HOME/Desktop" ]; then
    echo "[Desktop Entry]\nVersion=1.0\nName=Mount $folder\nExec=sudo mount /media/$USER/$folder \nIcon=folder\nTerminal=true\nType=Application\nCategories=Utility;" | tee -a "$HOME/Desktop/mount_share.desktop" > /dev/null
    chmod +x "$HOME/Desktop/mount_share.desktop"
    echo "Mount share shortcut has been created on your Desktop."
  fi

  echo "Do you want to restart now? (y/n): "
  read -r restart
  if [ "$restart" = "y" ] || [ "$restart" = "Y" ]; then
    sudo reboot
  fi
else
  echo "Error: Unable to access the server $server. Please check the server address and try again."
  rm -v "$credentials_file"
  exit 1
fi
