<div align="CENTER">
  
# ARCH FAST - Archlinux fastest installer [Titus] 

</div>

### Getting Started: Arch Linux Live Environment Setup

Before running the installer, you need to prepare your Arch Linux live environment.

### 1. Internet Connection (Wi-Fi Example)

If you're using Wi-Fi, connect to your network using `iwctl`:

```bash
iwctl
station wlan0 connect <YOUR_WIFI_SSID>
# Enter your Wi-Fi password when prompted.
exit
```
### 2. Initialize Pacman Keys

Ensure your package manager is ready for secure package downloads:
```bash
pacman-key --init
pacman-key --populate archlinux
```
### 3. Install Git

Git is required to clone the installer repository:
```bash
pacman -Syy git --noconfirm
```
### 💻 How to Install archfast

Once your live environment is set up and you have an internet connection:
```bash
git clone https://github.com/CtorW/archfast.git
cd archfast
./archfast.sh
```
### ✅ After Installation

### 💾 Eject USB/Installation Media

### 🔁 Reboot your system

🧏 Log in to your Machine $USERNAME|$PASSWORD

### ⌨️ Now Run the fast-hyprland.sh
```bash
./fast-hyprland.sh
```
Functions: Will install missing dependencies. (eg. fish, curl, wget) 

# Choose your Dots in `fast-hyprland.sh`
<div align="center">
  <table>
    <tr>
      <td>HyDE</td>
      <td>end-4</td>
    </tr>
    <tr>
      <td>
<img src="https://github.com/rishav12s/Vanta-Black/raw/Vanta-Black/screenshots/ss_2.png"/>
      </td>
      <td>
<img src="https://end-4.github.io/dots-hyprland-wiki/screenshots/i-i.2.png"/>
      </td>
    </tr>
  </table>
</div>

<div align="center">
  <table>
    <tr>
      <td>Hyprluna</td>
      <td>Caelestia</td>
    </tr>
    <tr>
      <td>
<img src="https://github.com/Lunaris-Project/HyprLuna/blob/main/previews/6.png?raw=true"/>
      </td>
      <td>
        
<video src="https://github.com/user-attachments/assets/0840f496-575c-4ca6-83a8-87bb01a85c5f" style="max"></video>
      </td>
    </tr>
  </table>
</div>

### For qt icon theme 
```bash
~/.config/gtk-3.0/settings.ini
~/.config/gtk-4.0/settings.ini
```

```bash
[Settings]
gtk-icon-theme-name=Papirus-Dark
```
### Caelestia theme config
```bash
yay nwg-look
or
https://github.com/nwg-piotr/nwg-look
```







