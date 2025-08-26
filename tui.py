#!/usr/bin/env python3

import curses
import os
import subprocess

def setup_colors():
    """Initializes color pairs for the TUI."""
    curses.start_color()
    curses.init_pair(1, curses.COLOR_CYAN, curses.COLOR_BLACK)
    curses.init_pair(2, curses.COLOR_YELLOW, curses.COLOR_BLACK)
    curses.init_pair(3, curses.COLOR_GREEN, curses.COLOR_BLACK)
    curses.init_pair(4, curses.COLOR_RED, curses.COLOR_BLACK)
    curses.init_pair(5, curses.COLOR_WHITE, curses.COLOR_BLACK)
    curses.init_pair(6, curses.COLOR_BLACK, curses.COLOR_YELLOW)

def get_input(stdscr, y, x, prompt_string):
    """Displays a prompt and returns the user's input."""
    stdscr.addstr(y, x, prompt_string)
    stdscr.refresh()
    curses.echo()
    input = stdscr.getstr(y + 1, x, 20)
    curses.noecho()
    return input.decode('utf-8')

def get_password(stdscr, y, x, prompt_string):
    """Displays a password prompt and returns the user's input."""
    stdscr.addstr(y, x, prompt_string)
    stdscr.refresh()
    curses.noecho()
    password = b""
    while True:
        ch = stdscr.getch()
        if ch == 10:  # Enter key
            break
        elif ch == 127: # Backspace
            if len(password) > 0:
                password = password[:-1]
                h, w = stdscr.getyx()
                stdscr.move(h, w - 1)
                stdscr.delch()
        else:
            password += bytes([ch])
            stdscr.addch('*')
    return password.decode('utf-8')

def display_menu(stdscr, y, x, title, options, menu_type='menu'):
    """Displays a menu and returns the selected option."""
    selected_idx = 0
    while True:
        stdscr.clear()
        stdscr.addstr(y, x, title, curses.A_BOLD | curses.color_pair(1))
        for i, option in enumerate(options):
            if i == selected_idx:
                stdscr.addstr(y + 2 + i, x + 2, f"> {option}", curses.A_REVERSE)
            else:
                stdscr.addstr(y + 2 + i, x + 2, f"  {option}")
        stdscr.refresh()
        key = stdscr.getch()
        if key == curses.KEY_UP:
            selected_idx = (selected_idx - 1) % len(options)
        elif key == curses.KEY_DOWN:
            selected_idx = (selected_idx + 1) % len(options)
        elif key == curses.KEY_ENTER or key in [10, 13]:
            return options[selected_idx]

def userinfo(stdscr):
    """Gathers username, password, and hostname."""
    setup_colors()
    username = get_input(stdscr, 2, 2, "Enter a username for your new system:")
    while True:
        password = get_password(stdscr, 5, 2, "Enter password:")
        password2 = get_password(stdscr, 8, 2, "Re-enter password:")
        if password == password2:
            break
        else:
            stdscr.addstr(11, 2, "Passwords do not match. Please try again.", curses.color_pair(4))
            stdscr.getch()
            stdscr.clear()
    hostname = get_input(stdscr, 11, 2, "Please name your machine (hostname):")
    print(f"{username}\n{password}\n{hostname}")

def diskpart(stdscr):
    """Allows the user to select a disk."""
    setup_colors()
    disk_list_cmd = "lsblk -o KNAME,SIZE,MODEL -d | grep -E 'sd|hd|vd|nvme|mmcblk'"
    disks_raw = subprocess.check_output(disk_list_cmd, shell=True).decode('utf-8').strip().split('\n')
    disk_options = [f"{d.split()[0]} ({' '.join(d.split()[1:])})" for d in disks_raw]
    selected_disk_str = display_menu(stdscr, 2, 2, "Select the disk to install Arch Linux on:", disk_options)
    selected_disk = selected_disk_str.split()[0]
    is_ssd = display_menu(stdscr, 2, 2, f"Is /dev/{selected_disk} an SSD?", ["yes", "no"])
    mount_options = "noatime,compress=zstd,ssd,commit=120" if is_ssd == "yes" else "noatime,compress=zstd,commit=120"
    print(f"/dev/{selected_disk}\n{mount_options}")

def filesystem(stdscr):
    """Allows the user to select a filesystem."""
    setup_colors()
    fs_options = ["btrfs", "ext4", "luks"]
    fs_choice = display_menu(stdscr, 2, 2, "Please select a filesystem:", fs_options, 'radiolist')
    luks_password = ""
    if fs_choice == "luks":
        while True:
            luks_pass1 = get_password(stdscr, 8, 2, "Enter a strong password for disk encryption:")
            luks_pass2 = get_password(stdscr, 11, 2, "Re-enter the password to confirm:")
            if luks_pass1 == luks_pass2:
                luks_password = luks_pass1
                break
            else:
                stdscr.addstr(14, 2, "Passwords do not match. Please try again.", curses.color_pair(4))
                stdscr.getch()
                stdscr.clear()
    print(f"{fs_choice}\n{luks_password}")

def timezone(stdscr):
    """Allows the user to set the timezone."""
    setup_colors()
    try:
        detected_timezone = subprocess.check_output("curl --fail https://ipapi.co/timezone", shell=True).decode('utf-8').strip()
        confirm = display_menu(stdscr, 2, 2, f"System detected your timezone to be '{detected_timezone}'. Is this correct?", ["yes", "no"])
        if confirm == "yes":
            print(detected_timezone)
            return
    except subprocess.CalledProcessError:
        pass
    new_timezone = get_input(stdscr, 5, 2, "Enter your desired timezone (e.g., Europe/London):")
    print(new_timezone)


def keymap(stdscr):
    """Allows the user to select a keyboard layout."""
    setup_colors()
    common_layouts = ["us", "de", "fr", "es", "More..."]
    keymap_choice = display_menu(stdscr, 2, 2, "Select a common keyboard layout:", common_layouts)

    if keymap_choice == "More...":
        all_layouts_cmd = "find /usr/share/kbd/keymaps/ -name '*.map.gz' -printf '%f\n' | sed 's/\.map\.gz$//' | sort"
        all_layouts = subprocess.check_output(all_layouts_cmd, shell=True).decode('utf-8').strip().split('\n')
        keymap_choice = display_menu(stdscr, 2, 2, "Select your keyboard layout:", all_layouts)

    print(keymap_choice)

def main(stdscr):
    """Main function to dispatch to the correct TUI screen."""
    import sys
    if len(sys.argv) > 1:
        if sys.argv[1] == 'userinfo':
            userinfo(stdscr)
        elif sys.argv[1] == 'diskpart':
            diskpart(stdscr)
        elif sys.argv[1] == 'filesystem':
            filesystem(stdscr)
        elif sys.argv[1] == 'timezone':
            timezone(stdscr)
        elif sys.argv[1] == 'keymap':
            keymap(stdscr)

if __name__ == '__main__':
    curses.wrapper(main)