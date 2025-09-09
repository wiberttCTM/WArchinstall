#!/bin/bash

# Este script se ejecuta después de una instalación exitosa de Arch Linux
# para configurar el entorno Hyprland. Requiere interacción del usuario.

# --- 1. Sincronizar y actualizar el sistema ---
#!/bin/bash

# Comprobar si el script se ejecuta como usuario normal
if [ "$EUID" -eq 0 ]; then
  echo "Por favor, ejecuta este script como usuario normal, NO como root."
  exit 1
fi

echo "Sincronizando la base de datos de pacman y actualizando el sistema..."
sudo pacman -Syu --noconfirm

install_package() {
    package=$1
    if pacman -Qq "$package" &>/dev/null; then
        echo "✅ El paquete $package ya está instalado. Omitiendo la instalación."
    else
        read -p "¿Quieres instalar el paquete '$package'? (s/n): " choice
        if [[ "$choice" =~ ^[Ss]$ ]]; then
            sudo pacman -S --noconfirm "$package"
            if [ $? -eq 0 ]; then
                echo "✅ $package se instaló correctamente."
            else
                echo "❌ Error al instalar $package."
            fi
        fi
    fi
}


# --- 3. Instalación de paquetes de Hyprland y aplicaciones ---
echo "--- Iniciando la instalación de paquetes ---"

# Paquetes principales del entorno de escritorio
install_package "neovim"
install_package "hyprland"
install_package "sddm"
install_package "wl-clipboard"
install_package "dunst"
install_package "swww"
install_package "nwg-look"
install_package "kitty"
install_package "fastfetch"
install_package "waybar"
install_package "rofi-wayland"
install_package "firefox"

# Paquetes de red y audio
install_package "network-manager-applet"
install_package "pipewire"
install_package "pavucontrol"
install_package "pipewire-pulse"

# Paquetes de Bluetooth
install_package "blueman"
install_package "bluez"
install_package "bluez-utils"

# Utilidades
install_package "yazi"
install_package "tlp"
install_package "udisks2"
install_package "udiskie"
install_package "unzip"
install_package "unrar"
install_package "zip"
install_package "reflector"

# --- 4. Instalación de Yay (AUR helper) ---
echo "--- Instalación de Yay ---"
if ! command -v yay &>/dev/null; then
    read -p "¿Quieres instalar Yay (AUR Helper)? (s/n): " choice
    if [[ "$choice" =~ ^[Ss]$ ]]; then
        sudo pacman -S --needed --noconfirm git base-devel
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ..
        rm -rf yay/
        echo "✅ Yay se instaló correctamente."
    fi
else
    echo "✅ Yay ya está instalado. Omitiendo la instalación."
fi

# --- 5. Configurar Oh My Zsh ---
echo "--- Instalación de Oh My Zsh ---"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    read -p "¿Quieres instalar Oh My Zsh para tu shell Zsh? (s/n): " choice
    if [[ "$choice" =~ ^[Ss]$ ]]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        echo "✅ Oh My Zsh se instaló correctamente."
    fi
else
    echo "✅ Oh My Zsh ya está instalado. Omitiendo la instalación."
fi

# --- 6. Habilitar y verificar servicios ---
echo "--- Habilitando servicios esenciales ---"
echo "Activando SDDM (gestor de pantalla)..."
sudo systemctl enable --now sddm.service

echo "Activando Bluetooth..."
sudo systemctl enable --now bluetooth.service

echo "Activando TLP para gestión de energía..."
sudo systemctl enable --now tlp.service

echo "Verificando el estado de PipeWire..."
systemctl --user enable --now pipewire.service
systemctl --user enable --now pipewire-pulse.service
systemctl --user enable --now pipewire-media-session.service
echo "Servicios de PipeWire activados para el usuario."

echo "¡Script de post-instalación finalizado!"
echo "Por favor, reinicia para que el entorno gráfico y los servicios se inicien correctamente."