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
# Description: This script sets up installation variables for an Artix  Linux system.


installtz() {
    printf "%s\n" "${bold}## Setting install variables"

    # Generate a list of regions from /usr/share/zoneinfo
    region_list=$(find /usr/share/zoneinfo -mindepth 1 -maxdepth 1 -type d | sed 's|/usr/share/zoneinfo/||' | sort)

    # Prepare the list of regions for the dialog menu
    dialog_options=()
    index=1
    while IFS= read -r region; do
        dialog_options+=("$index" "$region")
        index=$((index + 1))
    done <<< "$region_list"

    # Create a dialog menu for regions
    region_index=$(dialog --clear --title "Region Selection" \
        --menu "Choose your region:" 20 60 15 "${dialog_options[@]}" 3>&1 1>&2 2>&3)

    # Check if the user selected a region
    if [[ -z "$region_index" ]]; then
        error "No region selected!"
    fi

    # Map the selected index back to the region
    region=$(echo "$region_list" | sed -n "${region_index}p")

    # Generate a list of cities for the selected region
    city_list=$(find "/usr/share/zoneinfo/$region" -type f | sed "s|/usr/share/zoneinfo/$region/||" | sort)

    # Prepare the list of cities for the dialog menu
    dialog_options=()
    index=1
    while IFS= read -r city; do
        dialog_options+=("$index" "$city")
        index=$((index + 1))
    done <<< "$city_list"

    # Create a dialog menu for cities
    city_index=$(dialog --clear --title "City Selection" \
        --menu "Choose your city in $region:" 20 60 15 "${dialog_options[@]}" 3>&1 1>&2 2>&3)

    # Check if the user selected a city
    if [[ -z "$city_index" ]]; then
        error "No city selected!"
    fi

    # Map the selected index back to the city
    city=$(echo "$city_list" | sed -n "${city_index}p")

    # Set the selected timezone
    INST_TZ="/usr/share/zoneinfo/$region/$city"
    printf "%s\n" "${bold}Timezone set to $region/$city"
}


installhost() {
    printf "%s\n" "${bold}## Set desired hostname"

    # Create a dialog input box for the hostname
    INST_HOST=$(dialog --clear --title "Hostname Configuration" \
        --inputbox "Enter your desired hostname:" 10 50 3>&1 1>&2 2>&3)

    # Check if the user provided a hostname
    if [[ -z "$INST_HOST" ]]; then
        error "No hostname provided!"
    fi

    printf "%s\n" "${bold}Hostname set to $INST_HOST"
}


installkrn() {
    printf "%s\n" "${bold}Select the kernel you want to install"
    kernel_choice=$(dialog --clear --title "Kernel Selection" \
        --menu "Choose one of the following kernels:" 15 50 3 \
        1 "linux" \
        2 "linux-zen" \
        3 "linux-lts" \
        3>&1 1>&2 2>&3)

    case $kernel_choice in
        1) INST_LINVAR="linux" ;;
        2) INST_LINVAR="linux-zen" ;;
        3) INST_LINVAR="linux-lts" ;;
        *) error "Invalid kernel choice!" ;;
    esac

    printf "%s\n" "${bold}Kernel selected: $INST_LINVAR"
}


selectdisk() {
    printf "%s\n" "${bold}## Decide which disk you want to use"

    # Generate a list of disks from /dev/disk/by-id
    disk_list=$(ls -1 /dev/disk/by-id)

    # Prepare the list for the whiptail menu
    dialog_options=()
    for disk in $disk_list; do
        dialog_options+=("$disk" "Disk")
    done

    # Create a whiptail menu for disk selection with a larger box
    disk=$(whiptail --title "Disk Selection" \
        --menu "Choose a disk to use: DON'T USE PARTITIONS, THIS SCRIPT ASSUMES THE USE OF ONE DRIVE!!" 30 80 20 "${dialog_options[@]}" 3>&1 1>&2 2>&3)

    # Check if the user selected a disk
    if [[ -z "$disk" ]]; then
        error "No disk selected!"
    fi

    # Set the selected disk
    DISK="/dev/disk/by-id/$disk"
    printf "%s\n" "${bold}Disk selected: $DISK"
}
