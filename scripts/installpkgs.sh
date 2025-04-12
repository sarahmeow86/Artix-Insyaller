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


installpkgs() {
    printf "%s\n" "${bold}Installing packages"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Installing base packages..."; sleep 1
        basestrap $INST_MNT - < misc/pkglist.txt && echo "50"
        echo "Installing kernel and ZFS packages..."; sleep 1
        basestrap $INST_MNT $INST_LINVAR ${INST_LINVAR}-headers linux-firmware zfs-dkms-git zfs-utils-git && echo "80"
        rm misc/pkglist.txt
        echo "Copying pacman configuration..."; sleep 1
        rm -rf $INST_MNT/etc/pacman.d
        rm $INST_MNT/etc/pacman.conf
        cp -r /etc/pacman.d $INST_MNT/etc
        cp /etc/pacman.conf $INST_MNT/etc && echo "100"
    ) | dialog --gauge "Installing packages..." 10 70 0

    # Check if the packages were installed successfully
    if [[ $? -ne 0 ]]; then
        error "Error installing packages!"
    fi

    printf "%s\n" "${bold}Packages installed successfully!"
}
