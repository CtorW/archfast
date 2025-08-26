#!/bin/bash

# ==============================================================================
#           Gum Definitions for a More Beautiful Terminal Experience
# ==============================================================================

if ! command -v gum &> /dev/null; then
    echo "gum not found, installing..."
    pacman -S --noconfirm gum
fi

exec > >(tee -i archsetup.txt)
exec 2>&1

# ==============================================================================
#                          Initial System Checks
# ==============================================================================
logo() {
 clear
    gum style \
 --border normal --margin "1" --padding "1 2" --border-foreground 212 "
-------------------------------------------------------------------------
     █████╗ ██████╗  ██████╗██╗  ██╗███████╗ █████╗ ███████╗████████╗
    ██╔══██╗██╔══██╗██╔════╝██║  ██║██╔════╝██╔══██╗██╔════╝╚══██╔══╝
    ███████║██████╔╝██║     ███████║█████╗  ███████║███████╗   ██║   
    ██╔══██║██╔══██╗██║     ██╔══██║██╔══╝  ██╔══██║╚════██║   ██║   
    ██║  ██║██║  ██║╚██████╗██║  ██║██║     ██║  ██║███████║   ██║   
    ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚══════╝   ╚═╝                 
-------------------------------------------------------------------------
            Automated Arch Linux Installer
-------------------------------------------------------------------------
"
}

if [ ! -f /usr/bin/pacstrap ]; then
    gum style --foreground "red" "ERROR: This script must be run from an Arch Linux ISO environment. Exiting."
    exit 1
fi

root_check() {
    if [[ "$(id -u)" != "0" ]]; then
        gum style --foreground "red" "ERROR: This script must be run under the 'root' user!"
        exit 1
    fi
}

docker_check() {
    if awk -F/ '$2 == "docker"' /proc/self/cgroup | read -r; then
        gum style --foreground "red" "ERROR: Docker container is not supported (at the moment). Exiting."
        exit 1
    elif [[ -f /.dockerenv ]]; then
        gum style --foreground "red" "ERROR: Docker container is not supported (at the moment). Exiting."
        exit 1
    fi
}

arch_check() {
    if [[ ! -e /etc/arch-release ]]; then
        gum style --foreground "red" "ERROR: This script must be run in Arch Linux! Exiting."
        exit 1
    fi
}

pacman_check() {
    if [[ -f /var/lib/pacman/db.lck ]]; then
        gum style --foreground "red" "ERROR: Pacman is blocked."
        gum style --foreground "red" "If you are sure no pacman process is running, remove /var/lib/pacman/db.lck and try again."
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
#                          Interactive Prompts (using Gum TUI)
# ==============================================================================
userinfo () {
    gum style --foreground "green" "Starting user setup..."

    USERNAME=$(gum input --placeholder "Enter a username for your new system" --value "archuser")
    if [ -z "$USERNAME" ]; then
        gum style --foreground "red" "Username cannot be empty. Exiting."
        exit 1
    fi
    export USERNAME

    local password_match=false
    while [ "$password_match" = false ]; do
        PASSWORD=$(gum input --password --placeholder "Enter password for $USERNAME")
        if [ $? != 0 ]; then
            gum style --foreground "red" "User canceled. Exiting."
            exit 1
        fi
        
        PASSWORD2=$(gum input --password --placeholder "Re-enter password for $USERNAME")
        if [ $? != 0 ]; then
            gum style --foreground "red" "User canceled. Exiting."
            exit 1
        fi

        if [ "$PASSWORD" == "$PASSWORD2" ]; then
            password_match=true
        else
            gum style --foreground "yellow" "Passwords do not match. Please try again."
        fi
    done
    export PASSWORD
    
    NAME_OF_MACHINE=$(gum input --placeholder "Please name your machine (hostname)" --value "myarch")
    if [ -z "$NAME_OF_MACHINE" ]; then
        gum style --foreground "red" "Hostname cannot be empty. Exiting."
        exit 1
    fi
    export NAME_OF_MACHINE
}

diskpart () {
    disk_list=$(lsblk -o KNAME,SIZE,MODEL -d | grep -E "sd|hd|vd|nvme|mmcblk" | awk '{print $1 " (" $2 ", " $3 " " $4 " " $5 " " $6")"}')

    DISK=$(echo "$disk_list" | gum choose --header "Select the disk to install Arch Linux on. WARNING: THIS WILL FORMAT AND DELETE ALL DATA ON THE SELECTED DISK.")
    if [ -z "$DISK" ]; then
        gum style --foreground "red" "User canceled. Exiting."
        exit 1
    fi
    DISK=$(echo "$DISK" | awk '{print $1}')
    export DISK="/dev/${DISK}"

    if gum confirm "Is this an SSD?"; then
        export MOUNT_OPTIONS="noatime,compress=zstd,ssd,commit=120"
    else
        export MOUNT_OPTIONS="noatime,compress=zstd,commit=120"
    fi
}

filesystem () {
    FS_CHOICE=$(gum choose "btrfs" "ext4" "luks" --header "Please select a filesystem:")
    if [ -z "$FS_CHOICE" ]; then
        gum style --foreground "red" "User canceled. Exiting."
        exit 1
    fi
    export FS=${FS_CHOICE}
    
    if [[ "${FS}" == "luks" ]]; then
        local luks_password_match=false
        while [ "$luks_password_match" = false ]; do
            LUKS_PASSWORD=$(gum input --password --placeholder "Enter a strong password for disk encryption")
            LUKS_PASSWORD2=$(gum input --password --placeholder "Re-enter the password to confirm")
            if [[ "$LUKS_PASSWORD" == "$LUKS_PASSWORD2" ]]; then
                luks_password_match=true
            else
                gum style --foreground "yellow" "Passwords do not match. Please try again."
            fi
        done
        export LUKS_PASSWORD
    fi
}

timezone () {
    TIME_ZONE=$(curl --fail https://ipapi.co/timezone)
    if [ $? -eq 0 ] && [ -n "${TIME_ZONE}" ]; then
        if gum confirm "System detected your timezone to be '${TIME_ZONE}'. Is this correct?"; then
            export TIMEZONE=$TIME_ZONE
        else
            NEW_TIMEZONE=$(gum input --placeholder "Enter your desired timezone (e.g., Europe/London)")
            export TIMEZONE=$NEW_TIMEZONE
        fi
    else
        gum style --foreground "yellow" "Warning: Timezone auto-detection failed. Proceeding with manual prompt."
        NEW_TIMEZONE=$(gum input --placeholder "Enter your desired timezone (e.g., Europe/London)")
        export TIMEZONE=$NEW_TIMEZONE
    fi
}

keymap () {
    local keymap_choice

    keymap_choice=$(gum choose "us" "de" "fr" "es" "More..." --header "Select a common keyboard layout:")
    
    if [ -z "$keymap_choice" ]; then
        gum style --foreground "red" "User canceled. Exiting."
        exit 1
    fi

    if [ "$keymap_choice" == "More..." ]; then
        keymap_choice=$(find /usr/share/kbd/keymaps/ -name "*.map.gz" -printf "%f\n" | sed 's/\.map\.gz$//' | sort | gum filter --placeholder "Select your keyboard layout")
        if [ -z "$keymap_choice" ]; then
            gum style --foreground "red" "User canceled. Exiting."
            exit 1
        fi
    fi
    gum style --foreground "green" "Keyboard layout set to: ${keymap_choice}"
    export KEYMAP="${keymap_choice}"
}

# ==============================================================================
#                             Main Installation Workflow
# ==============================================================================

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

if gum confirm "Are you ready to begin the installation? All data on the selected disk will be erased."; then
     gum style \
 --border normal --margin "1" --padding "1 2" --border-foreground 212 "
-------------------------------------------------------------------------
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
-------------------------------------------------------------------------
"
else
    gum style --foreground "red" "Installation canceled by user. Exiting."
    exit 1
fi

gum spin --spinner dot --title "Setting up mirrors for optimal download speed..." -- bash -c "
iso=\$(curl -4 ifconfig.io/country_code)
timedatectl set-ntp true
pacman -Sy
pacman -S --noconfirm archlinux-keyring
pacman -S --noconfirm --needed pacman-contrib terminus-font
setfont ter-v18b
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
pacman -S --noconfirm --needed reflector rsync grub
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
echo -e \"\nSetting up \$iso mirrors for faster downloads\"
reflector -a 48 -c \"\$iso\" --score 5 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
if [[ \$(grep -c \"Server =\" /etc/pacman.d/mirrorlist) -lt 5 ]]; then
    echo \"Warning: Reflector failed. Restoring original mirrorlist.\"
    cp /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist
fi
"

if [ ! -d "/mnt" ]; then
    mkdir /mnt
fi

gum style --foreground "green" "Installing Prerequisites..."
pacman -S --noconfirm --needed gptfdisk btrfs-progs glibc

gum style --foreground "green" "Formatting Disk..."
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

gum style --foreground "green" "Creating Filesystems..."
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
    gum style --foreground "red" "ERROR: Failed to mount ${partition3} to /mnt. Exiting."
    exit 1
fi
mkdir -p /mnt/boot
mount -U "${BOOT_UUID}" /mnt/boot/

if ! grep -qs '/mnt' /proc/mounts; then
    gum style --foreground "red" "ERROR: Drive is not mounted. Rebooting in 3 seconds..." && sleep 1
    gum style --foreground "red" "Rebooting in 2 seconds..." && sleep 1
    gum style --foreground "red" "Rebooting in 1 second..." && sleep 1
    reboot now
fi

gum style --foreground "green" "Installing Arch Linux on Main Drive..."
if [[ ! -d "/sys/firmware/efi" ]]; then
    pacstrap /mnt base base-devel linux-lts linux-firmware --noconfirm --needed
else
    pacstrap /mnt base base-devel linux-lts linux-firmware efibootmgr --noconfirm --needed
fi
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

genfstab -U /mnt >> /mnt/etc/fstab
gum style --foreground "green" "Generated /etc/fstab:"
cat /mnt/etc/fstab

gum style --foreground "green" "GRUB Bootloader Installation"
if [[ ! -d "/sys/firmware/efi" ]]; then
    gum style --foreground "cyan" "Installing GRUB for BIOS..."
    grub-install --boot-directory=/mnt/boot "${DISK}"
    if [ $? -ne 0 ]; then
        gum style --foreground "red" "ERROR: GRUB BIOS installation failed. Exiting."
        exit 1
    fi
fi

gum style --foreground "green" "Checking for low memory systems (<8G) for swap file..."
TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[ $TOTAL_MEM -lt 8000000 ]]; then
    gum style --foreground "yellow" "System has less than 8GB RAM. Creating a 2GB swap file."
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

pacman -S --noconfirm --needed gum

gum style --border normal --margin "1" --padding "1" "Network Setup"
pacman -S --noconfirm --needed networkmanager dhcpcd
systemctl enable NetworkManager

gum style --border normal --margin "1" --padding "1" "Setting up mirrors for optimal download"
pacman -S --noconfirm --needed pacman-contrib curl
pacman -S --noconfirm --needed reflector rsync grub arch-install-scripts git ntp wget
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak

nc=\$(grep -c ^"cpu cores" /proc/cpuinfo)
export nc
gum style --border normal --margin "1" --padding "1" "You have \${nc} cores.
Changing the makeflags for \${nc} cores.
Changing the compression settings."

TOTAL_MEM=\$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[ \$TOTAL_MEM -gt 8000000 ]]; then
    sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j\${nc}\"/g" /etc/makepkg.conf
    sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T \${nc} -z -)/g" /etc/makepkg.conf
fi
gum style --border normal --margin "1" --padding "1" "Setup Language to US and set locale"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
timedatectl --no-ask-password set-timezone ${TIMEZONE}
timedatectl --no-ask-password set-ntp 1
localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"
ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
echo "XKBLAYOUT=${KEYMAP}" >> /etc/vconsole.conf
gum style --foreground "green" "Keymap set to: ${KEYMAP}"

sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf

sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm --needed

gum style --border normal --margin "1" --padding "1" "Installing Microcode"
if grep -q "GenuineIntel" /proc/cpuinfo; then
    gum style --foreground "green" "Installing Intel microcode..."
    pacman -S --noconfirm --needed intel-ucode
elif grep -q "AuthenticAMD" /proc/cpuinfo; then
    gum style --foreground "green" "Installing AMD microcode..."
    pacman -S --noconfirm --needed amd-ucode
else
    gum style --foreground "yellow" "Unable to determine CPU vendor. Skipping microcode installation."
fi

gum style --border normal --margin "1" --padding "1" "Installing Graphics Drivers"
if echo "${gpu_type}" | grep -E "NVIDIA|GeForce"; then
    gum style --foreground "green" "Installing NVIDIA drivers: nvidia-lts..."
    pacman -S --noconfirm --needed nvidia-lts
elif echo "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
    gum style --foreground "green" "Installing AMD drivers: xf86-video-amdgpu..."
    pacman -S --noconfirm --needed xf86-video-amdgpu
elif echo "${gpu_type}" | grep -E "Integrated Graphics Controller|Intel Corporation UHD"; then
    gum style --foreground "green" "Installing Intel drivers..."
    pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
else
    gum style --foreground "yellow" "Unable to determine GPU vendor. Skipping graphics driver installation."
fi

gum style --border normal --margin "1" --padding "1" "Adding User & fast-hyprland script"
groupadd libvirt
useradd -m -G wheel,libvirt -s /bin/bash $USERNAME
gum style --foreground "green" "User '$USERNAME' created, added to 'wheel' and 'libvirt' groups."
echo "$USERNAME:$PASSWORD" | chpasswd
gum style --foreground "green" "Password for '$USERNAME' has been set."
echo $NAME_OF_MACHINE > /etc/hostname
gum style --foreground "green" "Hostname set to '$NAME_OF_MACHINE'."

gum style --foreground "green" "Pulling Dots installer transfer to /home/$USERNAME/"
wget https://raw.githubusercontent.com/CtorW/archfast/refs/heads/uno/fast-hyprland.sh -P /home/$USERNAME/
gum style --foreground "green" "changing permission Dots installer script."
cd /home/$USERNAME/ && sudo chmod +x fast-hyprland.sh

if [[ ${FS} == "luks" ]]; then
    sed -i 's/filesystems/encrypt filesystems/g' /etc/mkinitcpio.conf
    mkinitcpio -p linux-lts
fi

gum style --border normal --margin "1" --padding "1 2" --border-foreground 212 "
Final Setup and Configurations
GRUB EFI Bootloader Install & Check"

if [[ -d "/sys/firmware/efi" ]]; then
    gum style --foreground "cyan" "Installing GRUB for EFI..."
    grub-install --efi-directory=/boot "${DISK}"
    if [ $? -ne 0 ]; then
        gum style --foreground "red" "ERROR: GRUB EFI installation failed. Exiting."
        exit 1
    fi
fi

gum style --border normal --margin "1" --padding "1" "Creating Grub Boot Menu"
if [[ "${FS}" == "luks" ]]; then
    sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"%GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=${ENCRYPTED_PARTITION_UUID}:ROOT root=/dev/mapper/ROOT %g" /etc/default/grub
fi
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& splash /' /etc/default/grub

gum style --foreground "green" "Updating grub..."
grub-mkconfig -o /boot/grub/grub.cfg
if [ $? -ne 0 ]; then
    gum style --foreground "red" "ERROR: Failed to create grub.cfg. Exiting."
    exit 1
fi

gum style --foreground "green" "Verifying grub configuration..."
if [ ! -f /boot/grub/grub.cfg ]; then
    gum style --foreground "red" "ERROR: grub.cfg was not created. Exiting."
    exit 1
fi
if ! grep -q "Arch Linux" /boot/grub/grub.cfg; then
    gum style --foreground "red" "ERROR: grub.cfg does not contain an Arch Linux entry. Exiting."
    exit 1
fi
gum style --foreground "green" "Grub configuration complete!"

gum style --border normal --margin "1" --padding "1" "Enabling Essential Services"
ntpd -qg
systemctl enable ntpd.service
gum style --foreground "green" "  NTP enabled."
systemctl disable dhcpcd.service
gum style --foreground "green" "  DHCP disabled."
systemctl start NetworkManager.service
gum style --foreground "green" "  NetworkManager started."
systemctl enable NetworkManager.service
gum style --foreground "green" "  NetworkManager enabled."
systemctl enable reflector.timer
gum style --foreground "green" "  Reflector enabled."

gum style --border normal --margin "1" --padding "1" "Cleaning"
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

EOF