#!/bin/bash

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
UBlack="\033[4;30m"
URed="\033[4;31m"
UGreen="\033[4;32m"
UYellow="\033[4;33m"
UBlue="\033[4;34m"
UPurple="\033[4;35m"
UCyan="\033[4;36m"
UWhite="\033[4;37m"
On_Black="\033[40m"
On_Red="\033[41m"
On_Green="\033[42m"
On_Yellow="\033[43m"
On_Blue="\033[44m"
On_Purple="\033[45m"
On_Cyan="\033[46m"
On_White="\033[47m"
IBlack="\033[0;90m"
IRed="\033[0;91m"
IGreen="\033[0;92m"
IYellow="\033[0;93m"
IBlue="\033[0;94m"
IPurple="\033[0;95m"
ICyan="\033[0;96m"
IWhite="\033[0;97m"
BIBlack="\033[1;90m"
BIRed="\033[1;91m"
BIGreen="\033[1;92m"
BIYellow="\033[1;93m"
BIBlue="\033[1;94m"
BIPurple="\033[1;95m"
BICyan="\033[1;96m"
BIWhite="\033[1;97m"
On_IBlack="\033[0;100m"
On_IRed="\033[0;101m"
On_IGreen="\033[0;102m"
On_IYellow="\033[0;103m"
On_IBlue="\033[0;104m"
On_IPurple="\033[10;95m"
On_ICyan="\033[0;106m"
On_IWhite="\033[0;107m"

set -euo pipefail

exec > >(tee -i archsetup.txt)
exec 2>&1

trap 'cleanup_on_exit' EXIT

cleanup_on_exit() {
    echo -e "${Cyan}--- Cleaning up on exit ---${Color_Off}"
    if mountpoint -q /mnt; then
        echo -e "${Yellow}Unmounting /mnt...${Color_Off}"
        umount -A --recursive /mnt || true
    fi
    echo -e "${Cyan}Cleanup complete.${Color_Off}"
}

export FS=""
export LUKS_PASSWORD=""
export TIMEZONE=""
export KEYMAP=""
export MOUNT_OPTIONS=""
export DISK=""
export USERNAME=""
export PASSWORD=""
export NAME_OF_MACHINE=""
export ENCRYPTED_PARTITION_UUID=""
export HYPRLAND_DOTS_CHOICE=""

logo() {
echo -ne "${BCyan}
-------------------------------------------------------------------------
             ___    ____  ________  ___________   ___________
            /   |  / __ \/ ____/ / / / ____/   | / ___/_  __/
           / /| | / /_/ / /   / /_/ / /_  / /| | \__ \ / /   
          / ___ |/ _, _/ /___/ __  / __/ / ___ |___/ // /    
         /_/  |_/_/ |_|\____/_/ /_/_/   /_/  |_/____//_/    
-------------------------------------------------------------------------
          Automated Arch Linux Installer
-------------------------------------------------------------------------
${Color_Off}"
}

display_section_title() {
    echo -e "${BCyan}
-------------------------------------------------------------------------
                      $1
-------------------------------------------------------------------------
${Color_Off}"
}

select_option() {
    local options=("$@")
    local num_options=${#options[@]}
    local selected=0
    local last_selected=-1

    echo -e "${BBlue}Please select an option using the arrow keys and Enter:${Color_Off}"

    while true; do
        if [ $last_selected -ne -1 ]; then
            echo -ne "\033[${num_options}A"
        fi

        for i in "${!options[@]}"; do
            if [ "$i" -eq "$selected" ]; then
                echo -e "${BGreen}> ${options[$i]}${Color_Off}"
            else
                echo -e "  ${options[$i]}"
            fi
        done

        last_selected=$selected

        read -rsn1 key
        case $key in
            $'\x1b')
                read -rsn2 -t 0.1 key_arrow
                case $key_arrow in
                    '[A')
                        ((selected--))
                        if [ "$selected" -lt 0 ]; then
                            selected=$((num_options - 1))
                        fi
                        ;;
                    '[B')
                        ((selected++))
                        if [ "$selected" -ge "$num_options" ]; then
                            selected=0
                        fi
                        ;;
                esac
                ;;
            '')
                break
                ;;
        esac
    done

    return "$selected"
}

set_password() {
    local var_name=$1
    local pass1
    local pass2
    while true; do
        read -rs -p "${BBlue}Please enter password for $var_name: ${Color_Off}" pass1
        echo ""
        read -rs -p "${BBlue}Please re-enter password for $var_name: ${Color_Off}" pass2
        echo ""
        if [[ "$pass1" == "$pass2" ]]; then
            eval "$var_name='$pass1'"
            echo -e "${Green}Password set successfully.${Color_Off}"
            break
        else
            echo -e "${BRed}ERROR! Passwords do not match. Please try again.${Color_Off}"
        fi
    done
}


check_arch_iso() {
    if [ ! -f /usr/bin/pacstrap ]; then
        echo -e "${BRed}ERROR: This script must be run from an Arch Linux ISO environment.${Color_Off}"
        exit 1
    fi
}

root_check() {
    if [[ "$(id -u)" -ne "0" ]]; then
        echo -e "${BRed}ERROR: This script must be run under the 'root' user!${Color_Off}"
        exit 1
    fi
}

docker_check() {
    if awk -F/ '$2 == "docker"' /proc/self/cgroup | read -r || [[ -f /.dockerenv ]]; then
        echo -e "${BRed}ERROR: Docker container is not supported (at the moment).${Color_Off}"
        exit 1
    fi
}

pacman_check() {
    if [[ -f /var/lib/pacman/db.lck ]]; then
        echo -e "${BRed}ERROR: Pacman is blocked. If not running, remove /var/lib/pacman/db.lck.${Color_Off}"
        exit 1
    fi
}

background_checks() {
    display_section_title "Verifying Arch Linux ISO is Booted & System Checks"
    check_arch_iso
    root_check
    pacman_check
    docker_check
    echo -e "${Green}All initial checks passed.${Color_Off}"
}


filesystem() {
    display_section_title "Filesystem Selection"
    echo -e "${BBlue}Please select your file system for both boot and root.${Color_Off}"
    # List options
    echo "1) btrfs"
    echo "2) ext4"
    echo "3) luks"
    echo "4) Exit Script"

    while true; do
        read -rp "Enter the number of your choice [1-4]: " choice
        case "$choice" in
            1)
                export FS="btrfs"
                break
                ;;
            2)
                export FS="ext4"
                break
                ;;
            3)
                set_password "LUKS_PASSWORD"
                export FS="luks"
                break
                ;;
            4)
                exit
                ;;
            *)
                echo -e "${BRed}Invalid option. Please select again.${Color_Off}"
                ;;
        esac
    done
    echo -e "${Green}Filesystem selected: ${FS}${Color_Off}"
}

timezone() {
    display_section_title "Timezone Configuration"
    local detected_timezone
    detected_timezone="$(curl --fail --silent --show-error https://ipapi.co/timezone || echo "Unknown")"

    echo -e "${BBlue}System detected your timezone to be '${detected_timezone}'.${Color_Off}"
    echo -e "${BBlue}Is this correct?${Color_Off}"
    options=("Yes" "No")
    select_option "${options[@]}"
    local choice_index=$?

    case ${choice_index} in
        0)
            echo -e "${Green}${detected_timezone} set as timezone.${Color_Off}"
            export TIMEZONE="${detected_timezone}"
            ;;
        1)
            read -r -p "${BBlue}Please enter your desired timezone (e.g., Europe/London): ${Color_Off}" new_timezone
            echo -e "${Green}${new_timezone} set as timezone.${Color_Off}"
            export TIMEZONE="${new_timezone}"
            ;;
        *) echo -e "${BRed}Invalid option. Trying again.${Color_Off}"; timezone;;
    esac

    if ! timedatectl list-timezones | grep -q "^${TIMEZONE}$"; then
        echo -e "${Yellow}WARNING: The selected timezone '${TIMEZONE}' might be invalid. Please double-check.${Color_Off}"
        read -r -p "${Yellow}Press Enter to continue or Ctrl+C to exit and correct.${Color_Off}"
    fi
}

keymap() {
    display_section_title "Keyboard Layout Selection"
    echo -e "${BBlue}Please select your keyboard layout from this list:${Color_Off}"
    options=(us by ca cf cz de dk es et fa fi fr gr hu il it lt lv mk nl no pl ro ru se sg ua uk)

    select_option "${options[@]}"
    export KEYMAP="${options[$?]}"

    echo -e "${Green}Your keyboard layout: ${KEYMAP}${Color_Off}"
}

drivessd() {
    display_section_title "Drive Type"
    echo -e "${BBlue}Is the selected disk an SSD? Type yes or no:${Color_Off}"
    while true; do
        read -r answer
        case "${answer,,}" in
            yes)
                export MOUNT_OPTIONS="noatime,compress=zstd,ssd,commit=120"
                break
                ;;
            no)
                export MOUNT_OPTIONS="noatime,compress=zstd,commit=120"
                break
                ;;
            *)
                echo -e "${BRed}Invalid input. Please type yes or no:${Color_Off}"
                ;;
        esac
    done
    echo -e "${Green}Mount options set based on drive type.${Color_Off}"
}

diskpart() {
    display_section_title "Disk Selection and Warning"
    echo -e "${On_IRed}${BIWhite}
------------------------------------------------------------------------
    !!! WARNING: THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK !!!
    Please ensure you know what you are doing. After formatting, there
    is no easy way to recover data.
    ***** BACKUP YOUR DATA BEFORE CONTINUING *****
    *** I AM NOT RESPONSIBLE FOR ANY DATA LOSS ***
------------------------------------------------------------------------
${Color_Off}"
    read -r -p "${BYellow}Type 'I UNDERSTAND' to continue with disk selection: ${Color_Off}" confirmation
    if [[ "$confirmation" != "I UNDERSTAND" ]]; then
        echo -e "${BRed}Confirmation failed. Exiting script.${Color_Off}"
        exit 1
    fi

    echo -e "${BBlue}Scanning for available disks...${Color_Off}"
    local options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))

    if [ ${#options[@]} -eq 0 ]; then
        echo -e "${BRed}ERROR: No disks found. Exiting.${Color_Off}"
        exit 1
    fi

    select_option "${options[@]}"
    local selected_disk_info="${options[$?]}"
    export DISK="${selected_disk_info%|*}"

    echo -e "${Green}Selected disk: ${DISK} (${selected_disk_info#*|})${Color_Off}"
    drivessd
}

userinfo() {
    display_section_title "User and Hostname Information"
    while true; do
        read -r -p "${BBlue}Please enter username for the new system: ${Color_Off}" username
        if [[ "${username,,}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]; then
            export USERNAME="$username"
            echo -e "${Green}Username accepted.${Color_Off}"
            break
        else
            echo -e "${BRed}Invalid username. Usernames must start with a lowercase letter or underscore, and can contain lowercase letters, numbers, underscores, or hyphens (max 31 chars).${Color_Off}"
        fi
    done

    set_password "PASSWORD"

    while true; do
        read -r -p "${BBlue}Please name your machine (hostname): ${Color_Off}" name_of_machine
        if [[ "${name_of_machine,,}" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]; then
            export NAME_OF_MACHINE="$name_of_machine"
            echo -e "${Green}Hostname accepted.${Color_Off}"
            break
        else
            echo -e "${BRed}Hostname doesn't seem correct. Hostnames should start and end with a letter or number, and can contain hyphens (max 63 chars).${Color_Off}"
            read -r -p "${BYellow}Do you still want to save it? (y/N) ${Color_Off}" force_save
            if [[ "${force_save,,}" = "y" ]]; then
                export NAME_OF_MACHINE="$name_of_machine"
                echo -e "${Yellow}Hostname saved by force. Proceeding with potentially invalid hostname.${Color_Off}"
                break
            fi
        fi
    done
    echo -e "${Green}Hostname set to: ${NAME_OF_MACHINE}${Color_Off}"
}

hyprland_dots_menu() {
    display_section_title "Hyprland Dotfiles Integration"
    echo -e "${BBlue}Do you want to install Hyprland with the HyDE dotfiles?${Color_Off}"
    echo -e "${Yellow}Note: This will clone and run the HyDE install script as your user.${Color_Off}"
    options=("Yes, install Hyprland with HyDE Dots" "No, skip dotfiles")
    select_option "${options[@]}"
    local choice_index=$?

    case ${choice_index} in
        0) export HYPRLAND_DOTS_CHOICE="yes";;
        1) export HYPRLAND_DOTS_CHOICE="no";;
        *) echo -e "${BRed}Invalid option. Please select again.${Color_Off}"; hyprland_dots_menu;;
    esac
    echo -e "${Green}Hyprland dotfiles choice: ${HYPRLAND_DOTS_CHOICE}${Color_Off}"
}


createsubvolumes() {
    echo -e "${Blue}Creating btrfs subvolumes...${Color_Off}"
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    echo -e "${Green}Btrfs subvolumes created: /@, /@home${Color_Off}"
}

mountallsubvol() {
    echo -e "${Blue}Mounting btrfs subvolumes...${Color_Off}"
    mount -o "${MOUNT_OPTIONS},subvol=@home" "${partition3}" /mnt/home
    echo -e "${Green}Btrfs subvolumes mounted.${Color_Off}"
}

subvolumesetup() {
    echo -e "${Blue}Setting up BTRFS subvolumes...${Color_Off}"
    createsubvolumes
    umount /mnt
    mount -o "${MOUNT_OPTIONS},subvol=@" "${partition3}" /mnt
    mkdir -p /mnt/home
    mountallsubvol
    echo -e "${Green}BTRFS subvolume setup complete.${Color_Off}"
}

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
hyprland_dots_menu
clear

display_section_title "System Setup and Mirror Configuration"

echo -e "${Blue}Setting up mirrors for optimal download...${Color_Off}"
local iso_country_code="$(curl --fail --silent --show-error https://ifconfig.io/country_code || echo "US")"
echo -e "${Green}Detected country: ${iso_country_code}${Color_Off}"

timedatectl set-ntp true
pacman -Sy --noconfirm --needed archlinux-keyring
pacman -S --noconfirm --needed pacman-contrib terminus-font reflector rsync grub git wget curl
setfont ter-v18b
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
echo -e "${Blue}Reflecting mirrors for ${iso_country_code}...${Color_Off}"
reflector -a 48 -c "${iso_country_code}" --score 5 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist || {
    echo -e "${BRed}Reflector failed. Falling back to backup mirrorlist.${Color_Off}"
    cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
}

if [[ $(grep -c "Server =" /etc/pacman.d/mirrorlist) -lt 5 ]]; then
    echo -e "${Yellow}Less than 5 mirrors found. Restoring mirrorlist from backup.${Color_Off}"
    cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
fi

if [ ! -d "/mnt" ]; then
    mkdir /mnt
fi

display_section_title "Installing Prerequisites"
echo -e "${Blue}Installing essential packages: gptfdisk, btrfs-progs, cryptsetup...${Color_Off}"
pacman -S --noconfirm --needed gptfdisk btrfs-progs cryptsetup
echo -e "${Green}Prerequisites installed.${Color_Off}"

display_section_title "Formatting Disk"
echo -e "${Yellow}Ensuring all partitions on /mnt are unmounted...${Color_Off}"
umount -A --recursive /mnt || true

echo -e "${Blue}Zapping all partitions on ${DISK}...${Color_Off}"
sgdisk -Z "${DISK}"
echo -e "${Blue}Creating new GPT partition table on ${DISK}...${Color_Off}"
sgdisk -a 2048 -o "${DISK}"

echo -e "${Blue}Creating partitions...${Color_Off}"
sgdisk -n 1::+1M --typecode=1:ef02 --change-name=1:'BIOSBOOT' "${DISK}"
sgdisk -n 2::+1GiB --typecode=2:ef00 --change-name=2:'EFIBOOT' "${DISK}"
sgdisk -n 3::-0 --typecode=3:8300 --change-name=3:'ROOT' "${DISK}"

if [[ ! -d "/sys/firmware/efi" ]]; then
    echo -e "${Yellow}BIOS detected. Setting BIOS bootable flag on partition 1.${Color_Off}"
    sgdisk -A 1:set:2 "${DISK}"
fi
echo -e "${Blue}Rereading partition table...${Color_Off}"
partprobe "${DISK}"
sleep 2

if [[ "${DISK}" =~ "nvme" ]]; then
    local partition2="${DISK}p2"
    local partition3="${DISK}p3"
else
    local partition2="${DISK}2"
    local partition3="${DISK}3"
fi

display_section_title "Creating Filesystems"

if [[ "${FS}" == "btrfs" ]]; then
    echo -e "${Blue}Creating FAT32 filesystem on ${partition2} (EFIBOOT)...${Color_Off}"
    mkfs.fat -F32 -n "EFIBOOT" "${partition2}"
    echo -e "${Blue}Creating BTRFS filesystem on ${partition3} (ROOT)...${Color_Off}"
    mkfs.btrfs -f "${partition3}"
    echo -e "${Blue}Mounting BTRFS root to /mnt...${Color_Off}"
    mount -t btrfs "${partition3}" /mnt
    subvolumesetup
elif [[ "${FS}" == "ext4" ]]; then
    echo -e "${Blue}Creating FAT32 filesystem on ${partition2} (EFIBOOT)...${Color_Off}"
    mkfs.fat -F32 -n "EFIBOOT" "${partition2}"
    echo -e "${Blue}Creating EXT4 filesystem on ${partition3} (ROOT)...${Color_Off}"
    mkfs.ext4 "${partition3}"
    echo -e "${Blue}Mounting EXT4 root to /mnt...${Color_Off}"
    mount -t ext4 "${partition3}" /mnt
elif [[ "${FS}" == "luks" ]]; then
    echo -e "${Blue}Creating FAT32 filesystem on ${partition2} (EFIBOOT)...${Color_Off}"
    mkfs.fat -F32 "${partition2}"
    echo -e "${Blue}Encrypting ${partition3} with LUKS...${Color_Off}"
    echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v luksFormat "${partition3}" -
    echo -e "${Blue}Opening LUKS container 'ROOT'...${Color_Off}"
    echo -n "${LUKS_PASSWORD}" | cryptsetup open "${partition3}" ROOT -
    echo -e "${Blue}Creating BTRFS filesystem on /dev/mapper/ROOT...${Color_Off}"
    mkfs.btrfs "/dev/mapper/ROOT"
    echo -e "${Blue}Mounting BTRFS root to /mnt...${Color_Off}"
    mount -t btrfs "/dev/mapper/ROOT" /mnt
    subvolumesetup
    export ENCRYPTED_PARTITION_UUID=$(blkid -s UUID -o value "${partition3}")
fi
echo -e "${Green}Filesystem creation complete.${Color_Off}"

sync

if ! mountpoint -q /mnt; then
    echo -e "${BRed}ERROR: Failed to mount the root partition (${partition3}) to /mnt after multiple attempts.${Color_Off}"
    exit 1
fi

local BOOT_UUID=$(blkid -s UUID -o value "${partition2}")
mkdir -p /mnt/boot
echo -e "${Blue}Mounting boot partition ${partition2} (UUID: ${BOOT_UUID}) to /mnt/boot...${Color_Off}"
mount -U "${BOOT_UUID}" /mnt/boot/

if ! grep -qs '/mnt' /proc/mounts; then
    echo -e "${BRed}ERROR: Drive is not mounted. Cannot continue. Rebooting in 3 seconds...${Color_Off}"
    sleep 3
    reboot now
fi

display_section_title "Arch Install on Main Drive"
if [[ ! -d "/sys/firmware/efi" ]]; then
    echo -e "${Blue}Installing base system (BIOS/Legacy boot)...${Color_Off}"
    pacstrap /mnt base base-devel linux-lts linux-firmware --noconfirm --needed
else
    echo -e "${Blue}Installing base system (UEFI boot)...${Color_Off}"
    pacstrap /mnt base base-devel linux-lts linux-firmware efibootmgr --noconfirm --needed
fi
echo -e "${Green}Base system installation complete.${Color_Off}"

echo -e "${Blue}Adding Arch Linux keyring keyserver to pacman.d/gnupg/gpg.conf...${Color_Off}"
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf
echo -e "${Blue}Copying mirrorlist to /mnt/etc/pacman.d/mirrorlist...${Color_Off}"
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

echo -e "${Blue}Generating /etc/fstab...${Color_Off}"
genfstab -U /mnt >> /mnt/etc/fstab
echo -e "${Green}Generated /etc/fstab:${Color_Off}"
cat /mnt/etc/fstab

display_section_title "GRUB BIOS Bootloader Install"
if [[ ! -d "/sys/firmware/efi" ]]; then
    echo -e "${Blue}Installing GRUB for BIOS on ${DISK}...${Color_Off}"
    grub-install --boot-directory=/mnt/boot "${DISK}"
    echo -e "${Green}GRUB BIOS installation complete.${Color_Off}"
fi

display_section_title "Checking for low memory systems (<8GB)"
local TOTAL_MEM_KB=$(grep -i 'memtotal' /proc/meminfo | awk '{print $2}')
local TOTAL_MEM_MB=$((TOTAL_MEM_KB / 1024))

if [[ "$TOTAL_MEM_MB" -lt 8000 ]]; then
    echo -e "${Yellow}System memory (${TOTAL_MEM_MB}MB) is less than 8GB. Creating a 2GB swap file.${Color_Off}"
    mkdir -p /mnt/opt/swap
    if findmnt -n -o FSTYPE /mnt | grep -q btrfs; then
        echo -e "${Blue}Applying NOCOW attribute to swap directory for Btrfs...${Color_Off}"
        chattr +C /mnt/opt/swap
    fi
    echo -e "${Blue}Creating swapfile (2GB)...${Color_Off}"
    dd if=/dev/zero of=/mnt/opt/swap/swapfile bs=1M count=2048 status=progress
    chmod 600 /mnt/opt/swap/swapfile
    chown root /mnt/opt/swap/swapfile
    mkswap /mnt/opt/swap/swapfile
    echo -e "${Blue}Enabling swap file...${Color_Off}"
    swapon /mnt/opt/swap/swapfile
    echo "/opt/swap/swapfile none swap sw 0 0" >> /mnt/etc/fstab
    echo -e "${Green}Swap file created and added to fstab.${Color_Off}"
else
    echo -e "${Green}System memory (${TOTAL_MEM_MB}MB) is 8GB or more. Skipping swap file creation.${Color_Off}"
fi

local gpu_type=$(lspci | grep -E "VGA|3D|Display")

display_section_title "Entering Chroot Environment for Final Configuration"

arch-chroot /mnt /bin/bash <<EOF
Color_Off="\033[0m"
Red="\033[0;31m"
Green="\033[0;32m"
Yellow="\033[0;33m"
Blue="\033[0;34m"
Cyan="\033[0;36m"
BRed="\033[1;31m"
BGreen="\033[1;32m"
BYellow="\033[1;33m"
BBlue="\033[1;34m"
BCyan="\033[1;36m"

set -euo pipefail

echo -e "${BCyan}--- Network Setup ---${Color_Off}"
echo -e "${Blue}Installing NetworkManager and dhcpcd...${Color_Off}"
pacman -S --noconfirm --needed networkmanager dhcpcd
systemctl enable NetworkManager
echo -e "${Green}NetworkManager enabled.${Color_Off}"

echo -e "${BCyan}--- Setting up pacman configuration ---${Color_Off}"
echo -e "${Blue}Installing pacman-contrib and curl...${Color_Off}"
pacman -S --noconfirm --needed pacman-contrib curl
echo -e "${Blue}Enabling parallel downloads...${Color_Off}"
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
echo -e "${Blue}Enabling pacman colors and 'ILoveCandy' easter egg...${Color_Off}"
sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf
echo -e "${Blue}Enabling multilib repository...${Color_Off}"
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
echo -e "${Blue}Synchronizing pacman databases after multilib enable...${Color_Off}"
pacman -Sy --noconfirm
echo -e "${Green}Pacman configuration updated.${Color_Off}"

local nc=\$(grep -c ^"cpu cores" /proc/cpuinfo)
echo -e "${Blue}Detected \${nc} CPU cores. Adjusting makeflags and compression settings.${Color_Off}"
local chroot_total_mem_kb=\$(grep -i 'memtotal' /proc/meminfo | awk '{print \$2}')
local chroot_total_mem_mb=\$((chroot_total_mem_kb / 1024))

if [[ "\$chroot_total_mem_mb" -gt 8000 ]]; then
    echo -e "${Blue}Adjusting MAKEFLAGS for \${nc} cores...${Color_Off}"
    sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j\$nc\"/g" /etc/makepkg.conf
    echo -e "${Blue}Adjusting XZ compression settings for \${nc} cores...${Color_Off}"
    sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T \$nc -z -)/g" /etc/makepkg.conf
    echo -e "${Green}Makepkg optimizations applied.${Color_Off}"
else
    echo -e "${Yellow}System memory is less than 8GB. Skipping makepkg optimization.${Color_Off}"
fi

echo -e "${BCyan}--- System Locale and Time Configuration ---${Color_Off}"
echo -e "${Blue}Setting language to en_US.UTF-8 and generating locales.${Color_Off}"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo -e "${Blue}Setting timezone to ${TIMEZONE}.${Color_Off}"
timedatectl --no-ask-password set-timezone "${TIMEZONE}"
timedatectl --no-ask-password set-ntp 1
echo -e "${Blue}Setting system locale to LANG=\"en_US.UTF-8\" LC_TIME=\"en_US.UTF-8\".${Color_Off}"
localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
echo -e "${Green}Locale and time configured.${Color_Off}"

echo -e "${BCyan}--- Keyboard Layout Configuration ---${Color_Off}"
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
echo "XKBLAYOUT=${KEYMAP}" >> /etc/vconsole.conf
echo -e "${Green}Keymap set to: ${KEYMAP}.${Color_Off}"

echo -e "${BCyan}--- Sudoers Configuration ---${Color_Off}"
echo -e "${Blue}Enabling NOPASSWD for wheel group temporarily (will be removed later).${Color_Off}"
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
echo -e "${Green}NOPASSWD for wheel group enabled.${Color_Off}"

echo -e "${BCyan}--- Installing Microcode ---${Color_Off}"
if grep -q "GenuineIntel" /proc/cpuinfo; then
    echo -e "${Blue}Installing Intel microcode...${Color_Off}"
    pacman -S --noconfirm --needed intel-ucode
    echo -e "${Green}Intel microcode installed.${Color_Off}"
elif grep -q "AuthenticAMD" /proc/cpuinfo; then
    echo -e "${Blue}Installing AMD microcode...${Color_Off}"
    pacman -S --noconfirm --needed amd-ucode
    echo -e "${Green}AMD microcode installed.${Color_Off}"
else
    echo -e "${Yellow}Unable to determine CPU vendor. Skipping microcode installation.${Color_Off}"
fi

echo -e "${BCyan}--- Installing Graphics Drivers ---${Color_Off}"
if echo "${gpu_type}" | grep -E "NVIDIA|GeForce"; then
    echo -e "${Blue}Installing NVIDIA drivers: nvidia-lts...${Color_Off}"
    pacman -S --noconfirm --needed nvidia-lts
    echo -e "${Green}NVIDIA drivers installed.${Color_Off}"
elif echo "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
    echo -e "${Blue}Installing AMD drivers: xf86-video-amdgpu...${Color_Off}"
    pacman -S --noconfirm --needed xf86-video-amdgpu
    echo -e "${Green}AMD drivers installed.${Color_Off}"
elif echo "${gpu_type}" | grep -E "Integrated Graphics Controller|Intel Corporation UHD"; then
    echo -e "${Blue}Installing Intel graphics drivers...${Color_Off}"
    pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-utils lib32-mesa
    echo -e "${Green}Intel graphics drivers installed.${Color_Off}"
else
    echo -e "${Yellow}Could not detect specific GPU type. Skipping discrete graphics driver installation. You may need to install them manually.${Color_Off}"
fi

echo -e "${BCyan}--- User Account Setup ---${Color_Off}"
echo -e "${Blue}Adding libvirt group...${Color_Off}"
groupadd libvirt
echo -e "${Blue}Creating user '${USERNAME}'...${Color_Off}"
useradd -m -G wheel,libvirt -s /bin/bash "$USERNAME"
echo -e "${Green}User '${USERNAME}' created, home directory created, added to wheel and libvirt groups, default shell set to /bin/bash.${Color_Off}"
echo "$USERNAME:$PASSWORD" | chpasswd
echo -e "${Green}Password set for user '${USERNAME}'.${Color_Off}"
echo "$NAME_OF_MACHINE" > /etc/hostname
echo -e "${Green}Hostname set to: ${NAME_OF_MACHINE}.${Color_Off}"

if [[ "${FS}" == "luks" ]]; then
    echo -e "${BCyan}--- Configuring mkinitcpio for LUKS Encryption ---${Color_Off}"
    echo -e "${Blue}Adding 'encrypt' hook to mkinitcpio.conf...${Color_Off}"
    sed -i '/^HOOKS=/s/filesystems/encrypt filesystems/' /etc/mkinitcpio.conf
    echo -e "${Blue}Generating new initramfs...${Color_Off}"
    mkinitcpio -p linux-lts
    echo -e "${Green}Initramfs generated with LUKS support.${Color_Off}"
fi

echo -e "${BCyan}--- GRUB Bootloader Configuration ---${Color_Off}"
if [[ -d "/sys/firmware/efi" ]]; then
    echo -e "${Blue}Installing GRUB for UEFI...${Color_Off}"
    grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=ArchLinux --recheck ${DISK}
    echo -e "${Green}GRUB UEFI installation complete.${Color_Off}"
fi

echo -e "${Blue}Configuring GRUB kernel parameters...${Color_Off}"
if [[ "${FS}" == "luks" ]]; then
    echo -e "${Blue}Adding LUKS decryption parameters to GRUB_CMDLINE_LINUX_DEFAULT...${Color_Off}"
    sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"%GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=${ENCRYPTED_PARTITION_UUID}:ROOT root=/dev/mapper/ROOT %g" /etc/default/grub
fi
echo -e "${Blue}Adding 'splash' to GRUB_CMDLINE_LINUX_DEFAULT...${Color_Off}"
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& splash /' /etc/default/grub

echo -e "${Blue}Updating grub configuration file...${Color_Off}"
grub-mkconfig -o /boot/grub/grub.cfg
echo -e "${Green}Grub configuration updated. All set!${Color_Off}"

echo -e "${BCyan}--- Enabling Essential Services ---${Color_Off}"
ntpd -qg || true
systemctl enable ntpd.service
echo -e "${Green}NTP service enabled.${Color_Off}"
systemctl disable dhcpcd.service || true
echo -e "${Green}DHCPCD service disabled.${Color_Off}"
systemctl enable NetworkManager.service
echo -e "${Green}NetworkManager service enabled.${Color_Off}"
systemctl enable reflector.timer
echo -e "${Green}Reflector timer enabled.${Color_Off}"


if [[ "${HYPRLAND_DOTS_CHOICE}" == "yes" ]]; then
    echo -e "${BCyan}--- Hyprland with HyDE Dots Installation ---${Color_Off}"
    echo -e "${Blue}Ensuring git is installed for cloning dotfiles...${Color_Off}"
    pacman -S --noconfirm --needed git

    echo -e "${Blue}Cloning HyDE-Project dotfiles...${Color_Off}"
    cd /home/"$USERNAME" || { echo -e "${BRed}ERROR: Could not change to user home directory /home/${USERNAME}.${Color_Off}"; exit 1; }
    
    echo -e "${Yellow}Cloning HyDE dotfiles to /home/${USERNAME}/HyDE... This might take a while.${Color_Off}"
    sudo -u "$USERNAME" git clone https://github.com/HyDE-Project/HyDE.git
    
    cd /home/"$USERNAME"/HyDE || { echo -e "${BRed}ERROR: Could not change to HyDE directory.${Color_Off}"; exit 1; }
    
    echo -e "${Blue}Executing HyDE dotfiles install script as user '${USERNAME}'...${Color_Off}"
    sudo -u "$USERNAME" bash ./install.sh
    
    echo -e "${Blue}Cleaning up cloned HyDE repository...${Color_Off}"
    cd /home/"$USERNAME" || true
    rm -rf HyDE
    
    echo -e "${Green}Hyprland with HyDE dotfiles installation complete!${Color_Off}"
    echo -e "${Yellow}You will need to manually set up the display server (Hyprland). After rebooting, log in as '${USERNAME}', then you can start Hyprland with 'Hyprland'.${Color_Off}"
else
    echo -e "${Yellow}Skipping Hyprland with HyDE dotfiles installation as per user choice.${Color_Off}"
fi

echo -e "${BCyan}--- Cleaning Up Sudoers and Finalizing ---${Color_Off}"
echo -e "${Blue}Removing NOPASSWD for wheel group.${Color_Off}"
sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
echo -e "${Blue}Enabling standard sudo rights for wheel group.${Color_Off}"
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo -e "${Green}Sudoers configuration finalized.${Color_Off}"

echo -e "${Green}Arch Linux installation complete!${Color_Off}"
EOF

display_section_title "Installation Complete"
logo
echo -e "${Green}Your Arch Linux system has been successfully installed.${Color_Off}"
echo -e "${BBlue}You can now reboot into your new system.${Color_Off}"
read -r -p "${BBlue}Press Enter to reboot, or Ctrl+C to stay in the ISO environment.${Color_Off}"
reboot now
