#!/bin/bash

# Este script automatiza la instalación de Arch Linux en un dispositivo específico.
# Asegúrate de haber arrancado con un USB de instalación de Arch y de tener conexión a Internet.
# --- ADVERTENCIA: Este script borrará TODA la información en /dev/nvme0n1. ---

# Variables
DISK="/dev/nvme0n1"
HOSTNAME="Archertt"
USERNAME="wibertt"

# --- 1. Conexión y reloj ---
echo "Configurando la conexión de red y el reloj..."
ping -c 3 archlinux.org || { echo "Error: No se pudo conectar a Internet. Saliendo."; exit 1; }
timedatectl set-ntp true

# --- 2. Borrar firmas del disco ---
echo "Borrando firmas del disco $DISK..."
wipefs -a "$DISK"

# --- 3. Crear particiones ---
echo "Creando particiones en $DISK..."
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 801MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 801MiB 100%

# --- 4. Formatear particiones ---
echo "Formateando las particiones..."
mkfs.fat -F32 "${DISK}p1"
mkfs.ext4 "${DISK}p2"

# --- 5. Montar particiones ---
echo "Montando las particiones..."
mount "${DISK}p2" /mnt
mkdir -p /mnt/boot
mount "${DISK}p1" /mnt/boot

# --- 6. Instalar sistema base y paquetes ---
echo "Instalando el sistema base y los paquetes..."
pacstrap -K /mnt base linux linux-firmware vim networkmanager grub efibootmgr amd-ucode zsh sudo

# --- 7. Generar fstab ---
echo "Generando fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# --- 8. Configuración dentro de chroot ---
echo "Ingresando a chroot para la configuración final..."
arch-chroot /mnt <<EOF
    # Zona horaria
    ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
    hwclock --systohc

    # Locales
    sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

    # Hostname y hosts
    echo "$HOSTNAME" > /etc/hostname
    cat <<EOT >> /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOT

    # Root y usuario
    echo "Establece la contraseña para el usuario root:"
    passwd

    useradd -m -G wheel -s /bin/zsh "$USERNAME"
    echo "Establece la contraseña para el usuario $USERNAME:"
    passwd "$USERNAME"

    # Habilitar sudo para el grupo wheel
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

    # Instalar y configurar grub (UEFI)
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Archlinux
    grub-mkconfig -o /boot/grub/grub.cfg

    # Habilitar red
    systemctl enable NetworkManager

    echo "Configuración finalizada dentro de chroot."
EOF

# --- 9. Desmontar y reiniciar ---
echo "Desmontando las particiones y reiniciando..."
umount -R /mnt
reboot