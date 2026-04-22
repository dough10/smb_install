#!/bin/bash

set -e

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install cifs-utils samba-client -y

echo "Run autoremove? (y/n)"
read -r auto
if [[ "$auto" =~ ^[Yy]$ ]]; then
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
  {
    echo "username=$uname"
    echo "password=$pass"
  } > "$credentials_file"

  chmod 600 "$credentials_file"
else
  echo ".smbcredentials file already exists. Skipping creation."
fi

echo "Enter file share address (e.g., //192.168.1.100/Music): "
read -r network_share

# Validate format
if [[ ! "$network_share" =~ ^//[^/]+/.+ ]]; then
  echo "Invalid format. Use //host/share"
  exit 1
fi

echo "Checking if the share ${network_share} is accessible..."
host=$(echo "$network_share" | awk -F/ '{print $3}')

if smbclient -L "$host" -A "$credentials_file" > /tmp/smbclient_output.txt 2>&1; then
  echo "Share $network_share is accessible. Proceeding."

  default_folder=$(basename "$network_share")
  echo "Enter the mount folder name [default: $default_folder]: "
  read -r folder
  folder=${folder:-$default_folder}

  echo "Is /mnt/$USER/$folder the correct location? (y/n): "
  read -r confirm_folder

  while [[ ! "$confirm_folder" =~ ^[Yy]$ ]]; do
    echo "Enter the mount folder name: "
    read -r folder
    echo "Is /mnt/$USER/$folder the correct location? (y/n): "
    read -r confirm_folder
  done

  echo "Creating folders and setting permissions..."
  sudo mkdir -p "/mnt/$USER/$folder"
  sudo chown "$USER":"$USER" "/mnt/$USER"
  sudo chown "$USER":"$USER" "/mnt/$USER/$folder"

  echo "Adding share to /etc/fstab..."
  if ! grep -qs "$network_share" /etc/fstab; then
    echo "${network_share} /mnt/${USER}/${folder} cifs credentials=${credentials_file},uid=${USER},gid=${USER},vers=3.0,_netdev,nofail 0 0" \
      | sudo tee -a /etc/fstab > /dev/null
    echo "Share successfully added to /etc/fstab."
  else
    echo "Entry already exists in /etc/fstab. Skipping."
  fi

  if [ -d "$HOME/Desktop" ]; then
    cat > "${HOME}/Desktop/mount_share.desktop" <<EOF
[Desktop Entry]
Version=1.0
Name=Mount ${folder}
Exec=mount /mnt/${USER}/${folder}
Icon=folder
Terminal=true
Type=Application
Categories=Utility;
EOF
    chmod +x "${HOME}/Desktop/mount_share.desktop"
    echo "'Mount ${folder}' shortcut has been created on your Desktop."
  fi

  rm -f /tmp/smbclient_output.txt

  echo "Restart now? (y/n): "
  read -r restart
  if [[ "$restart" =~ ^[Yy]$ ]]; then
    sudo reboot
  fi

else
  echo "Error: Unable to access the share ${network_share}. Please check the address and credentials."
  cat /tmp/smbclient_output.txt
  exit 1
fi
