#!/bin/bash

# ==============================================================================
# Hyprland Dotfiles Installer Script
#
# You should run this script after the archfast installation 
# Reboot the Arch ISO installation
# log in as $USERNAME$ then run ./fast-hyprland.sh
#
# Author: CtorW - Github - Thanks!
# ==============================================================================
# tput for the compatible in arrow keys function :> 
if tput setaf 1 >/dev/null 2>&1; then

    Color_Off="$(tput sgr0)"
    Black="$(tput setaf 0)"
    Red="$(tput setaf 1)"
    Green="$(tput setaf 2)"
    Yellow="$(tput setaf 3)"
    Blue="$(tput setaf 4)"
    Purple="$(tput setaf 5)"
    Cyan="$(tput setaf 6)"
    White="$(tput setaf 7)"


    BBlack="$(tput bold; tput setaf 0)"
    BRed="$(tput bold; tput setaf 1)"
    BGreen="$(tput bold; tput setaf 2)"
    BYellow="$(tput bold; tput setaf 3)"
    BBlue="$(tput bold; tput setaf 4)"
    BPurple="$(tput bold; tput setaf 5)"
    BCyan="$(tput bold; tput setaf 6)"
    BWhite="$(tput bold; tput setaf 7)"
    
    BIBlack="$(tput bold; tput setaf 8)"
    BIRed="$(tput bold; tput setaf 9)"
    BIGreen="$(tput bold; tput setaf 10)"
    BIYellow="$(tput bold; tput setaf 11)"
    BIBlue="$(tput bold; tput setaf 12)"
    BIPurple="$(tput bold; tput setaf 13)"
    BICyan="$(tput bold; tput setaf 14)"
    BIWhite="$(tput bold; tput setaf 15)"
else
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
  
# ==============================================================================
# Arrow-key selection function :> 
# ==============================================================================
select_option() {
    local options=("$@")
    local num_options=${#options[@]}
    local selected=0
    
    echo -e "${BIWhite}Please select an option using the arrow keys and Enter:${Color_Off}"

    for i in "${!options[@]}"; do
        if [ "$i" -eq $selected ]; then
            echo -e "${BICyan}> ${options[$i]}${Color_Off}"
        else
            echo -e "${BYellow}  ${options[$i]}${Color_Off}"
        fi
    done

    while true; do
        tput cuu "${num_options}"
        
        for i in "${!options[@]}"; do
            tput el
            if [ "$i" -eq $selected ]; then
                echo -e "${BICyan}> ${options[$i]}${Color_Off}"
            else
                echo -e "${BYellow}  ${options[$i]}${Color_Off}"
            fi
        done

        read -rsn1 key
        case "$key" in
            $'\x1b') 
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

    return $selected
}

check_dependencies() {
    if ! command -v pacman &> /dev/null; then
        echo -e "${BIRed}Error: 'pacman' is not found. This script is designed for Arch Linux.${Color_Off}"
        exit 1
    fi
    
    local dependencies=("git" "curl" "fish")
    local install_list=()
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            install_list+=("$dep")
        fi
    done
    
    if [ ${#install_list[@]} -gt 0 ]; then
        echo -e "${BYellow}The following dependencies are missing: ${install_list[*]}${Color_Off}"
        echo -e "${BYellow}Attempting to install them with pacman...${Color_Off}"
        
        sudo pacman -S --noconfirm "${install_list[@]}"
        if [ $? -ne 0 ]; then
            echo -e "${BIRed}Error: Failed to install one or more dependencies. Please install them manually.${Color_Off}"
            exit 1
        fi
        
        echo -e "${BIGreen}Dependencies successfully installed!${Color_Off}"
    fi
}

show_menu() {
    clear
    logo
    echo -e "${BWhite}=========================================="
    echo "  Hyprland Dotfiles Installation Menu"
    echo "==========================================${Color_Off}"
}

main() {
    check_dependencies

    while true; do
        show_menu
        
        options=(
            "HyDE"
            "end-4's dots-hyprland"
            "Lunaris-Project-Hyprluna"
            "Caelestia-dots"
            "Exit"
        )
        
        select_option "${options[@]}"
        choice_index=$?
        
        case $choice_index in
            0)
                echo -e "${BIGreen}Installing HyDE...${Color_Off}"
                git clone --depth 1 https://github.com/HyDE-Project/HyDE ~/HyDE
                cd ~/HyDE/Scripts || { echo -e "${BIRed}Error: Failed to enter ~/HyDE/Scripts directory.${Color_Off}"; exit 1; }
                ./install.sh
                echo -e "${BIGreen}HyDE installation complete. You may need to reboot or log out.${Color_Off}"
                break
                ;;
            1)
                echo -e "${BIGreen}Installing end-4's dots-hyprland...${Color_Off}"
                git clone https://github.com/end-4/dots-hyprland
                cd dots-hyprland || { echo -e "${BIRed}Error: Failed to enter dots-hyprland directory.${Color_Off}"; exit 1; }
                ./install.sh
                echo -e "${BIGreen}end-4's dots-hyprland installation complete. You may need to reboot or log out.${Color_Off}"
                break
                ;;
            2)
                echo -e "${BIGreen}Installing Lunaris-Project-Hyprluna...${Color_Off}"
                curl -sL hyprluna.org/install | bash
                echo -e "${BIGreen}Lunaris-Project-Hyprluna installation complete. You may need to reboot or log out.${Color_Off}"
                break
                ;;
            3)
                echo -e "${BIGreen}Installing Caelestia-dots...${Color_Off}"
                
                git clone https://github.com/caelestia-dots/caelestia.git ~/.local/share/caelestia
                echo -e "${BYellow}Caelestia-dots repository cloned to ~/.local/share/caelestia${Color_Off}"
                
                echo -e "${BWhite}=========================================="
                echo " Caelestia Installation Options "
                echo "==========================================${Color_Off}"
                echo -e "${BIWhite}The install.fish script can be run with the following options:${Color_Off}"
                echo -e "  ${BCyan}./install.fish [-h] [--noconfirm] [--spotify] [--vscode] [--discord] [--paru]${Color_Off}"
                echo
                echo -e "${BIWhite}For example, to install without confirmation and include Spotify, you can run:${Color_Off}"
                echo -e "  ${BCyan}fish ~/.local/share/caelestia/install.fish --noconfirm --spotify${Color_Off}"
                
                read -p "Enter any arguments you wish to pass to the install.fish script (e.g., --noconfirm --spotify), or press Enter to skip: " install_args
                
                echo -e "${BYellow}Running install.fish with arguments: $install_args${Color_Off}"
                fish ~/.local/share/caelestia/install.fish $install_args
                
                echo -e "${BIGreen}Caelestia-dots installation complete. You may need to reboot or log out.${Color_Off}"
                break
                ;;
            4)
                echo -e "${BWhite}Exiting script. Goodbye :>${Color_Off}"
                exit 0
                ;;
            *)
                echo -e "${BIRed}Invalid selection. Please use the arrow keys and Enter.${Color_Off}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

main "$@"
