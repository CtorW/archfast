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
#                Python Curses TUI Script Generation
# ==============================================================================
create_tui_script() {
    cat << 'EOF' > tui.py
#!/usr/bin/env python3

import curses
import os
import subprocess
import sys

def setup_colors():
    """Initializes color pairs for the TUI."""
    if curses.has_colors():
        curses.start_color()
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_CYAN, -1)
        curses.init_pair(2, curses.COLOR_YELLOW, -1)
        curses.init_pair(3, curses.COLOR_GREEN, -1)
        curses.init_pair(4, curses.COLOR_RED, -1)
        curses.init_pair(5, curses.COLOR_WHITE, -1)
        curses.init_pair(6, curses.COLOR_BLACK, curses.COLOR_YELLOW)

def get_input(stdscr, y, x, prompt_string):
    """Displays a prompt and returns the user's input."""
    stdscr.addstr(y, x, prompt_string)
    stdscr.refresh()
    curses.echo()
    curses.curs_set(1)
    input_str = stdscr.getstr(y + 1, x, 60).decode('utf-8')
    curses.noecho()
    curses.curs_set(0)
    return input_str

def get_password(stdscr, y, x, prompt_string):
    """Displays a password prompt and returns the user's input."""
    stdscr.addstr(y, x, prompt_string)
    stdscr.refresh()
    curses.noecho()
    curses.curs_set(1)
    password = b""
    while True:
        try:
            ch = stdscr.getch()
            if ch == 10:  # Enter key
                break
            elif ch in [curses.KEY_BACKSPACE, 127, 8]: # Backspace
                if len(password) > 0:
                    h, w = stdscr.getyx()
                    stdscr.move(h, w - 1)
                    stdscr.delch()
                    password = password[:-1]
            elif 32 <= ch <= 126: # Regular character
                password += bytes([ch])
                stdscr.addch('*')
        except KeyboardInterrupt:
             sys.exit(1)
    curses.curs_set(0)
    return password.decode('utf-8')

def display_menu(stdscr, title, options):
    """Displays a menu and returns the selected option string."""
    selected_idx = 0
    curses.curs_set(0)
    
    while True:
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        
        title_y = 2
        for i, line in enumerate(title.split('\n')):
            title_x = w // 2 - len(line) // 2
            stdscr.addstr(title_y + i, title_x, line, curses.A_BOLD)

        for i, option in enumerate(options):
            opt_x = w // 2 - len(option) // 2
            if i == selected_idx:
                stdscr.addstr(title_y + len(title.split('\n')) + 2 + i, opt_x, f"> {option} <", curses.A_REVERSE)
            else:
                stdscr.addstr(title_y + len(title.split('\n')) + 2 + i, opt_x, f"  {option}  ")
        
        stdscr.refresh()
        try:
            key = stdscr.getch()
        except KeyboardInterrupt:
            sys.exit(1)

        if key == curses.KEY_UP:
            selected_idx = (selected_idx - 1) % len(options)
        elif key == curses.KEY_DOWN:
            selected_idx = (selected_idx + 1) % len(options)
        elif key in [curses.KEY_ENTER, 10, 13]:
            if not options:
                return None
            return options[selected_idx]

def userinfo(stdscr):
    """Gathers username, password, and hostname."""
    setup_colors()
    username = ""
    password = ""
    hostname = ""
    while not username:
        username = get_input(stdscr, 2, 2, "Enter a username for your new system:")
    
    while True:
        stdscr.clear()
        stdscr.addstr(2, 2, f"Username: {username}")
        password = get_password(stdscr, 4, 2, "Enter password:")
        password2 = get_password(stdscr, 7, 2, "Re-enter password:")
        if password == password2 and password != "":
            break
        else:
            stdscr.addstr(10, 2, "Passwords do not match or are empty. Press any key to try again.", curses.color_pair(4))
            stdscr.getch()

    while not hostname:
        stdscr.clear()
        stdscr.addstr(2, 2, f"Username: {username}")
        stdscr.addstr(4, 2, "Password: [set]")
        hostname = get_input(stdscr, 7, 2, "Please name your machine (hostname):")

    print(f"{username}\n{password}\n{hostname}")

def diskpart(stdscr):
    """Allows the user to select a disk."""
    setup_colors()
    disk_list_cmd = "lsblk -o KNAME,SIZE,MODEL -d | grep -E 'sd|hd|vd|nvme|mmcblk'"
    disks_raw = subprocess.check_output(disk_list_cmd, shell=True).decode('utf-8').strip().split('\n')
    disk_options = [f"{d.split()[0]:<10} {d.split()[1]:<10} {' '.join(d.split()[2:])}" for d in disks_raw]
    
    selected_disk_str = display_menu(stdscr, "WARNING: THIS WILL FORMAT THE DISK.\nPlease select the disk to install Arch Linux on:", disk_options)
    if not selected_disk_str:
        sys.exit(1)
        
    selected_disk = selected_disk_str.split()[0]
    
    is_ssd_str = display_menu(stdscr, f"Is /dev/{selected_disk} an SSD?", ["Yes", "No"])
    mount_options = "noatime,compress=zstd,ssd,commit=120" if is_ssd_str == "Yes" else "noatime,compress=zstd,commit=120"
    print(f"/dev/{selected_disk}\n{mount_options}")

def filesystem(stdscr):
    """Allows the user to select a filesystem."""
    setup_colors()
    fs_options = ["btrfs", "ext4", "luks"]
    fs_choice = display_menu(stdscr, "Please select a filesystem:", fs_options)
    
    luks_password = ""
    if fs_choice == "luks":
        stdscr.clear()
        while True:
            luks_pass1 = get_password(stdscr, 8, 2, "Enter a strong password for disk encryption:")
            luks_pass2 = get_password(stdscr, 11, 2, "Re-enter the password to confirm:")
            if luks_pass1 == luks_pass2 and luks_pass1 != "":
                luks_password = luks_pass1
                break
            else:
                stdscr.addstr(14, 2, "Passwords do not match or are empty. Please try again.", curses.color_pair(4))
                stdscr.getch()
                stdscr.clear()

    print(f"{fs_choice}\n{luks_password}")

def timezone(stdscr):
    """Allows the user to set the timezone."""
    setup_colors()
    try:
        detected_timezone = subprocess.check_output("curl --fail https://ipapi.co/timezone", shell=True).decode('utf-8').strip()
        confirm = display_menu(stdscr, f"System detected your timezone to be '{detected_timezone}'.\nIs this correct?", ["Yes", "No"])
        if confirm == "Yes":
            print(detected_timezone)
            return
    except subprocess.CalledProcessError:
        pass
    stdscr.clear()
    new_timezone = ""
    while not new_timezone:
        new_timezone = get_input(stdscr, 5, 2, "Enter your desired timezone (e.g., Europe/London):")
    print(new_timezone)

def keymap(stdscr):
    """Allows the user to select a keyboard layout."""
    setup_colors()
    common_layouts = ["us", "de", "fr", "es", "More..."]
    keymap_choice = display_menu(stdscr, "Select a common keyboard layout:", common_layouts)

    if keymap_choice == "More...":
        all_layouts_cmd = r"find /usr/share/kbd/keymaps/ -name '*.map.gz' -printf '%f\n' | sed 's/\.map\.gz$//' | sort"
        all_layouts = subprocess.check_output(all_layouts_cmd, shell=True).decode('utf-8').strip().split('\n')
        keymap_choice = display_menu(stdscr, "Select your keyboard layout:", all_layouts)

    print(keymap_choice)

def confirm_installation(stdscr):
    """Asks the user to confirm the installation."""
    setup_colors()
    answer = display_menu(stdscr, "Are you ready to begin the installation?\nAll data on the selected disk will be erased.", ["Yes", "No"])
    if answer == "Yes":
        print("yes")
    else:
        print("no")

def main(stdscr):
    """Main function to dispatch to the correct TUI screen."""
    if len(sys.argv) > 1:
        screen = sys.argv[1]
        if screen == 'userinfo':
            userinfo(stdscr)
        elif screen == 'diskpart':
            diskpart(stdscr)
        elif screen == 'filesystem':
            filesystem(stdscr)
        elif screen == 'timezone':
            timezone(stdscr)
        elif screen == 'keymap':
            keymap(stdscr)
        elif screen == 'confirm':
            confirm_installation(stdscr)

if __name__ == '__main__':
    try:
        curses.wrapper(main)
    except KeyboardInterrupt:
        print("Installation canceled by user.")
        sys.exit(1)
    except Exception:
        # If curses fails for any reason, exit gracefully.
        sys.exit(1)

EOF

    chmod +x tui.py
}

# ==============================================================================
#                          Interactive Prompts (using Python Curses TUI)
# ==============================================================================
userinfo () {
    echo -e "${BGreen}Checking for python...${Color_Off}"
    pacman -S --noconfirm --needed python
    
    create_tui_script

    USER_DATA=$(./tui.py userinfo)
    if [ $? -ne 0 ]; then
        echo -e "${BRed}User canceled or an error occurred. Exiting.${Color_Off}"
        exit 1
    fi

    USERNAME=$(echo "$USER_DATA" | sed -n 1p)
    PASSWORD=$(echo "$USER_DATA" | sed -n 2p)
    NAME_OF_MACHINE=$(echo "$USER_DATA" | sed -n 3p)

    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$NAME_OF_MACHINE" ]; then
        echo -e "${BRed}User canceled or provided empty input. Exiting.${Color_Off}"
        exit 1
    fi
    export USERNAME PASSWORD NAME_OF_MACHINE
}

diskpart () {
    DISK_DATA=$(./tui.py diskpart)
    if [ $? -ne 0 ]; then
        echo -e "${BRed}User canceled or an error occurred. Exiting.${Color_Off}"
        exit 1
    fi
    DISK=$(echo "$DISK_DATA" | sed -n 1p)
    MOUNT_OPTIONS=$(echo "$DISK_DATA" | sed -n 2p)

    if [ -z "$DISK" ]; then
        echo -e "${BRed}No disk selected. Exiting.${Color_Off}"
        exit 1
    fi
    export DISK MOUNT_OPTIONS
}

filesystem () {
    FS_DATA=$(./tui.py filesystem)
     if [ $? -ne 0 ]; then
        echo -e "${BRed}User canceled or an error occurred. Exiting.${Color_Off}"
        exit 1
    fi
    FS=$(echo "$FS_DATA" | sed -n 1p)
    LUKS_PASSWORD=$(echo "$FS_DATA" | sed -n 2p)

    if [ -z "$FS" ]; then
        echo -e "${BRed}No filesystem selected. Exiting.${Color_Off}"
        exit 1
    fi
    export FS LUKS_PASSWORD
}

timezone () {
    TIMEZONE=$(./tui.py timezone)
    if [ $? -ne 0 ] || [ -z "$TIMEZONE" ]; then
        echo -e "${BRed}User canceled or an error occurred. Exiting.${Color_Off}"
        exit 1
    fi
    export TIMEZONE
}

keymap () {
    KEYMAP=$(./tui.py keymap)
    if [ $? -ne 0 ] || [ -z "$KEYMAP" ]; then
        echo -e "${BRed}User canceled or an error occurred. Exiting.${Color_Off}"
        exit 1
    fi
    echo -e "${BGreen}Keyboard layout set to: ${KEYMAP}${Color_Off}"
    export KEYMAP
}

# ==============================================================================
#                             Main Installation Workflow
# ==============================================================================

background_checks
logo
userinfo
diskpart
filesystem
timezone
keymap
clear

if [ "$(./tui.py confirm)" == "yes" ]; then
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
iso=$(curl -4 ifconfig.co/country_code)
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

echo -e "${BGreen}Detecting GPU for driver installation...${Color_Off}"
gpu_type=$(lspci | grep -E "VGA|3D")
export gpu_type

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

arch-chroot /mnt /bin/bash -c "gpu_type='${gpu_type}' KEYMAP='${KEYMAP}' TIMEZONE='${TIMEZONE}' USERNAME='${USERNAME}' PASSWORD='${PASSWORD}' NAME_OF_MACHINE='${NAME_OF_MACHINE}' FS='${FS}' ENCRYPTED_PARTITION_UUID='${ENCRYPTED_PARTITION_UUID}' DISK='${DISK}' /bin/bash" <<'EOF'

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
export nc
echo -ne "
${BGreen}-------------------------------------------------------------------------
                    You have ${nc} cores. And
              changing the makeflags for ${nc} cores. Aswell as
                   changing the compression settings.
-------------------------------------------------------------------------${Color_Off}
"
TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[ $TOTAL_MEM -gt 8000000 ]]; then
    sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j${nc}\"/g" /etc/makepkg.conf
    sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T ${nc} -z -)/g" /etc/makepkg.conf
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
if echo "${gpu_type}" | grep -qiE "NVIDIA|GeForce"; then
    echo -e "${BGreen}Installing NVIDIA drivers: nvidia-lts...${Color_Off}"
    pacman -S --noconfirm --needed nvidia-lts
elif echo "${gpu_type}" | grep -qiE "Radeon|AMD"; then
    echo -e "${BGreen}Installing AMD drivers: xf86-video-amdgpu...${Color_Off}"
    pacman -S --noconfirm --needed xf86-video-amdgpu
elif echo "${gpu_type}" | grep -qiE "Integrated Graphics Controller|Intel"; then
    echo -e "${BGreen}Installing Intel drivers...${Color_Off}"
    pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
else
    echo -e "${BYellow}Unable to determine GPU vendor (${gpu_type}). Skipping graphics driver installation.${Color_Off}"
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
    sed -i 's/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
fi
mkinitcpio -p linux-lts

echo -ne "
${BGreen}Final Setup and Configurations
GRUB EFI Bootloader Install & Check${Color_Off}"

if [[ -d "/sys/firmware/efi" ]]; then
    echo -e "${BCyan}Installing GRUB for EFI...${Color_Off}"
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
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
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

EOF

rm -f tui.py

echo -e "${BIGreen}Installation is complete! You can now reboot your system.${Color_Off}"
echo -e "${BIYellow}After rebooting, log in as '$USERNAME' to continue with the fast-hyprland setup by running ./fast-hyprland.sh${Color_Off}"