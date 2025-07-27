#!/bin/bash

exec > >(tee -i archsetup.log) 2>&1

echo -ne "
-------------------------------------------------------------------------
             ___    ____  ________  ___________   ___________
            /   |  / __ \/ ____/ / / / ____/   | / ___/_  __/
           / /| | / /_/ / /   / /_/ / /_  / /| | \__ \ / /   
          / ___ |/ _, _/ /___/ __  / __/ / ___ |___/ // /    
         /_/  |_/_/ |_|\____/_/ /_/_/   /_/  |_/____//_/     
                               CTOR
-------------------------------------------------------------------------
            Automated Arch Linux Setup - Initializing
-------------------------------------------------------------------------

Verifying Arch Linux ISO environment...
"

check_environment() {
    if [ ! -f /usr/bin/pacstrap ]; then
        echo "Error: This script must be run from an Arch Linux ISO environment. Exiting."
        exit 1
    fi
    if [[ "$(id -u)" != "0" ]]; then
        echo "Error: This script requires root privileges. Please run as root. Exiting."
        exit 1
    fi
    if awk -F/ '$2 == "docker"' /proc/self/cgroup | read -r || [[ -f /.dockerenv ]]; then
        echo "Error: Running inside a Docker container is not supported. Exiting."
        exit 1
    fi
    if [[ -f /var/lib/pacman/db.lck ]]; then
        echo "Error: Pacman database is locked. If no other Pacman process is running, remove /var/lib/pacman/db.lck. Exiting."
        exit 1
    fi
}

select_interactive_option() {
    local options=("$@")
    local num_options=${#options[@]}
    local selected=0
    local last_selected=-1

    while true; do
        if [ $last_selected -ne -1 ]; then
            echo -ne "\033[${num_options}A"
        fi

        if [ $last_selected -eq -1 ]; then
            echo "Use arrow keys and Enter to select an option:"
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
                    '[A') ((selected--)); if [ $selected -lt 0 ]; then selected=$((num_options - 1)); fi ;;
                    '[B') ((selected++)); if [ $selected -ge $num_options ]; then selected=0; fi ;;
                esac
                ;;
            '') break ;;
        esac
    done
    return $selected
}

display_section_header() {
echo -ne "
-------------------------------------------------------------------------
             ___    ____  ________  ___________   ___________
            /   |  / __ \/ ____/ / / / ____/   | / ___/_  __/
           / /| | / /_/ / /   / /_/ / /_  / /| | \__ \ / /   
          / ___ |/ _, _/ /___/ __  / __/ / ___ |___/ // /    
         /_/  |_/_/ |_|\____/_/ /_/_/   /_/  |_/____//_/     
------------------------------------------------------------------------
            Setup Configuration: Choose your preferences
------------------------------------------------------------------------
"
}

select_filesystem() {
    echo -ne "
Please select your file system for both boot and root partitions:
"
    local options=("btrfs" "ext4" "luks (encrypted Btrfs)")
    select_interactive_option "${options[@]}"
    local choice=$?

    case $choice in
        0) export FS="btrfs";;
        1) export FS="ext4";;
        2)
            echo -n "Enter LUKS encryption password: "
            read -rs LUKS_PASSWORD_1
            echo
            echo -n "Re-enter LUKS encryption password: "
            read -rs LUKS_PASSWORD_2
            echo

            if [[ "$LUKS_PASSWORD_1" != "$LUKS_PASSWORD_2" ]]; then
                echo "Error: Passwords do not match. Please try again."
                select_filesystem
            else
                export LUKS_PASSWORD="$LUKS_PASSWORD_1"
                export FS="luks"
            fi
            ;;
        *) echo "Invalid option. Please select again."; select_filesystem;;
    esac
}

select_hyprland_dots() {
    echo -ne "
Please select a Hyprland dotfiles configuration to install (or skip):
"
    local options=("End-4" "HyDE" "Hyprluna" "Caelestia" "Skip")
    select_interactive_option "${options[@]}"
    local choice=$?

    case $choice in
        0)
            export HYPR_DOTS="End-4"
            export HYPR_DOTS_URL="https://github.com/end-4/dots-hyprland"
            export HYPR_DOTS_DIR="/home/${USERNAME}/Downloads/dots-hyprland"
            export HYPR_INSTALL_COMMAND="cd ~/Downloads/dots-hyprland && ./install.sh"
            ;;
        1)
            export HYPR_DOTS="HyDE"
            export HYPR_DOTS_URL="https://github.com/HyDE-Project/HyDE"
            export HYPR_DOTS_DIR="/home/${USERNAME}/Downloads/HyDE"
            export HYPR_INSTALL_COMMAND="cd ~/Downloads/HyDE/Scripts && ./install.sh"
            ;;
        2)
            export HYPR_DOTS="Hyprluna"
            export HYPR_DOTS_URL="https://github.com/Lunaris-Project/HyprLuna"
            export HYPR_DOTS_DIR="/home/${USERNAME}/Downloads/HyprLuna"
            export HYPR_INSTALL_COMMAND="cd ~/Downloads/HyprLuna && ./install.sh"
            ;;
        3)
            export HYPR_DOTS="Caelestia"
            export HYPR_DOTS_URL="https://github.com/caelestia-dots/caelestia.git"
            export HYPR_DOTS_DIR="/home/${USERNAME}/.local/share/caelestia"
            export HYPR_INSTALL_COMMAND="fish ~/.local/share/caelestia/install.fish --noconfirm --spotify --vscode=code --discord --zen"
            ;;
        4)
            export HYPR_DOTS="None"
            export HYPR_DOTS_URL=""
            export HYPR_DOTS_DIR=""
            export HYPR_INSTALL_COMMAND=""
            ;;
        *)
            echo "Invalid option. Please select again."
            select_hyprland_dots
            ;;
    esac
    echo -ne "Hyprland dotfiles set to: ${HYPR_DOTS}
"
}

select_shell() {
    echo -ne "
Please select the shell to use in the chroot environment:
"
    local options=("bash" "fish")
    select_interactive_option "${options[@]}"
    local choice=$?

    case $choice in
        0) export CHROOT_SHELL="/bin/bash"; export SHELL_NAME="bash";;
        1) export CHROOT_SHELL="/usr/bin/fish"; export SHELL_NAME="fish";;
        *) echo "Invalid option. Please select again."; select_shell;;
    esac
    echo -ne "Chroot shell set to: ${SHELL_NAME}\n"
}

set_timezone() {
    local detected_timezone=$(curl --fail --silent https://ipapi.co/timezone)
    echo -ne "
System detected your timezone as: '$detected_timezone'
Is this correct?
"
    local options=("Yes" "No")
    select_interactive_option "${options[@]}"
    local choice=$?

    case $choice in
        0) export TIMEZONE="$detected_timezone"; echo "Timezone set to: $TIMEZONE";;
        1)
            echo "Please enter your desired timezone (e.g., Europe/London or Asia/Manila):"
            read -r new_timezone
            export TIMEZONE="$new_timezone"
            echo "Timezone set to: $TIMEZONE"
            ;;
        *) echo "Invalid option. Please try again."; set_timezone;;
    esac
}

set_keymap() {
    echo -ne "
Select your keyboard layout from the list below:
"
    local options=(us by ca cf cz de dk es et fa fi fr gr hu il it lt lv mk nl no pl ro ru se sg ua uk)
    select_interactive_option "${options[@]}"
    export KEYMAP="${options[$?]}"
    echo -ne "Keyboard layout set to: ${KEYMAP}\n"
}

choose_drive_type() {
    echo -ne "
Is this an SSD (Solid State Drive)?
"
    local options=("Yes" "No")
    select_interactive_option "${options[@]}"
    local choice=$?

    case $choice in
        0) export MOUNT_OPTIONS="noatime,compress=zstd,ssd,commit=120";;
        1) export MOUNT_OPTIONS="noatime,compress=zstd,commit=120";;
        *) echo "Invalid option. Please try again."; choose_drive_type;;
    esac
}

select_disk() {
echo -ne "
------------------------------------------------------------------------
    *** CRITICAL WARNING: DISK SELECTION ***
  This process will FORMAT and DELETE ALL DATA on the selected disk.
  Ensure you have backed up any important data.
  I AM NOT RESPONSIBLE FOR ANY DATA LOSS. Proceed with caution!
------------------------------------------------------------------------

"
    PS3='Select the disk to install Arch Linux on: '
    local options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))

    select_interactive_option "${options[@]}"
    local disk_choice=${options[$?]}
    export DISK="${disk_choice%|*}"

    echo -e "\nSelected disk: ${DISK}\n"
    choose_drive_type
}

gather_user_info() {
    while true; do
        read -r -p "Enter a username for your new system: " USERNAME
        if [[ "${USERNAME,,}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]; then
            break
        fi
        echo "Invalid username. Usernames must start with a lowercase letter or underscore, and can contain lowercase letters, digits, underscores, or hyphens (max 31 chars)."
    done

    while true; do
        read -rs -p "Enter a strong password for your user: " PASSWORD_1
        echo
        read -rs -p "Re-enter the password: " PASSWORD_2
        echo
        if [[ "$PASSWORD_1" == "$PASSWORD_2" ]]; then
            export PASSWORD="$PASSWORD_1"
            break
        else
            echo "Error: Passwords do not match. Please try again."
        fi
    done

    while true; do
        read -r -p "Enter a hostname for your machine: " NAME_OF_MACHINE
        if [[ "${NAME_OF_MACHINE,,}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]; then
            break
        fi
        read -r -p "The hostname appears invalid. Do you still want to use it? (y/n): " force_hostname
        if [[ "${force_hostname,,}" = "y" ]]; then
            break
        fi
    done
}

create_btrfs_subvolumes() {
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
}

mount_all_btrfs_subvolumes() {
    mount -o "${MOUNT_OPTIONS}",subvol=@home "${partition3}" /mnt/home
}

setup_btrfs_subvolumes() {
    create_btrfs_subvolumes
    umount /mnt
    mount -o "${MOUNT_OPTIONS}",subvol=@ "${partition3}" /mnt
    mkdir -p /mnt/home
    mount_all_btrfs_subvolumes
}

format_and_mount_disks() {
    echo "Unmounting any existing mounts on /mnt..."
    umount -A --recursive /mnt || true

    echo "Preparing disk: ${DISK}"
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

    echo "Creating filesystems..."
    mkfs.fat -F32 -n "EFIBOOT" "${partition2}"

    if [[ "${FS}" == "btrfs" ]]; then
        mkfs.btrfs -f "${partition3}"
        mount -t btrfs "${partition3}" /mnt
        setup_btrfs_subvolumes
    elif [[ "${FS}" == "ext4" ]]; then
        mkfs.ext4 "${partition3}"
        mount -t ext4 "${partition3}" /mnt
    elif [[ "${FS}" == "luks" ]]; then
        echo "Encrypting root partition with LUKS..."
        echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v luksFormat "${partition3}" -
        echo -n "${LUKS_PASSWORD}" | cryptsetup open "${partition3}" cryptroot -
        mkfs.btrfs /dev/mapper/cryptroot
        mount -t btrfs /dev/mapper/cryptroot /mnt
        setup_btrfs_subvolumes
        export ENCRYPTED_PARTITION_UUID=$(blkid -s UUID -o value "${partition3}")
    fi

    local BOOT_UUID=$(blkid -s UUID -o value "${partition2}")
    sync

    if ! mountpoint -q /mnt; then
        echo "Error: Failed to mount root partition to /mnt. Rebooting in 5 seconds..."
        sleep 5
        reboot now
    fi
    mkdir -p /mnt/boot
    mount -U "${BOOT_UUID}" /mnt/boot/

    if ! grep -qs '/mnt' /proc/mounts; then
        echo "Error: Drive is not mounted correctly. Cannot continue. Rebooting in 5 seconds..."
        sleep 5
        reboot now
    fi
}

install_base_system() {
    echo "Installing base Arch Linux system..."
    local pacstrap_packages="base base-devel linux-lts linux-firmware"
    if [[ -d "/sys/firmware/efi" ]]; then
        pacstrap_packages+=" efibootmgr"
    fi
    pacstrap /mnt ${pacstrap_packages} --noconfirm --needed

    echo "Configuring mirrorlist and fstab..."
    echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf
    cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
    genfstab -U /mnt >> /mnt/etc/fstab
    echo "Generated /mnt/etc/fstab:"
    cat /mnt/etc/fstab
}

chroot_configuration() {
    local gpu_type=$(lspci | grep -E "VGA|3D|Display")
    local total_mem_kb=$(grep -i 'memtotal' /proc/meminfo | awk '{print $2}')
    local cpu_cores=$(grep -c ^"cpu cores" /proc/cpuinfo)

    arch-chroot /mnt pacman -S --noconfirm --needed networkmanager dhcpcd pacman-contrib curl reflector rsync grub arch-install-scripts git ntp wget fish
    
    if [[ "${SHELL_NAME}" == "fish" ]]; then
        arch-chroot /mnt pacman -S --noconfirm --needed fish
        arch-chroot /mnt chsh -s /usr/bin/fish ${USERNAME}
    fi

    arch-chroot /mnt /bin/bash -c "

        echo 'Setting up network...'
        systemctl enable NetworkManager

        echo 'Optimizing Pacman and system settings...'
        cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak

        echo 'Configuring MAKEFLAGS for ${cpu_cores} cores and XZ compression...'
        if [[ ${total_mem_kb} -gt 8000000 ]]; then
            sed -i \"s/#MAKEFLAGS=\\\"-j2\\\"/MAKEFLAGS=\\\"-j${cpu_cores}\\\"/g\" /etc/makepkg.conf
            sed -i \"s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T ${cpu_cores} -z -)/g\" /etc/makepkg.conf
        fi

        echo 'Setting locale and timezone...'
        sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
        locale-gen
        timedatectl --no-ask-password set-timezone ${TIMEZONE}
        timedatectl --no-ask-password set-ntp 1
        localectl --no-ask-password set-locale LANG=\"en_US.UTF-8\" LC_TIME=\"en_US.UTF-8\"
        ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

        echo \"KEYMAP=${KEYMAP}\" > /etc/vconsole.conf
        echo \"XKBLAYOUT=${KEYMAP}\" >> /etc/vconsole.conf
        echo \"Keyboard layout set to: ${KEYMAP}\"

        echo 'Configuring sudoers and Pacman features...'
        sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
        sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
        sed -i 's/^#Color/Color\\nILoveCandy/' /etc/pacman.conf
        sed -i \"/\\[multilib\\]/,/Include/s/^#//\" /etc/pacman.conf
        pacman -Sy --noconfirm --needed

        echo 'Installing microcode...'
        if grep -q \"GenuineIntel\" /proc/cpuinfo; then
            echo \"Installing Intel microcode.\"
            pacman -S --noconfirm --needed intel-ucode
        elif grep -q \"AuthenticAMD\" /proc/cpuinfo; then
            echo \"Installing AMD microcode.\"
            pacman -S --noconfirm --needed amd-ucode
        else
            echo \"CPU vendor not determined. Skipping microcode installation.\"
        fi

        echo 'Installing graphics drivers...'
        if echo \"${gpu_type}\" | grep -E \"NVIDIA|GeForce\"; then
            echo \"Installing NVIDIA drivers: nvidia-lts\"
            pacman -S --noconfirm --needed nvidia-lts
        elif echo \"${gpu_type}\" | grep 'VGA' | grep -E \"Radeon|AMD\"; then
            echo \"Installing AMD drivers: mesa\"
            pacman -S --noconfirm --needed mesa
        elif echo \"${gpu_type}\" | grep -E \"Intel Corporation|Integrated Graphics Controller|Intel Corporation UHD\"; then
            echo \"Installing Intel graphics drivers.\"
            pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
        else
            echo \"No specific GPU detected, skipping graphics driver installation.\"
        fi

        echo 'Installing Hyprland and dependencies...'
        if [[ \"${HYPR_DOTS}\" != \"None\" ]]; then
            pacman -S --noconfirm --needed hyprland wayland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk qt5-wayland qt6-wayland
            pacman -S --noconfirm --needed waybar hyprpaper dunst kitty rofi polkit-gnome pipewire pipewire-alsa pipewire-pulse pipewire-jack
        fi

        echo 'Creating user account...'
        groupadd libvirt
        useradd -m -G wheel,libvirt -s /bin/bash ${USERNAME}
        echo \"User ${USERNAME} created and configured.\"
        echo \"${USERNAME}:${PASSWORD}\" | chpasswd
        echo \"Password set for ${USERNAME}.\"
        echo ${NAME_OF_MACHINE} > /etc/hostname

        echo 'Downloading selected Hyprland dotfiles...'
        if [[ \"${HYPR_DOTS}\" != \"None\" ]]; then
            mkdir -p /home/${USERNAME}/Downloads
            if [[ \"${HYPR_DOTS}\" == \"Caelestia\" ]]; then
                mkdir -p /home/${USERNAME}/.local/share
                if ! git clone --depth 1 ${HYPR_DOTS_URL} /home/${USERNAME}/.local/share/caelestia; then
                    echo \"Error: Failed to clone Caelestia dotfiles. Aborting.\"
                    exit 1
                fi
                chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.local/share/caelestia
                echo \"Caelestia dotfiles downloaded to ~/.local/share/caelestia.\"
            else
                if ! git clone --depth 1 ${HYPR_DOTS_URL} ${HYPR_DOTS_DIR}; then
                    echo \"Error: Failed to clone ${HYPR_DOTS} dotfiles. Aborting.\"
                    exit 1
                fi
                chown -R ${USERNAME}:${USERNAME} ${HYPR_DOTS_DIR}
                echo \"${HYPR_DOTS} dotfiles downloaded to ${HYPR_DOTS_DIR}.\"
            fi
        fi

        if [[ ${FS} == \"luks\" ]]; then
            echo 'Configuring mkinitcpio for LUKS encryption...'
            sed -i 's/filesystems/encrypt filesystems/g' /etc/mkinitcpio.conf
            mkinitcpio -p linux-lts
        fi

        echo 'Setting up GRUB bootloader...'
        if [[ -d \"/sys/firmware/efi\" ]]; then
            grub-install --efi-directory=/boot ${DISK}
        else
            grub-install --boot-directory=/boot ${DISK}
        fi

        echo 'Generating GRUB configuration...'
        if [[ \"${FS}\" == \"luks\" ]]; then
            sed -i \"s/GRUB_CMDLINE_LINUX_DEFAULT=\\\"/GRUB_CMDLINE_LINUX_DEFAULT=\\\"cryptdevice=UUID=${ENCRYPTED_PARTITION_UUID}:cryptroot root=\/dev\/mapper\/cryptroot /g\" /etc/default/grub
        fi
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"[^\\\"]*/& splash /' /etc/default/grub
        grub-mkconfig -o /boot/grub/grub.cfg

        echo 'Enabling essential services...'
        ntpd -qg
        systemctl enable ntpd.service
        systemctl disable dhcpcd.service
        systemctl enable NetworkManager.service
        systemctl enable reflector.timer
        if [[ \"${HYPR_DOTS}\" != \"None\" ]]; then
            systemctl enable polkit.service
        fi

        echo 'Finalizing user permissions...'
    "
}

create_swap_if_needed() {
    local total_mem_mb=$(grep -i 'memtotal' /proc/meminfo | awk '{print $2 / 1024}')
    if (( $(echo "$total_mem_mb < 8192" | bc -l) )); then
        echo "System memory is ${total_mem_mb}MB (<8GB). Creating 2GB swap file."
        mkdir -p /mnt/opt/swap
        if findmnt -n -o FSTYPE /mnt | grep -q btrfs; then
            chattr +C /mnt/opt/swap
        fi
        dd if=/dev/zero of=/mnt/opt/swap/swapfile bs=1M count=2048 status=progress
        chmod 600 /mnt/opt/swap/swapfile
        chown root /mnt/opt/swap/swapfile
        mkswap /mnt/opt/swap/swapfile
        swapon /mnt/opt/swap/swapfile
        echo "/opt/swap/swapfile none swap sw 0 0" >> /mnt/etc/fstab
    else
        echo "Sufficient memory detected (${total_mem_mb}MB). Skipping swap file creation."
    fi
}

main() {
    clear
    check_environment

    clear
    display_section_header
    gather_user_info

    clear
    display_section_header
    select_disk

    clear
    display_section_header
    select_filesystem

    clear
    display_section_header
    set_timezone

    clear
    display_section_header
    set_keymap

    clear
    display_section_header
    select_hyprland_dots

    clear
    display_section_header
    select_shell

    echo "--- System Preparation ---"
    timedatectl set-ntp true
    pacman -Sy
    pacman -S --noconfirm archlinux-keyring pacman-contrib terminus-font reflector rsync grub gptfdisk btrfs-progs glibc --needed
    setfont ter-v18b
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

    local country_code=$(curl -4 --silent ifconfig.io/country_code)
    echo "Optimizing Pacman mirrors for your region ($country_code)..."
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    reflector -a 48 -c "$country_code" --score 5 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
    if [[ $(grep -c "Server =" /etc/pacman.d/mirrorlist) -lt 5 ]]; then
        echo "Less than 5 mirrors found. Reverting to backup mirrorlist."
        cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
    fi

    echo "--- Partitioning and Formatting Disks ---"
    format_and_mount_disks

    echo "--- Installing Arch Linux Base System ---"
    install_base_system

    echo "--- Creating Swap File (if needed) ---"
    create_swap_if_needed

    echo "--- Configuring Installed System (chroot) ---"
    chroot_configuration

    echo "Unmounting partitions..."
    umount -R /mnt

    echo -ne "
-------------------------------------------------------------------------
             ___    ____  ________  ___________   ___________
            /   |  / __ \/ ____/ / / / ____/   | / ___/_  __/
           / /| | / /_/ / /   / /_/ / /_  / /| | \__ \ / /   
          / ___ |/ _, _/ /___/ __  / __/ / ___ |___/ // /    
         /_/  |_/_/ |_|\____/_/ /_/_/   /_/  |_/____//_/     
                                CTOR
-------------------------------------------------------------------------
            Arch Linux Installation Complete! 🎉
-------------------------------------------------------------------------
"

    if [[ "${HYPR_DOTS}" != "None" ]]; then
        echo ""
        echo "=================================================================="
        echo "  Next Step: Install Hyprland Dotfiles. "
        echo "=================================================================="
        echo "Your selected Hyprland dotfiles (${HYPR_DOTS}) have been downloaded."

        if [[ "${HYPR_DOTS}" == "Caelestia" ]]; then
            echo "Caelestia dotfiles are located at: ~/.local/share/caelestia"
            echo "To install Caelestia, log into your new Arch system as '${USERNAME}' and run:"
            echo "  cd ~/.local/share/caelestia"
            echo "  ./install.fish --noconfirm --spotify --vscode=code --discord --zen"
            echo "(Note: You will need to switch to fish shell if you chose bash as primary, or just run the .fish script directly)"
        else
            echo "The dotfiles are located in your new system's Downloads directory:"
            echo "  ${HYPR_DOTS_DIR}"
            echo "To install them, log into your new Arch system as '${USERNAME}' and run:"
            echo "  ${HYPR_INSTALL_COMMAND}"
        fi

        echo ""
        echo "Remember to reboot your system and log in as '${USERNAME}' to complete the setup."
    else
        echo "No Hyprland dotfiles were selected for download."
    fi

    echo ""
    echo "Installation script finished."
    read -p "Press Enter to reboot, or Ctrl+C to exit."
    reboot
}

main
