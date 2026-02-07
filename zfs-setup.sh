#!/bin/bash
set -euo pipefail

# --- Must run as root ---
if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

ARCHZFS_KEY=3A9917BF0DED5C13F69AC68FABEC0A1208037BE9

# --- Check if archzfs repo already configured ---
if grep -q '^\[archzfs\]' /etc/pacman.conf; then
  echo "archzfs repo already in pacman.conf"
else
  echo "Adding archzfs repo to pacman.conf..."
  awk '/^\[core\]/ {
      print "[archzfs]"
      print "Server = https://github.com/archzfs/archzfs/releases/download/experimental"
      print ""
  }
  {print}' /etc/pacman.conf >/etc/pacman.conf.tmp
  mv /etc/pacman.conf.tmp /etc/pacman.conf
fi

# --- Import archzfs key ---
echo "Importing archzfs key..."
pacman-key --recv-keys "$ARCHZFS_KEY"
pacman-key --lsign-key "$ARCHZFS_KEY"
pacman -Sy

# --- Install ZFS + LTS kernel ---
echo "Installing ZFS packages..."
pacman -S --noconfirm --needed linux-lts linux-lts-headers zfs-linux zfs-linux-lts zfs-utils

# --- Create ZFS boot entries (copy options from existing entry) ---
echo "Creating ZFS boot entries..."
OPTIONS=$(grep '^options ' /boot/loader/entries/arch.conf)

cat >/boot/loader/entries/arch-zfs.conf <<EOF
title Arch Linux (ZFS)
linux /vmlinuz-linux
initrd /initramfs-linux.img
${OPTIONS}
EOF

cat >/boot/loader/entries/arch-lts-zfs.conf <<EOF
title Arch Linux LTS (ZFS)
linux /vmlinuz-linux-lts
initrd /initramfs-linux-lts.img
${OPTIONS}
EOF

# --- Enable ZFS services ---
echo "Enabling ZFS services..."
systemctl enable zfs-import-cache.service
systemctl enable zfs-import.target
systemctl enable zfs-mount.service
systemctl enable zfs.target

echo ""
echo "ZFS setup complete. Added boot entries:"
echo "  - Arch Linux (ZFS)      <- mainline + ZFS"
echo "  - Arch Linux LTS (ZFS)  <- LTS + ZFS"
echo ""
echo "Reboot to use ZFS."
