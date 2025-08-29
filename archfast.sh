#!/bin/bash

# ==============================================================================
#           Color Definitions for a More Beautiful Terminal Experience
# ==============================================================================

if tput setaf 1 >/dev/null 2>&1; then
    Color_Off="$(tput sgr0)"
    Black="$(tput setaf 0)"
    Red="$(tput setaf 1)"
    Green="$(tput setaf 2)"
    Yellow="$(tput setaf 3)"
    Blue="$(tput setaf 4)"
    Purple="$(tput setaf 5)"
    Cyan="$(tput setaf 6)"
    White="$(tput setaf 7)"

    BBlack="$(tput bold; tput setaf 0)"
    BRed="$(tput bold; tput setaf 1)"
    BGreen="$(tput bold; tput setaf 2)"
    BYellow="$(tput bold; tput setaf 3)"
    BBlue="$(tput bold; tput setaf 4)"
    BPurple="$(tput bold; tput setaf 5)"
    BCyan="$(tput bold; tput setaf 6)"
    BWhite="$(tput bold; tput setaf 7)"

    BIBlack="$(tput bold; tput setaf 8)"
    BIRed="$(tput bold; tput setaf 9)"
    BIGreen="$(tput bold; tput setaf 10)"
    BIYellow="$(tput bold; tput setaf 11)"
    BIBlue="$(tput bold; tput setaf 12)"
    BIPurple="$(tput bold; tput setaf 13)"
    BICyan="$(tput bold; tput setaf 14)"
    BIWhite="$(tput bold; tput setaf 15)"
else
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
        echo -e "${BRed}ERROR: This script must be run in Arch Linux! Exiting.${Color_Off}"
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

# ==============================================================================
#                          Interactive Prompts (using Whiptail TUI)
# ==============================================================================
userinfo () {
    echo -e "${BGreen}Checking for whiptail...${Color_Off}"
    pacman -S --noconfirm --needed whiptail
    
    USERNAME=$(whiptail --title "User Account Setup" --inputbox \
    "Please enter your desired username.\n\n(Use lowercase letters, no spaces. e.g., 'alex')" 10 60 archuser 3>&1 1>&2 2>&3)
    if [ $? != 0 ]; then echo -e "${BRed}User canceled at Username prompt. Exiting.${Color_Off}"; exit 1; fi
    export USERNAME

    local password_match=false
    while [ "$password_match" = false ]; do
        PASSWORD=$(whiptail --title "Set User Password" --passwordbox "Enter a password for user '$USERNAME':" 10 60 3>&1 1>&2 2>&3)
        if [ $? != 0 ]; then echo -e "${BRed}User canceled at Password prompt. Exiting.${Color_Off}"; exit 1; fi
        
        PASSWORD2=$(whiptail --title "Confirm User Password" --passwordbox "Please re-enter the password to confirm:" 10 60 3>&1 1>&2 2>&3)
        if [ $? != 0 ]; then echo -e "${BRed}User canceled at Password Confirmation prompt. Exiting.${Color_Off}"; exit 1; fi

        if [ "$PASSWORD" == "$PASSWORD2" ]; then
            password_match=true
        else
            whiptail --title "Password Mismatch" --msgbox "The passwords you entered do not match. Please try again." 10 60
        fi
    done
    export PASSWORD
    
    NAME_OF_MACHINE=$(whiptail --title "System Hostname" --inputbox \
    "Please enter a hostname for this machine.\n\n(This is how it will appear on a network. e.g., 'arch-desktop')" 10 60 myarch 3>&1 1>&2 2>&3)
    if [ $? != 0 ]; then echo -e "${BRed}User canceled at Hostname prompt. Exiting.${Color_Off}"; exit 1; fi
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

    DISK=$(whiptail --title "Select Target Installation Disk" --menu \
    "Please select the disk to install Arch Linux onto.\n\n[ DANGER ]: All data on the selected disk will be PERMANENTLY DELETED." 20 78 12 "${disk_list[@]}" 3>&1 1>&2 2>&3)
    if [ $? != 0 ]; then echo -e "${BRed}User canceled at Disk Selection. Exiting.${Color_Off}"; exit 1; fi
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
    if [ $? != 0 ]; then echo -e "${BRed}User canceled at Filesystem Selection. Exiting.${Color_Off}"; exit 1; fi
    export FS=${FS_CHOICE}
    
    if [[ "${FS}" == "luks" ]]; then
        local luks_match=false
        while [ "$luks_match" = false ]; do
            LUKS_PASSWORD=$(whiptail --title "Set Encryption Password" --passwordbox "Enter a strong password for disk encryption:" 10 60 3>&1 1>&2 2>&3)
            if [ $? != 0 ]; then echo -e "${BRed}User canceled at LUKS Password prompt. Exiting.${Color_Off}"; exit 1; fi
            LUKS_PASSWORD2=$(whiptail --title "Confirm Encryption Password" --passwordbox "Re-enter the password to confirm:" 10 60 3>&1 1>&2 2>&3)
            if [ $? != 0 ]; then echo -e "${BRed}User canceled at LUKS Password Confirmation. Exiting.${Color_Off}"; exit 1; fi

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
    TIME_ZONE=$(curl --fail https://ipapi.co/timezone)
    if [ $? -eq 0 ] && [ -n "${TIME_ZONE}" ]; then
        if (whiptail --title "Timezone Confirmation" --yesno "Your timezone appears to be '${TIME_ZONE}'.\n\nIs this correct?" 10 60 3>&1 1>&2 2>&3); then
            export TIMEZONE=$TIME_ZONE
            return
        fi
    else
        echo -e "${BYellow}Warning: Timezone auto-detection failed. This is likely due to no internet connection.${Color_Off}"
    fi
    
    echo -e "${BYellow}Please enter your timezone manually.${Color_Off}"
    NEW_TIMEZONE=$(whiptail --title "Manual Timezone Entry" --inputbox \
    "Please enter your timezone.\n(Format: Region/City, e.g., America/New_York, Europe/Paris)" 10 60 "Etc/UTC" 3>&1 1>&2 2>&3)
    if [ $? != 0 ]; then echo -e "${BRed}User canceled at Manual Timezone Entry. Exiting.${Color_Off}"; exit 1; fi
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
    
    if [ $? != 0 ]; then echo -e "${BRed}User canceled at Keyboard Layout selection. Exiting.${Color_Off}"; exit 1; fi

    if [ "$keymap_choice" == "More..." ]; then
        declare -a keymap_list=()
        while read -r line; do
            keymap_list+=("$(echo "$line" | cut -d' ' -f1)" "$(echo "$line" | cut -d' ' -f2-)")
        done < <(find /usr/share/kbd/keymaps/ -name "*.map.gz" -printf "%f\n" | sed 's/\.map\.gz$//' | sort | xargs -I {} echo "{} ()")

        keymap_choice=$(whiptail --title "All Keyboard Layouts" --menu "Select your keyboard layout:" 25 78 15 "${keymap_list[@]}" 3>&1 1>&2 2>&3)
        if [ $? != 0 ]; then echo -e "${BRed}User canceled at full Keyboard Layout list. Exiting.${Color_Off}"; exit 1; fi
    fi

    echo -e "${BGreen}Keyboard layout set to: ${keymap_choice}${Color_Off}"
    export KEYMAP="${keymap_choice}"
}

swap_option () {
    if (whiptail --title "Swap Configuration" --yesno \
    "Do you want to create a swap space?\n\nThis is recommended for systems with low RAM (less than 8GB) or for users who run memory-intensive applications or use hibernation." 12 78 3>&1 1>&2 2>&3); then
        export USE_SWAP="yes"
    else
        export USE_SWAP="no"
    fi
    if [ $? != 0 ]; then echo -e "${BRed}User canceled at Swap Configuration prompt. Exiting.${Color_Off}"; exit 1; fi
}

# ==============================================================================
#                             Main Installation Workflow
# ==============================================================================

background_checks
clear
logo
userinfo
clear
logo
diskpart
clear
logo
filesystem
clear
logo
timezone
clear
logo
keymap
clear
logo
swap_option
clear

SUMMARY="
    User:           ${USERNAME}
    Hostname:       ${NAME_OF_MACHINE}
    Timezone:       ${TIMEZONE}
    Keyboard:       ${KEYMAP}
    Filesystem:     ${FS}
    Use Swap:       ${USE_SWAP}
"

if (whiptail --title "FINAL CONFIRMATION" --yesno \
"Please review your settings before proceeding.\n\n------------------------------------------------\n${SUMMARY}\n------------------------------------------------\n\nInstallation Target:  ${DISK}\n\n[  WARNING  ]\nContinuing will PARTITION and FORMAT the disk, permanently ERASING ALL DATA.\n\nAre you absolutely sure you want to begin the installation?" 24 78 3>&1 1>&2 2>&3); then
     echo -en "
${BCyan}-------------------------------------------------------------------------
██████╗ ██╗   ██╗███╗   ██╗███╗   ██╗██╗███╗   ██╗ ██████╗               
██╔══██╗██║   ██║████╗  ██║████╗  ██║██║████╗  ██║██╔════╝               
██████╔╝██║   ██║██╔██╗ ██║██╔██╗ ██║██║██╔██╗ ██║██║  ███╗              
██╔══██╗██║   ██║██║╚██╗██║██║╚██╗██║██║██║╚██╗██║██║   ██║              
██║  ██║╚██████╔╝██║ ╚████║██║ ╚████║██║██║ ╚████║╚██████╔╝██╗██╗██╗     
╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝╚═╝╚═╝     
                                                                         
 ██████╗ ██████╗ ██╗   ██╗██████╗     ██╗   ██╗ ██████╗ ██╗   ██╗██████╗ 
██╔════╝ ██╔══██╗██║   ██║██╔══██╗    ╚██╗ ██╔╝██╔═══██╗██║   ██║██╔══██╗
██║  ███╗██████╔╝██║   ██║██████╔╝     ╚████╔╝ ██║   ██║██║   ██║██████╔╝
██║   ██║██╔══██╗██║   ██║██╔══██╗      ╚██╔╝  ██║   ██║██║   ██║██╔══██╗
╚██████╔╝██║  ██║╚██████╔╝██████╔╝       ██║   ╚██████╔╝╚██████╔╝██║  ██║
 ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═════╝        ╚═╝    ╚═════╝  ╚═════╝ ╚═╝  ╚═╝
                                                                         
 ██████╗ ██████╗ ███████╗███████╗███████╗███████╗                        
██╔════╝██╔═══██╗██╔════╝██╔════╝██╔════╝██╔════╝                        
██║     ██║   ██║█████╗  █████╗  █████╗  █████╗                          
██║     ██║   ██║██╔══╝  ██╔══╝  ██╔══╝  ██╔══╝                          
╚██████╗╚██████╔╝██║     ██║     ███████╗███████╗                        
 ╚═════╝ ╚═════╝ ╚═╝     ╚═╝     ╚══════╝╚══════╝                        
-------------------------------------------------------------------------${Color_Off}
"
else
    echo -e "${BRed}Installation canceled by user at final confirmation. Exiting.${Color_Off}"
    exit 1
fi

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
if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to wipe partition table on ${DISK}. Exiting.${Color_Off}"; exit 1; fi
sgdisk -a 2048 -o "${DISK}"
if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to create new GPT label on ${DISK}. Exiting.${Color_Off}"; exit 1; fi

sgdisk -n 1::+1M --typecode=1:ef02 --change-name=1:'BIOSBOOT' "${DISK}"
if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to create BIOS boot partition on ${DISK}. Exiting.${Color_Off}"; exit 1; fi
sgdisk -n 2::+1GiB --typecode=2:ef00 --change-name=2:'EFIBOOT' "${DISK}"
if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to create EFI boot partition on ${DISK}. Exiting.${Color_Off}"; exit 1; fi
sgdisk -n 3::-0 --typecode=3:8300 --change-name=3:'ROOT' "${DISK}"
if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to create root partition on ${DISK}. Exiting.${Color_Off}"; exit 1; fi

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
    if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to mount btrfs root subvolume. Exiting.${Color_Off}"; exit 1; fi
    mkdir -p /mnt/home
    mountallsubvol
    if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to mount btrfs home subvolume. Exiting.${Color_Off}"; exit 1; fi
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
    if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to create FAT32 filesystem on ${partition2}. Exiting.${Color_Off}"; exit 1; fi
    mkfs.btrfs -f "${partition3}"
    if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to create btrfs filesystem on ${partition3}. Exiting.${Color_Off}"; exit 1; fi
    mount -t btrfs "${partition3}" /mnt
    if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to mount ${partition3}. Exiting.${Color_Off}"; exit 1; fi
    subvolumesetup
elif [[ "${FS}" == "ext4" ]]; then
    mkfs.fat -F32 -n "EFIBOOT" "${partition2}"
    if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to create FAT32 filesystem on ${partition2}. Exiting.${Color_Off}"; exit 1; fi
    mkfs.ext4 -F "${partition3}"
    if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to create ext4 filesystem on ${partition3}. Exiting.${Color_Off}"; exit 1; fi
    mount -t ext4 "${partition3}" /mnt
    if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to mount ${partition3}. Exiting.${Color_Off}"; exit 1; fi
elif [[ "${FS}" == "luks" ]]; then
    mkfs.fat -F32 "${partition2}"
    if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to create FAT32 filesystem on ${partition2}. Exiting.${Color_Off}"; exit 1; fi
    echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v luksFormat "${partition3}" -
    if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to format LUKS container on ${partition3}. Exiting.${Color_Off}"; exit 1; fi
    echo -n "${LUKS_PASSWORD}" | cryptsetup open "${partition3}" ROOT -
    if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to open LUKS container on ${partition3}. Exiting.${Color_Off}"; exit 1; fi
    mkfs.btrfs /dev/mapper/ROOT
    if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to create btrfs filesystem on LUKS container. Exiting.${Color_Off}"; exit 1; fi
    mount -t btrfs /dev/mapper/ROOT /mnt
    if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to mount LUKS container. Exiting.${Color_Off}"; exit 1; fi
    subvolumesetup
    ENCRYPTED_PARTITION_UUID=$(blkid -s UUID -o value "${partition3}")
fi

BOOT_UUID=$(blkid -s UUID -o value "${partition2}")

sync
if ! mountpoint -q /mnt; then
    echo -e "${BRed}ERROR: Failed to mount root partition to /mnt. Exiting.${Color_Off}"
    exit 1
fi
mkdir -p /mnt/boot
mount -U "${BOOT_UUID}" /mnt/boot/
if [ $? -ne 0 ]; then echo -e "${BRed}ERROR: Failed to mount EFI partition to /mnt/boot. Exiting.${Color_Off}"; exit 1; fi

if ! grep -qs '/mnt' /proc/mounts; then
    echo -e "${BRed}ERROR: Drive is not mounted. Rebooting in 3 seconds...${Color_Off}" && sleep 1
    echo -e "${BRed}Rebooting in 2 seconds...${Color_Off}" && sleep 1
    echo -e "${BRed}Rebooting in 1 second...${Color_Off}" && sleep 1
    reboot now
fi

echo -e "${BGreen}Installing Arch Linux on Main Drive... This may take a while.${Color_Off}"
PKGS="base base-devel linux-lts linux-firmware"
if [[ -d "/sys/firmware/efi" ]]; then
    PKGS+=" efibootmgr"
fi
pacstrap /mnt $PKGS --noconfirm --needed
if [ $? -ne 0 ]; then
    echo -e "${BRed}ERROR: Pacstrap failed to install the base system.${Color_Off}"
    echo -e "${BYellow}This is often due to a network issue or bad mirrors.${Color_Off}"
    echo -e "${BYellow}Check archsetup.txt for detailed logs. Exiting.${Color_Off}"
    exit 1
fi

echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

genfstab -U /mnt >> /mnt/etc/fstab
echo -e "\n${BGreen}Generated /etc/fstab:${Color_Off}\n"
cat /mnt/etc/fstab

echo -e "${BGreen}GRUB Bootloader Installation${Color_Off}"
if [[ ! -d "/sys/firmware/efi" ]]; then
    echo -e "${BCyan}Installing GRUB for BIOS...${Color_Off}"
    grub-install --boot-directory=/mnt/boot "${DISK}"
    if [ $? -ne 0 ]; then
        echo -e "${BRed}ERROR: GRUB BIOS installation failed. Exiting.${Color_Off}"
        exit 1
    fi
fi

if [[ "${USE_SWAP}" == "yes" ]]; then
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
    else
        echo -e "${BGreen}System has 8GB or more RAM. Skipping swap file creation as per script's logic.${Color_Off}"
    fi
else
    echo -e "${BYellow}User opted out of swap creation. Skipping.${Color_Off}"
fi


arch-chroot /mnt /bin/bash -c "KEYMAP='${KEYMAP}' /bin/bash" <<EOF
set -e

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

nc=\$(grep -c ^"cpu cores" /proc/cpuinfo)
export nc
echo -ne "
${BGreen}-------------------------------------------------------------------------
                    You have \${nc} cores. And
              changing the makeflags for \${nc} cores. Aswell as
                   changing the compression settings.
-------------------------------------------------------------------------${Color_Off}
"
TOTAL_MEM=\$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[ \$TOTAL_MEM -gt 8000000 ]]; then
    sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j\${nc}\"/g" /etc/makepkg.conf
    sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T \${nc} -z -)/g" /etc/makepkg.conf
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
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

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
gpu_type=\$(lspci)
if echo "\${gpu_type}" | grep -E "NVIDIA|GeForce"; then
    echo -e "${BGreen}Installing NVIDIA drivers: nvidia-lts...${Color_Off}"
    pacman -S --noconfirm --needed nvidia-lts
elif echo "\${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
    echo -e "${BGreen}Installing AMD drivers: xf86-video-amdgpu...${Color_Off}"
    pacman -S --noconfirm --needed xf86-video-amdgpu
elif echo "\${gpu_type}" | grep -E "Integrated Graphics Controller|Intel Corporation UHD"; then
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
chown $USERNAME:$USERNAME /home/$USERNAME/fast-hyprland.sh
chmod +x /home/$USERNAME/fast-hyprland.sh

if [[ ${FS} == "luks" ]]; then
    sed -i 's/filesystems/encrypt filesystems/g' /etc/mkinitcpio.conf
fi
mkinitcpio -p linux-lts


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
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH
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

echo -e "${BGreen}Verifying grub configuration...${Color_Off}"
if [ ! -f /boot/grub/grub.cfg ]; then
    echo -e "${BRed}FATAL: grub.cfg was not created.${Color_Off}"
    exit 1
fi
if ! grep -q "Arch Linux" /boot/grub/grub.cfg; then
    echo -e "${BRed}FATAL: grub.cfg does not contain an Arch Linux entry.${Color_Off}"
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
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

EOF

if [ $? -ne 0 ]; then
    echo -e "${BRed}ERROR: A critical command failed inside the chroot environment.${Color_Off}"
    echo -e "${BYellow}Check the logs in archsetup.txt above this message to see what failed. Installation cannot continue.${Color_Off}"
    exit 1
fi

echo -e "${BGreen}Installation is complete! You may now reboot your system.${Color_Off}"