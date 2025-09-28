#!/bin/bash

# ==============================================================================
# Arch Linux Post-Install Setup Script
#
# It should be run after a base Arch Linux installation.
# Environments or Window Managers.
#
# Original Author: CtorW - Github
# ==============================================================================

set -euo pipefail

if tput setaf 1 >/dev/null 2>&1; then
    Color_Off="$(tput sgr0)"
    Red="$(tput setaf 1)"
    Green="$(tput setaf 2)"
    Yellow="$(tput setaf 3)"
    Blue="$(tput setaf 4)"
    Purple="$(tput setaf 5)"
    Cyan="$(tput setaf 6)"
    White="$(tput setaf 7)"
    BRed="$(tput bold; tput setaf 1)"
    BGreen="$(tput bold; tput setaf 2)"
    BYellow="$(tput bold; tput setaf 3)"
    BBlue="$(tput bold; tput setaf 4)"
    BPurple="$(tput bold; tput setaf 5)"
    BCyan="$(tput bold; tput setaf 6)"
    BWhite="$(tput bold; tput setaf 7)"
    BIBlue="$(tput bold; tput setaf 12)"
    BICyan="$(tput bold; tput setaf 14)"
else
    Color_Off="\033[0m"
    Red="\033[0;31m"
    Green="\033[0;32m"
    Yellow="\033[0;33m"
    Blue="\033[0;34m"
    Purple="\033[0;35m"
    Cyan="\033[0;36m"
    White="\033[0;37m"
    BRed="\033[1;31m"
    BGreen="\033[1;32m"
    BYellow="\033[1;33m"
    BBlue="\033[1;34m"
    BPurple="\033[1;35m"
    BCyan="\033[1;36m"
    BWhite="\033[1;37m"
    BIBlue="\033[1;94m"
    BICyan="\033[1;96m"
fi

_msg() {
    local color="$1"
    local prefix="$2"
    local message="$3"
    echo -e "${color}${prefix}${Color_Off} ${White}${message}${Color_Off}"
}

info() {
    _msg "${BBlue}" "[INFO]" "$*"
}

success() {
    _msg "${BGreen}" "[SUCCESS]" "$*"
}

warn() {
    _msg "${BYellow}" "[WARN]" "$*"
}

error() {
    _msg "${BRed}" "[ERROR]" "$*" >&2
    exit 1
}

# ==============================================================================
# Logo :> Thanks to HyDE for the Arch logo :>
# ==============================================================================
logo() {
    echo -e "${BICyan}
        .
       / \         _       _               _           _ 
      /^  \      _| |_    | |_ _ _ ___ ___| |___ ___ _| |
     /  _  \    |_   _|   |   | | | . |  _| | .'|   | . |
    /  | | ~\     |_|     |_|_|_  |  _|_| |_|__,|_|_|___|
   /.-'   '-.\                |___|_|                    
    ${Color_Off}"
}

check_dependencies() {
    info "Checking for required dependencies..."
    if ! command -v pacman &>/dev/null; then
        error "'pacman' not found. This script is intended for Arch-based distributions."
    fi
    
    local missing_deps=()
    local dependencies=("git" "curl" "whiptail")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        warn "Missing dependencies: ${missing_deps[*]}. Attempting to install."
        sudo pacman -S --noconfirm "${missing_deps[@]}"
        success "Dependencies installed."
    fi
}

install_display_server_basics() {
    info "Installing essential display server components (Xorg, Mesa)..."
    sudo pacman -S --noconfirm --needed xorg-server xorg-xinit mesa libglvnd
    success "Display server basics installed."
}

install_packages() {
    info "Installing packages: $*"
    sudo pacman -S --noconfirm --needed "$@"
    success "Package installation complete for: $*"
}

enable_service() {
    info "Enabling systemd service: $1"
    sudo systemctl enable "$1"
    success "Service $1 enabled."
}

backup_config() {
    local config_dir="$1"
    if [ -d "$config_dir" ]; then
        info "Existing configuration found at $config_dir. Backing it up to ${config_dir}.bak..."
        mv "$config_dir" "${config_dir}.bak"
    fi
}

install_from_repo() {
    local name="$1"
    local repo_url="$2"
    local clone_dir="$3"
    local install_cmd="$4"

    info "Starting installation for $name..."

    if [ -d "$clone_dir" ]; then
        warn "Directory '$clone_dir' already exists. Skipping clone."
    else
        info "Cloning $repo_url into $clone_dir..."
        git clone --depth 1 "$repo_url" "$clone_dir"
    fi

    cd "$clone_dir" || error "Failed to enter directory '$clone_dir'. Installation aborted."

    info "Running install command: '$install_cmd'..."
    bash -c "$install_cmd"

    success "$name installation complete. You may need to reboot or log out."
    read -p "Press Enter to continue..."
}

install_caelestia() {
    info "Starting Caelestia-dots installation..."

    info "Installing Caelestia-specific dependencies..."
    sudo pacman -S --noconfirm fish pipewire wireplumber pipewire-pulse

    local clone_dir="$HOME/.local/share/caelestia"
    local repo_url="https://github.com/caelestia-dots/caelestia.git"
    
    if [ -d "$clone_dir" ]; then
        warn "Directory '$clone_dir' already exists. Skipping clone."
    else
        info "Cloning $repo_url into $clone_dir..."
        git clone "$repo_url" "$clone_dir"
    fi

    echo -e "${BWhite}=========================================="
    echo " Caelestia Installation Options "
    echo "==========================================${Color_Off}"
    echo -e "${White}The install.fish script can be run with the following options:${Color_Off}"
    echo -e "  ${Cyan}./install.fish [-h] [--noconfirm] [--spotify] [--vscode] [--discord] [--paru]${Color_Off}"
    echo
    echo -e "${White}Example: to install without confirmation and with Spotify support, enter:${Color_Off}"
    echo -e "  ${Cyan}--noconfirm --spotify${Color_Off}"

    read -p "Enter arguments for install.fish script (or press Enter for default): " install_args

    info "Running install.fish with arguments: '$install_args'"
    fish "$clone_dir/install.fish" $install_args

    success "Caelestia-dots installation complete. You may need to reboot or log out."
    read -p "Press Enter to continue..."
}

show_hyprland_menu() {
    local options=()
    local item_list=(
        "Hyprland (Official)"
        "HyDE"
        "end-4's dots-hyprland"
        "Lunaris-Project-Hyprluna"
        "Caelestia-dots"
        "KooL's Arch - Hyprland"
        "vantesh/dotfiles"
        "Back"
    )

    for item in "${item_list[@]}"; do
        options+=("$item" "")
    done

    whiptail --title "Hyprland Dotfiles Installer" \
             --menu "Please select a Hyprland configuration to install:" 20 60 12 \
             "${options[@]}" 3>&1 1>&2 2>&3
}

install_hyprland() {
    while true; do
        choice=$(show_hyprland_menu) || { return; }

        case "$choice" in
            "Hyprland (Official)")
                info "Installing official Hyprland packages..."
                install_packages hyprland waybar wofi foot thunar xdg-desktop-portal-hyprland
                success "Official Hyprland installed. You will need to create your own configuration."
                read -p "Press Enter to continue..."
                ;;
            "HyDE")
                install_from_repo "HyDE" \
                    "https://github.com/HyDE-Project/HyDE" \
                    "$HOME/HyDE" \
                    "./install.sh"
                ;;
            "end-4's dots-hyprland")
                install_from_repo "end-4's dots-hyprland" \
                    "https://github.com/end-4/dots-hyprland" \
                    "$HOME/dots-hyprland" \
                    "./install.sh"
                ;;
            "Lunaris-Project-Hyprluna")
                install_from_repo "Lunaris-Project-Hyprluna" \
                    "https://github.com/Lunaris-Project/HyprLuna.git" \
                    "$HOME/HyprLuna" \
                    "chmod +x installer.sh && ./installer.sh -m"
                ;;
            "Caelestia-dots")
                install_caelestia
                ;;
            "KooL's Arch - Hyprland")
                install_from_repo "KooL's Arch - Hyprland" \
                    "https://github.com/JaKooLit/Arch-Hyprland.git" \
                    "$HOME/Arch-Hyprland" \
                    "chmod +x install.sh && ./install.sh"
                ;;
            "vantesh/dotfiles")
                install_from_repo "Installing vantesh/dotfiles HyprNiri" \
                "https://github.com/Vantesh/dotfiles.git" \
                "$HOME/dotfiles" \
                "chmod +x install.sh && ./install.sh"
                ;;
            "Back")
                return
                ;;
        esac
    done
}

install_gnome() {
    info "Installing GNOME Desktop Environment..."
    install_packages gnome gdm gnome-tweaks
    enable_service "gdm.service"
    success "GNOME installation complete. Please reboot."
    read -p "Press Enter to continue..."
}

install_kde() {
    info "Installing KDE Plasma Desktop Environment..."
    install_packages plasma-meta kde-applications sddm
    enable_service "sddm.service"
    success "KDE Plasma installation complete. Please reboot."
    read -p "Press Enter to continue..."
}

install_xfce() {
    info "Installing XFCE Desktop Environment..."
    install_packages xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
    enable_service "lightdm.service"
    success "XFCE installation complete. Please reboot."
    read -p "Press Enter to continue..."
}

install_cinnamon() {
    info "Installing Cinnamon Desktop Environment..."
    install_packages cinnamon lightdm lightdm-gtk-greeter
    enable_service "lightdm.service"
    success "Cinnamon installation complete. Please reboot."
    read -p "Press Enter to continue..."
}

install_mate() {
    info "Installing MATE Desktop Environment..."
    install_packages mate mate-extra lightdm lightdm-gtk-greeter
    enable_service "lightdm.service"
    success "MATE installation complete. Please reboot."
    read -p "Press Enter to continue..."
}

install_lxqt() {
    info "Installing LXQt Desktop Environment..."
    install_packages lxqt breeze-icons sddm
    enable_service "sddm.service"
    success "LXQt installation complete. Please reboot."
    read -p "Press Enter to continue..."
}

install_i3() {
    info "Installing i3 Window Manager..."
    install_packages i3-wm i3status dmenu picom alacritty firefox thunar
    
    backup_config "$HOME/.config/i3"
    info "Cloning basic i3 config from github.com/karlstav/i3-config..."
    git clone --depth 1 "https://github.com/karlstav/i3-config.git" "$HOME/.config/i3"
    
    success "i3 installation complete. Type 'startx' after logging into the TTY."
    read -p "Press Enter to continue..."
}

install_sway() {
    info "Installing Sway (Wayland) Window Manager..."
    install_packages sway swaybg swaylock waybar wofi foot firefox thunar polkit
    backup_config "$HOME/.config/sway"
    info "Cloning basic sway config..."
    git clone --depth 1 "https://github.com/Alexays/dotfiles-i3" "$HOME/.config/sway-temp"
    mkdir -p "$HOME/.config/sway"
    mv "$HOME/.config/sway-temp/sway/config" "$HOME/.config/sway/config"
    rm -rf "$HOME/.config/sway-temp"

    success "Sway installation complete. Type 'sway' after logging into the TTY."
    read -p "Press Enter to continue..."
}

install_awesomewm() {
    info "Installing AwesomeWM Window Manager..."
    install_packages awesome picom rofi alacritty firefox thunar
    backup_config "$HOME/.config/awesome"
    info "Copying default awesome config..."
    mkdir -p "$HOME/.config/awesome"
    cp "/etc/xdg/awesome/rc.lua" "$HOME/.config/awesome/rc.lua"
    
    success "AwesomeWM installation complete. You will need a display manager or startx."
    read -p "Press Enter to continue..."
}

show_de_menu() {
    local options=()
    local item_list=("GNOME" "KDE Plasma" "XFCE" "Cinnamon" "MATE" "LXQt" "Back")

    for item in "${item_list[@]}"; do
        options+=("$item" "")
    done

    whiptail --title "Desktop Environment Installer" \
             --menu "Please select a Desktop Environment to install:" 20 60 12 \
             "${options[@]}" 3>&1 1>&2 2>&3
}

show_wm_menu() {
    local options=()
    local item_list=("Hyprland" "i3" "Sway" "AwesomeWM" "Back")

    for item in "${item_list[@]}"; do
        options+=("$item" "")
    done

    whiptail --title "Window Manager Installer" \
             --menu "Please select a Window Manager to install:" 20 60 12 \
             "${options[@]}" 3>&1 1>&2 2>&3
}

show_main_menu() {
    local options=()
    local item_list=("Desktop Environment" "Window Manager" "Exit")

    for item in "${item_list[@]}"; do
        options+=("$item" "")
    done

    whiptail --title "Arch Post-Install Setup" \
             --menu "What would you like to install?" 20 60 12 \
             "${options[@]}" 3>&1 1>&2 2>&3
}

main() {
    check_dependencies
    
    install_display_server_basics
    while true; do
        clear
        logo
        echo -e "${BWhite}=================================================="
        echo "      Arch Linux Post-Install Setup Script"
        echo -e "==================================================${Color_Off}"
        
        main_choice=$(show_main_menu) || { info "Exiting script. Goodbye! :>"; exit 0; }

        case "$main_choice" in
            "Desktop Environment")
                de_choice=$(show_de_menu) || continue
                case "$de_choice" in
                    "GNOME") install_gnome ;;
                    "KDE Plasma") install_kde ;;
                    "XFCE") install_xfce ;;
                    "Cinnamon") install_cinnamon ;;
                    "MATE") install_mate ;;
                    "LXQt") install_lxqt ;;
                    "Back") continue ;;
                esac
                ;;
            "Window Manager")
                wm_choice=$(show_wm_menu) || continue
                case "$wm_choice" in
                    "Hyprland") install_hyprland ;;
                    "i3") install_i3 ;;
                    "Sway") install_sway ;;
                    "AwesomeWM") install_awesomewm ;;
                    "Back") continue ;;
                esac
                ;;
            "Exit")
                info "Exiting script. Goodbye! :>"
                exit 0
                ;;
        esac
    done
}

main "$@"

