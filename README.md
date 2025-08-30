
***

<div align="CENTER">

# 🚀 ARCHFAST - The Fast Arch Linux Installer 🚀

Inspired by the efficiency of Titus's scripts, `archfast` is a streamlined installer designed to get you up and running with a clean Arch Linux environment as quickly as possible.

</div>

---

## ⚠️ Disclaimer

**Warning:** This script will partition and format your drives. Please back up any important data before proceeding. I'm not responsible for any data loss.

---

##📋 Prerequisites

Before you begin, ensure you have the following:

*   A bootable Arch Linux USB drive. You can download the latest ISO from the [official Arch Linux website](https://archlinux.org/download/).
*   A stable internet connection.
*   You have booted into the Arch Linux live environment.

---

## 🛠️ Installation

The installation process is broken down into two main parts: preparing the live environment and running the installer script.

### **Step 1: Prepare the Live Environment**

First, you need to set up the live environment to download and run the installer.

1.  **Connect to the Internet**

    *   **For Wi-Fi:** Use `iwctl` to connect to your network.
        ```bash
        iwctl
        station wlan0 connect <YOUR_WIFI_SSID>
        # Enter your Wi-Fi password when prompted.
        exit
        ```
    *   **For Ethernet:** Your connection should be automatically established.

    You can verify your connection with:
    ```bash
    ping archlinux.org
    ```

2.  **Initialize Pacman Keys**

    This step ensures that all packages downloaded are from trusted sources.
    ```bash
    pacman-key --init
    pacman-key --populate archlinux
    ```

3.  **Install Git**

    Git is required to download the `archfast` installer from its repository.
    ```bash
    pacman -Syy git --noconfirm
    ```

### **Step 2: Run the Archfast Installer**

Now you are ready to download and run the main installer.

```bash
git clone https://github.com/CtorW/archfast.git
cd archfast
./archfast.sh
```

Follow the on-screen prompts to complete the base installation of Arch Linux.

---

## 🎉 Post-Installation

Congratulations! The base system is installed. A couple more steps and you'll have a full desktop environment.

1.  **Reboot Your System**

    First, eject the installation media (USB drive).
    ```bash
    reboot
    ```

2.  **Log In**

    Log in to your new system with the username and password you created during the installation.

3.  **Install Your Desktop Environment**

    The `fast-de.sh` script will install your chosen Desktop Environment and essential applications like `fish`, `curl`, and `wget`.

    From your home directory (`/home/$USERNAME/archfast`), run the script:
    ```bash
    ./fast-de.sh
    ```
| Desktop Environments | Window Manager |
|---|---|
| GNOME, KDE Plasma, XFCE, Cinnamon, MATE, LXQt | i3, Sway, AwesomeWM, Hyprland |

---

## 🎨 Customization

### **Applying GTK Icon and Interface Themes**

To manually set your GTK theme, icons, and font, you can edit the following configuration files:

*   `~/.config/gtk-3.0/settings.ini`
*   `~/.config/gtk-4.0/settings.ini`

Add the following content to both files, replacing the bracketed values with your desired theme names:

```ini
[Settings]
gtk-theme-name=[your_gtk_theme]
gtk-icon-theme-name=[your_icon_theme]
gtk-font-name=[your_font_name]
gtk-cursor-theme-name=[your_cursor_theme]
gtk-cursor-theme-size=[size_in_pixels]
gtk-application-prefer-dark-theme=1 # 1 for dark theme, 0 for light
```

### **Advanced Theming with `nwg-look`**

For a graphical interface to manage and apply GTK themes, you can use `nwg-look`. It is a powerful tool for customizing the look and feel of your desktop.

You can install it from the AUR using `yay`:
```bash
yay -S nwg-look
```
Alternatively, you can build it from source from its [GitHub repository](https://github.com/nwg-piotr/nwg-look).
