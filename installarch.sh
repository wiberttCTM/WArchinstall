#!/bin/bash

# Función para leer contraseña mostrando asteriscos
read_password() {
    prompt="$1"
    password=""
    while IFS= read -p "$prompt" -r -s -n 1 char; do
        if [[ $char == $'\0' ]]; then
            break
        fi
        if [[ $char == $'\177' ]]; then
            # Backspace
            if [ -n "$password" ]; then
                password=${password%?}
                echo -ne "\b \b"
            fi
        else
            password+="$char"
            echo -n "*"
        fi
    done
    echo
    REPLY="$password"
}

echo "========================================"
echo "      Script de instalación Arch Linux"
echo "========================================"

# Preguntar datos al usuario con confirmación y verificación de contraseñas
while true; do
    echo "----------------------------------------"
    read -p "Nombre del equipo (hostname): " HOSTNAME
    read -p "Nombre de usuario: " USERNAME

    # Contraseña de usuario con confirmación y asteriscos
    while true; do
        read_password "Contraseña para $USERNAME: "
        USERPASS1="$REPLY"
        read_password "Confirma la contraseña para $USERNAME: "
        USERPASS2="$REPLY"
        [ "$USERPASS1" = "$USERPASS2" ] && USERPASS="$USERPASS1" && break
        echo "❌ Las contraseñas de usuario no coinciden. Intenta de nuevo."
    done

    # Contraseña de root con confirmación y asteriscos
    while true; do
        read_password "Contraseña para root: "
        ROOTPASS1="$REPLY"
        read_password "Confirma la contraseña para root: "
        ROOTPASS2="$REPLY"
        [ "$ROOTPASS1" = "$ROOTPASS2" ] && ROOTPASS="$ROOTPASS1" && break
        echo "❌ Las contraseñas de root no coinciden. Intenta de nuevo."
    done

    echo "----------------------------------------"
    echo "Resumen de configuración:"
    echo "Hostname: $HOSTNAME"
    echo "Usuario: $USERNAME"
    echo "Contraseña de usuario: [oculta]"
    echo "Contraseña de root: [oculta]"
    echo "----------------------------------------"
    read -p "¿Son correctos estos datos? (s/n): " CONFIRM
    [[ "$CONFIRM" =~ ^[Ss]$ ]] && break
    echo "----------------------------------------"
    echo "Por favor, vuelve a ingresar los datos."
done

echo "========================================"
echo "   Iniciando instalación del sistema..."
echo "========================================"

# Variables de disco (puedes preguntar esto también si quieres)
DISK="/dev/nvme0n1"

# 1. Conexión y reloj
echo "----------------------------------------"
echo "Verificando conexión a Internet..."
ping -c 3 archlinux.org || { echo "Sin internet"; exit 1; }
timedatectl set-ntp true

# 2. Limpieza y particionado
echo "----------------------------------------"
echo "Particionando y formateando disco..."
wipefs -a "$DISK"
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 801MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 801MiB 100%

# 3. Formateo
mkfs.fat -F32 "${DISK}p1"
mkfs.ext4 "${DISK}p2"

# 4. Montaje
mount "${DISK}p2" /mnt
mkdir -p /mnt/boot
mount "${DISK}p1" /mnt/boot

# 5. Instalación base
echo "----------------------------------------"
echo "Instalando sistema base..."
pacstrap -K /mnt base linux linux-firmware vim networkmanager grub efibootmgr amd-ucode zsh sudo

# 6. fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 7. Configuración completa en chroot (totalmente automática)
echo "----------------------------------------"
echo "Configurando sistema en chroot..."
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/America/Lima /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname
cat <<EOT >> /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOT
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Contraseña root
echo "root:$ROOTPASS" | chpasswd

# Crear usuario y contraseña
useradd -m -G wheel -s /bin/zsh $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Archlinux
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable NetworkManager
EOF

# --- COPIAR SCRIPT DE POSTINSTALACIÓN AL HOME DEL NUEVO USUARIO ---
cp /root/WArchinstall/postinstallarch.sh /mnt/home/$USERNAME/

echo "----------------------------------------"
echo "Desmontando particiones y finalizando..."
umount -R /mnt

echo "========================================"
echo "Instalación finalizada. ¡Reinicia tu equipo!"
echo "========================================"