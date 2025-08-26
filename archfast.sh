#!/bin/bash

LOG_FILE="/tmp/archfast.log"
rm -f "$LOG_FILE"

# ==============================================================================
#                          Interactive Prompts (Cleaned)
# ==============================================================================

if [ ! -f /usr/bin/pacstrap ]; then whiptail --title "Error" --msgbox "Must be run from Arch ISO." 8 78; exit 1; fi
if [[ "$(id -u)" != "0" ]]; then whiptail --title "Error" --msgbox "Must be run as root." 8 78; exit 1; fi
if [[ -f /var/lib/pacman/db.lck ]]; then whiptail --title "Error" --msgbox "Pacman is locked." 8 78; exit 1; fi
if ! ping -c 1 archlinux.org &> /dev/null; then whiptail --title "Error" --msgbox "No internet connection." 8 78; exit 1; fi

userinfo () {
    pacman -S --noconfirm --needed whiptail &> /dev/null
    USERNAME=$(whiptail --title "User Account Setup" --inputbox "Enter a username:" 10 60 archuser 3>&1 1>&2 2>&3) || exit 1
    export USERNAME
    
    local password_match=false
    while [ "$password_match" = false ]; do
        PASSWORD=$(whiptail --title "Password" --passwordbox "Enter password for $USERNAME:" 10 60 3>&1 1>&2 2>&3) || exit 1
        PASSWORD2=$(whiptail --title "Password" --passwordbox "Re-enter password:" 10 60 3>&1 1>&2 2>&3) || exit 1
        if [ "$PASSWORD" == "$PASSWORD2" ]; then password_match=true; else whiptail --title "Mismatch" --msgbox "Passwords do not match." 8 78; fi
    done
    export PASSWORD
    
    NAME_OF_MACHINE=$(whiptail --title "Hostname" --inputbox "Enter a hostname:" 10 60 myarch 3>&1 1>&2 2>&3) || exit 1
    export NAME_OF_MACHINE
}

diskpart () {
    declare -a disk_list=();
    while read -r line; do disk_list+=($(echo "$line" | awk '{print $1, "(" $2 ")"}')); done < <(lsblk -o KNAME,SIZE -d | grep -E "sd|hd|vd|nvme|mmcblk")
    DISK=$(whiptail --title "Disk Selection" --menu "Select install disk:" 20 78 12 "${disk_list[@]}" 3>&1 1>&2 2>&3) || exit 1
    export DISK="/dev/${DISK}"
}

filesystem () {
    FS_CHOICE=$(whiptail --title "Filesystem" --radiolist "Select a filesystem:" 15 60 3 "btrfs" "" ON "ext4" "" OFF "luks" "" OFF 3>&1 1>&2 2>&3) || exit 1
    export FS=${FS_CHOICE}
    if [[ "${FS}" == "luks" ]]; then
        LUKS_PASSWORD=$(whiptail --title "Encryption" --passwordbox "Enter LUKS password:" 10 60 3>&1 1>&2 2>&3) || exit 1
        export LUKS_PASSWORD
    fi
}
timezone () { export TIMEZONE=$(whiptail --title "Timezone" --inputbox "Enter your timezone (e.g. America/New_York):" 10 60 "Etc/UTC" 3>&1 1>&2 2>&3) || exit 1; }
keymap () { export KEYMAP=$(whiptail --title "Keyboard Layout" --inputbox "Enter your keymap (e.g. us):" 10 60 "us" 3>&1 1>&2 2>&3) || exit 1; }

# ==============================================================================
#                             Main Installation Function
# ==============================================================================

perform_installation() {
    
    {
        set -e 

        echo "--- Starting Installation ---"
        echo "Configuration:"
        echo "  User: $USERNAME"
        echo "  Hostname: $NAME_OF_MACHINE"
        echo "  Disk: $DISK"
        echo "  Filesystem: $FS"
        echo "-----------------------------"

        echo "--> Setting up mirrors..."
        iso=$(curl -4s ifconfig.io/country_code) || iso="US"
        timedatectl set-ntp true
        pacman -Sy >/dev/null
        pacman -S --noconfirm --needed reflector
        reflector -a 48 -c "$iso" --sort rate --save /etc/pacman.d/mirrorlist

        echo "--> Partitioning disk..."
        umount -A --recursive /mnt || true
        sgdisk -Z "${DISK}"
        sgdisk -n 1::+1M --typecode=1:ef02 "${DISK}"
        sgdisk -n 2::+1GiB --typecode=2:ef00 "${DISK}"
        sgdisk -n 3::-0 --typecode=3:8300 "${DISK}"
        partprobe "${DISK}"

        echo "--> Creating filesystems..."
        if [[ "${DISK}" =~ "nvme" || "${DISK}" =~ "mmcblk" ]]; then p2=${DISK}p2; p3=${DISK}p3; else p2=${DISK}2; p3=${DISK}3; fi
        mkfs.fat -F32 "${p2}"
        if [[ "${FS}" == "ext4" ]]; then
            mkfs.ext4 -F "${p3}"
            mount "${p3}" /mnt
        else # For btrfs or luks
            if [[ "${FS}" == "luks" ]]; then
                echo -n "${LUKS_PASSWORD}" | cryptsetup luksFormat "${p3}" -
                echo -n "${LUKS_PASSWORD}" | cryptsetup open "${p3}" ROOT
                mkfs.btrfs -f /dev/mapper/ROOT
                mount /dev/mapper/ROOT /mnt
            else
                mkfs.btrfs -f "${p3}"
                mount "${p3}" /mnt
            fi
            btrfs subvolume create /mnt/@
            btrfs subvolume create /mnt/@home
            umount /mnt
            mount -o noatime,compress=zstd,subvol=@ /dev/mapper/ROOT 2>/dev/null || mount -o noatime,compress=zstd,subvol=@ "${p3}" /mnt
            mkdir /mnt/home
            mount -o noatime,compress=zstd,subvol=@home /dev/mapper/ROOT 2>/dev/null || mount -o noatime,compress=zstd,subvol=@home "${p3}" /mnt
        fi
        mkdir -p /mnt/boot
        mount "${p2}" /mnt/boot

        echo "--> Installing base system (this will take a while)..."
        pacstrap /mnt base base-devel linux-lts linux-firmware efibootmgr

        echo "--> Generating fstab..."
        genfstab -U /mnt >> /mnt/etc/fstab

        echo "--> Configuring system in chroot..."
        arch-chroot /mnt /bin/bash -c "
            set -e
            pacman -S --noconfirm networkmanager grub
            systemctl enable NetworkManager
            ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
            hwclock --systohc
            sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
            locale-gen
            echo 'LANG=en_US.UTF-8' > /etc/locale.conf
            echo 'KEYMAP=${KEYMAP}' > /etc/vconsole.conf
            echo '${NAME_OF_MACHINE}' > /etc/hostname
            sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
            useradd -m -G wheel -s /bin/bash '${USERNAME}'
            echo '${USERNAME}:${PASSWORD}' | chpasswd
            grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH --recheck
            grub-mkconfig -o /boot/grub/grub.cfg
        "

        echo "--------------------------------"
        echo "--- Installation Complete! ---"
        echo "--------------------------------"
    } &>> "$LOG_FILE"
}

# ==============================================================================
#                                  Main Execution
# ==============================================================================
clear
userinfo
clear; diskpart
clear; filesystem
clear; timezone
clear; keymap
clear

SUMMARY="
    User:           ${USERNAME}
    Hostname:       ${NAME_OF_MACHINE}
    Disk:           ${DISK}
    Filesystem:     ${FS}
"

if (whiptail --title "FINAL CONFIRMATION" --yesno \
"Review your settings. Continuing will format ${DISK} and install Arch Linux.\n\n${SUMMARY}\n\nAre you sure you want to proceed?" 20 78 3>&1 1>&2 2>&3); then
    
    perform_installation &
    INSTALL_PID=$!

    tail -f "$LOG_FILE" | whiptail --title "Installation in Progress..." --textbox /dev/stdin 25 80

    wait $INSTALL_PID
    INSTALL_EXIT_CODE=$?

    if [ $INSTALL_EXIT_CODE -eq 0 ]; then
        whiptail --title "Success" --msgbox "Installation complete! The system will now reboot. Remove the installation media." 10 78
        umount -A --recursive /mnt
        reboot
    else
        whiptail --title "Failure" --msgbox "Installation failed. Please review the log file for errors:\n\n${LOG_FILE}" 10 78
    fi

else
    echo "Installation canceled by user."
    exit 1
fi