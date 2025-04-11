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

rootpool() {
    printf "%s\n" "${bold}Creating root pool"
    dialog --infobox "Starting install, it will take time, so go GRUB a cup of coffee! ;D" 5 50
    sleep 3
    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Creating ZFS root pool..."; sleep 1
        zpool create -f -o ashift=12 -O acltype=posixacl -O canmount=off -O compression=zstd \
            -O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa \
            -O mountpoint=/ -R $INST_MNT rpool_$INST_UUID $DISK-part2 && echo "50"
        sleep 1
        echo "Finalizing setup..."; sleep 1
        echo "100"
    ) | dialog --gauge "Setting up the ZFS root pool..." 10 70 0

    # Check if the pool was created successfully
    if ! zpool status rpool_$INST_UUID &>/dev/null; then
        error "Error setting up the root pool!"
    fi

    printf "%s\n" "${bold}Root pool created successfully!"
}


createdatasets() {
    printf "%s\n" "${bold}Creating datasets"

    # Start the progress bar
    (
        echo "10"; sleep 1
        zfs create -o mountpoint=none rpool_$INST_UUID/DATA && echo "20"
        zfs create -o mountpoint=none rpool_$INST_UUID/ROOT && echo "40"
        zfs create -o mountpoint=/ -o canmount=noauto rpool_$INST_UUID/ROOT/default && echo "60"
        zfs create -o mountpoint=/home rpool_$INST_UUID/DATA/home && echo "70"
        zfs create -o mountpoint=/var -o canmount=off rpool_$INST_UUID/var && echo "80"
        zfs create rpool_$INST_UUID/var/log && echo "90"
        zfs create -o mountpoint=/var/lib -o canmount=off rpool_$INST_UUID/var/lib && echo "100"
    ) | dialog --gauge "Creating ZFS datasets..." 10 70 0

    # Check if datasets were created successfully
    if ! zfs list rpool_$INST_UUID &>/dev/null; then
        error "Error creating the datasets!"
    fi

    printf "%s\n" "${bold}Datasets created successfully!"
}


mountall() {
    printf "%s\n" "${bold}Mounting everything"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Mounting root dataset..."; sleep 1
        zfs mount rpool_$INST_UUID/ROOT/default && echo "50"
        echo "Mounting all other datasets..."; sleep 1
        zfs mount -a && echo "100"
    ) | dialog --gauge "Mounting ZFS datasets..." 10 70 0

    # Check if all datasets are mounted successfully
    if ! zfs mount | grep -q "rpool_$INST_UUID"; then
        error "Error mounting partitions!"
    fi

    printf "%s\n" "${bold}All datasets mounted successfully!"
}


permissions() {
    printf "%s\n" "${bold}Giving correct permissions to /root and /var/tmp"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Creating /root directory..."; sleep 1
        mkdir $INST_MNT/root && echo "30"
        echo "Creating /var/tmp directory..."; sleep 1
        mkdir -p $INST_MNT/var/tmp && echo "60"
        echo "Setting permissions for /root..."; sleep 1
        chmod 750 $INST_MNT/root && echo "80"
        echo "Setting permissions for /var/tmp..."; sleep 1
        chmod 1777 $INST_MNT/var/tmp && echo "100"
    ) | dialog --gauge "Setting up permissions..." 10 70 0

        # Check if the directories and permissions were set correctly
    if [[ ! -d "$INST_MNT/root" || ! -d "$INST_MNT/var/tmp" ]]; then
        error "Error setting up permissions!"
    fi

    printf "%s\n" "${bold}Permissions set successfully!"
}
permissions || error "Wrong permissions!"

efiswap() {
    printf "%s\n" "${bold}Formatting and mounting boot, EFI system partition, and swap"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Creating swap partition..."; sleep 1
        mkswap -L SWAP ${DISK}-part3 && echo "30"
        echo "Activating swap partition..."; sleep 1
        swapon ${DISK}-part3 && echo "50"
        echo "Formatting EFI partition..."; sleep 1
        mkfs.vfat -n EFI ${DISK}-part1 && echo "70"
        echo "Mounting EFI partition..."; sleep 1
        mkdir -p $INST_MNT/boot/efi && mount -t vfat ${DISK}-part1 $INST_MNT/boot/efi && echo "100"
    ) | dialog --gauge "Setting up EFI and swap partitions..." 10 70 0

    # Check if the EFI partition is mounted
    if ! mount | grep -q "$INST_MNT/boot/efi"; then
        error "EFI partition is not mounted!"
    fi

    printf "%s\n" "${bold}EFI and swap partitions set up successfully!"
}
efiswap || error "Error setting up EFI and swap partitions!"
