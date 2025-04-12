#!/usr/bin/env bash

bold=$(tput setaf 2 bold)
bolderror=$(tput setaf 3 bold)
normal=$(tput sgr0)

error() {
    printf "%s\n" "${bolderror}ERROR:${normal}\\n%s\\n" "$1" >&2
    exit 1
}

# Ensure dialog is installed
if ! command -v dialog &> /dev/null; then
    echo "dialog is not installed. Installing it now..."
    pacman -Sy --noconfirm dialog || { echo "Failed to install dialog. Please install it manually."; exit 1; }
fi

# Prompt the user to select a desktop environment
select_desktop_environment() {
    # Prompt the user to select a desktop environment
    dialog --clear --title "Desktop Environment Selection" \
        --menu "Choose a desktop environment to install:" 15 60 6 \
        1 "Base (No Desktop Environment)" \
        2 "Cinnamon" \
        3 "MATE" \
        4 "KDE Plasma (HIGHLY EXPERIMENTAL! May freeze the system!)" \
        5 "LXQt" \
        6 "XFCE" 2> /tmp/de_choice

    # Read the user's choice
    DE_CHOICE=$(< /tmp/de_choice)
    rm /tmp/de_choice

    # Map the choice to the corresponding pkglist file
    case $DE_CHOICE in
        1) PKGLIST="pkglist-base.txt" ;;
        2) PKGLIST="pkglist-cinnamon.txt" ;;
        3) PKGLIST="pkglist-mate.txt" ;;
        4) PKGLIST="pkglist-plasma.txt" ;;
        5) PKGLIST="pkglist-lxqt.txt" ;;
        6) PKGLIST="pkglist-xfce.txt" ;;
        *) error "Invalid choice or no selection made!" ;;
    esac

    # Update the pkglist.txt symlink to point to the selected pkglist
    ln -sf "misc/$PKGLIST" "misc/pkglist.txt" || error "Failed to update pkglist.txt!"

    printf "%s\n" "${bold}Desktop environment selected: $PKGLIST"
    printf "%s\n" "${bold}pkglist.txt updated successfully!"
}