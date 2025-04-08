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
selectdisk || error     "Cannot select disk"

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
    partprobe || true

    printf "%s\n" "${bold}Partitioning completed successfully!"
}
partdrive || error "Error setting up the drive!"
