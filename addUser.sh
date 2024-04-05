#!/bin/bash

# Ensure the script is run with root privileges
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root." >&2
   exit 1
fi

# Prompt for the username
read -p "Enter the username for the new user: " username

# Repeated password entry
while true; do
    read -sp "Enter the password for the new user: " password
    echo
    read -sp "Re-enter the password: " password2
    echo
    if [ "$password" == "$password2" ]; then
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done

# Optional sudo privileges
read -p "Should the user have sudo privileges? (y/n): " sudo_priv

# Optional SSH access
read -p "Should the user have SSH access? (y/n): " ssh_access

ssh_key=""
if [[ "$ssh_access" =~ ^[Yy]$ ]]; then
    echo "Enter the public SSH key for the user (leave empty if not using SSH key):"
    read -r ssh_key
fi

# Summary and confirmation
echo
echo "Please review the entered information:"
echo "Username: $username"
[[ "$sudo_priv" =~ ^[Yy]$ ]] && echo "Sudo privileges: Yes" || echo "Sudo privileges: No"
if [[ "$ssh_access" =~ ^[Yy]$ ]]; then
    echo "SSH access: Yes"
    if [ -n "$ssh_key" ]; then
        echo "Public SSH key: Provided"
    else
        echo "Public SSH key: Not Provided"
    fi
else
    echo "SSH access: No"
fi

read -p "Do you want to proceed with these settings? (y/n): " confirm

if ! [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation aborted. No changes were made."
    exit 0
fi

# Proceed with adding the user
useradd -m -s /bin/bash "$username" && echo "$username:$password" | chpasswd

if [[ "$sudo_priv" =~ ^[Yy]$ ]]; then
    usermod -aG sudo "$username"
fi

# Setup SSH access if requested
if [[ "$ssh_access" =~ ^[Yy]$ ]] && [ -n "$ssh_key" ]; then
    # Check for SSH service installation
    if ! dpkg -s openssh-server >/dev/null 2>&1; then
        read -p "SSH service is not installed. Would you like to install it now? (y/n): " install_ssh
        if [[ "$install_ssh" =~ ^[Yy]$ ]]; then
            apt-get update && apt-get install openssh-server -y
            echo "SSH service has been installed."
        else
            echo "SSH service not installed. SSH access won't be configured."
            exit 1
        fi
    fi

    # Configure SSH key
    ssh_dir="/home/$username/.ssh"
    mkdir -p "$ssh_dir"
    echo "$ssh_key" > "$ssh_dir/authorized_keys"
    chmod 700 "$ssh_dir"
    chmod 600 "$ssh_dir/authorized_keys"
    chown -R "$username":"$username" "$ssh_dir"
fi

echo "User '$username' has been successfully added and configured."
