#!/usr/bin/env bash
# filepath: /home/sarah/git-projects/Artix installer/artix-install-on-zfs2.sh

bold=$(tput setaf 2 bold)
bolderror=$(tput setaf 3 bold)
normal=$(tput sgr0)

# Define the log file
LOG_FILE="$(dirname "$0")/artix-install.log"

# Redirect stdout and stderr to the log file, but keep stdin connected to the terminal
exec > >(tee -a "$LOG_FILE") 2> >(tee -a "$LOG_FILE" >&2)

error() {
    printf "%s\n" "${bolderror}ERROR:${normal}\\n%s\\n" "$1" >&2
    exit 1
}

# Ensure dialog is installed
if ! command -v dialog &> /dev/null; then
    echo "dialog is not installed. Installing it now..."
    pacman -Sy --noconfirm dialog || { echo "Failed to install dialog. Please install it manually."; exit 1; }
fi

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    dialog --title "Permission Denied" --msgbox "\
${bolderror}ERROR:${normal} This script must be run as root.\n\n\
Please run it with sudo or as the root user." 10 50
    exit 1
fi

# Source individual scripts
source ./scripts/zfs-live.sh   # Handles Chaotic AUR and ZFS installation on the live system
source ./scripts/inst_var.sh       # Contains timezone, hostname, kernel, and disk selection
source ./scripts/select-desktop-environment.sh # Handles desktop environment selection
source ./scripts/disksetup.sh  # Handles disk partitioning
source ./scripts/installpkgs.sh # Installs base system and packages
source ./scripts/configuration.sh # Handles system configuration (e.g., fstab, mkinitcpio)

# Main installation process
printf "%s\n" "${bold}Starting the Artix installation process..."

# Install ZFS on the live system
chaoticaur || error "Error installing Chaotic AUR!"
addrepo || error "Error adding repos!"
installzfs || error "Error installing ZFS!"

# Set installation variables
# Timezone selection
installtz || error "Error selecting timezone!"

# Hostname configuration
installhost || error "Error setting hostname!"

# Kernel selection
installkrn || error "Error selecting kernel!"

# Disk selection
selectdisk || error "Error selecting disk!"

# Desktop environment selection
select_desktop_environment || error "Error selecting desktop environment!"

# Actual installation process
# Partitioning
partdrive || error "Error partitioning the drive!"

# Formatting and mounting
rootpool    || error "Error creating root pool!"
createdatasets || error "Error creating datasets!"
mountall || error "Error mounting filesystems!"
permissions || error "Error setting permissions!"
efiswap || error "Error setting up EFI and swap partitions!"

# Installing packages
installpkgs || error "Error installing packages!"
fstab || error "Error creating fstab!"
mkinitram || error "Error generating initramfs!"
# Configuring the system
finishtouch || error "Error finalizing installation!"

printf "%s\n" "${bold}Installation completed successfully!"