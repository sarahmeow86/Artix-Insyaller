#!/usr/bin/env bash
bold=$(tput setaf 2 bold)      # makes text bold and sets color to 2
bolderror=$(tput setaf 3 bold) # makes text bold and sets color to 3
normal=$(tput sgr0)            # resets text settings back to normal

fstab() {
    printf "%s\n" "${bold}Generating fstab"

    # Start the progress bar
    (
        echo "10"; sleep 1
        
        # Add the root partition to fstab if the filesystem is not ZFS
        if [[ $FILESYSTEM != "zfs" ]]; then
            echo "Adding root partition to fstab..."; sleep 1
            echo "UUID=$(blkid -s UUID -o value ${DISK}-part2) / $FILESYSTEM defaults 0 1" >> $INST_MNT/etc/fstab && echo "40"
        fi
        
        echo "Adding EFI partition to fstab..."; sleep 1
        echo "UUID=$(blkid -s UUID -o value ${DISK}-part1) /boot/efi vfat umask=0022,fmask=0022,dmask=0022 0 1" >> $INST_MNT/etc/fstab && echo "70"

        echo "Adding swap partition to fstab..."; sleep 1
        echo "UUID=$(blkid -s UUID -o value ${DISK}-part3) none swap defaults 0 0" >> $INST_MNT/etc/fstab && echo "100"
    ) | dialog --gauge "Generating fstab..." 10 70 0

    # Check if fstab was generated successfully
    if [[ ! -f "$INST_MNT/etc/fstab" ]]; then
        error "Error generating fstab!"
    fi

    printf "%s\n" "${bold}fstab generated successfully!"
}

mkinitram() {
    printf "%s\n" "${bold}Creating new mkinitcpio configuration and regenerating initramfs"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Backing up existing mkinitcpio.conf..."; sleep 1
        mv $INST_MNT/etc/mkinitcpio.conf $INST_MNT/etc/mkinitcpio.conf.back && echo "30"
        echo "Writing new mkinitcpio.conf..."; sleep 1
        tee $INST_MNT/etc/mkinitcpio.conf <<EOF
HOOKS=(base udev autodetect modconf block keyboard zfs filesystems)
EOF
        echo "Regenerating initramfs..."; sleep 1
        artix-chroot $INST_MNT /bin/bash -c mkinitcpio -P && echo "100"
    ) | dialog --gauge "Creating new mkinitcpio configuration..." 10 70 0

    # Check if the initramfs was regenerated successfully
    if [[ $? -ne 0 ]]; then
        error "Error creating new mkinitcpio!"
    fi

    printf "%s\n" "${bold}mkinitcpio configuration and initramfs created successfully!"
}


finishtouch() {
    printf "%s\n" "${bold}Finalizing installation"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Setting hostname..."; sleep 1
        echo $INST_HOST > $INST_MNT/etc/hostname && echo "20"
        echo "Setting timezone..."; sleep 1
        ln -sf $INST_TZ $INST_MNT/etc/localtime && echo "40"
        echo "Generating locale..."; sleep 1
        echo "en_US.UTF-8 UTF-8" >> $INST_MNT/etc/locale.gen
        echo "LANG=en_US.UTF-8" >> $INST_MNT/etc/locale.conf
        artix-chroot $INST_MNT /bin/bash -c locale-gen && echo "60"
    ) | dialog --gauge "Finalizing installation..." 10 70 0

    printf "%s\n" "${bold}System configuration completed successfully!"
}

prepare_chroot() {
    printf "%s\n" "${bold}Preparing chroot environment"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Preparing installation scripts..."; sleep 1
        mkdir -p $INST_MNT/install
        # Copy the zfs-openrc package only if ZFS is selected
        if [[ $FILESYSTEM == "zfs" ]]; then
            echo "Copying ZFS OpenRC package..."; sleep 1
            cp misc/zfs-openrc-20241023-1-any.pkg.tar.zst $INST_MNT/install/ || error "Failed to copy ZFS OpenRC package!"
        fi
        cp misc/locale.gen $INST_MNT/install
        awk -v n=5 -v s="INST_UUID=${INST_UUID}" 'NR == n {print s} {print}' scripts/artix-chroot.sh > scripts/artix-chroot-new.sh
        awk -v n=6 -v s="DISK=${DISK}" 'NR == n {print s} {print}' scripts/artix-chroot-new.sh > scripts/artix-chroot-new2.sh
        rm scripts/artix-chroot-new.sh
        mv scripts/artix-chroot-new2.sh $INST_MNT/install/artix-chroot.sh
        chmod +x $INST_MNT/install/artix-chroot.sh && echo "80"
        echo "Chroot environment prepared successfully."; sleep 1
    ) | dialog --gauge "Preparing chroot environment..." 10 70 0
}

run_chroot() {
    printf "%s\n" "${bold}Running chroot script"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Running final chroot script..."; sleep 1
        artix-chroot $INST_MNT /bin/bash /install/artix-chroot.sh && echo "100"
    ) | dialog --gauge "Running chroot script..." 10 70 0

    if [[ $? -ne 0 ]]; then
        error "Error running chroot script!"
    fi

    printf "%s\n" "${bold}Chroot script executed successfully!"
}