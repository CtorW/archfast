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

msg() {
    local type="$1"
    local message="$2"
    local color_prefix=""
    local prefix=""

    case "$type" in
        INFO)
            color_prefix="${BCyan}"
            prefix="[INFO]"
            ;;
        SUCCESS)
            color_prefix="${BGreen}"
            prefix="[SUCCESS]"
            ;;
        WARN)
            color_prefix="${BYellow}"
            prefix="[WARN]"
            ;;
        ERROR)
            color_prefix="${BRed}"
            prefix="[ERROR]"
            ;;
        *)
            # Default to plain text if type is unknown
            echo "$message"
            return
            ;;
    esac

    echo -e "${color_prefix}${prefix}${Color_Off} ${message}"
}


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
    msg "ERROR" "This script must be run from an Arch Linux ISO environment. Exiting."
    exit 1
fi

root_check() {
    if [[ "$(id -u)" != "0" ]]; then
        msg "ERROR" "This script must be run under the 'root' user! Exiting."
        exit 1
    fi
}

docker_check() {
    if awk -F/ '$2 == "docker"' /proc/self/cgroup | read -r; then
        msg "ERROR" "Docker container is not supported (at the moment). Exiting."
        exit 1
    elif [[ -f /.dockerenv ]]; then
        msg "ERROR" "Docker container is not supported (at the moment). Exiting."
        exit 1
    fi
}

arch_check() {
    if [[ ! -e /etc/arch-release ]]; then
        msg "ERROR" "This script must be run in Arch Linux! Exiting."
        exit 1
    fi
}

pacman_check() {
    if [[ -f /var/lib/pacman/db.lck ]]; then
        msg "ERROR" "Pacman is blocked."
        echo -e "If you are sure no pacman process is running, remove /var/lib/pacman/db.lck and try again."
        exit 1
    fi
}

background_checks() {
    msg "INFO" "Performing initial system checks..."
    root_check
    arch_check
    pacman_check
    docker_check
    msg "SUCCESS" "System checks passed."
}

# ==============================================================================
#                          Interactive Prompts (using Whiptail TUI)
# ==============================================================================
userinfo () {
    
    msg "INFO" "Installing 'whiptail' for user interface..."
    pacman -S --noconfirm --needed whiptail &> /dev/null

    USERNAME=$(whiptail --title "User Account Setup" --inputbox \
    "Please enter your desired username.\n\n(Use lowercase letters, no spaces. e.g., 'alex')" 10 60 archuser 3>&1 1>&2 2>&3)
    if [ $? != 0 ]; then msg "ERROR" "User canceled at Username prompt. Exiting."; exit 1; fi
    export USERNAME

    local password_match=false
    while [ "$password_match" = false ]; do
        PASSWORD=$(whiptail --title "Set User Password" --passwordbox "Enter a password for user '$USERNAME':" 10 60 3>&1 1>&2 2>&3)
        if [ $? != 0 ]; then msg "ERROR" "User canceled at Password prompt. Exiting."; exit 1; fi
        PASSWORD2=$(whiptail --title "Confirm User Password" --passwordbox "Please re-enter the password to confirm:" 10 60 3>&1 1>&2 2>&3)
        if [ $? != 0 ]; then msg "ERROR" "User canceled at Password Confirmation prompt. Exiting."; exit 1; fi

        if [ "$PASSWORD" == "$PASSWORD2" ]; then
            password_match=true
        else
            whiptail --title "Password Mismatch" --msgbox "The passwords you entered do not match. Please try again." 10 60
        fi
    done
    export PASSWORD
    
    NAME_OF_MACHINE=$(whiptail --title "System Hostname" --inputbox \
    "Please enter a hostname for this machine.\n\n(This is how it will appear on a network. e.g., 'arch-desktop')" 10 60 myarch 3>&1 1>&2 2>&3)
    if [ $? != 0 ]; then msg "ERROR" "User canceled at Hostname prompt. Exiting."; exit 1; fi
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
    if [ $? != 0 ]; then msg "ERROR" "User canceled at Disk Selection. Exiting."; exit 1; fi
    export DISK="/dev/${DISK}"

    if (whiptail --title "Storage Optimization" --yesno \
    "Is the selected disk an SSD?\n\n(Choosing 'Yes' will apply SSD-specific mount options for better performance and longevity.)" 10 60 3>&1 1>&2 2>&3); then
        export MOUNT_OPTIONS="noatime,compress=zstd,ssd,commit=120"
    else
        export MOUNT_OPTIONS="noatime,compress=zstd,commit=120"
    fi
}

filesystem () {
    FS_CHOICE=$(whiptail --title "Filesystem & Partition Scheme" --radiolist \
    "Choose the filesystem and layout for your root partition.\n(Use arrow keys and SPACE to select)" 15 78 5 \
    "btrfs" "Modern filesystem with compression & snapshots" ON \
    "ext4"  "Traditional, stable, and widely-used" OFF \
    "lvm"   "Flexible LVM layout with ext4 volumes" OFF \
    "luks"  "Btrfs with full-disk encryption for security" OFF \
    "lvm_on_luks" "LVM with ext4 volumes inside an encrypted container" OFF 3>&1 1>&2 2>&3)
    if [ $? != 0 ]; then msg "ERROR" "User canceled at Filesystem Selection. Exiting."; exit 1; fi
    export FS=${FS_CHOICE}
    
    if [[ "${FS}" == "luks" || "${FS}" == "lvm_on_luks" ]]; then
        local luks_match=false
        while [ "$luks_match" = false ]; do
            LUKS_PASSWORD=$(whiptail --title "Set Encryption Password" --passwordbox "Enter a strong password for disk encryption:" 10 60 3>&1 1>&2 2>&3)
            if [ $? != 0 ]; then msg "ERROR" "User canceled at LUKS Password prompt. Exiting."; exit 1; fi
            LUKS_PASSWORD2=$(whiptail --title "Confirm Encryption Password" --passwordbox "Re-enter the password to confirm:" 10 60 3>&1 1>&2 2>&3)
            if [ $? != 0 ]; then msg "ERROR" "User canceled at LUKS Password Confirmation. Exiting."; exit 1; fi

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
        msg "WARN" "Timezone auto-detection failed. This may be due to no internet connection."
    fi
    
    msg "INFO" "Please enter your timezone manually."
    NEW_TIMEZONE=$(whiptail --title "Manual Timezone Entry" --inputbox \
    "Please enter your timezone.\n(Format: Region/City, e.g., America/New_York, Europe/Paris)" 10 60 "Etc/UTC" 3>&1 1>&2 2>&3)
    if [ $? != 0 ]; then msg "ERROR" "User canceled at Manual Timezone Entry. Exiting."; exit 1; fi
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
    
    if [ $? != 0 ]; then msg "ERROR" "User canceled at Keyboard Layout selection. Exiting."; exit 1; fi

    if [ "$keymap_choice" == "More..." ]; then
        declare -a keymap_list=()
        while read -r line; do
            keymap_list+=("$(echo "$line" | cut -d' ' -f1)" "$(echo "$line" | cut -d' ' -f2-)")
        done < <(find /usr/share/kbd/keymaps/ -name "*.map.gz" -printf "%f\n" | sed 's/\.map\.gz$//' | sort | xargs -I {} echo "{} ()")

        keymap_choice=$(whiptail --title "All Keyboard Layouts" --menu "Select your keyboard layout:" 25 78 15 "${keymap_list[@]}" 3>&1 1>&2 2>&3)
        if [ $? != 0 ]; then msg "ERROR" "User canceled at full Keyboard Layout list. Exiting."; exit 1; fi
    fi

    msg "SUCCESS" "Keyboard layout set to: ${keymap_choice}"
    export KEYMAP="${keymap_choice}"
}

swap_option () {
    if (whiptail --title "Swap Configuration" --yesno \
    "Do you want to create a swap space?\n\nThis is recommended for systems with low RAM (less than 8GB) or for users who run memory-intensive applications or use hibernation." 12 78 3>&1 1>&2 2>&3); then
        export USE_SWAP="yes"
    else
        export USE_SWAP="no"
    fi
    if [ $? != 0 ]; then msg "ERROR" "User canceled at Swap Configuration prompt. Exiting."; exit 1; fi
}

swap_size_customization () {
    SWAP_CHOICE=$(whiptail --title "Swap File Size" --radiolist \
    "Choose a swap file size. This is recommended for systems with low RAM or for hibernation." 15 78 5 \
    "2" "2GB - Suitable for systems with 4-8GB RAM" ON \
    "4" "4GB - Good for 8GB RAM or light hibernation use" OFF \
    "8" "8GB - Recommended for 8GB+ RAM with hibernation" OFF \
    "custom" "Enter a custom size manually" OFF 3>&1 1>&2 2>&3)
    

    if [ "$SWAP_CHOICE" == "custom" ]; then
        SWAP_SIZE_GB=$(whiptail --title "Custom Swap Size" --inputbox \
        "Please enter the desired swap file size in Gigabytes (e.g., 4)." 10 60 4 3>&1 1>&2 2>&3)
        
        if [ $? != 0 ]; then msg "ERROR" "User canceled at Custom Swap Size input. Exiting."; exit 1; fi
        if ! [[ "$SWAP_SIZE_GB" =~ ^[1-9][0-9]*$ ]]; then
            whiptail --title "Invalid Input" --msgbox "Invalid number entered. Defaulting to 2GB." 10 60
            SWAP_SIZE_GB=2
        fi
    else
        SWAP_SIZE_GB=$SWAP_CHOICE
    fi

    export SWAP_SIZE_GB
    export SWAP_FILE_SIZE_MB=$((SWAP_SIZE_GB * 1024))
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
if [[ "${USE_SWAP}" == "yes" && "${FS}" != "lvm" && "${FS}" != "lvm_on_luks" ]]; then
    clear
    logo
    swap_size_customization
fi
clear

SUMMARY="
    User:           ${USERNAME}
    Hostname:       ${NAME_OF_MACHINE}
    Timezone:       ${TIMEZONE}
    Keyboard:       ${KEYMAP}
    Filesystem:     ${FS}
    Use Swap:       ${USE_SWAP}
"
if [[ "${USE_SWAP}" == "yes" && -n "$SWAP_SIZE_GB" ]]; then
    SUMMARY+="    Swap File Size: ${SWAP_SIZE_GB}GB\n"
fi


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
    msg "ERROR" "Installation canceled by user at final confirmation. Exiting."
    exit 1
fi

msg "INFO" "Setting up mirrors for optimal download speed..."
iso=$(curl -4 ifconfig.io/country_code)
timedatectl set-ntp true
pacman -Sy --noconfirm
pacman -S --noconfirm archlinux-keyring
pacman -S --noconfirm --needed pacman-contrib terminus-font
setfont ter-v18b
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
pacman -S --noconfirm --needed reflector rsync grub
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
msg "INFO" "Setting up mirrors for country '$iso' for faster downloads..."
reflector -a 48 -c "$iso" --score 5 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
if [[ $(grep -c "Server =" /etc/pacman.d/mirrorlist) -lt 5 ]]; then
    msg "WARN" "Reflector failed to find enough fast mirrors for your country."
    msg "INFO" "Falling back to a global mirror list."
    cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
    reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
fi
msg "SUCCESS" "Mirror list configured."

if [ ! -d "/mnt" ]; then
    mkdir /mnt
fi

msg "INFO" "Installing disk partitioning prerequisites..."
pacman -S --noconfirm --needed gptfdisk btrfs-progs lvm2 glibc &> /dev/null

msg "INFO" "Preparing Target Disk: ${DISK}..."
umount -A --recursive /mnt
msg "INFO" "  -> Wiping partition table..."
sgdisk -Z "${DISK}"
if [ $? -ne 0 ]; then msg "ERROR" "Failed to wipe partition table on ${DISK}. Exiting."; exit 1; fi
msg "INFO" "  -> Creating new GPT label..."
sgdisk -a 2048 -o "${DISK}"
if [ $? -ne 0 ]; then msg "ERROR" "Failed to create new GPT label on ${DISK}. Exiting."; exit 1; fi

msg "INFO" "  -> Creating BIOS boot partition (1MB)..."
sgdisk -n 1::+1M --typecode=1:ef02 --change-name=1:'BIOSBOOT' "${DISK}"
if [ $? -ne 0 ]; then msg "ERROR" "Failed to create BIOS boot partition. Exiting."; exit 1; fi
msg "INFO" "  -> Creating EFI boot partition (1GB)..."
sgdisk -n 2::+1GiB --typecode=2:ef00 --change-name=2:'EFIBOOT' "${DISK}"
if [ $? -ne 0 ]; then msg "ERROR" "Failed to create EFI boot partition. Exiting."; exit 1; fi

if [[ "${FS}" == "lvm" || "${FS}" == "lvm_on_luks" ]]; then
    msg "INFO" "  -> Creating LVM container partition (remaining space)..."
    [[ "${FS}" == "lvm" ]] && p_type="8e00" || p_type="8300"
    sgdisk -n 3::-0 --typecode=3:${p_type} --change-name=3:'LVMVOL' "${DISK}"
    if [ $? -ne 0 ]; then msg "ERROR" "Failed to create LVM container partition. Exiting."; exit 1; fi
else
    msg "INFO" "  -> Creating root partition (remaining space)..."
    sgdisk -n 3::-0 --typecode=3:8300 --change-name=3:'ROOT' "${DISK}"
    if [ $? -ne 0 ]; then msg "ERROR" "Failed to create root partition. Exiting."; exit 1; fi
fi
msg "SUCCESS" "Disk partitioning complete."

if [[ ! -d "/sys/firmware/efi" ]]; then
    sgdisk -A 1:set:2 "${DISK}"
fi
partprobe "${DISK}"

msg "INFO" "Creating Filesystems on ${DISK}..."
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
    if [ $? -ne 0 ]; then msg "ERROR" "Failed to mount btrfs root subvolume. Exiting."; exit 1; fi
    mkdir -p /mnt/home
    mountallsubvol
    if [ $? -ne 0 ]; then msg "ERROR" "Failed to mount btrfs home subvolume. Exiting."; exit 1; fi
}

if [[ "${DISK}" =~ "nvme" || "${DISK}" =~ "mmcblk" ]]; then
    partition2=${DISK}p2
    partition3=${DISK}p3
else
    partition2=${DISK}2
    partition3=${DISK}3
fi

if [[ "${FS}" == "btrfs" ]]; then
    msg "INFO" "  -> Formatting EFI partition as FAT32..."
    mkfs.fat -F32 -n "EFIBOOT" "${partition2}"; if [ $? -ne 0 ]; then msg "ERROR" "Failed to format EFI partition."; exit 1; fi
    msg "INFO" "  -> Formatting root partition as BTRFS..."
    mkfs.btrfs -f "${partition3}"; if [ $? -ne 0 ]; then msg "ERROR" "Failed to format root partition as BTRFS."; exit 1; fi
    mount -t btrfs "${partition3}" /mnt; if [ $? -ne 0 ]; then msg "ERROR" "Failed to mount BTRFS root."; exit 1; fi
    subvolumesetup
elif [[ "${FS}" == "ext4" ]]; then
    msg "INFO" "  -> Formatting EFI partition as FAT32..."
    mkfs.fat -F32 -n "EFIBOOT" "${partition2}"; if [ $? -ne 0 ]; then msg "ERROR" "Failed to format EFI partition."; exit 1; fi
    msg "INFO" "  -> Formatting root partition as EXT4..."
    mkfs.ext4 -F "${partition3}"; if [ $? -ne 0 ]; then msg "ERROR" "Failed to format root partition as EXT4."; exit 1; fi
    mount -t ext4 "${partition3}" /mnt; if [ $? -ne 0 ]; then msg "ERROR" "Failed to mount EXT4 root."; exit 1; fi
elif [[ "${FS}" == "luks" ]]; then
    msg "INFO" "  -> Formatting EFI partition as FAT32..."
    mkfs.fat -F32 "${partition2}"; if [ $? -ne 0 ]; then msg "ERROR" "Failed to format EFI partition."; exit 1; fi
    msg "INFO" "  -> Creating LUKS encrypted container..."
    echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v luksFormat "${partition3}" -; if [ $? -ne 0 ]; then msg "ERROR" "LUKS container creation failed."; exit 1; fi
    msg "INFO" "  -> Opening LUKS container..."
    echo -n "${LUKS_PASSWORD}" | cryptsetup open "${partition3}" ROOT -; if [ $? -ne 0 ]; then msg "ERROR" "Failed to open LUKS container."; exit 1; fi
    msg "INFO" "  -> Formatting LUKS container as BTRFS..."
    mkfs.btrfs /dev/mapper/ROOT; if [ $? -ne 0 ]; then msg "ERROR" "Failed to format LUKS container as BTRFS."; exit 1; fi
    mount -t btrfs /dev/mapper/ROOT /mnt; if [ $? -ne 0 ]; then msg "ERROR" "Failed to mount encrypted BTRFS root."; exit 1; fi
    subvolumesetup
    ENCRYPTED_PARTITION_UUID=$(blkid -s UUID -o value "${partition3}")
elif [[ "${FS}" == "lvm" || "${FS}" == "lvm_on_luks" ]]; then
    
    msg "INFO" "  -> Formatting EFI partition as FAT32..."
    mkfs.fat -F32 -n "EFIBOOT" "${partition2}"; if [ $? -ne 0 ]; then msg "ERROR" "Failed to format EFI partition."; exit 1; fi
    LVM_TARGET="${partition3}"
    if [[ "${FS}" == "lvm_on_luks" ]]; then
        msg "INFO" "  -> Creating LUKS encrypted container..."
        echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v luksFormat "${partition3}" -; if [ $? -ne 0 ]; then msg "ERROR" "LUKS container creation failed."; exit 1; fi
        msg "INFO" "  -> Opening LUKS container..."
        echo -n "${LUKS_PASSWORD}" | cryptsetup open "${partition3}" cryptlvm -; if [ $? -ne 0 ]; then msg "ERROR" "Failed to open LUKS container."; exit 1; fi
        LVM_TARGET="/dev/mapper/cryptlvm"
        ENCRYPTED_PARTITION_UUID=$(blkid -s UUID -o value "${partition3}")
    fi

    
    msg "INFO" "  -> Setting up LVM on ${LVM_TARGET}..."
    pvcreate "${LVM_TARGET}"; if [ $? -ne 0 ]; then msg "ERROR" "LVM pvcreate failed."; exit 1; fi
    vgcreate arch-vg "${LVM_TARGET}"; if [ $? -ne 0 ]; then msg "ERROR" "LVM vgcreate failed."; exit 1; fi
    if [[ "${USE_SWAP}" == "yes" ]]; then
        TOTAL_MEM_GB=$(($(grep -i 'memtotal' /proc/meminfo | grep -o '[[:digit:]]*') / 1024 / 1024))
        SWAP_SIZE=$((TOTAL_MEM_GB > 8 ? 8 : TOTAL_MEM_GB))
        msg "INFO" "  -> Creating ${SWAP_SIZE}G LVM swap volume..."
        lvcreate -L ${SWAP_SIZE}G arch-vg -n swap; if [ $? -ne 0 ]; then msg "ERROR" "LVM swap volume creation failed."; exit 1; fi
    fi
    
    msg "INFO" "  -> Creating 40G LVM root volume..."
    lvcreate -L 40G arch-vg -n root; if [ $? -ne 0 ]; then msg "ERROR" "LVM root volume creation failed."; exit 1; fi
    msg "INFO" "  -> Creating LVM home volume (using remaining space)..."
    lvcreate -l 100%FREE arch-vg -n home; if [ $? -ne 0 ]; then msg "ERROR" "LVM home volume creation failed."; exit 1; fi

    msg "INFO" "  -> Formatting LVM volumes with ext4..."
    mkfs.ext4 /dev/arch-vg/root; if [ $? -ne 0 ]; then msg "ERROR" "Failed to format LVM root volume."; exit 1; fi
    mkfs.ext4 /dev/arch-vg/home; if [ $? -ne 0 ]; then msg "ERROR" "Failed to format LVM home volume."; exit 1; fi
    if [[ "${USE_SWAP}" == "yes" ]]; then
        mkswap /dev/arch-vg/swap; if [ $? -ne 0 ]; then msg "ERROR" "Failed to create swap on LVM volume."; exit 1; fi
    fi

    msg "INFO" "  -> Mounting LVM volumes..."
    mount /dev/arch-vg/root /mnt
    mkdir -p /mnt/home
    mount /dev/arch-vg/home /mnt/home
    if [[ "${USE_SWAP}" == "yes" ]]; then
        swapon /dev/arch-vg/swap
    fi
fi
msg "SUCCESS" "Filesystem creation and mounting complete."

BOOT_UUID=$(blkid -s UUID -o value "${partition2}")

sync
if ! mountpoint -q /mnt; then
    msg "ERROR" "Failed to mount root partition to /mnt. Exiting."
    exit 1
fi
mkdir -p /mnt/boot
mount -U "${BOOT_UUID}" /mnt/boot/
if [ $? -ne 0 ]; then msg "ERROR" "Failed to mount EFI partition to /mnt/boot. Exiting."; exit 1; fi

if ! grep -qs '/mnt' /proc/mounts; then
    msg "ERROR" "Drive is not mounted. Rebooting in 3 seconds..." && sleep 3
    reboot now
fi

msg "INFO" "Installing Arch Linux base system via Pacstrap..."
echo -e "${BYellow}This is the longest step and can take several minutes. Please be patient.${Color_Off}"
PKGS="base base-devel linux-lts linux-firmware"
if [[ -d "/sys/firmware/efi" ]]; then
    PKGS+=" efibootmgr"
fi
pacstrap /mnt $PKGS --noconfirm --needed
if [ $? -ne 0 ]; then
    msg "ERROR" "Pacstrap failed to install the base system."
    msg "WARN" "This is often due to a network issue or bad mirrors. Exiting."
    exit 1
fi
msg "SUCCESS" "Base system installation complete."

echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

genfstab -U /mnt >> /mnt/etc/fstab
msg "SUCCESS" "Generated /etc/fstab."

msg "INFO" "Installing GRUB Bootloader..."
if [[ ! -d "/sys/firmware/efi" ]]; then
    msg "INFO" "  -> Installing GRUB for BIOS..."
    grub-install --boot-directory=/mnt/boot "${DISK}"
    if [ $? -ne 0 ]; then msg "ERROR" "GRUB BIOS installation failed. Exiting."; exit 1; fi
fi

if [[ "${USE_SWAP}" == "yes" && "${FS}" != "lvm" && "${FS}" != "lvm_on_luks" ]]; then
    msg "INFO" "Creating a ${SWAP_SIZE_GB}GB swap file..."
    mkdir -p /mnt/swap
    dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=${SWAP_FILE_SIZE_MB} status=progress
    chmod 600 /mnt/swap/swapfile
    mkswap /mnt/swap/swapfile
    swapon /mnt/swap/swapfile
    echo "/swap/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
    msg "SUCCESS" "Swap file created and enabled."
fi

arch-chroot /mnt /bin/bash -c "FS='${FS}' ENCRYPTED_PARTITION_UUID='${ENCRYPTED_PARTITION_UUID}' /bin/bash" <<EOF
set -e

echo "root:${PASSWORD}" | chpasswd

echo -e "${BGreen}[INFO]${Color_Off} Setting up network configuration..."
pacman -S --noconfirm --needed networkmanager dhcpcd &> /dev/null
systemctl enable NetworkManager
echo -e "${BGreen}[SUCCESS]${Color_Off} NetworkManager enabled."

echo -e "${BGreen}[INFO]${Color_Off} Refreshing pacman repositories and enabling parallel downloads..."
pacman -S --noconfirm --needed pacman-contrib curl reflector rsync grub arch-install-scripts git ntp wget &> /dev/null
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak

nc=\$(grep -c ^"cpu cores" /proc/cpuinfo)
export nc
echo -e "${BGreen}[INFO]${Color_Off} Detected \${nc} CPU cores. Optimizing makepkg configuration..."
TOTAL_MEM=\$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[ \$TOTAL_MEM -gt 8000000 ]]; then
    sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j\${nc}\"/g" /etc/makepkg.conf
    sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T \${nc} -z -)/g" /etc/makepkg.conf
fi

echo -e "${BGreen}[INFO]${Color_Off} Configuring system locale and time..."
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
timedatectl --no-ask-password set-timezone ${TIMEZONE}
timedatectl --no-ask-password set-ntp 1
localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
echo "XKBLAYOUT=${KEYMAP}" >> /etc/vconsole.conf
echo -e "${BGreen}[SUCCESS]${Color_Off} System keymap set to: ${KEYMAP}"

sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm --needed

echo -e "${BGreen}[INFO]${Color_Off} Installing CPU microcode..."
if grep -q "GenuineIntel" /proc/cpuinfo; then
    pacman -S --noconfirm --needed intel-ucode &> /dev/null
    echo -e "${BGreen}[SUCCESS]${Color_Off} Installed Intel microcode."
elif grep -q "AuthenticAMD" /proc/cpuinfo; then
    pacman -S --noconfirm --needed amd-ucode &> /dev/null
    echo -e "${BGreen}[SUCCESS]${Color_Off} Installed AMD microcode."
else
    echo -e "${BYellow}[WARN]${Color_Off} Could not determine CPU vendor. Skipping microcode installation."
fi

echo -e "${BGreen}[INFO]${Color_Off} Detecting and installing graphics drivers..."
gpu_type=\$(lspci)
if echo "\${gpu_type}" | grep -E "NVIDIA|GeForce"; then
    pacman -S --noconfirm --needed nvidia-lts &> /dev/null
    echo -e "${BGreen}[SUCCESS]${Color_Off} Installed NVIDIA drivers."
elif echo "\${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
    pacman -S --noconfirm --needed xf86-video-amdgpu &> /dev/null
    echo -e "${BGreen}[SUCCESS]${Color_Off} Installed AMD drivers."
elif echo "\${gpu_type}" | grep -E "Integrated Graphics Controller|Intel Corporation UHD"; then
    pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa &> /dev/null
    echo -e "${BGreen}[SUCCESS]${Color_Off} Installed Intel drivers."
else
    echo -e "${BYellow}[WARN]${Color_Off} Could not determine GPU vendor. Skipping graphics driver installation."
fi

echo -e "${BGreen}[INFO]${Color_Off} Creating user account and setting hostname..."
groupadd libvirt
useradd -m -G wheel,libvirt -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo $NAME_OF_MACHINE > /etc/hostname
echo -e "${BGreen}[SUCCESS]${Color_Off} User '$USERNAME' created and hostname set to '$NAME_OF_MACHINE'."

echo -e "${BGreen}[INFO]${Color_Off} Downloading post-install script to /home/$USERNAME/..."
wget https://raw.githubusercontent.com/CtorW/archfast/refs/heads/uno/fast-de.sh -P /home/$USERNAME/ &> /dev/null
chown $USERNAME:$USERNAME /home/$USERNAME/fast-de.sh
chmod +x /home/$USERNAME/fast-de.sh
echo -e "${BGreen}[SUCCESS]${Color_Off} Post-install script is ready."

echo -e "${BGreen}[INFO]${Color_Off} Configuring bootloader initramfs..."
# Add hooks for encryption and LVM if needed
if [[ \${FS} == "luks" ]]; then
    sed -i 's/HOOKS=(base udev/HOOKS=(base udev encrypt/' /etc/mkinitcpio.conf
elif [[ \${FS} == "lvm" ]]; then
    sed -i 's/HOOKS=(base udev/HOOKS=(base udev lvm2/' /etc/mkinitcpio.conf
elif [[ \${FS} == "lvm_on_luks" ]]; then
    sed -i 's/HOOKS=(base udev/HOOKS=(base udev encrypt lvm2/' /etc/mkinitcpio.conf
fi
mkinitcpio -p linux-lts

echo -e "${BGreen}[INFO]${Color_Off} Finalizing GRUB bootloader installation..."

if [[ -d "/sys/firmware/efi" ]]; then
    echo -e "${BGreen}[INFO]${Color_Off}   -> Installing GRUB for EFI..."
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH
fi

echo -e "${BGreen}[INFO]${Color_Off}   -> Creating GRUB boot menu..."
# Update GRUB command line for encrypted systems
if [[ "\${FS}" == "luks" ]]; then
    sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"%GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=\${ENCRYPTED_PARTITION_UUID}:ROOT root=/dev/mapper/ROOT %g" /etc/default/grub
elif [[ "\${FS}" == "lvm_on_luks" ]]; then
    sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"%GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=\${ENCRYPTED_PARTITION_UUID}:cryptlvm root=/dev/mapper/arch--vg-root %g" /etc/default/grub
fi
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& splash /' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo -e "${BGreen}[INFO]${Color_Off} Enabling essential system services..."
ntpd -qg
systemctl enable ntpd.service &> /dev/null
systemctl disable dhcpcd.service &> /dev/null
systemctl enable NetworkManager.service &> /dev/null
systemctl enable reflector.timer &> /dev/null
echo -e "${BGreen}[SUCCESS]${Color_Off} Services (NTP, NetworkManager, Reflector) enabled."

echo -e "${BGreen}[INFO]${Color_Off} Cleaning up and finalizing user permissions..."
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

EOF

if [ $? -ne 0 ]; then
    msg "ERROR" "A critical command failed inside the chroot environment."
    msg "WARN" "Check the logs in archsetup.txt above this message. Installation cannot continue."
    exit 1
fi

msg "SUCCESS" "Installation is complete! You may now reboot your system."