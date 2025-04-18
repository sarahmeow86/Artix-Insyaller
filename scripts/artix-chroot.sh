#!/usr/bin/env bash
bold=$(tput setaf 2 bold)      # makes text bold and sets color to 2
bolderror=$(tput setaf 3 bold) # makes text bold and sets color to 3
normal=$(tput sgr0)            # resets text settings back to normal

error() {
    printf "%s\n" "${bolderror}ERROR:${normal}\\n%s\\n" "$1" >&2
    exit 1
}

# Function to detect the root filesystem
detect_root_filesystem() {
    ROOT_FS=$(findmnt -n -o FSTYPE /)
    if [[ -z "$ROOT_FS" ]]; then
        error "Failed to detect the root filesystem!"
    fi
    printf "%s\n" "${bold}Detected root filesystem: $ROOT_FS"
}

# Function to install and configure GRUB
install_grub() {
    dialog --infobox "Installing and configuring GRUB bootloader..." 5 50
    (
        echo "10"; sleep 1
        echo "Installing GRUB and related packages..."; sleep 1
        pacman -S --noconfirm grub os-prober efibootmgr || error "Failed to install GRUB packages!" && echo "50"
        echo "Installing GRUB to EFI system partition..."; sleep 1
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB || error "Failed to install GRUB!" && echo "80"
        echo "Generating GRUB configuration file..."; sleep 1
        grub-mkconfig -o /boot/grub/grub.cfg || error "Failed to generate GRUB configuration!" && echo "100"
    ) | dialog --gauge "Installing GRUB bootloader..." 10 70 0

    dialog --msgbox "GRUB has been installed and configured successfully!" 10 50
}

# Function to install and configure ZFSBootMenu
install_zfsbootmenu() {
    dialog --infobox "Installing ZFSBootMenu..." 5 50
    (
        echo "10"; sleep 1
        echo "Creating ZFSBootMenu directory..."; sleep 1
        mkdir -p /boot/efi/EFI/BOOT && echo "30"
        echo "Downloading ZFSBootMenu EFI file..."; sleep 1
        curl -L https://get.zfsbootmenu.org/efi -o /boot/efi/EFI/BOOT/BOOTX64.EFI && echo "70"
        echo "Configuring EFI boot entry..."; sleep         efibootmgr --disk $(findmnt -n -o SOURCE /boot/efi | sed 's/[0-9]*$//') --part 1 --create --label "ZFSBootMenu" \
            --loader '\EFI\BOOT\BOOTX64.EFI' \
            --unicode "spl_hostid=$(hostid) zbm.timeout=3 zbm.prefer=zroot zbm.import_policy=hostid" --verbose && echo "100"
    ) | dialog --gauge "Installing ZFSBootMenu..." 10 70 0

    dialog --msgbox "ZFSBootMenu has been installed and configured successfully!" 10 50
}

zfsservice() {
    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Installing ZFS OpenRC package..."; sleep 1
        pacman -U --noconfirm /install/zfs-openrc-20241023-1-any.pkg.tar.zst && echo "30"
        echo "Adding zfs-import service to boot..."; sleep 1
        rc-update add zfs-import boot && echo "50"
        echo "Adding zfs-load-key service to boot..."; sleep 1
        rc-update add zfs-load-key boot && echo "60"
        echo "Adding zfs-share service to boot..."; sleep 1
        rc-update add zfs-share boot && echo "70"
        echo "Adding zfs-zed service to boot..."; sleep 1
        rc-update add zfs-zed boot && echo "80"
        echo "Adding zfs-mount service to boot..."; sleep 1
        rc-update add zfs-mount boot && echo "100"
    ) | dialog --gauge "Configuring ZFS services..." 10 70 0

    # Check if the ZFS services were configured successfully
    if [[ $? -ne 0 ]]; then
        error "Error configuring ZFS services!"
    fi

    printf "%s\n" "${bold}ZFS services configured successfully!"
}

cachefile() {
    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Setting ZFS cachefile..."; slee        zpool set cachefile=/etc/zfs/zpool.cache rpool_$INST_UUID && echo "100"
    ) | dialog --gauge "Creating ZFS cachefile for initcpio..." 10 70 0

    # Check if the cachefile was created successfully
    if [[ $? -ne 0 ]]; then
        error "Failed to generate cachefile!"
    fi

    printf "%s\n" "${bold}Cachefile created successfully!"
}

regenerate_initcpio() {
    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Backing up existing initramfs..."; sleep 1
        cp /boot/initramfs-linux.img /boot/initramfs-linux.img.bak && echo "30"
        echo "Regenerating initramfs..."; sleep 1
        mkinitcpio -P && echo "100"
    ) | dialog --gauge "Regenerating initramfs..." 10 70 0

    # Check if the initramfs was regenerated successfully
    if [[ $? -ne 0 ]]; then
        error "Error regenerating initramfs!"
    fi

    printf "%s\n" "${bold}Initramfs regenerated successfully!"
}


# Function to configure the bootloader based on the detected filesystem
configure_bootloader() {
    detect_root_filesystem
    if [[ "$ROOT_FS" == "zfs" ]]; then
        install_zfsbootmenu && zfsservice && cachefile && regenerate_initcpio || error "Error installing ZFSBootMenu!"
    else
        install_grub || error "Error installing GRUB!"
    fi
}

# Other functions remain unchanged
addlocales() {
    locale_list=$(grep -v '^$' /install/locale.gen | awk '{print $1}' | sort)
    dialog_options=()
    while IFS= read -r locale; do
        dialog_options+=("$locale" "$locale")
    done <<< "$locale_list"

    alocale=$(dialog --clear --title "Locale Selection" \
        --menu "Choose your locale from the list:" 20 70 15 "${dialog_options[@]}" 3>&1 1>&2 2>&3)

    if [[ -z "$alocale" ]]; then
        printf "%s\n" "No locale selected. Skipping locale configuration."
        return 0
    fi

    sed -i "s/^#\s*\($alocale\)/\1/" /etc/locale.gen
    locale-gen || error "Failed to generate locale!"
    printf "%s\n" "${bold}Locale '$alocale' has been added and generated successfully!"
}
addlocales || error "Cannot generate locales"

setlocale() {
    printf "%s\n" "${bold}Setting locale to $alocale"
    echo "LANG=$alocale" > /etc/locale.conf || error "Cannot set locale!"
}
setlocale || error "Cannot set locale"

USERADD() {
    username=$(dialog --clear --title "Create User Account" \
        --inputbox "Enter the non-root username:" 10 50 3>&1 1>&2 2>&3)

    if [[ -z "$username" ]]; then
        error "No username provided!"
    fi

    useradd -m -G audio,video,wheel "$username" || error "Failed to add user $username"

    password=$(dialog --clear --title "Set User Password" \
        --passwordbox "Enter the password for $username:" 10 50 3>&1 1>&2 2>&3)

    if [[ -z "$password" ]]; then
        error "No password provided!"
    fi

    echo "$username:$password" | chpasswd || error "Failed to set password for $username"
    printf "%s\n" "${bold}User $username has been created successfully!"
}
USERADD || error "Error adding user to your install"

passwdroot() {
    root_password=$(dialog --clear --title "Set Root Password" \
        --passwordbox "Enter the desired password for the root user:" 10 50 3>&1 1>&2 2>&3)

    if [[ -z "$root_password" ]]; then
        error "No password provided for root!"
    fi

    confirm_password=$(dialog --clear --title "Confirm Root Password" \
        --passwordbox "Re-enter the password for the root user:" 10 50 3>&1 1>&2 2>&3)

    if [[ "$root_password" != "$confirm_password" ]]; then
        error "Passwords do not match!"
    fi

    echo "root:$root_password" | chpasswd || error "Failed to set root password!"
    printf "%s\n" "${bold}Root password has been set successfully!"
}
passwdroot || error "Error setting root password!"

enableservices() {
    # Start the progress bar
    (
        echo "10"; sleep 1
        echo "Enabling NetworkManager service..."; sleep 1
        rc-update add NetworkManager default && echo "20"

        # Check for display managers and enable the appropriate one
        if command -v sddm &> /dev/null; then
            echo "Enabling SDDM service..."; sleep 1
            rc-update add sddm default && echo "30"
        elif command -v lightdm &> /dev/null; then
            echo "Enabling LightDM service..."; sleep 1
            rc-update add lightdm default && echo "30"
        else
            echo "No display manager (SDDM or LightDM) found!"
        fi

        echo "Enabling D-Bus service..."; sleep 1
        rc-update add dbus default && echo "40"
        echo "Enabling Metalog service..."; sleep 1
        rc-update add metalog default && echo "50"
        echo "Enabling ACPID service..."; sleep 1
        rc-update add acpid default && echo "60"
        echo "Enabling Bluetooth service..."; sleep 1
        rc-update add bluetoothd default && echo "70"
        echo "Enabling Cronie service..."; sleep 1
        rc-update add cronie default && echo "80"
        echo "Enabling Elogind service..."; sleep 1
        rc-update add elogind boot && echo "100"
    ) | dialog --gauge "Enabling system services..." 10 70 0

    # Check if the services were enabled successfully
    if [[ $? -ne 0 ]]; then
        error "Error enabling services!"
    fi

    printf "%s\n" "${bold}Services enabled successfully!"
}

#Configure the bootloader based on the detected filesystem
configure_bootloader

# Display a message box indicating the installation is complete
dialog --title "Installation Complete" --msgbox "\
${bold}Finish!${normal}\n\n\
The installation process has been completed successfully." 10 50