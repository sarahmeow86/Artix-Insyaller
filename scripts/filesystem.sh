#!/usr/bin/env bash
choose_filesystem() {
    dialog --clear --title "Filesystem Selection" \
        --menu "Choose your preferred filesystem:" 15 50 4 \
        1 "ext4" \
        2 "btrfs" \
        3 "xfs" \
        4 "zfs" 2> /tmp/fs_choice

    FS_CHOICE=$(< /tmp/fs_choice)
    rm /tmp/fs_choice

    case $FS_CHOICE in
        1) FILESYSTEM="ext4" ;;
        2) FILESYSTEM="btrfs" ;;
        3) FILESYSTEM="xfs" ;;
        4) FILESYSTEM="zfs" ;;
        *) error "Invalid choice or no selection made!" ;;
    esac

    dialog --msgbox "You selected $FILESYSTEM as your filesystem." 10 50
}


setup_filesystem() {
    case $FILESYSTEM in
        ext4)
            mkfs.ext4 /dev/disk/by-id/$disk-part2 || error "Failed to format partition as ext4!"
            mount /dev/disk/by-id/$disk-part2 $INST_MNT || error "Failed to mount ext4 filesystem!"
            ;;
        btrfs)
            mkfs.btrfs /dev/disk/by-id/$disk-part2 || error "Failed to format partition as btrfs!"
            mount /dev/disk/by-id/$disk-part2 $INST_MNT || error "Failed to mount btrfs filesystem!"

            # Create Btrfs subvolumes
            btrfs subvolume create $INST_MNT/@ || error "Failed to create root subvolume!"
            btrfs subvolume create $INST_MNT/@home || error "Failed to create home subvolume!"
            btrfs subvolume create $INST_MNT/@cache || error "Failed to create var subvolume!"
            btrfs subvolume create $INST_MNT/@log || error "Failed to create var log subvolume!"
            # Unmount and remount with subvolumes
            umount $INST_MNT || error "Failed to unmount Btrfs filesystem!"
            mount -o subvol=@ /dev/disk/by-id/$disk-part2 $INST_MNT || error "Failed to mount root subvolume!"
            mkdir -p $INST_MNT/{home,var} || error "Failed to create mount points!"
            mkdir -p $INST_MNT/var/cache || error "Failed to create var cache mount point!"
            mkdir -p $INST_MNT/var/log || error "Failed to create var log mount point!"
            mount -o subvol=@home /dev/disk/by-id/$disk-part2 $INST_MNT/home || error "Failed to mount home subvolume!"
            mount -o subvol=@cache /dev/disk/by-id/$disk-part2 $INST_MNT/var/cache || error "Failed to mount var subvolume!"
            mount -o subvol=@log /dev/disk/by-id/$disk-part2 $INST_MNT/var/log || error "Failed to mount var subvolume!"
            ;;
        xfs)
            mkfs.xfs /dev/disk/by-id/$disk-part2 || error "Failed to format partition as xfs!"
            ;;
        zfs)
            rootpool || error "Error creating ZFS root pool!"
            createdatasets || error "Error creating ZFS datasets!"
            mountall || error "Error mounting ZFS datasets!"
            ;;
        *)
            error "Unsupported filesystem selected!"
            ;;
    esac
}

