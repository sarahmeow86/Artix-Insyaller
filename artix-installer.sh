#!/usr/bin/env bash

bold=$(tput setaf 2 bold)
bolderror=$(tput setaf 3 bold)
normal=$(tput sgr0)

error() {
    dialog --title "Error" --msgbox "${bolderror}ERROR:${normal}\n\n$1" 10 50
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

INST_MNT=$(mktemp -d)
INST_UUID=$(dd if=/dev/urandom of=/dev/stdout bs=1 count=100 2>/dev/null | tr -dc 'a-z0-9' | cut -c-6)

# Source individual scripts
source ./scripts/zfs-live.sh   # Handles Chaotic AUR and ZFS installation on the live system
source ./scripts/zfs-setup.sh   # Handles ZFS setup and dataset creation
source ./scripts/inst_var.sh       # Contains timezone, hostname, kernel, and disk selection
source ./scripts/select-desktop-environment.sh # Handles desktop environment selection
source ./scripts/disksetup.sh  # Handles disk partitioning
source ./scripts/installpkgs.sh # Installs base system and packages
source ./scripts/configuration.sh # Handles system configuration (e.g., fstab, mkinitcpio)
source ./scripts/filesystem.sh # Handles filesystem selection and setup



# Main installation process
printf "%s\n" "${bold}Starting the Artix installation process..."

# Desktop environment selection
select_desktop_environment || error "Error selecting desktop environment!"

# Choose filesystem
choose_filesystem

# Install Chaotic AUR and add arch repositories
chaoticaur || error "Error installing Chaotic AUR!"
addrepo || error "Error adding repos!"

# Install ZFS on the live system (only if ZFS is selected)
if [[ $FILESYSTEM == "zfs" ]]; then
    installzfs || error "Error installing ZFS!"
fi

# Set installation variables
installtz || error "Error selecting timezone!"
installhost || error "Error setting hostname!"
installkrn || error "Error selecting kernel!"
selectdisk || error "Error selecting disk!"

# Partitioning
partdrive || error "Error partitioning the drive!"

# Formatting and mounting
setup_filesystem || error "Error setting up the filesystem!"

# Installing packages
installpkgs || error "Error installing packages!"
fstab || error "Error creating fstab!"
mkinitram || error "Error generating initramfs!"

# Configuring the system
finishtouch || error "Error configuring the system!"

# Chroot into the new system for further configuration
prepare_chroot || error "Error preparing chroot environment!"
run_chroot || error "Error running chroot script!"

printf "%s\n" "${bold}Installation completed successfully!"