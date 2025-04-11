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


chaoticaur() {
    printf "%s\n" "## Installing Chaotic AUR ##"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Receiving key for Chaotic AUR..."; sleep 1
        pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com && echo "30"
        echo "Signing key for Chaotic AUR..."; sleep 1
        pacman-key --lsign-key 3056513887B78AEB && echo "50"
        echo "Updating package database..."; sleep 1
        pacman -Sy && echo "70"
        echo "Installing Chaotic AUR keyring..."; sleep 1
        yes | LC_ALL=en_US.UTF-8 pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' && echo "85"
        echo "Installing Chaotic AUR mirrorlist..."; sleep 1
        yes | LC_ALL=en_US.UTF-8 pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' && echo "100"
    ) | dialog --gauge "Installing Chaotic AUR..." 10 70 0

    # Check if the installation was successful
    if [[ $? -ne 0 ]]; then
        error "Error installing Chaotic AUR!"
    fi

    printf "%s\n" "${bold}Chaotic AUR installed successfully!"
}
chaoticaur || error "Error installing Chaotic AUR!"


addrepo() {
    printf "%s\n" "## Adding repos to /etc/pacman.conf."

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Installing artix-archlinux-support package..."; sleep 1
        pacman -Sy --noconfirm artix-archlinux-support && echo "50"
        echo "Copying pacman.conf to /etc/..."; sleep 1
        cp misc/pacman.conf /etc/ && echo "100"
    ) | dialog --gauge "Adding repositories to pacman.conf..." 10 70 0

    # Check if the operation was successful
    if [[ $? -ne 0 ]]; then
        error "Error adding repos!"
    fi

    printf "%s\n" "${bold}Repositories added successfully!"
}
addrepo || error "Error adding repos!"


installzfs() {
    printf "%s\n" "${bold}# Installing the ZFS modules"

    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Updating package database..."; sleep 1
        pacman -Sy --noconfirm --needed zfs-dkms-git zfs-utils-git gptfdisk && echo "50"
        echo "Installing ZFS OpenRC package..."; sleep 1
        pacman -U --noconfirm misc/zfs-openrc-20241023-1-any.pkg.tar.zst && echo "70"
        echo "Loading ZFS kernel module..."; sleep 1
        modprobe zfs && echo "80"
        echo "Enabling ZFS services..."; sleep 1
        rc-update add zfs-zed boot && rc-service zfs-zed start && echo "100"
    ) | dialog --gauge "Installing ZFS modules..." 10 70 0

    # Check if ZFS was installed successfully
    if ! modinfo zfs &>/dev/null; then
        error "Error installing ZFS!"
    fi

    printf "%s\n" "${bold}Done!"
}
installzfs || error "Error installing ZFS!"
