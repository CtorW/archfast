#!/bin/bash

LOG_FILE="archsetup.txt"
rm -f "$LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

# ==============================================================================
#                          Initial System Checks
# ==============================================================================
if [ ! -f /usr/bin/pacstrap ]; then
    echo "ERROR: This script must be run from an Arch Linux ISO environment. Exiting."
    # Use whiptail for user-facing errors even before main installation
    whiptail --title "Startup Error" --msgbox "This script must be run from an Arch Linux ISO environment. Exiting." 10 60
    exit 1
fi
root_check() {
    if [[ "$(id -u)" != "0" ]]; then
        whiptail --title "Startup Error" --msgbox "This script must be run as the 'root' user. Exiting." 10 60
        exit 1
    fi
}
pacman_check() {
    if [[ -f /var/lib/pacman/db.lck ]]; then
        whiptail --title "Startup Error" --msgbox "Pacman is locked. If you are sure no other package manager is running, remove /var/lib/pacman/db.lck and try again." 12 78
        exit 1
    fi
}
root_check
pacman_check

# ==============================================================================
#                          Interactive Prompts (using Whiptail TUI)
# ==============================================================================
userinfo () {
    echo "Checking for whiptail..."
    pacman -S --noconfirm --needed whiptail &>> "$LOG_FILE"
    
    USERNAME=$(whiptail --title "User Account Setup" --inputbox \
    "Please enter your desired username.\n\n(Use lowercase letters, no spaces. e.g., 'alex')" 10 60 archuser 3>&1 1>&2 2>&3)
    if [ $? != 0 ]; then echo "User canceled."; exit 1; fi
    export USERNAME

    local password_match=false
    while [ "$password_match" = false ]; do
        PASSWORD=$(whiptail --title "Set User Password" --passwordbox "Enter a password for user '$USERNAME':" 10 60 3>&1 1>&2 2>&3)
        if [ $? != 0 ]; then echo "User canceled."; exit 1; fi
        
        PASSWORD2=$(whiptail --title "Confirm User Password" --passwordbox "Please re-enter the password to confirm:" 10 60 3>&1 1>&2 2>&3)
        if [ $? != 0 ]; then echo "User canceled."; exit 1; fi

        if [ "$PASSWORD" == "$PASSWORD2" ]; then
            password_match=true
        else
            whiptail --title "Password Mismatch" --msgbox "The passwords you entered do not match. Please try again." 10 60
        fi
    done
    export PASSWORD
    
    NAME_OF_MACHINE=$(whiptail --title "System Hostname" --inputbox \
    "Please enter a hostname for this machine.\n\n(This is how it will appear on a network. e.g., 'arch-desktop')" 10 60 myarch 3>&1 1>&2 2>&3)
    if [ $? != 0 ]; then echo "User canceled."; exit 1; fi
    export NAME_OF_MACHINE
}

diskpart () {
    declare -a disk_list=()
    while read -r line; do
        disk_name=$(echo "$line" | awk '{print $1}')
        disk_size=$(echo "$line" | awk '{print $2}')
        disk_model=$(echo "$line" | awk '{print $3}')
        disk_list+=("${disk_name}" "(${disk_size}) ${disk_model}")
    done < <(lsblk -o KNAME,SIZE,MODEL -d | grep -E "sd|hd|vd|nvme|mmcblk")

    if [ ${#disk_list[@]} -eq 0 ]; then
        whiptail --title "Disk Error" --msgbox "No suitable disks found. Cannot continue." 10 60
        exit 1
    fi

    DISK=$(whiptail --title "Select Target Installation Disk" --menu \
    "Please select the disk to install Arch Linux onto.\n\n[ DANGER ]: All data on the selected disk will be PERMANENTLY DELETED." 20 78 12 "${disk_list[@]}" 3>&1 1>&2 2>&3)
    if [ $? != 0 ]; then echo "User canceled."; exit 1; fi
    export DISK="/dev/${DISK}"

    if (whiptail --title "Storage Optimization" --yesno \
    "Is the selected disk an SSD?\n\n(Choosing 'Yes' will apply SSD-specific mount options for better performance and longevity.)" 10 60 3>&1 1>&2 2>&3); then
        export MOUNT_OPTIONS="noatime,compress=zstd,ssd,commit=120"
    else
        export MOUNT_OPTIONS="noatime,compress=zstd,commit=120"
    fi
}

filesystem () {
    FS_CHOICE=$(whiptail --title "Filesystem Selection" --radiolist \
    "Choose the filesystem for your root partition.\n(Use arrow keys and SPACE to select)" 15 78 3 \
    "btrfs" "Modern filesystem with compression & snapshots" ON \
    "ext4"  "Traditional, stable, and widely-used" OFF \
    "luks"  "Btrfs with full-disk encryption for security" OFF 3>&1 1>&2 2>&3)
    if [ $? != 0 ]; then echo "User canceled."; exit 1; fi
    export FS=${FS_CHOICE}
    
    if [[ "${FS}" == "luks" ]]; then
        local luks_match=false
        while [ "$luks_match" = false ]; do
            LUKS_PASSWORD=$(whiptail --title "Set Encryption Password" --passwordbox "Enter a strong password for disk encryption:" 10 60 3>&1 1>&2 2>&3)
            if [ $? != 0 ]; then echo "User canceled."; exit 1; fi
            LUKS_PASSWORD2=$(whiptail --title "Confirm Encryption Password" --passwordbox "Re-enter the password to confirm:" 10 60 3>&1 1>&2 2>&3)
            if [ $? != 0 ]; then echo "User canceled."; exit 1; fi

            if [[ "$LUKS_PASSWORD" == "$LUKS_PASSWORD2" ]]; then
                luks_match=true
            else
                whiptail --title "Password Mismatch" --msgbox "Passwords do not match. Please try again." 10 60
            fi
        done
        export LUKS_PASSWORD
    fi
}

timezone () {
    TIME_ZONE=$(curl --fail https://ipapi.co/timezone 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "${TIME_ZONE}" ]; then
        if (whiptail --title "Timezone Confirmation" --yesno "Your timezone appears to be '${TIME_ZONE}'.\n\nIs this correct?" 10 60 3>&1 1>&2 2>&3); then
            export TIMEZONE=$TIME_ZONE
            return
        fi
    fi
    
    echo "Warning: Timezone auto-detection failed or was rejected. Please enter it manually."
    NEW_TIMEZONE=$(whiptail --title "Manual Timezone Entry" --inputbox \
    "Please enter your timezone.\n(Format: Region/City, e.g., America/New_York, Europe/Paris)" 10 60 "Etc/UTC" 3>&1 1>&2 2>&3)
    if [ $? != 0 ]; then echo "User canceled."; exit 1; fi
    export TIMEZONE=$NEW_TIMEZONE
}

keymap () {
    local keymap_choice

    keymap_choice=$(whiptail --title "Keyboard Layout" --menu \
    "Select a common keyboard layout, or choose 'More...' for a full list." 15 60 7 \
    "us" "United States (QWERTY)" \
    "de" "Germany (QWERTZ)" \
    "fr" "France (AZERTY)" \
    "uk" "United Kingdom" \
    "es" "Spain" \
    "br-abnt2" "Brazil" \
    "More..." "Browse all available layouts" 3>&1 1>&2 2>&3)
    
    if [ $? != 0 ]; then echo "User canceled."; exit 1; fi

    if [ "$keymap_choice" == "More..." ]; then
        declare -a keymap_list=()
        while read -r line; do
            keymap_list+=("$(echo "$line" | cut -d'.' -f1)" "")
        done < <(find /usr/share/kbd/keymaps/ -type f -name "*.map.gz" -printf "%f\n" | sort)

        keymap_choice=$(whiptail --title "All Keyboard Layouts" --menu "Select your keyboard layout:" 25 78 15 "${keymap_list[@]}" 3>&1 1>&2 2>&3)
        if [ $? != 0 ]; then echo "User canceled."; exit 1; fi
    fi

    echo "Keyboard layout set to: ${keymap_choice}"
    export KEYMAP="${keymap_choice}"
}

# ==============================================================================
#                      Main Installation Function
# ==============================================================================
perform_installation() {
    set -e

    echo -e "XXX\n0\nSetting up mirrors for optimal download speed...\n(This may take a moment)XXX"
    iso=$(curl -4 --silent --fail ifconfig.io/country_code) || iso="US"
    timedatectl set-ntp true &>> "$LOG_FILE"
    pacman -Sy &>> "$LOG_FILE"
    pacman -S --noconfirm --needed archlinux-keyring &>> "$LOG_FILE"
    pacman -S --noconfirm --needed reflector rsync grub &>> "$LOG_FILE"
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    reflector -a 48 -c "$iso" --score 5 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist &>> "$LOG_FILE"

    echo -e "XXX\n10\nPartitioning disk: ${DISK}...\nXXX"
    umount -A --recursive /mnt &>/dev/null || true
    sgdisk -Z "${DISK}" &>> "$LOG_FILE"
    sgdisk -a 2048 -o "${DISK}" &>> "$LOG_FILE"
    sgdisk -n 1::+1M --typecode=1:ef02 --change-name=1:'BIOSBOOT' "${DISK}" &>> "$LOG_FILE"
    sgdisk -n 2::+1GiB --typecode=2:ef00 --change-name=2:'EFIBOOT' "${DISK}" &>> "$LOG_FILE"
    sgdisk -n 3::-0 --typecode=3:8300 --change-name=3:'ROOT' "${DISK}" &>> "$LOG_FILE"
    if [[ ! -d "/sys/firmware/efi" ]]; then
        sgdisk -A 1:set:2 "${DISK}" &>> "$LOG_FILE"
    fi
    partprobe "${DISK}" &>> "$LOG_FILE"

    echo -e "XXX\n20\nCreating filesystems (${FS})...\nXXX"
    if [[ "${DISK}" =~ "nvme" || "${DISK}" =~ "mmcblk" ]]; then
        partition3=${DISK}p3; partition2=${DISK}p2
    else
        partition3=${DISK}3; partition2=${DISK}2
    fi

    if [[ "${FS}" == "btrfs" ]] || [[ "${FS}" == "luks" ]]; then
        createsubvolumes() { btrfs subvolume create /mnt/@ &>> "$LOG_FILE"; btrfs subvolume create /mnt/@home &>> "$LOG_FILE"; }
        mountallsubvol() { mount -o "${MOUNT_OPTIONS}",subvol=@home /dev/mapper/ROOT /mnt/home 2>> "$LOG_FILE" || mount -o "${MOUNT_OPTIONS}",subvol=@home "${partition3}" /mnt/home &>> "$LOG_FILE"; }
        subvolumesetup() { createsubvolumes; umount /mnt; mount -o "${MOUNT_OPTIONS}",subvol=@ /dev/mapper/ROOT /mnt 2>> "$LOG_FILE" || mount -o "${MOUNT_OPTIONS}",subvol=@ "${partition3}" /mnt &>> "$LOG_FILE"; mkdir -p /mnt/home; mountallsubvol; }
    fi

    if [[ "${FS}" == "btrfs" ]]; then
        mkfs.fat -F32 -n "EFIBOOT" "${partition2}" &>> "$LOG_FILE"
        mkfs.btrfs -f -L ROOT "${partition3}" &>> "$LOG_FILE"
        mount -t btrfs "${partition3}" /mnt
        subvolumesetup
    elif [[ "${FS}" == "ext4" ]]; then
        mkfs.fat -F32 -n "EFIBOOT" "${partition2}" &>> "$LOG_FILE"
        mkfs.ext4 -F -L ROOT "${partition3}" &>> "$LOG_FILE"
        mount -t ext4 "${partition3}" /mnt
    elif [[ "${FS}" == "luks" ]]; then
        mkfs.fat -F32 -n "EFIBOOT" "${partition2}" &>> "$LOG_FILE"
        echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v luksFormat "${partition3}" - &>> "$LOG_FILE"
        echo -n "${LUKS_PASSWORD}" | cryptsetup open "${partition3}" ROOT -
        mkfs.btrfs -f -L ROOT /dev/mapper/ROOT &>> "$LOG_FILE"
        mount -t btrfs /dev/mapper/ROOT /mnt
        subvolumesetup
        ENCRYPTED_PARTITION_UUID=$(blkid -s UUID -o value "${partition3}")
    fi
    BOOT_UUID=$(blkid -s UUID -o value "${partition2}")
    mkdir -p /mnt/boot
    mount -U "${BOOT_UUID}" /mnt/boot/

    echo -e "XXX\n35\nInstalling Arch Linux base packages...\n(This is the longest step)XXX"
    pacstrap_pkgs="base base-devel linux-lts linux-firmware"
    [[ -d "/sys/firmware/efi" ]] && pacstrap_pkgs="$pacstrap_pkgs efibootmgr"
    pacstrap /mnt $pacstrap_pkgs --noconfirm --needed &>> "$LOG_FILE"

    echo -e "XXX\n75\nGenerating fstab and configuring swap...\nXXX"
    genfstab -U /mnt >> /mnt/etc/fstab
    TOTAL_MEM=$(grep -i 'memtotal' /proc/meminfo | grep -o '[[:digit:]]*')
    if [[ $TOTAL_MEM -lt 8000000 ]]; then
        mkdir -p /mnt/opt/swap
        [[ $(findmnt -n -o FSTYPE /mnt) == "btrfs" ]] && chattr +C /mnt/opt/swap
        dd if=/dev/zero of=/mnt/opt/swap/swapfile bs=1M count=2048 status=progress &>> "$LOG_FILE"
        chmod 600 /mnt/opt/swap/swapfile
        mkswap /mnt/opt/swap/swapfile &>> "$LOG_FILE"
        swapon /mnt/opt/swap/swapfile
        echo "/opt/swap/swapfile none swap sw 0 0" >> /mnt/etc/fstab
    fi

    echo -e "XXX\n85\nConfiguring the installed system (chroot)...\nXXX"
    cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
    
    chroot_script=$(cat <<CHROOT_EOF
set -e
echo "root:${PASSWORD}" | chpasswd
pacman -S --noconfirm --needed networkmanager grub reflector
systemctl enable NetworkManager
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
timedatectl set-timezone ${TIMEZONE}
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
localectl set-locale LANG="en_US.UTF-8"
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
echo "${NAME_OF_MACHINE}" > /etc/hostname
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm

if grep -q "GenuineIntel" /proc/cpuinfo; then pacman -S --noconfirm --needed intel-ucode; fi
if grep -q "AuthenticAMD" /proc/cpuinfo; then pacman -S --noconfirm --needed amd-ucode; fi

groupadd libvirt &>/dev/null || true
useradd -m -G wheel,libvirt -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${PASSWORD}" | chpasswd
wget https://raw.githubusercontent.com/CtorW/archfast/refs/heads/uno/fast-hyprland.sh -P "/home/${USERNAME}/"
chown -R ${USERNAME}:${USERNAME} "/home/${USERNAME}"
chmod +x "/home/${USERNAME}/fast-hyprland.sh"

if [[ "${FS}" == "luks" ]]; then sed -i 's/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf; fi
mkinitcpio -P

if [[ -d "/sys/firmware/efi" ]]; then grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH --recheck; else grub-install --target=i386-pc "${DISK}" --recheck; fi
if [[ "${FS}" == "luks" ]]; then sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"%GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=${ENCRYPTED_PARTITION_UUID}:ROOT root=/dev/mapper/ROOT %g" /etc/default/grub; fi
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable reflector.timer
CHROOT_EOF
)
    arch-chroot /mnt /bin/bash -c "${chroot_script}" &>> "$LOG_FILE"

    echo -e "XXX\n100\nInstallation complete!\nXXX"
    sleep 2
}

# ==============================================================================
#                      Main Installation Workflow
# ==============================================================================
clear
userinfo
clear
diskpart
clear
filesystem
clear
timezone
clear
keymap
clear

SUMMARY="
    User:           ${USERNAME}
    Hostname:       ${NAME_OF_MACHINE}
    Timezone:       ${TIMEZONE}
    Keyboard:       ${KEYMAP}
    Filesystem:     ${FS}
"

if (whiptail --title "FINAL CONFIRMATION" --yesno \
"Please review your settings before proceeding.\n\n------------------------------------------------\n${SUMMARY}\n------------------------------------------------\n\nInstallation Target:  ${DISK}\n\n[  WARNING  ]\nContinuing will PARTITION and FORMAT the disk, permanently ERASING ALL DATA.\n\nAre you absolutely sure you want to begin the installation?" 22 78 3>&1 1>&2 2>&3); then
    {
        perform_installation
    } 2>&1 | whiptail --title "Arch Linux Installation" --gauge "Starting installation..." 8 78 0

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        whiptail --title "Installation Failed" --msgbox "An error occurred during installation. Please check the log file for details:\n\n${LOG_FILE}" 10 60
        exit 1
    else
        whiptail --title "Installation Successful" --msgbox "Arch Linux has been installed successfully!\n\nThe system will now reboot. Please remove the installation media." 10 60
        umount -A --recursive /mnt
        reboot
    fi
else
    echo "Installation canceled by user. Exiting."
    exit 1
fi