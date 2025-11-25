#!/usr/bin/env bash
#
# UniCore interactive installer (dialog-based)
#
# WARNING: This script will perform destructive disk operations in "Auto" mode.
# Use in a VM for testing.

set -Eeuo pipefail
LANG=C

# Helpers
die() { echo "ERROR: $*" >&2; exit 1; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

if ! has_cmd dialog; then
  echo "Dialog is required. Install it before running this script: sudo pacman -S dialog"
  exit 1
fi

dialog_msg() {
  dialog --msgbox "$1" 10 60
}

dialog_input() {
  dialog --inputbox "$1" 8 60 "$2" 3>&1 1>&2 2>&3
}

dialog_yesno() {
  dialog --yesno "$1" 10 60
  return $?
}

detect_network() {
  ping -c1 1.1.1.1 >/dev/null 2>&1
}

main_menu() {
  dialog --menu "UniCore Installer - Main Menu" 15 60 4             1 "Install (auto partition, btrfs snapshots)"             2 "Install (manual partition - advanced)"             3 "Exit" 2> /tmp/unicore.choice
  cat /tmp/unicore.choice
}

confirm_and_partition_auto() {
  local disk="$1"
  dialog_yesno "This will erase all data on ${disk}. Continue?"
  if [ $? -ne 0 ]; then
    dialog_msg "Aborted by user."
    exit 0
  fi
  # Wipe partition table
  sgdisk -Z "$disk"
  # Create EFI (512M), System (40G), Recovery (rest)
  sgdisk -n1:0:+512M -t1:ef00 "$disk"
  sgdisk -n2:0:+40G -t2:8300 "$disk"
  sgdisk -n3:0:0 -t3:8300 "$disk"

  # Create filesystems
  mkfs.fat -F32 "${disk}1"
  mkfs.btrfs -f "${disk}2"
  mkfs.btrfs -f "${disk}3"

  # Mount and create subvolumes
  mount "${disk}2" /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@snapshots
  umount /mnt

  mount -o subvol=@ "${disk}2" /mnt
  mkdir -p /mnt/{boot,home,.snapshots}
  mount -o subvol=@home "${disk}2" /mnt/home
  mount -o subvol=@snapshots "${disk}2" /mnt/.snapshots
  mount "${disk}1" /mnt/boot
}

perform_install() {
  local disk="$1"
  # Basic pacstrap; assumes you are in an Arch live environment with pacman & pacstrap ready
  pacstrap /mnt base base-devel linux linux-firmware networkmanager dialog sudo
  genfstab -U /mnt >> /mnt/etc/fstab

  # Copy scaffold extras (if present next to script)
  if [ -d "$(pwd)/../system" ]; then
    cp -a "$(pwd)/../system" /mnt/opt/unicore-system || true
  fi

  # Chroot setup minimal
  arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/UTC /etc/localtime; echo en_US.UTF-8 UTF-8 > /etc/locale.gen; locale-gen"
  arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager"

  # Install grub
  arch-chroot /mnt /bin/bash -c "pacman -Sy --noconfirm grub efibootmgr; grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=UniCore || true; grub-mkconfig -o /boot/grub/grub.cfg"
}

# --- Start ---
dialog_msg "Welcome to the UniCore Linux Installer. Test/Development only."

if detect_network; then
  dialog_msg "Network detected."
else
  dialog_yesno "No network detected. Continue offline?" || die "Need network for package install."
fi

CHOICE=$(main_menu)
case "$CHOICE" in
  1)
    DISK=$(dialog_input "Enter target disk (eg. /dev/sda):" "/dev/sda")
    confirm_and_partition_auto "$DISK"
    perform_install "$DISK"
    dialog_msg "Install complete. Please reboot into your new system."
    ;;
  2)
    dialog_msg "Manual partition mode is not fully automated by this script. Use this on your own risk."
    exit 0
    ;;
  3)
    dialog_msg "Goodbye."
    exit 0
    ;;
  *)
    dialog_msg "No valid choice selected."
    exit 1
    ;;
esac
