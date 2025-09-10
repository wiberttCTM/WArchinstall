#!/bin/bash

# ========================================
# Script de post-instalación para Arch Linux + Hyprland
# Autor: tú >:)
# ========================================

# 0. Verificar usuario
if [ "$EUID" -eq 0 ]; then
  echo "[X] No ejecutes este script como root. Usa un usuario normal."
  exit 1
fi

echo "========================================"
echo "[>] Iniciando post-instalación de Arch Linux"
echo "========================================"

# --- 1. Actualizar sistema ---
echo "[*] Sincronizando y actualizando sistema..."
sudo pacman -Syu --noconfirm

# --- 2. Instalar yay (AUR helper) ---
echo "----------------------------------------"
echo "[*] Instalando yay (si no está presente)..."
if ! command -v yay &>/dev/null; then
    sudo pacman -S --needed --noconfirm git base-devel
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    pushd "$tmpdir/yay" || exit 1
    makepkg -si --noconfirm
    popd
    rm -rf "$tmpdir"
    echo "[OK] Yay instalado correctamente."
else
    echo "[OK] Yay ya estaba instalado. Omitiendo."
fi

# --- 3. Instalación de paquetes principales ---
echo "----------------------------------------"
echo "[*] Instalando paquetes principales..."
sudo pacman -S --needed \
  neovim hyprland sddm wl-clipboard dunst swww nwg-look kitty fastfetch waybar rofi-wayland firefox \
  network-manager-applet pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol \
  blueman bluez bluez-utils \
  yazi tlp udisks2 udiskie unzip unrar zip reflector

echo "[OK] Paquetes instalados."

# --- 4. Habilitar servicios (solo al reiniciar) ---
echo "----------------------------------------"
echo "[*] Habilitando servicios esenciales..."

echo " - SDDM (gestor de pantalla)"
sudo systemctl enable sddm.service

echo " - Bluetooth"
sudo systemctl enable bluetooth.service

echo " - TLP (gestión de energía)"
sudo systemctl enable tlp.service

echo " - PipeWire + WirePlumber (usuario)"
systemctl --user enable pipewire.service
systemctl --user enable pipewire-pulse.service
systemctl --user enable wireplumber.service

echo "[OK] Todos los servicios fueron habilitados (se activarán tras reinicio)."

# --- 5. Configurar Oh My Zsh ---
echo "----------------------------------------"
echo "[*] Configuración de Zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    read -p "[?] ¿Quieres instalar Oh My Zsh en este usuario? (Y/n): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
          sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        echo "[OK] Oh My Zsh instalado. (No se cambió shell automáticamente)."
        echo "[!] Ejecuta 'chsh -s /bin/zsh' si quieres usar Zsh como predeterminado."
    else
        echo "[!] Oh My Zsh omitido por el usuario."
    fi
else
    echo "[OK] Oh My Zsh ya estaba instalado."
fi

# --- 6. Final ---
echo "========================================"
echo "[>] Post-instalación finalizada >:)"
echo "[!] Reinicia tu sistema para activar entorno gráfico y servicios."
echo "========================================"
