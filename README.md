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

### 🧏 Log in to your Machine $USERNAME|$PASSWORD

### ⌨️ Now Run the fast-de.sh
```bash
./fast-de.sh
```
Functions: Will install missing dependencies. (eg. fish, curl, wget) 


### For qt icon theme 
```bash
~/.config/gtk-3.0/settings.ini
~/.config/gtk-4.0/settings.ini
```

```bash
[Settings]
gtk-theme-name=[your gtk theme]
gtk-icon-theme-name=[your icons name]
gtk-font-name=[your font name]
gtk-cursor-theme-name=[your cursor name]
gtk-cursor-theme-size=[what u prefer]
gtk-application-prefer-dark-theme=1nor0
```
### Caelestia theme config
```bash
yay nwg-look
or
https://github.com/nwg-piotr/nwg-look
```







