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

echo -ne "
${BCyan}-------------------------------------------------------------------------
                                                                                   
   _|_|    _|_|_|      _|_|_|  _|    _|  _|_|_|_|    _|_|      _|_|_|  _|_|_|_|_|  
 _|    _|  _|    _|  _|        _|    _|  _|        _|    _|  _|            _|      
 _|_|_|_|  _|_|_|    _|        _|_|_|_|  _|_|_|    _|_|_|_|    _|_|        _|      
 _|    _|  _|    _|  _|        _|    _|  _|        _|    _|        _|      _|      
 _|    _|  _|    _|    _|_|_|  _|    _|  _|        _|    _|  _|_|_|        _|     
-------------------------------------------------------------------------
${BYellow}                 Automated Arch Linux Installer${Color_Off}
${BCyan}------------------------------------------------------------------------- ${Color_Off}

${BGreen}Verifying Arch Linux ISO is Booted${Color_Off}

"
if [ ! -f /usr/bin/pacstrap ]; then
    echo "This script must be run from an Arch Linux ISO environment."
    exit 1
fi

root_check() {
    if [[ "$(id -u)" != "0" ]]; then
        echo -ne "ERROR! This script must be run under the 'root' user!\n"
        exit 0
    fi
}

docker_check() {
    if awk -F/ '$2 == "docker"' /proc/self/cgroup | read -r; then
        echo -ne "ERROR! Docker container is not supported (at the moment)\n"
        exit 0
    elif [[ -f /.dockerenv ]]; then
        echo -ne "ERROR! Docker container is not supported (at the moment)\n"
        exit 0
    fi
}

arch_check() {
    if [[ ! -e /etc/arch-release ]]; then
        echo -ne "ERROR! This script must be run in Arch Linux!\n"
        exit 0
    fi
}

pacman_check() {
    if [[ -f /var/lib/pacman/db.lck ]]; then
        echo "ERROR! Pacman is blocked."
        echo -ne "If not running remove /var/lib/pacman/db.lck.\n"
        exit 0
    fi
}

background_checks() {
    root_check
    arch_check
    pacman_check
    docker_check
}

select_option() {
    local options=("$@")
    local num_options=${#options[@]}
    local selected=0
    local last_selected=-1

    while true; do
        if [ $last_selected -ne -1 ]; then
            echo -ne "\033[${num_options}A"
        fi

        if [ $last_selected -eq -1 ]; then
            echo "Please select an option using the arrow keys and Enter:"
        fi
        for i in "${!options[@]}"; do
            if [ "$i" -eq $selected ]; then
                echo "> ${options[$i]}"
            else
                echo "  ${options[$i]}"
            fi
        done

        last_selected=$selected

        read -rsn1 key
        case $key in
            $'\x1b') 
                read -rsn2 -t 0.1 key
                case $key in
                    '[A') 
                        ((selected--))
                        if [ $selected -lt 0 ]; then
                            selected=$((num_options - 1))
                        fi
                        ;;
                    '[B') 
                        ((selected++))
                        if [ $selected -ge $num_options ]; then
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

    return $selected
}

logo () {
echo -ne "
${BCyan}-------------------------------------------------------------------------
                                                                                   
   _|_|    _|_|_|      _|_|_|  _|    _|  _|_|_|_|    _|_|      _|_|_|  _|_|_|_|_|  
 _|    _|  _|    _|  _|        _|    _|  _|        _|    _|  _|            _|      
 _|_|_|_|  _|_|_|    _|        _|_|_|_|  _|_|_|    _|_|_|_|    _|_|        _|      
 _|    _|  _|    _|  _|        _|    _|  _|        _|    _|        _|      _|      
 _|    _|  _|    _|    _|_|_|  _|    _|  _|        _|    _|  _|_|_|        _|      
------------------------------------------------------------------------
${BYellow}      Please select presetup settings for your system${Color_Off}
${BCyan}------------------------------------------------------------------------${Color_Off}
"
}
filesystem () {
    echo -ne "
    ${BGreen}Please Select your file system for both boot and root${Color_Off}
    "
    options=("btrfs" "ext4" "luks" "exit")
    select_option "${options[@]}"

    case $? in
    0) export FS=btrfs;;
    1) export FS=ext4;;
    2)
        set_password "LUKS_PASSWORD"
        export FS=luks
        ;;
    3) exit ;;
    *) echo "Wrong option please select again"; filesystem;;
    esac
}

timezone () {
    time_zone="$(curl --fail https://ipapi.co/timezone)"
    echo -ne "
    ${BGreen}System detected your timezone to be '$time_zone'${Color_Off} \n"
    echo -ne "${BYellow}Is this correct?${Color_Off}
    "
    options=("Yes" "No")
    select_option "${options[@]}"

    case ${options[$?]} in
        y|Y|yes|Yes|YES)
        echo "${time_zone} set as timezone"
        export TIMEZONE=$time_zone;;
        n|N|no|NO|No)
        echo "Please enter your desired timezone e.g. Europe/London :"
        read -r new_timezone
        echo "${new_timezone} set as timezone"
        export TIMEZONE=$new_timezone;;
        *) echo "Wrong option. Try again";timezone;;
    esac
}
keymap () {
    echo -ne "
    ${BGreen}Please select key board layout from this list${Color_Off} \n"
    options=(us by ca cf cz de dk es et fa fi fr gr hu il it lt lv mk nl no pl ro ru se sg ua uk)

    select_option "${options[@]}"
    keymap=${options[$?]}

    echo -ne "Your key boards layout: ${keymap} \n"
    export KEYMAP=$keymap
}

drivessd () {
    echo -ne "
    ${BGreen}Is this an ssd? yes/no:${Color_Off}
    "

    options=("Yes" "No")
    select_option "${options[@]}"

    case ${options[$?]} in
        y|Y|yes|Yes|YES)
        export MOUNT_OPTIONS="noatime,compress=zstd,ssd,commit=120";;
        n|N|no|NO|No)
        export MOUNT_OPTIONS="noatime,compress=zstd,commit=120";;
        *) echo "Wrong option. Try again";drivessd;;
    esac
}

diskpart () {
echo -ne "
${BRed}------------------------------------------------------------------------
    THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK
    Please make sure you know what you are doing because
    after formatting your disk there is no way to get data back
    *****BACKUP YOUR DATA BEFORE CONTINUING*****
    ***I AM NOT RESPONSIBLE FOR ANY DATA LOSS***
------------------------------------------------------------------------${Color_Off}

"

    PS3='
    Select the disk to install on: '
    options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))

    select_option "${options[@]}"
    disk=${options[$?]%|*}

    echo -e "\n${disk%|*} selected \n"
        export DISK=${disk%|*}

    drivessd
}

userinfo () {
    while true
    do
            read -r -p "Please enter username: " username
            if [[ "${username,,}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]
            then
                    break
            fi
            echo "Incorrect username."
    done
    export USERNAME=$username

    while true
    do
        read -rs -p "Please enter password: " PASSWORD1
        echo -ne "\n"
        read -rs -p "Please re-enter password: " PASSWORD2
        echo -ne "\n"
        if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
            break
        else
            echo -ne "ERROR! Passwords do not match. \n"
        fi
    done
    export PASSWORD=$PASSWORD1

    while true
    do
            read -r -p "Please name your machine: " name_of_machine
            if [[ "${name_of_machine,,}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]
            then
                    break
            fi
            read -r -p "Hostname doesn't seem correct. Do you still want to save it? (y/n)" force
            if [[ "${force,,}" = "y" ]]
            then
                    break
            fi
    done
    export NAME_OF_MACHINE=$name_of_machine
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

echo -e "${BYellow}Setting up mirrors for optimal download${Color_Off}"
iso=$(curl -4 ifconfig.io/country_code)
timedatectl set-ntp true
pacman -Sy
pacman -S --noconfirm archlinux-keyring 
pacman -S --noconfirm --needed pacman-contrib terminus-font
setfont ter-v18b
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
pacman -S --noconfirm --needed reflector rsync grub
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
echo -ne "
${BGreen}-------------------------------------------------------------------------
                 Setting up $iso mirrors for faster downloads
-------------------------------------------------------------------------${Color_Off}
"
reflector -a 48 -c "$iso" --score 5 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
if [[ $(grep -c "Server =" /etc/pacman.d/mirrorlist) -lt 5 ]]; then 
    cp /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist
fi

if [ ! -d "/mnt" ]; then
    mkdir /mnt
fi
echo -ne "
${BGreen}-------------------------------------------------------------------------
                    Installing Prerequisites
-------------------------------------------------------------------------${Color_Off}
"
pacman -S --noconfirm --needed gptfdisk btrfs-progs glibc
echo -ne "
${BGreen}-------------------------------------------------------------------------
                       Formatting Disk
-------------------------------------------------------------------------${Color_Off}
"
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

echo -ne "
${BGreen}-------------------------------------------------------------------------
                     Creating Filesystems
-------------------------------------------------------------------------${Color_Off}
"
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
    echo "ERROR! Failed to mount ${partition3} to /mnt after multiple attempts."
    exit 1
fi
mkdir -p /mnt/boot
mount -U "${BOOT_UUID}" /mnt/boot/

if ! grep -qs '/mnt' /proc/mounts; then
    echo "Drive is not mounted can not continue"
    echo "Rebooting in 3 Seconds ..." && sleep 1
    echo "Rebooting in 2 Seconds ..." && sleep 1
    echo "Rebooting in 1 Second ..." && sleep 1
    reboot now
fi

echo -ne "
${BGreen}-------------------------------------------------------------------------
                 Arch Install on Main Drive
-------------------------------------------------------------------------${Color_Off}
"
if [[ ! -d "/sys/firmware/efi" ]]; then
    pacstrap /mnt base base-devel linux-lts linux-firmware --noconfirm --needed
else
    pacstrap /mnt base base-devel linux-lts linux-firmware efibootmgr --noconfirm --needed
fi
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

genfstab -U /mnt >> /mnt/etc/fstab
echo "
  Generated /etc/fstab:
"
cat /mnt/etc/fstab
echo -ne "
${BGreen}-------------------------------------------------------------------------
             GRUB BIOS Bootloader Install & Check
-------------------------------------------------------------------------${Color_Off}
"
if [[ ! -d "/sys/firmware/efi" ]]; then
    grub-install --boot-directory=/mnt/boot "${DISK}"
fi
echo -ne "
${BGreen}-------------------------------------------------------------------------
             Checking for low memory systems <8G
-------------------------------------------------------------------------${Color_Off}
"
TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[  $TOTAL_MEM -lt 8000000 ]]; then
    mkdir -p /mnt/opt/swap 
    if findmnt -n -o FSTYPE /mnt | grep -q btrfs; then
        chattr +C /mnt/opt/swap 
    fi
    dd if=/dev/zero of=/mnt/opt/swap/swapfile bs=1M count=2048 status=progress
    chmod 600 /mnt/opt/swap/swapfile 
    chown root /mnt/opt/swap/swapfile
    mkswap /mnt/opt/swap/swapfile
    swapon /mnt/opt/swap/swapfile
    echo "/opt/swap/swapfile    none    swap    sw    0    0" >> /mnt/etc/fstab 
fi

gpu_type=$(lspci | grep -E "VGA|3D|Display")

arch-chroot /mnt /bin/bash -c "KEYMAP='${KEYMAP}' /bin/bash" <<EOF

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
                   You have " $nc" cores. And
             changing the makeflags for " $nc" cores. Aswell as
                  changing the compression settings.
-------------------------------------------------------------------------${Color_Off}
"
TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[  $TOTAL_MEM -gt 8000000 ]]; then
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
echo "Keymap set to: ${KEYMAP}"

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
    echo "Installing Intel microcode"
    pacman -S --noconfirm --needed intel-ucode
elif grep -q "AuthenticAMD" /proc/cpuinfo; then
    echo "Installing AMD microcode"
    pacman -S --noconfirm --needed amd-ucode
else
    echo "Unable to determine CPU vendor. Skipping microcode installation."
fi

echo -ne "
${BGreen}-------------------------------------------------------------------------
                  Installing Graphics Drivers
-------------------------------------------------------------------------${Color_Off}
"
if echo "${gpu_type}" | grep -E "NVIDIA|GeForce"; then
    echo "Installing NVIDIA drivers: nvidia-lts"
    pacman -S --noconfirm --needed nvidia-lts
elif echo "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
    echo "Installing AMD drivers: xf86-video-amdgpu"
    pacman -S --noconfirm --needed xf86-video-amdgpu
elif echo "${gpu_type}" | grep -E "Integrated Graphics Controller"; then
    echo "Installing Intel drivers:"
    pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
elif echo "${gpu_type}" | grep -E "Intel Corporation UHD"; then
    echo "Installing Intel UHD drivers:"
    pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
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
                        Adding User
-------------------------------------------------------------------------${Color_Off}
"
groupadd libvirt
useradd -m -G wheel,libvirt -s /bin/bash $USERNAME
echo "$USERNAME created, home directory created, added to wheel and libvirt group, default shell set to /bin/bash"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "$USERNAME password set"
echo $NAME_OF_MACHINE > /etc/hostname

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

Final Setup and Configurations
GRUB EFI Bootloader Install & Check
${Color_Off}"

if [[ -d "/sys/firmware/efi" ]]; then
    grub-install --efi-directory=/boot ${DISK}
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

echo -e "Updating grub..."
grub-mkconfig -o /boot/grub/grub.cfg
echo -e "All set!"

echo -ne "
${BGreen}-------------------------------------------------------------------------
                  Enabling Essential Services
-------------------------------------------------------------------------${Color_Off}
"
ntpd -qg
systemctl enable ntpd.service
echo "  NTP enabled"
systemctl disable dhcpcd.service
echo "  DHCP disabled"
systemctl enable NetworkManager.service
echo "  NetworkManager enabled"
systemctl enable reflector.timer
echo "  Reflector enabled"

echo -ne "
${BGreen}-------------------------------------------------------------------------
             HYPRLAND-TEST
-------------------------------------------------------------------------${Color_Off}
"
su - "$USERNAME" <<'HYPERLAND_TEST_EOF'
echo "Cloning HyDE repository..."
git clone --depth 1 https://github.com/HyDE-Project/HyDE ~/HyDE

cd ~/HyDE/Scripts
echo "Running the HyDE install script..."
./install.sh
HYPERLAND_TEST_EOF

echo -ne "
${BGreen}-------------------------------------------------------------------------
                         Cleaning
-------------------------------------------------------------------------${Color_Off}
"
sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

EOF
