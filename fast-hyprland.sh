#!/bin/bash

# ==============================================================================
# Hyprland Dotfiles Installer Script
#
# It should be run after a base Arch Linux installation.
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

# ==============================================================================
# Logo :> Thanks to HyDE for the Arch logo :>
# ==============================================================================
msg() {
    echo -e "${BGreen}==>${Color_Off} ${BWhite}$*${Color_Off}"
}

warning() {
    echo -e "${BYellow}==> WARNING:${Color_Off} ${White}$*${Color_Off}"
}

error() {
    echo -e "${BRed}==> ERROR:${Color_Off} ${Red}$*${Color_Off}" >&2
    exit 1
}

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
    msg "Checking for required dependencies..."
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
        warning "Missing dependencies: ${missing_deps[*]}. Attempting to install."
        sudo pacman -S --noconfirm "${missing_deps[@]}"
    fi
}

show_welcome_screen() {
    clear
    logo
    echo -e "${BWhite}=========================================="
    echo "  Hyprland Dotfiles Installation Menu"
    echo -e "==========================================${Color_Off}"
}

show_whiptail_menu() {
    local options=()
    local item_list=(
        "HyDE"
        "end-4's dots-hyprland"
        "Lunaris-Project-Hyprluna"
        "Caelestia-dots"
        "KooL's Arch - Hyprland"
        "Exit"
    )

    for item in "${item_list[@]}"; do
        options+=("$item" "")
    done

    whiptail --title "Hyprland Dotfiles Installer" \
             --menu "Please select a dotfiles configuration to install:" 20 60 12 \
             "${options[@]}" 3>&1 1>&2 2>&3
}

install_from_repo() {
    local name="$1"
    local repo_url="$2"
    local clone_dir="$3"
    local install_cmd="$4"

    msg "Installing $name..."

    if [ -d "$clone_dir" ]; then
        warning "Directory '$clone_dir' already exists. Skipping clone."
    else
        msg "Cloning $repo_url into $clone_dir..."
        git clone --depth 1 "$repo_url" "$clone_dir"
    fi

    cd "$clone_dir" || error "Failed to enter directory '$clone_dir'. Installation aborted."

    msg "Running install command: '$install_cmd'..."
    bash -c "$install_cmd"

    msg "$name installation complete. You may need to reboot or log out."
    read -p "Press Enter to continue..."
}

install_caelestia() {
    msg "Installing Caelestia-dots..."

    msg "Installing Caelestia-specific dependencies..."
    sudo pacman -S --noconfirm fish pipewire wireplumber pipewire-pulse

    local clone_dir="$HOME/.local/share/caelestia"
    local repo_url="https://github.com/caelestia-dots/caelestia.git"
    
    if [ -d "$clone_dir" ]; then
        warning "Directory '$clone_dir' already exists. Skipping clone."
    else
        msg "Cloning $repo_url into $clone_dir..."
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

    msg "Running install.fish with arguments: '$install_args'"
    fish "$clone_dir/install.fish" $install_args

    msg "Caelestia-dots installation complete. You may need to reboot or log out."
    read -p "Press Enter to continue..."
}

main() {
    check_dependencies

    while true; do
        show_welcome_screen
        choice=$(show_whiptail_menu) || { msg "Exiting script. Goodbye! :>"; exit 0; }

        case "$choice" in
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
            "Exit")
                msg "Exiting script. Goodbye! :>"
                exit 0
                ;;
        esac
    done
}

main "$@"

