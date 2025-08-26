#!/bin/bash

# ==============================================================================
#           Color Definitions for a More Beautiful Terminal Experience
# ==============================================================================

# Hardcoded ANSI codes
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

# Redirect all output to a log file
exec > >(tee -i archsetup.txt)
exec 2>&1

# ==============================================================================
#                          Helper Functions
# ==============================================================================

print_box_title() {
    local title="$1"
    local color="${2:-$BBlue}"
    
    local tl="╭" tr="╮" bl="╰" br="╯" H="─"
    local title_len=${#title}
    local box_width=60
    local padding_total=$((box_width - title_len - 2)) # -2 for spaces around title
    local padding_left=$((padding_total / 2))
    local padding_right=$((padding_total - padding_left))

    local top_border="${tl}"
    for ((i=0; i<padding_left; i++)); do top_border+="${H}"; done
    top_border+=" ${BIWhite}${title}${color} "
    for ((i=0; i<padding_right; i++)); do top_border+="${H}"; done
    top_border+="${tr}"

    echo -e "\n${color}${top_border}${Color_Off}"
}


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
${BYellow}                            Automated Arch Linux Installer${Color_Off}
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
#                          Interactive Prompts (using fzf TUI)
# ==============================================================================
userinfo () {
    # Install fzf if it's not already installed
    echo -e "${BGreen}Checking for fzf...${Color_Off}"
    pacman -S --noconfirm --needed fzf
    
    # Prompt for username
    USERNAME=$(echo "archuser" | fzf --prompt="Enter a username for your new system: " --print-query --height=20% --layout=reverse --border=rounded --border-label=" User Setup " | tail -n 1)
    if [ -z "$USERNAME" ]; then
        echo -e "${BRed}User canceled. Exiting.${Color_Off}"
        exit 1
    fi
    export USERNAME

    # Prompt for password
    local password_match=false
    while [ "$password_match" = false ]; do
        clear
        logo
        print_box_title "Password for $USERNAME"
        echo -e "${BYellow}Please enter the password (input will not be visible).${Color_Off}"
        read -s -p "  Password: " PASSWORD
        echo
        read -s -p "  Confirm Password: " PASSWORD2
        echo

        if [ "$PASSWORD" == "$PASSWORD2" ]; then
            password_match=true
        else
            echo -e "\n${BRed}Passwords do not match. Press Enter to try again.${Color_Off}"
            read -r
        fi
    done
    export PASSWORD
    
    # Prompt for hostname
    NAME_OF_MACHINE=$(echo "myarch" | fzf --prompt="Please name your machine (hostname): " --print-query --height=20% --layout=reverse --border=rounded --border-label=" Hostname Setup " | tail -n 1)
    if [ -z "$NAME_OF_MACHINE" ]; then
        echo -e "${BRed}User canceled. Exiting.${Color_Off}"
        exit 1
    fi
    export NAME_OF_MACHINE
}

diskpart () {
    DISK_INFO=$(lsblk -o KNAME,SIZE,MODEL -d | grep -E "sd|hd|vd|nvme|mmcblk")
    DISK=$(echo "$DISK_INFO" | fzf --prompt="Select the disk to install Arch Linux on: " \
        --border=rounded --border-label=" Disk Selection " \
        --header="WARNING: THIS WILL FORMAT AND DELETE ALL DATA ON THE SELECTED DISK." \
        --height=40% --layout=reverse | awk '{print $1}')
    
    if [ -z "$DISK" ]; then
        echo -e "${BRed}User canceled. Exiting.${Color_Off}"
        exit 1
    fi
    export DISK="/dev/${DISK}"

    IS_SSD=$(echo -e "Yes\nNo" | fzf --prompt="Is this an SSD? " --height=20% --layout=reverse --border=rounded --border-label=" SSD Check ")
    if [ "$IS_SSD" == "Yes" ]; then
        export MOUNT_OPTIONS="noatime,compress=zstd,ssd,commit=120"
    else
        export MOUNT_OPTIONS="noatime,compress=zstd,commit=120"
    fi
}

filesystem () {
    FS_CHOICE=$(echo -e "btrfs - Btrfs with zstd compression and snapshots\next4 - Ext4 - a simple and reliable choice\nluks - Btrfs with LUKS full-disk encryption" | fzf --prompt="Please select a filesystem: " --height=40% --layout=reverse --border=rounded --border-label=" Filesystem Selection " | awk '{print $1}')

    if [ -z "$FS_CHOICE" ]; then
        echo -e "${BRed}User canceled. Exiting.${Color_Off}"
        exit 1
    fi
    export FS=${FS_CHOICE}
    
    if [[ "${FS}" == "luks" ]]; then
        local luks_password_match=false
        while [ "$luks_password_match" = false ]; do
            clear
            logo
            print_box_title "LUKS Encryption Password"
            echo -e "${BYellow}Enter a strong password for disk encryption.${Color_Off}"
            read -s -p "  Encryption Password: " LUKS_PASSWORD
            echo
            read -s -p "  Confirm Password: " LUKS_PASSWORD2
            echo

            if [ "$LUKS_PASSWORD" == "$LUKS_PASSWORD2" ]; then
                luks_password_match=true
            else
                echo -e "\n${BRed}Passwords do not match. Press Enter to try again.${Color_Off}"
                read -r
            fi
        done
        export LUKS_PASSWORD
    fi
}

timezone () {
    TIME_ZONE=$(curl --fail https://ipapi.co/timezone)
    if [ $? -eq 0 ] && [ -n "${TIME_ZONE}" ]; then
        CONFIRM_TZ=$(echo -e "Yes\nNo" | fzf --prompt="System detected timezone '${TIME_ZONE}'. Is this correct? " --height=20% --layout=reverse --border=rounded --border-label=" Timezone Confirmation ")
        if [ "$CONFIRM_TZ" == "Yes" ]; then
            export TIMEZONE=$TIME_ZONE
        else
            NEW_TIMEZONE=$(find /usr/share/zoneinfo -type f | sed 's|/usr/share/zoneinfo/||' | fzf --prompt="Please select your timezone: " --height=60% --layout=reverse --border=rounded --border-label=" Timezone Selection ")
            export TIMEZONE=$NEW_TIMEZONE
        fi
    else
        echo -e "${BYellow}Warning: Timezone auto-detection failed. Proceeding with manual prompt.${Color_Off}"
        NEW_TIMEZONE=$(find /usr/share/zoneinfo -type f | sed 's|/usr/share/zoneinfo/||' | fzf --prompt="Please select your timezone: " --height=60% --layout=reverse --border=rounded --border-label=" Timezone Selection ")
        export TIMEZONE=$NEW_TIMEZONE
    fi
}

keymap () {
    local keymap_choice

    keymap_choice=$(echo -e "us\t- United States\nde\t- Germany\nfr\t- France\nes\t- Spain\nMore...\t- Browse all layouts" | fzf --prompt="Select a common keyboard layout: " --height=40% --layout=reverse --border=rounded --border-label=" Keyboard Layout " | awk '{print $1}')
    
    if [ -z "$keymap_choice" ]; then
        echo -e "${BRed}User canceled. Exiting.${Color_Off}"
        exit 1
    fi

    if [ "$keymap_choice" == "More..." ]; then
        keymap_choice=$(find /usr/share/kbd/keymaps/ -name "*.map.gz" -printf "%f\n" | sed 's/\.map\.gz$//' | sort | fzf --prompt="Select your keyboard layout: " --height=60% --layout=reverse --border=rounded --border-label=" All Keyboard Layouts ")
        if [ -z "$keymap_choice" ]; then
            echo -e "${BRed}User canceled. Exiting.${Color_Off}"
            exit 1
        fi
    fi

    echo -e "${BGreen}Keyboard layout set to: ${keymap_choice}${Color_Off}"
    export KEYMAP="${keymap_choice}"
}

# ==============================================================================
#                             Main Installation Workflow
# ==============================================================================

background_checks
logo
userinfo
logo
diskpart
logo
filesystem
logo
timezone
logo
keymap

logo
CONFIRM_INSTALL=$(echo -e "Yes\nNo" | fzf --prompt="Ready to begin installation? All data on the selected disk will be erased. " --height=20% --layout=reverse --border=rounded --border-label=" Final Confirmation ")
if [ "$CONFIRM_INSTALL" == "Yes" ]; then
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
    echo -e "${BRed}Installation canceled by user. Exiting.${Color_Off}"
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
    mkfs.btrfs /dev/mapper/ROOT
    mount -t btrfs /dev/mapper/ROOT /mnt
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
    echo -e "${BCyan}Installing GRUB for BIOS...${Color_Off}"
    grub-install --boot-directory=/mnt/boot "${DISK}"
    if [ $? -ne 0 ]; then
        echo -e "${BRed}ERROR: GRUB BIOS installation failed. Exiting.${Color_Off}"
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
gpu_type=\$(lspci | grep -E "VGA|3D")
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
${BYellow}                            Automated Arch Linux Installer${Color_Off}
${BCyan}-------------------------------------------------------------------------${Color_Off}

${BGreen}Final Setup and Configurations
GRUB EFI Bootloader Install & Check${Color_Off}"

if [[ -d "/sys/firmware/efi" ]]; then
    echo -e "${BCyan}Installing GRUB for EFI...${Color_Off}"
    grub-install --efi-directory=/boot --removable
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
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

EOF