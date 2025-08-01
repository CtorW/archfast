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

# Function to display the main logo and title
logo () {
    clear
echo -ne "
${BCyan}-------------------------------------------------------------------------
   _|_|    _|_|_|      _|_|_|  _|    _|  _|_|_|_|    _|_|      _|_|_|  _|_|_|_|_|  
 _|    _|  _|    _|  _|        _|    _|  _|        _|    _|  _|            _|      
 _|_|_|_|  _|_|_|    _|        _|_|_|_|  _|_|_|    _|_|_|_|    _|_|        _|      
 _|    _|  _|    _|  _|        _|    _|  _|        _|    _|        _|      _|      
 _|    _|  _|    _|    _|_|_|  _|    _|  _|        _|    _|  _|_|_|        _|     
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

# ==============================================================================
#                          Interactive Menus and Prompts
# ==============================================================================

# Function for a colorful, arrow-key selectable menu
select_option() {
    local options=("$@")
    local num_options=${#options[@]}
    local selected=0
    
    echo -e "${BIWhite}Please select an option using the arrow keys and Enter:${Color_Off}"

    # Print the options for the first time
    for i in "${!options[@]}"; do
        if [ "$i" -eq $selected ]; then
            echo -e "${BICyan}> ${options[$i]}${Color_Off}"
        else
            echo -e "${BYellow}  ${options[$i]}${Color_Off}"
        fi
    done

    # Start the key press loop
    while true; do
        # Move cursor up to the beginning of the menu options for redrawing
        tput cuu "${num_options}"
        
        # Redraw the options with the current selection highlighted
        for i in "${!options[@]}"; do
            # Clear the current line before printing
            tput el
            if [ "$i" -eq $selected ]; then
                echo -e "${BICyan}> ${options[$i]}${Color_Off}"
            else
                echo -e "${BYellow}  ${options[$i]}${Color_Off}"
            fi
        done

        # Read a single key press without echoing it
        read -rsn1 key
        case "$key" in
            $'\x1b') # Arrow key escape sequence
                read -rsn2 -t 0.1 key
                case "$key" in
                    '[A') # Up arrow
                        ((selected--))
                        if [ $selected -lt 0 ]; then
                            selected=$((num_options - 1))
                        fi
                        ;;
                    '[B') # Down arrow
                        ((selected++))
                        if [ $selected -ge $num_options ]; then
                            selected=0
                        fi
                        ;;
                esac
                ;;
            '') # Enter key
                echo
                break
                ;;
        esac
    done

    # Return the index of the selected option
    return $selected
}

filesystem () {
    logo
    echo -e "${BGreen}Please Select your file system for both boot and root${Color_Off}"
    options=("btrfs" "ext4" "luks" "exit")
    select_option "${options[@]}"
    local selected_option=$?

    case $selected_option in
        0) export FS=btrfs;;
        1) export FS=ext4;;
        2)
            logo
            echo -e "${BYellow}Please enter a password for LUKS encryption.${Color_Off}"
            read -s -p "Enter LUKS password: " LUKS_PASSWORD
            echo
            read -s -p "Re-enter LUKS password: " LUKS_PASSWORD2
            echo
            if [[ "$LUKS_PASSWORD" != "$LUKS_PASSWORD2" ]]; then
                echo -e "${BRed}Passwords do not match. Please try again.${Color_Off}"
                sleep 2
                filesystem
                return
            fi
            export FS=luks
            ;;
        3) exit ;;
        *) echo -e "${BRed}Wrong option, please select again.${Color_Off}"; filesystem;;
    esac
}

timezone () {
    logo
    time_zone="$(curl --fail https://ipapi.co/timezone)"
    echo -e "${BGreen}System detected your timezone to be '${time_zone}'.${Color_Off}"
    echo -e "${BYellow}Is this correct?${Color_Off}"
    options=("Yes" "No")
    select_option "${options[@]}"
    local selected_option=${options[$?]}

    case "$selected_option" in
        "Yes")
            echo -e "${BGreen}${time_zone} set as timezone.${Color_Off}"
            export TIMEZONE=$time_zone;;
        "No")
            logo
            echo -e "${BYellow}Please enter your desired timezone (e.g., Europe/London):${Color_Off}"
            read -r new_timezone
            echo -e "${BGreen}${new_timezone} set as timezone.${Color_Off}"
            export TIMEZONE=$new_timezone;;
        *)
            echo -e "${BRed}Wrong option. Try again.${Color_Off}"; timezone;;
    esac
}

keymap () {
    logo
    echo -e "${BGreen}Please select your keyboard layout from the list below:${Color_Off}"
    options=(us by ca cf cz de dk es et fa fi fr gr hu il it lt lv mk nl no pl ro ru se sg ua uk)
    select_option "${options[@]}"
    local keymap=${options[$?]}

    echo -e "${BGreen}Keyboard layout set to: ${keymap}${Color_Off}"
    export KEYMAP=$keymap
}

drivessd () {
    logo
    echo -e "${BGreen}Is this an SSD?${Color_Off}"
    options=("Yes" "No")
    select_option "${options[@]}"
    local selected_option=${options[$?]}

    case "$selected_option" in
        "Yes") export MOUNT_OPTIONS="noatime,compress=zstd,ssd,commit=120";;
        "No") export MOUNT_OPTIONS="noatime,compress=zstd,commit=120";;
        *) echo -e "${BRed}Wrong option. Try again.${Color_Off}"; drivessd;;
    esac
}

diskpart () {
    logo
    echo -e "
${BRed}------------------------------------------------------------------------
    WARNING: THIS WILL FORMAT AND DELETE ALL DATA ON THE SELECTED DISK
    Please be absolutely sure you have backed up any important data.
    There is no way to recover data after this process.
    *****I AM NOT RESPONSIBLE FOR ANY DATA LOSS*****
------------------------------------------------------------------------${Color_Off}"

    PS3='
    Please select the disk to install Arch Linux on: '
    options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))

    select_option "${options[@]}"
    disk=${options[$?]%|*}

    echo -e "\n${BGreen}Disk selected: ${disk}${Color_Off}\n"
    export DISK=${disk%|*}

    drivessd
}

userinfo () {
    logo
    while true
    do
        read -r -p "${BYellow}Please enter a username:${Color_Off} " username
        if [[ "${username,,}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]
        then
            break
        fi
        echo -e "${BRed}Invalid username. Please try again.${Color_Off}"
    done
    export USERNAME=$username

    while true
    do
        read -rs -p "${BYellow}Please enter a password:${Color_Off} " PASSWORD1
        echo -ne "\n"
        read -rs -p "${BYellow}Please re-enter the password:${Color_Off} " PASSWORD2
        echo -ne "\n"
        if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
            break
        else
            echo -e "${BRed}ERROR: Passwords do not match. Please try again.${Color_Off}\n"
        fi
    done
    export PASSWORD=$PASSWORD1

    while true
    do
        read -r -p "${BYellow}Please name your machine (hostname):${Color_Off} " name_of_machine
        if [[ "${name_of_machine,,}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]
        then
            break
        fi
        read -r -p "${BRed}Hostname doesn't seem correct. Do you still want to save it? (y/n):${Color_Off} " force
        if [[ "${force,,}" = "y" ]]
        then
            break
        fi
    done
    export NAME_OF_MACHINE=$name_of_machine
}

# ==============================================================================
#                             Main Installation Workflow
# ==============================================================================

# Run initial checks before starting
background_checks
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

if [[ "${DISK}" =~ "nvme" ]]; then
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
                    Enabling Sudo Permissions
-------------------------------------------------------------------------${Color_Off}
"
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-custom-sudoers
chmod 0440 /etc/sudoers.d/10-custom-sudoers

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

echo -e "${BGreen}Pulling fast-hyprland.sh transfer to /home/$USERNAME/${Color_Off}"
wget https://raw.githubusercontent.com/CtorW/archfast/refs/heads/uno/fast-hyprland.sh -P /home/$USERNAME/

if [[ ${FS} == "luks" ]]; then
    sed -i 's/filesystems/encrypt filesystems/g' /etc/mkinitcpio.conf
    mkinitcpio -p linux-lts
fi

echo -ne "
${BCyan}-------------------------------------------------------------------------
    _|_|    _|_|_|      _|_|_|  _|    _|  _|_|_|_|    _|_|      _|_|_|  _|_|_|_|_|  
 _|    _|  _|    _|  _|        _|    _|  _|        _|    _|  _|            _|      
 _|_|_|_|  _|_|_|    _|        _|_|_|_|  _|_|_|    _|_|_|_|    _|_|        _|      
 _|    _|  _|    _|  _|        _|    _|  _|        _|    _|        _|      _|      
 _|    _|  _|    _|    _|_|_|  _|    _|  _|        _|    _|  _|_|_|        _|     
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
