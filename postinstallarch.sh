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

# --- 1. Configurar pacman.conf ---
echo "----------------------------------------"
echo "[*] Configurando /etc/pacman.conf..."

# Color
if grep -q "^#Color" /etc/pacman.conf; then
  sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
  echo "[OK] Color activado en pacman.conf."
else
  echo "[!] Color ya estaba activado."
fi

# ParallelDownloads (cambiar a 10 si ya está activo o añadirlo si no está)
if grep -q "^ParallelDownloads" /etc/pacman.conf; then
  sudo sed -i 's/^ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
  echo "[OK] ParallelDownloads cambiado a 10 en pacman.conf."
else
  echo "ParallelDownloads = 10" | sudo tee -a /etc/pacman.conf >/dev/null
  echo "[OK] ParallelDownloads añadido a pacman.conf."
fi

# Descomentar [multilib] si está comentado
echo "----------------------------------------"
echo "[*] Verificando [multilib] en pacman.conf..."
multilib_changed=0
if grep -q "^#\[multilib\]" /etc/pacman.conf; then
  sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
  multilib_changed=1
  echo "[OK] multilib descomentado en pacman.conf."
else
  echo "[!] multilib ya estaba habilitado o no se encontró."
fi

echo "[OK] pacman.conf configurado."

# --- 2. Actualizar sistema (solo si se cambió multilib) ---
if [ "$multilib_changed" -eq 1 ]; then
  echo "----------------------------------------"
  echo "[*] Sincronizando y actualizando sistema (por cambio en multilib)..."
  sudo pacman -Syu --noconfirm
else
  echo "[!] No es necesario actualizar sistema (multilib ya estaba habilitado)."
fi

# --- 3. Instalar yay (AUR helper) ---
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
    echo "[!] Yay ya estaba instalado. Omitiendo."
fi

# --- 4. Instalación de paquetes principales ---
echo "----------------------------------------"
echo "[*] Instalando paquetes principales..."
main_pkgs=(
  neovim hyprland sddm wl-clipboard dunst swww nwg-look kitty fastfetch waybar rofi-wayland firefox
  network-manager-applet pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol
  blueman bluez bluez-utils
  yazi tlp udisks2 udiskie unzip unrar zip reflector
  xdg-user-dirs
)
sudo pacman -S --needed "${main_pkgs[@]}"

# Actualizar carpetas de usuario
xdg-user-dirs-update

echo "[OK] Paquetes y carpetas de usuario configuradas."

# --- 4.1 Instalar paquetes desde AUR ---
echo "----------------------------------------"
echo "[*] Instalando paquetes desde AUR (zen-browser-bin, visual-studio-code-bin)..."
yay -S --needed zen-browser-bin visual-studio-code-bin
echo "[OK] Paquetes AUR instalados."

# --- 5. Instalar drivers gráficos (mesa / vulkan / AMD) ---
echo "----------------------------------------"
echo "[*] Instalando drivers gráficos AMD (Mesa, Vulkan)..."
gpu_pkgs=(
  mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver libva-utils
)
sudo pacman -S --needed "${gpu_pkgs[@]}"
echo "[OK] Drivers gráficos instalados."

# --- 6. Habilitar servicios (solo al reiniciar) ---
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

# --- 7. Configurar Oh My Zsh ---
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
    echo "[!] Oh My Zsh ya estaba instalado."
fi

# --- 8. Final ---
echo "========================================"
echo "[>] Post-instalación finalizada >:)"
echo "[!] Reinicia tu sistema para activar entorno gráfico y servicios."
echo ""
