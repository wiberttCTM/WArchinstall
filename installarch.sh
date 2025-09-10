#!/bin/bash

echo "========================================"
echo "     Script de instalación Arch Linux"
echo "========================================"

# -------------------------------
# Función para leer contraseñas con asteriscos
# -------------------------------
read_password() {
    local password=""
    local char

    while IFS= read -r -s -n1 char; do
        [[ $char == "" ]] && break
        if [[ $char == $'\177' || $char == $'\b' ]]; then
            [[ -n $password ]] && password=${password%?}
            echo -ne "\b \b"
        else
            password+=$char
            echo -n "*"
        fi
    done
    echo
    REPLY=$password
}

# -------------------------------
# Preguntar datos al usuario
# -------------------------------
while true; do
    echo "----------------------------------------"
    read -p "[*] Nombre del equipo (hostname): " HOSTNAME || { echo "[X] Instalación cancelada."; exit 1; }
    read -p "[*] Nombre de usuario: " USERNAME || { echo "[X] Instalación cancelada."; exit 1; }

    # Contraseña de usuario
    while true; do
        echo -n "[*] Contraseña para $USERNAME: "
        read_password
        USERPASS1=$REPLY

        echo -n "[*] Confirma la contraseña para $USERNAME: "
        read_password
        USERPASS2=$REPLY

        [ "$USERPASS1" = "$USERPASS2" ] && USERPASS="$USERPASS1" && break
        echo "[X] Las contraseñas no coinciden, inténtalo de nuevo."
    done

    # Contraseña de root
    while true; do
        echo -n "[*] Contraseña para root: "
        read_password
        ROOTPASS1=$REPLY

        echo -n "[*] Confirma la contraseña para root: "
        read_password
        ROOTPASS2=$REPLY

        [ "$ROOTPASS1" = "$ROOTPASS2" ] && ROOTPASS="$ROOTPASS1" && break
        echo "[X] Las contraseñas no coinciden, inténtalo de nuevo."
    done

    echo "----------------------------------------"
    echo "[>] Resumen de configuración:"
    echo "  - Hostname: $HOSTNAME"
    echo "  - Usuario: $USERNAME"
    echo "  - Contraseñas: ocultas"
    echo "----------------------------------------"
    read -p "[?] ¿Son correctos estos datos? (Y/n): " CONFIRM || { echo "[X] Instalación cancelada."; exit 1; }
    [[ "$CONFIRM" =~ ^[Yy]$ ]] && break
    echo "[!] Vuelve a ingresar los datos."
done

# -------------------------------
# Instalación del sistema
# -------------------------------
echo "========================================"
echo "   Iniciando instalación del sistema..."
echo "========================================"

DISK="/dev/nvme0n1"

# 1. Sincronizar reloj y configurar mirrors con reflector
echo "----------------------------------------"
echo "[*] Configurando reloj y mirrors..."
timedatectl set-ntp true
reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# 2. Particionado y formateo
echo "----------------------------------------"
echo "[*] Particionando y formateando disco en $DISK..."
wipefs -a "$DISK"
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 801MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 801MiB 100%

mkfs.fat -F32 "${DISK}p1"
mkfs.ext4 "${DISK}p2"

# 3. Montaje
echo "[*] Montando particiones..."
mount "${DISK}p2" /mnt
mkdir -p /mnt/boot
mount "${DISK}p1" /mnt/boot

# 4. Instalación base
echo "----------------------------------------"
echo "[*] Instalando sistema base..."
pacstrap -K /mnt base linux linux-firmware vim networkmanager grub efibootmgr amd-ucode zsh sudo reflector

# 5. fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 6. Configuración dentro de chroot
echo "----------------------------------------"
echo "[*] Configurando sistema dentro de chroot..."
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

# Contraseñas
echo "root:$ROOTPASS" | chpasswd
useradd -m -G wheel -s /bin/zsh $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd

# Bootloader y servicios
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Archlinux
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable NetworkManager
EOF

# 7. Copiar script de post-instalación
echo "[*] Copiando script de post-instalación al home del usuario..."
cp /root/WArchinstall/postinstallarch.sh /mnt/home/$USERNAME/ 2>/dev/null || echo "[!] No se encontró postinstallarch.sh"

# 8. Finalización
echo "----------------------------------------"
echo "[*] Desmontando particiones..."
umount -R /mnt

echo "========================================"
echo "Instalación finalizada >:)"
echo "Reinicia tu equipo para arrancar en Arch Linux."
echo "========================================"
