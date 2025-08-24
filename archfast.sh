#!/bin/bash

# ==============================================================================
#           Color Definitions for a More Beautiful Terminal Experience
# ==============================================================================

# Check if terminal supports colors and use tput, otherwise use raw codes
if tput setaf 1 >/dev/null 2>&1; then
    # Standard Colors
    Color_Off="$(tput sgr0)"
    Black="$(tput setaf 0)"
    Red="$(tput setaf 1)"
    Green="$(tput setaf 2)"
    Yellow="$(tput setaf 3)"
    Blue="$(tput setaf 4)"
    Purple="$(tput setaf 5)"
    Cyan="$(tput setaf 6)"
    White="$(tput setaf 7)"

    # Bold Colors
    BBlack="$(tput bold; tput setaf 0)"
    BRed="$(tput bold; tput setaf 1)"
    BGreen="$(tput bold; tput setaf 2)"
    BYellow="$(tput bold; tput setaf 3)"
    BBlue="$(tput bold; tput setaf 4)"
    BPurple="$(tput bold; tput setaf 5)"
    BCyan="$(tput bold; tput setaf 6)"
    BWhite="$(tput bold; tput setaf 7)"

    # Bright Bold Colors
    BIBlack="$(tput bold; tput setaf 8)"
    BIRed="$(tput bold; tput setaf 9)"
    BIGreen="$(tput bold; tput setaf 10)"
    BIYellow="$(tput bold; tput setaf 11)"
    BIBlue="$(tput bold; tput setaf 12)"
    BIPurple="$(tput bold; tput setaf 13)"
    BICyan="$(tput bold; tput setaf 14)"
    BIWhite="$(tput bold; tput setaf 15)"
else
    # Fallback to hardcoded ANSI codes if tput is not available or supported
    Color_Off="\033[0m"
    Black="\033[0;30m"
    Red="\033[0;31m"
    Green="\033[0;32m"
    Yellow="\033[0;33m"
    Blue="\033[0;34m"
    Purple="\033[0;35m"
    Cyan="\033[0;36m"
    White="\033[0;37m"

    BBlack="\033[1;30m"
    BRed="\033[1;31m"
    BGreen="\033[1;32m"
    BYellow="\033[1;33m"
    BBlue="\033[1;34m"
    BPurple="\033[1;35m"
    BCyan="\033[1;36m"
    BWhite="\033[1;37m"
    
    BIBlack="\033[1;90m"
    BIRed="\033[1;91m"
    BIGreen="\033[1;92m"
    BIYellow="\033[1;93m"
    BIBlue="\033[1;94m"
    BIPurple="\033[1;95m"
    BICyan="\033[1;96m"
    BIWhite="\033[1;97m"
fi

# Redirect all output to a log file
exec > >(tee -i archsetup.txt)
exec 2>&1

# ==============================================================================
#                          Initial System Checks
# ==============================================================================
logo() {
 clear
 echo -en "
${BCyan}-------------------------------------------------------------------------
     █████╗ ██████╗  ██████╗██╗  ██╗███████╗ █████╗ ███████╗████████╗
    ██╔══██╗██╔══██╗██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝╚══██╔══╝
    ███████║██████╔╝██║     ███████║█████╗  ███████║███████╗   ██║   
    ██╔══██║██╔══██╗██║     ██╔══██║██╔══╝  ██╔══██║╚════██║   ██║   
    ██║  ██║██║  ██║╚██████╗██║  ██║██║     ██║  ██║███████║   ██║   
    ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚══════╝   ╚═╝                 
-------------------------------------------------------------------------
${BYellow}                 Automated Arch Linux Installer${Color_Off}
${BCyan}-------------------------------------------------------------------------${Color_Off}
"
}

# Initial checks
logo
echo -ne "
${BGreen}Verifying Arch Linux ISO is Booted${Color_Off}

"
if [ ! -f /usr/bin/pacstrap ]; then
    echo -e "${BRed}ERROR: This script must be run from an Arch Linux ISO environment. Exiting.${Color_Off}"
    exit 1
fi

root_check() {
    if [[ "$(id -u)" != "0" ]]; then
        echo -e "${BRed}ERROR: This script must be run under the 'root' user!${Color_Off}\n"
        exit 1
    fi
}

docker_check() {
    if awk -F/ '$2 == "docker"' /proc/self/cgroup | read -r; then
        echo -e "${BRed}ERROR: Docker container is not supported (at the moment). Exiting.${Color_Off}\n"
        exit 1
    elif [[ -f /.dockerenv ]]; then
        echo -e "${BRed}ERROR: Docker container is not supported (at the moment). Exiting.${Color_Off}\n"
        exit 1
    fi
}

arch_check() {
    if [[ ! -e /etc/arch-release ]]; then
        echo -e "${BRed}ERROR: This script must be run in Arch Linux! Exiting.${Color_Off}\n"
        exit 1
    fi
}

pacman_check() {
    if [[ -f /var/lib/pacman/db.lck ]]; then
        echo -e "${BRed}ERROR: Pacman is blocked.${Color_Off}"
        echo -e "${BRed}If you are sure no pacman process is running, remove /var/lib/pacman/db.lck and try again.${Color_Off}\n"
        exit 1
    fi
}

background_checks() {
    root_check
    arch_check
    pacman_check
    docker_check
}

check_dependencies() {
    echo -e "${BGreen}Checking for required packages...${Color_Off}"
    if ! command -v dialog > /dev/null; then
        echo -e "${BYellow}The 'dialog' tool is not found. Attempting to install it...${Color_Off}"
        pacman -Sy --noconfirm dialog
        if ! command -v dialog > /dev/null; then
            echo -e "${BRed}ERROR: Failed to install 'dialog'. Please ensure you have an internet connection. Exiting.${Color_Off}"
            exit 1
        fi
        echo -e "${BGreen}'dialog' has been successfully installed.${Color_Off}"
    fi
    echo -e "${BGreen}All dependencies are met. Continuing...${Color_Off}"
}

# ==============================================================================
#                          Interactive Menus and Prompts
# ==============================================================================
filesystem () {
    logo
    exec 3>&1
    FS_CHOICE=$(dialog --backtitle "Archfast Installer" --title "Filesystem Selection" \
        --menu "Please select a filesystem for your installation" 15 50 4 \
        "btrfs" "Btrfs with zstd compression and snapshots" \
        "ext4" "Ext4 - a simple and reliable choice" \
        "luks" "Btrfs with LUKS full-disk encryption" \
        "exit" "Exit the installer" 2>&1 1>&3)
    exec 3>&-

    case "$FS_CHOICE" in
        "btrfs") export FS=btrfs ;;
        "ext4") export FS=ext4 ;;
        "luks")
            export FS=luks
            dialog --backtitle "Archfast Installer" --title "LUKS Encryption Password" \
                --msgbox "You have selected LUKS encryption. Please enter a strong password in the next step." 10 50
            local password_match=false
            while [ "$password_match" = false ]; do
                LUKS_PASSWORD=$(dialog --backtitle "Archfast Installer" --title "LUKS Password" --passwordbox "Enter password:" 10 50 3>&1 1>&2 2>&3)
                LUKS_PASSWORD2=$(dialog --backtitle "Archfast Installer" --title "LUKS Password" --passwordbox "Re-enter password:" 10 50 3>&1 1>&2 2>&3)
                if [ "$LUKS_PASSWORD" == "$LUKS_PASSWORD2" ]; then
                    password_match=true
                else
                    dialog --backtitle "Archfast Installer" --title "Error" --msgbox "Passwords do not match. Please try again." 10 50
                fi
            done
            export LUKS_PASSWORD
            ;;
        "exit") exit ;;
        *) dialog --backtitle "Archfast Installer" --title "Error" --msgbox "Invalid selection. Please try again." 10 50; filesystem ;;
    esac
}

timezone () {
    logo
    TIME_ZONE=$(curl --fail https://ipapi.co/timezone)
    exec 3>&1
    TIME_ZONE_CHOICE=$(dialog --backtitle "Archfast Installer" --title "Timezone Selection" \
        --yesno "System detected your timezone to be '${TIME_ZONE}'. Is this correct?" 10 50)
    exec 3>&-

    case $? in
        0)
            export TIMEZONE=$TIME_ZONE
            dialog --backtitle "Archfast Installer" --title "Timezone" \
                --msgbox "Timezone set to ${TIMEZONE}" 10 50
            ;;
        1)
            NEW_TIMEZONE=$(dialog --backtitle "Archfast Installer" --title "Timezone" \
                --inputbox "Enter your desired timezone (e.g., Europe/London):" 10 50 "America/Los_Angeles" 3>&1 1>&2 2>&3)
            if [ -z "$NEW_TIMEZONE" ]; then
                dialog --backtitle "Archfast Installer" --title "Error" --msgbox "Timezone cannot be empty." 10 50
                timezone
                return
            fi
            export TIMEZONE=$NEW_TIMEZONE
            dialog --backtitle "Archfast Installer" --title "Timezone" \
                --msgbox "Timezone set to ${TIMEZONE}" 10 50
            ;;
    esac
}

keymap () {
    logo
    exec 3>&1
    KEYMAP_CHOICE=$(dialog --backtitle "Archfast Installer" --title "Keyboard Layout" \
        --inputbox "Please enter your keyboard layout (e.g., us):" 10 50 "us" 2>&1 1>&3)
    exec 3>&-
    export KEYMAP=$KEYMAP_CHOICE
    dialog --backtitle "Archfast Installer" --title "Keymap" \
        --msgbox "Keyboard layout set to: ${KEYMAP}" 10 50
}

drivessd () {
    logo
    exec 3>&1
    SSD_CHOICE=$(dialog --backtitle "Archfast Installer" --title "Drive Type" \
        --yesno "Is this an SSD?" 10 50)
    exec 3>&-

    case $? in
        0) export MOUNT_OPTIONS="noatime,compress=zstd,ssd,commit=120" ;;
        1) export MOUNT_OPTIONS="noatime,compress=zstd,commit=120" ;;
    esac
}

diskpart () {
    logo
    dialog --backtitle "Archfast Installer" --title "Warning" --msgbox "WARNING: THIS WILL FORMAT AND DELETE ALL DATA ON THE SELECTED DISK. Please be absolutely sure you have backed up any important data. There is no way to recover data after this process. *****I AM NOT RESPONSIBLE FOR ANY DATA LOSS*****" 15 60
    
    local disks=($(lsblk -n --output KNAME,SIZE,MODEL | awk '$1~/^sd|hd|vd|nvme|mmcblk/{printf "%s (%s - %s) ", $1, $2, $3}'))
    local dialog_options=()
    for i in "${!disks[@]}"; do
        dialog_options+=("$((i+1))" "${disks[$i]}")
    done
    
    local choice_raw=$(dialog --backtitle "Archfast Installer" --title "Disk Selection" \
        --menu "Select a disk to install to:" 20 60 15 "${dialog_options[@]}" 3>&1 1>&2 2>&3)
    
    local disk_choice_raw=${disks[$((choice_raw-1))]}
    local disk=$(echo "$disk_choice_raw" | awk '{print $1}')
    
    dialog --backtitle "Archfast Installer" --title "Disk Selected" \
        --msgbox "Disk selected: /dev/${disk}" 10 50
    export DISK="/dev/${disk}"

    drivessd
}

userinfo () {
    logo
    USERNAME=$(dialog --backtitle "Archfast Installer" --title "User Information" --inputbox "Please enter a username:" 10 50 "" 3>&1 1>&2 2>&3)
    export USERNAME

    local password_match=false
    while [ "$password_match" = false ]; do
        PASSWORD=$(dialog --backtitle "Archfast Installer" --title "Password" --passwordbox "Enter password for '$USERNAME':" 10 50 3>&1 1>&2 2>&3)
        PASSWORD2=$(dialog --backtitle "Archfast Installer" --title "Password" --passwordbox "Re-enter password:" 10 50 3>&1 1>&2 2>&3)
        if [ "$PASSWORD" == "$PASSWORD2" ]; then
            password_match=true
        else
            dialog --backtitle "Archfast Installer" --title "Error" --msgbox "Passwords do not match. Please try again." 10 50
        fi
    done
    export PASSWORD

    NAME_OF_MACHINE=$(dialog --backtitle "Archfast Installer" --title "Hostname" --inputbox "Please name your machine (hostname):" 10 50 "" 3>&1 1>&2 2>&3)
    export NAME_OF_MACHINE
}

# ==============================================================================
#                             Main Installation Workflow
# ==============================================================================

# Run initial checks before starting
background_checks
clear
check_dependencies
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

dialog --backtitle "Archfast Installer" --title "Installation Confirmation" \
    --yesno "Are you ready to begin the installation? All data on the selected disk will be erased." 10 50

if [ $? -ne 0 ]; then
    dialog --backtitle "Archfast Installer" --title "Installation Canceled" \
        --msgbox "Installation canceled by user. Exiting." 10 50
    exit 1
fi

echo -e "${BYellow}Starting the installation process...${Color_Off}"
echo -e "${BGreen}Setting up mirrors for optimal download speed...${Color_Off}"
iso=$(curl -4 ifconfig.io/country_code)
timedatectl set-ntp true
pacman -Sy
pacman -S --noconfirm archlinux-keyring
pacman -S --noconfirm --needed pacman-contrib terminus-font
setfont ter-v18b
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
pacman -S --noconfirm --needed reflector rsync grub
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
echo -e "${BCyan}-------------------------------------------------------------------------
              Setting up $iso mirrors for faster downloads
-------------------------------------------------------------------------${Color_Off}"
reflector -a 48 -c "$iso" --score 5 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
if [[ $(grep -c "Server =" /etc/pacman.d/mirrorlist) -lt 5 ]]; then
    echo -e "${BRed}Warning: Reflector failed. Restoring original mirrorlist.${Color_Off}"
    cp /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist
fi

if [ ! -d "/mnt" ]; then
    mkdir /mnt
fi

echo -e "${BGreen}Installing Prerequisites...${Color_Off}"
pacman -S --noconfirm --needed gptfdisk btrfs-progs glibc

echo -e "${BGreen}Formatting Disk...${Color_Off}"
umount -A --recursive /mnt
sgdisk -Z "${DISK}"
sgdisk -a 2048 -o "${DISK}"

sgdisk -n 1::+1M --typecode=1:ef02 --change-name=1:'BIOSBOOT' "${DISK}"
sgdisk -n 2::+1GiB --typecode=2:ef00 --change-name=2:'EFIBOOT' "${DISK}"
sgdisk -n 3::-0 --typecode=3:8300 --change-name=3:'ROOT' "${DISK}"
if [[ ! -d "/sys/firmware/efi" ]]; then
    sgdisk -A 1:set:2 "${DISK}"
fi
partprobe "${DISK}"

echo -e "${BGreen}Creating Filesystems...${Color_Off}"
createsubvolumes () {
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
}

mountallsubvol () {
    mount -o "${MOUNT_OPTIONS}",subvol=@home "${partition3}" /mnt/home
}

subvolumesetup () {
    createsubvolumes
    umount /mnt
    mount -o "${MOUNT_OPTIONS}",subvol=@ "${partition3}" /mnt
    mkdir -p /mnt/home
    mountallsubvol
}

if [[ "${DISK}" =~ "nvme" || "${DISK}" =~ "mmcblk" ]]; then
    partition2=${DISK}p2
    partition3=${DISK}p3
else
    partition2=${DISK}2
    partition3=${DISK}3
fi

if [[ "${FS}" == "btrfs" ]]; then
    mkfs.fat -F32 -n "EFIBOOT" "${partition2}"
    mkfs.btrfs -f "${partition3}"
    mount -t btrfs "${partition3}" /mnt
    subvolumesetup
elif [[ "${FS}" == "ext4" ]]; then
    mkfs.fat -F32 -n "EFIBOOT" "${partition2}"
    mkfs.ext4 "${partition3}"
    mount -t ext4 "${partition3}" /mnt
elif [[ "${FS}" == "luks" ]]; then
    mkfs.fat -F32 "${partition2}"
    echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v luksFormat "${partition3}" -
    echo -n "${LUKS_PASSWORD}" | cryptsetup open "${partition3}" ROOT -
    mkfs.btrfs "${partition3}"
    mount -t btrfs "${partition3}" /mnt
    subvolumesetup
    ENCRYPTED_PARTITION_UUID=$(blkid -s UUID -o value "${partition3}")
fi

BOOT_UUID=$(blkid -s UUID -o value "${partition2}")

sync
if ! mountpoint -q /mnt; then
    echo -e "${BRed}ERROR: Failed to mount ${partition3} to /mnt. Exiting.${Color_Off}"
    exit 1
fi
mkdir -p /mnt/boot
mount -U "${BOOT_UUID}" /mnt/boot/

if ! grep -qs '/mnt' /proc/mounts; then
    echo -e "${BRed}ERROR: Drive is not mounted. Rebooting in 3 seconds...${Color_Off}" && sleep 1
    echo -e "${BRed}Rebooting in 2 seconds...${Color_Off}" && sleep 1
    echo -e "${BRed}Rebooting in 1 second...${Color_Off}" && sleep 1
    reboot now
fi

echo -e "${BGreen}Installing Arch Linux on Main Drive...${Color_Off}"
if [[ ! -d "/sys/firmware/efi" ]]; then
    pacstrap /mnt base base-devel linux-lts linux-firmware --noconfirm --needed
else
    pacstrap /mnt base base-devel linux-lts linux-firmware efibootmgr --noconfirm --needed
fi
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

genfstab -U /mnt >> /mnt/etc/fstab
echo -e "\n${BGreen}Generated /etc/fstab:${Color_Off}\n"
cat /mnt/etc/fstab

echo -e "${BGreen}GRUB Bootloader Installation${Color_Off}"
if [[ ! -d "/sys/firmware/efi" ]]; then
    echo -e "${BCyan}Installing GRUB for EFI...${Color_Off}"
    grub-install --boot-directory=/mnt/boot "${DISK}"
    if [ $? -ne 0 ]; then
        echo -e "${BRed}ERROR: GRUB EFI installation failed. Exiting.${Color_Off}"
        exit 1
    fi
fi

echo -e "${BGreen}Checking for low memory systems (<8G) for swap file...${Color_Off}"
TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[ $TOTAL_MEM -lt 8000000 ]]; then
    echo -e "${BYellow}System has less than 8GB RAM. Creating a 2GB swap file.${Color_Off}"
    mkdir -p /mnt/opt/swap
    if findmnt -n -o FSTYPE /mnt | grep -q btrfs; then
        chattr +C /mnt/opt/swap
    fi
    dd if=/dev/zero of=/mnt/opt/swap/swapfile bs=1M count=2048 status=progress
    chmod 600 /mnt/opt/swap/swapfile
    chown root /mnt/opt/swap/swapfile
    mkswap /mnt/opt/swap/swapfile
    swapon /mnt/opt/swap/swapfile
    echo "/opt/swap/swapfile  none  swap  sw  0  0" >> /mnt/etc/fstab
fi

# Chroot into the new system to continue configuration
arch-chroot /mnt /bin/bash -c "KEYMAP='${KEYMAP}' /bin/bash" <<EOF

echo "root:${PASSWORD}" | chpasswd

echo -ne "
${BGreen}-------------------------------------------------------------------------
                        Network Setup
-------------------------------------------------------------------------${Color_Off}
"
pacman -S --noconfirm --needed networkmanager dhcpcd
systemctl enable NetworkManager

echo -ne "
${BGreen}-------------------------------------------------------------------------
              Setting up mirrors for optimal download
-------------------------------------------------------------------------${Color_Off}
"
pacman -S --noconfirm --needed pacman-contrib curl
pacman -S --noconfirm --needed reflector rsync grub arch-install-scripts git ntp wget
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak

nc=$(grep -c ^"cpu cores" /proc/cpuinfo)
echo -ne "
${BGreen}-------------------------------------------------------------------------
                    You have ${nc} cores. And
              changing the makeflags for ${nc} cores. Aswell as
                   changing the compression settings.
-------------------------------------------------------------------------${Color_Off}
"
TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[ $TOTAL_MEM -gt 8000000 ]]; then
    sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$nc\"/g" /etc/makepkg.conf
    sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g" /etc/makepkg.conf
fi
echo -ne "
${BGreen}-------------------------------------------------------------------------
              Setup Language to US and set locale
-------------------------------------------------------------------------${Color_Off}
"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
timedatectl --no-ask-password set-timezone ${TIMEZONE}
timedatectl --no-ask-password set-ntp 1
localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"
ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
echo "XKBLAYOUT=${KEYMAP}" >> /etc/vconsole.conf
echo -e "${BGreen}Keymap set to: ${KEYMAP}${Color_Off}"

sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf

sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm --needed

echo -ne "
${BGreen}-------------------------------------------------------------------------
                     Installing Microcode
-------------------------------------------------------------------------${Color_Off}
"
if grep -q "GenuineIntel" /proc/cpuinfo; then
    echo -e "${BGreen}Installing Intel microcode...${Color_Off}"
    pacman -S --noconfirm --needed intel-ucode
elif grep -q "AuthenticAMD" /proc/cpuinfo; then
    echo -e "${BGreen}Installing AMD microcode...${Color_Off}"
    pacman -S --noconfirm --needed amd-ucode
else
    echo -e "${BYellow}Unable to determine CPU vendor. Skipping microcode installation.${Color_Off}"
fi

echo -ne "
${BGreen}-------------------------------------------------------------------------
                 Installing Graphics Drivers
-------------------------------------------------------------------------${Color_Off}
"
if echo "${gpu_type}" | grep -E "NVIDIA|GeForce"; then
    echo -e "${BGreen}Installing NVIDIA drivers: nvidia-lts...${Color_Off}"
    pacman -S --noconfirm --needed nvidia-lts
elif echo "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
    echo -e "${BGreen}Installing AMD drivers: xf86-video-amdgpu...${Color_Off}"
    pacman -S --noconfirm --needed xf86-video-amdgpu
elif echo "${gpu_type}" | grep -E "Integrated Graphics Controller|Intel Corporation UHD"; then
    echo -e "${BGreen}Installing Intel drivers...${Color_Off}"
    pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
else
    echo -e "${BYellow}Unable to determine GPU vendor. Skipping graphics driver installation.${Color_Off}"
fi

echo -ne "
${BGreen}-------------------------------------------------------------------------
    Adding User & fast-hyprland scipt
-------------------------------------------------------------------------${Color_Off}
"
groupadd libvirt
useradd -m -G wheel,libvirt -s /bin/bash $USERNAME
echo -e "${BGreen}User '$USERNAME' created, added to 'wheel' and 'libvirt' groups.${Color_Off}"
echo "$USERNAME:$PASSWORD" | chpasswd
echo -e "${BGreen}Password for '$USERNAME' has been set.${Color_Off}"
echo $NAME_OF_MACHINE > /etc/hostname
echo -e "${BGreen}Hostname set to '$NAME_OF_MACHINE'.${Color_Off}"

echo -e "${BGreen}Pulling Dots installer transfer to /home/$USERNAME/${Color_Off}"
wget https://raw.githubusercontent.com/CtorW/archfast/refs/heads/uno/fast-hyprland.sh -P /home/$USERNAME/
echo -e "${BGreen} changing permission Dots installer script.${Color_Off}"
cd /home/$USERNAME/ && sudo chmod +x fast-hyprland.sh

if [[ ${FS} == "luks" ]]; then
    sed -i 's/filesystems/encrypt filesystems/g' /etc/mkinitcpio.conf
    mkinitcpio -p linux-lts
fi

echo -ne "
${BCyan}-------------------------------------------------------------------------
     █████╗ ██████╗  ██████╗██╗  ██╗███████╗ █████╗ ███████╗████████╗
    ██╔══██╗██╔══██╗██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝╚══██╔══╝
    ███████║██████╔╝██║     ███████║█████╗  ███████║███████╗   ██║   
    ██╔══██║██╔══██╗██║     ██╔══██║██╔══╝  ██╔══██║╚════██║   ██║   
    ██║  ██║██║  ██║╚██████╗██║  ██║██║     ██║  ██║███████║   ██║   
    ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚══════╝   ╚═╝                 
-------------------------------------------------------------------------
${BYellow}                 Automated Arch Linux Installer${Color_Off}
${BCyan}-------------------------------------------------------------------------${Color_Off}

${BGreen}Final Setup and Configurations
GRUB EFI Bootloader Install & Check${Color_Off}"

if [[ -d "/sys/firmware/efi" ]]; then
    echo -e "${BCyan}Installing GRUB for EFI...${Color_Off}"
    grub-install --efi-directory=/boot "${DISK}"
    if [ $? -ne 0 ]; then
        echo -e "${BRed}ERROR: GRUB EFI installation failed. Exiting.${Color_Off}"
        exit 1
    fi
fi

echo -ne "
${BGreen}-------------------------------------------------------------------------
                   Creating Grub Boot Menu
-------------------------------------------------------------------------${Color_Off}
"
if [[ "${FS}" == "luks" ]]; then
    sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"%GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=${ENCRYPTED_PARTITION_UUID}:ROOT root=/dev/mapper/ROOT %g" /etc/default/grub
fi
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& splash /' /etc/default/grub

echo -e "${BGreen}Updating grub...${Color_Off}"
grub-mkconfig -o /boot/grub/grub.cfg
if [ $? -ne 0 ]; then
    echo -e "${BRed}ERROR: Failed to create grub.cfg. Exiting.${Color_Off}"
    exit 1
fi

echo -e "${BGreen}Verifying grub configuration...${Color_Off}"
if [ ! -f /boot/grub/grub.cfg ]; then
    echo -e "${BRed}ERROR: grub.cfg was not created. Exiting.${Color_Off}"
    exit 1
fi
if ! grep -q "Arch Linux" /boot/grub/grub.cfg; then
    echo -e "${BRed}ERROR: grub.cfg does not contain an Arch Linux entry. Exiting.${Color_Off}"
    exit 1
fi
echo -e "${BGreen}Grub configuration complete!${Color_Off}"

echo -ne "
${BGreen}-------------------------------------------------------------------------
                   Enabling Essential Services
-------------------------------------------------------------------------${Color_Off}
"
ntpd -qg
systemctl enable ntpd.service
echo -e "${BGreen}  NTP enabled.${Color_Off}"
systemctl disable dhcpcd.service
echo -e "${BGreen}  DHCP disabled.${Color_Off}"
systemctl start NetworkManager.service
echo -e "${BGreen}  NetworkManager started.${Color_Off}"
systemctl enable NetworkManager.service
echo -e "${BGreen}  NetworkManager enabled.${Color_Off}"
systemctl enable reflector.timer
echo -e "${BGreen}  Reflector enabled.${Color_Off}"

echo -ne "
${BGreen}-------------------------------------------------------------------------
                          Cleaning
-------------------------------------------------------------------------${Color_Off}
"
# Reverting temporary sudoers changes for security
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

EOF
