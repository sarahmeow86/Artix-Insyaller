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

fstab() {
    printf "%s\n" "${bold}Generating fstab"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Adding EFI partition to fstab..."; sleep 1
        echo "UUID=$(blkid -s UUID -o value ${DISK}-part1) /boot/efi vfat umask=0022,fmask=0022,dmask=0022 0 1" >> $INST_MNT/etc/fstab && echo "50"
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
        echo "Preparing installation scripts..."; sleep 1
        mkdir $INST_MNT/install
        cp misc/zfs-openrc-20241023-1-any.pkg.tar.zst $INST_MNT/install/
        awk -v n=5 -v s="INST_UUID=${INST_UUID}" 'NR == n {print s} {print}' misc/artix-chroot.sh >  misc/artix-chroot-new.sh
        awk -v n=6 -v s="DISK=${DISK}" 'NR == n {print s} {print}' misc/artix-chroot-new.sh >  misc/artix-chroot-new2.sh
        rm misc/artix-chroot-new.sh
        mv misc/artix-chroot-new2.sh $INST_MNT/install/artix-chroot.sh
        chmod +x $INST_MNT/install/artix-chroot.sh && echo "80"
        echo "Running final chroot script..."; sleep 1
        artix-chroot $INST_MNT /bin/bash /install/artix-chroot.sh && echo "100"
    ) | dialog --gauge "Finalizing installation..." 10 70 0
}
