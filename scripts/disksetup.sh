#!/usr/bin/env bash
bold=$(tput setaf 2 bold)      # makes text bold and sets color to 2
bolderror=$(tput setaf 3 bold) # makes text bold and sets color to 3
normal=$(tput sgr0)            # resets text settings back to normal

error() {\
    printf "%s\n" "${bolderror}ERROR:${normal}\\n%s\\n" "$1" >&2; exit 1;
}

if ! command -v dialog &> /dev/null; then
    echo "dialog is not installed. Installing it now..."
    pacman -Sy --noconfirm dialog || { echo "Failed to install dialog. Please install it manually."; exit 1; }
fi


check_root() {
    if [[ $EUID -ne 0 ]]; then
        dialog --title "Permission Denied" --msgbox "\
${bolderror}ERROR:${normal} This script must be run as root.\n\n\
Please run it with sudo or as the root user." 10 50
        exit 1
    fi
}

partdrive() {
    printf "%s\n" "${bold}Partitioning drive"

    # Prompt the user for the swap partition size
    SWAP_SIZE=$(dialog --clear --title "Swap Partition Size" \
        --inputbox "Enter the size of the swap partition in GB (e.g., 8 for 8GB):" 10 50 3>&1 1>&2 2>&3)

    # Validate the input
    while true; do
        SWAP_SIZE=$(dialog --clear --title "Swap Partition Size" \
            --inputbox "Enter the size of the swap partition in GB (e.g., 8 for 8GB):" 10 50 3>&1 1>&2 2>&3)
    
        if [[ -n "$SWAP_SIZE" && "$SWAP_SIZE" =~ ^[0-9]+$ ]]; then
            break
        else
            dialog --title "Invalid Input" --msgbox "Invalid swap size entered! Please enter a positive integer." 10 50
        fi
    done

    # Partition the drive
    sgdisk --zap-all $DISK
    sgdisk -n1:0:+1G -t1:EF00 $DISK  # EFI System Partition
    sgdisk -n2:0:-${SWAP_SIZE}G -t2:BF00 $DISK  # ZFS Pool Partition
    sgdisk -n3:0:0 -t3:8308 $DISK  # Swap Partition
    printf "%s\n" "${bold}Partitioning completed successfully!"
}
