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

exec > >(tee -i archsetup.txt)
exec 2>&1

echo -e "${BBlue}-------------------------------------------------------------------------${Color_Off}"
echo -e "${BCyan}                  Automated Arch Linux Installer${Color_Off}"
echo -e "${BBlue}-------------------------------------------------------------------------${Color_Off}"
echo ""
echo "Verifying Arch Linux ISO is Booted..."

if ! command -v pacstrap &> /dev/null; then
    echo -e "${BRed}ERROR: This script must be run from an Arch Linux ISO environment.${Color_Off}"
    exit 1
fi

check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo -e "${BRed}ERROR: This script must be run as the 'root' user!${Color_Off}"
        exit 1
    fi
}

check_docker() {
    if awk -F/ '$2 == "docker"' /proc/self/cgroup | grep -q .; then
        echo -e "${BRed}ERROR: Docker container is not supported (at the moment).${Color_Off}"
        exit 1
    elif [[ -f /.dockerenv ]]; then
        echo -e "${BRed}ERROR: Docker container is not supported (at the moment).${Color_Off}"
        exit 1
    fi
}

check_arch_env() {
    if [[ ! -e /etc/arch-release ]]; then
        echo -e "${BRed}ERROR: This script must be run in Arch Linux!${Color_Off}"
        exit 1
    fi
}

check_pacman_lock() {
    if [[ -f /var/lib/pacman/db.lck ]]; then
        echo -e "${BRed}ERROR: Pacman is blocked. If not running, remove /var/lib/pacman/db.lck.${Color_Off}"
        exit 1
    fi
}

run_initial_checks() {
    check_root
    check_arch_env
    check_pacman_lock
    check_docker
}

select_option() {
    local options=("$@")
    local num_options=${#options[@]}
    local selected=0
    local last_selected=-1

    while true; do
        if [ "$last_selected" -ne -1 ]; then
            printf "\033[${num_options}A"
        fi

        echo "Please select an option using the arrow keys and Enter:"
        for i in "${!options[@]}"; do
            if [ "$i" -eq "$selected" ]; then
                echo -e "${BGreen}> ${options[$i]}${Color_Off}"
            else
                echo -e "  ${options[$i]}"
            fi
        done

        last_selected=$selected

        IFS= read -rsn1 key
        case "$key" in
            $'\x1b')
                IFS= read -rsn2 -t 0.1 key_arrow
                case "$key_arrow" in
                    '[A')
                        ((selected = (selected - 1 + num_options) % num_options))
                        ;;
                    '[B')
                        ((selected = (selected + 1) % num_options))
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

display_header() {
    echo -e "${BBlue}-------------------------------------------------------------------------${Color_Off}"
    echo -e "${BCyan}            $1${Color_Off}"
    echo -e "${BBlue}-------------------------------------------------------------------------${Color_Off}"
}

set_filesystem() {
    display_header "File System Selection"
    echo "Please select your file system for both boot and root:"
    options=("btrfs" "ext4" "luks" "exit")
    select_option "${options[@]}"
    local choice_idx=$?

    case ${options[$choice_idx]} in
    btrfs) export FS="btrfs";;
    ext4) export FS="ext4";;
    luks)
        read -s -p "Enter LUKS password: " LUKS_PASSWORD
        echo
        read -s -p "Confirm LUKS password: " LUKS_PASSWORD_CONFIRM
        echo
        if [[ "$LUKS_PASSWORD" != "$LUKS_PASSWORD_CONFIRM" ]]; then
            echo -e "${BRed}Passwords do not match. Please try again.${Color_Off}"
            set_filesystem
        fi
        export FS="luks"
        ;;
    exit) exit 0;;
    *) echo -e "${BRed}Invalid option. Please try again.${Color_Off}"; set_filesystem;;
    esac
}

set_timezone() {
    display_header "Timezone Configuration"
    local detected_timezone=$(curl --fail https://ipapi.co/timezone 2>/dev/null)
    if [[ -z "$detected_timezone" ]]; then
        echo -e "${BYellow}Could not auto-detect timezone. Please enter manually.${Color_Off}"
        read -r -p "Enter your desired timezone (e.g., Europe/London): " new_timezone
        export TIMEZONE="$new_timezone"
    else
        echo "System detected your timezone to be '$detected_timezone'."
        echo "Is this correct?"
        options=("Yes" "No")
        select_option "${options[@]}"
        local choice_idx=$?
        if [[ "${options[$choice_idx]}" == "Yes" ]]; then
            export TIMEZONE="$detected_timezone"
        else
            read -r -p "Please enter your desired timezone (e.g., Europe/London): " new_timezone
            export TIMEZONE="$new_timezone"
        fi
    fi
    echo -e "${BGreen}Timezone set to: $TIMEZONE${Color_Off}"
}

set_keymap() {
    display_header "Keyboard Layout Selection"
    echo "Please select your keyboard layout from this list:"
    local options=(us by ca cf cz de dk es et fa fi fr gr hu il it lt lv mk nl no pl ro ru se sg ua uk)
    select_option "${options[@]}"
    export KEYMAP="${options[$?]}"
    echo -e "${BGreen}Keyboard layout set to: ${KEYMAP}${Color_Off}"
}

set_drive_ssd_status() {
    display_header "Drive Type"
    echo "Is this an SSD?"
    options=("Yes" "No")
    select_option "${options[@]}"
    local choice_idx=$?

    if [[ "${options[$choice_idx]}" == "Yes" ]]; then
        export MOUNT_OPTIONS="noatime,compress=zstd,ssd,commit=120"
        echo -e "${BGreen}Drive type set to SSD.${Color_Off}"
    else
        export MOUNT_OPTIONS="noatime,compress=zstd,commit=120"
        echo -e "${BGreen}Drive type set to HDD/other.${Color_Off}"
    fi
}

select_disk_for_installation() {
    display_header "Disk Selection - WARNING: DATA WILL BE ERASED!"
    echo -e "${BRed}-------------------------------------------------------------------------${Color_Off}"
    echo -e "${BRed}    THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK!${Color_Off}"
    echo -e "${BRed}    Please make sure you know what you are doing because${Color_Off}"
    echo -e "${BRed}    after formatting your disk there is no way to get data back.${Color_Off}"
    echo -e "${BRed}    *****BACKUP YOUR DATA BEFORE CONTINUING*****${Color_Off}"
    echo -e "${BRed}    ***I AM NOT RESPONSIBLE FOR ANY DATA LOSS***${Color_Off}"
    echo -e "${BRed}-------------------------------------------------------------------------${Color_Off}"
    echo ""

    PS3='Select the disk to install on: '
    local disk_options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2" ("$3")"}'))

    select_option "${disk_options[@]}"
    local selected_disk_info="${disk_options[$?]}"
    export DISK=$(echo "$selected_disk_info" | awk '{print $1}')

    echo -e "${BGreen}Selected disk: ${DISK}${Color_Off}"
    set_drive_ssd_status
}

set_user_info() {
    display_header "User Information"
    while true; do
        read -r -p "Please enter username: " USERNAME
        if [[ "$USERNAME" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]; then
            break
        fi
        echo -e "${BRed}Invalid username. Usernames must start with a lowercase letter or underscore, and can contain lowercase letters, numbers, underscores, and hyphens (max 32 chars).${Color_Off}"
    done

    while true; do
        read -rs -p "Please enter password: " PASSWORD
        echo
        read -rs -p "Please re-enter password: " PASSWORD2
        echo
        if [[ "$PASSWORD" == "$PASSWORD2" ]]; then
            break
        else
            echo -e "${BRed}ERROR: Passwords do not match. Please try again.${Color_Off}"
        fi
    done

    while true; do
        read -r -p "Please name your machine (hostname): " NAME_OF_MACHINE
        if [[ "$NAME_OF_MACHINE" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]; then
            break
        else
            read -r -p "${BYellow}Hostname '$NAME_OF_MACHINE' doesn't seem correct. Do you still want to save it? (y/N) ${Color_Off}" force_hostname
            [[ "${force_hostname,,}" == "y" ]] && break
        fi
    done
}

create_btrfs_subvolumes() {
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
}

mount_btrfs_subvolumes() {
    mount -o "${MOUNT_OPTIONS}",subvol=@home "${partition3}" /mnt/home
}

btrfs_setup() {
    create_btrfs_subvolumes
    umount /mnt
    mount -o "${MOUNT_OPTIONS}",subvol=@ "${partition3}" /mnt
    mkdir -p /mnt/home
    mount_btrfs_subvolumes
}

run_initial_checks

clear
set_user_info
clear
set_keymap
clear
set_timezone
clear
select_disk_for_installation
clear
set_filesystem

display_header "Pre-installation Setup"
echo "Setting up mirrors for optimal download..."
local_country_code=$(curl -4 ifconfig.io/country_code 2>/dev/null || echo "US")
timedatectl set-ntp true
pacman -Sy --noconfirm
pacman -S --noconfirm --needed archlinux-keyring
pacman -S --noconfirm --needed pacman-contrib terminus-font
setfont ter-v18b
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
pacman -S --noconfirm --needed reflector rsync grub
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

echo -e "${BGreen}Setting up $local_country_code mirrors for faster downloads...${Color_Off}"
reflector -a 48 -c "$local_country_code" --score 5 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
if [[ $(grep -c "Server =" /etc/pacman.d/mirrorlist) -lt 5 ]]; then
    echo -e "${BYellow}Less than 5 mirrors found, restoring backup mirrorlist.${Color_Off}"
    cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
fi

mkdir -p /mnt

display_header "Installing Prerequisites"
pacman -S --noconfirm --needed gptfdisk btrfs-progs glibc

display_header "Formatting Disk: ${DISK}"
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

if [[ "${DISK}" =~ "nvme" ]]; then
    partition2="${DISK}p2"
    partition3="${DISK}p3"
else
    partition2="${DISK}2"
    partition3="${DISK}3"
fi

display_header "Creating Filesystems"
mkfs.fat -F32 -n "EFIBOOT" "${partition2}"

if [[ "${FS}" == "btrfs" ]]; then
    mkfs.btrfs -f "${partition3}"
    mount -t btrfs "${partition3}" /mnt
    btrfs_setup
elif [[ "${FS}" == "ext4" ]]; then
    mkfs.ext4 -F "${partition3}"
    mount -t ext4 "${partition3}" /mnt
elif [[ "${FS}" == "luks" ]]; then
    echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v luksFormat "${partition3}" -
    echo -n "${LUKS_PASSWORD}" | cryptsetup open "${partition3}" ROOT -
    mkfs.btrfs -f /dev/mapper/ROOT
    mount -t btrfs /dev/mapper/ROOT /mnt
    btrfs_setup
    ENCRYPTED_PARTITION_UUID=$(blkid -s UUID -o value "${partition3}")
fi

sync

if ! mountpoint -q /mnt; then
    echo -e "${BRed}ERROR: Failed to mount root partition to /mnt. Rebooting...${Color_Off}"
    sleep 3; reboot now
fi

BOOT_UUID=$(blkid -s UUID -o value "${partition2}")
mkdir -p /mnt/boot
mount -U "${BOOT_UUID}" /mnt/boot/

display_header "Installing Arch Linux Base System"
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

display_header "Checking for Low Memory Systems (<8GB) for Swap"
TOTAL_MEM_KB=$(grep -i 'memtotal' /proc/meminfo | awk '{print $2}')
if [[ "$TOTAL_MEM_KB" -lt 8000000 ]]; then
    echo -e "${BYellow}System memory is less than 8GB, adding 2GB swap file.${Color_Off}"
    mkdir -p /mnt/opt/swap
    if findmnt -n -o FSTYPE /mnt | grep -q btrfs; then
        chattr +C /mnt/opt/swap
    fi
    dd if=/dev/zero of=/mnt/opt/swap/swapfile bs=1M count=2048 status=progress
    chmod 600 /mnt/opt/swap/swapfile
    chown root /mnt/opt/swap/swapfile
    mkswap /mnt/opt/swap/swapfile
    echo "/opt/swap/swapfile none swap sw 0 0" >> /mnt/etc/fstab
fi

display_header "Entering Chroot Environment for Final Configurations"
gpu_type=$(lspci | grep -E "VGA|3D|Display")

arch-chroot /mnt /bin/bash <<EOF
set -e

echo -e "${BPurple}--- Network Setup ---${Color_Off}"
pacman -S --noconfirm --needed networkmanager dhcpcd
systemctl enable NetworkManager

echo -e "${BPurple}--- Pacman and System Configuration ---${Color_Off}"
pacman -S --noconfirm --needed pacman-contrib curl reflector rsync git ntp wget

nc=\$(grep -c ^"cpu cores" /proc/cpuinfo)
if [[ "\$(grep -i 'memtotal' /proc/meminfo | awk '{print \$2}')" -gt 8000000 ]]; then
    echo -e "${BGreen}Configuring makepkg for \$nc cores and optimized compression.${Color_Off}"
    sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j\$nc\"/g" /etc/makepkg.conf
    sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T \$nc -z -)/g" /etc/makepkg.conf
fi

echo -e "${BPurple}--- Language and Locale Setup ---${Color_Off}"
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

echo -e "${BPurple}--- Microcode Installation ---${Color_Off}"
if grep -q "GenuineIntel" /proc/cpuinfo; then
    echo -e "${BGreen}Installing Intel microcode.${Color_Off}"
    pacman -S --noconfirm --needed intel-ucode
elif grep -q "AuthenticAMD" /proc/cpuinfo; then
    echo -e "${BGreen}Installing AMD microcode.${Color_Off}"
    pacman -S --noconfirm --needed amd-ucode
else
    echo -e "${BYellow}Unable to determine CPU vendor. Skipping microcode installation.${Color_Off}"
fi

echo -e "${BPurple}--- Graphics Drivers Installation ---${Color_Off}"
if echo "${gpu_type}" | grep -E "NVIDIA|GeForce"; then
    echo -e "${BGreen}Installing NVIDIA drivers: nvidia-lts${Color_Off}"
    pacman -S --noconfirm --needed nvidia-lts
elif echo "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
    echo -e "${BGreen}Installing AMD drivers: xf86-video-amdgpu${Color_Off}"
    pacman -S --noconfirm --needed xf86-video-amdgpu
elif echo "${gpu_type}" | grep -E "Intel Corporation|Integrated Graphics Controller"; then
    echo -e "${BGreen}Installing Intel drivers.${Color_Off}"
    pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-utils lib32-mesa
fi

echo -e "${BPurple}--- User Creation and Hostname ---${Color_Off}"
groupadd libvirt
useradd -m -G wheel,libvirt -s /bin/bash $USERNAME
echo -e "${BGreen}$USERNAME created, home directory created, added to wheel and libvirt group, default shell set to /bin/bash.${Color_Off}"
echo "$USERNAME:$PASSWORD" | chpasswd
echo -e "${BGreen}Password for $USERNAME set.${Color_Off}"
echo "$NAME_OF_MACHINE" > /etc/hostname

if [[ "${FS}" == "luks" ]]; then
    echo -e "${BPurple}--- LUKS Configuration in mkinitcpio ---${Color_Off}"
    sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck)/g' /etc/mkinitcpio.conf
    mkinitcpio -P linux-lts
fi

echo -e "${BPurple}--- GRUB Bootloader Installation & Configuration ---${Color_Off}"
if [[ -d "/sys/firmware/efi" ]]; then
    grub-install --efi-directory=/boot --target=x86_64-efi --bootloader-id=GRUB ${DISK}
else
    grub-install --boot-directory=/boot ${DISK}
fi

if [[ "${FS}" == "luks" ]]; then
    sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"%GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=${ENCRYPTED_PARTITION_UUID}:ROOT root=/dev/mapper/ROOT %g" /etc/default/grub
fi
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& splash /' /etc/default/grub

echo -e "${BGreen}Updating grub configuration...${Color_Off}"
grub-mkconfig -o /boot/grub/grub.cfg

echo -e "${BPurple}--- Enabling Essential Services ---${Color_Off}"
systemctl enable ntpd.service
echo -e "${BGreen}  NTP enabled${Color_Off}"
systemctl disable dhcpcd.service
echo -e "${BGreen}  DHCP disabled (NetworkManager will be used)${Color_Off}"
systemctl enable NetworkManager.service
echo -e "${BGreen}  NetworkManager enabled${Color_Off}"
systemctl enable reflector.timer
echo -e "${BGreen}  Reflector enabled${Color_Off}"

echo -e "${BPurple}--- Cleaning Up Sudoers ---${Color_Off}"
sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo -e "${BGreen}Arch Linux installation complete!${Color_Off}"
EOF

display_header "Installation Finished!"
echo -e "${BGreen}You can now reboot into your new Arch Linux system.${Color_Off}"
echo "Unmounting /mnt..."
umount -R /mnt

echo -e "${BYellow}Rebooting in 5 seconds... Press Ctrl+C to cancel.${Color_Off}"
sleep 5
reboot now
