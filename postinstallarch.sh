#!/bin/bash

# Este script se ejecuta después de una instalación exitosa de Arch Linux
# para configurar el entorno Hyprland. Requiere intervención mínima del usuario.

# Comprobar si el script se ejecuta como usuario normal
if [ "$EUID" -eq 0 ]; then
  echo "Por favor, ejecuta este script como usuario normal, NO como root."
  exit 1
fi

echo "Sincronizando la base de datos de pacman y actualizando el sistema..."
sudo pacman -Syu

# --- 1. Instalación de Yay (AUR helper) ---
echo "--- Instalación de Yay ---"
if ! command -v yay &>/dev/null; then
    sudo pacman -S --needed git base-devel
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si
    cd ..
    rm -rf yay/
    echo "✅ Yay se instaló correctamente."
else
    echo "✅ Yay ya está instalado. Omitiendo la instalación."
fi

# --- 2. Instalación de paquetes principales de golpe ---
echo "--- Instalando todos los paquetes principales de una sola vez ---"
sudo pacman -S \
neovim hyprland sddm wl-clipboard dunst swww nwg-look kitty fastfetch waybar rofi-wayland firefox \
network-manager-applet pipewire pavucontrol pipewire-pulse \
blueman bluez bluez-utils \
yazi tlp udisks2 udiskie unzip unrar zip reflector

# --- 3. Habilitar y verificar servicios ---
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

# --- 4. Configurar Oh My Zsh ---
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

echo "¡Script de post-instalación finalizado!"
echo "Por favor, reinicia para que el entorno gráfico y los servicios se