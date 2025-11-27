#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
BASE="$PWD"                       # jalankan dari folder yang ingin jadi project root
REPO_REMOTE_EXPECTED="git@github.com:Wahyud1/UniCoreLinux.git"
GIT_PUSH=true                     # set false jika hanya ingin buat files tanpa push

echo "[unicore-setup] Project root: $BASE"
read -rp "Continue and create files here? [Y/n] " RESP
RESP=${RESP:-Y}
if [[ "$RESP" =~ ^[Nn] ]]; then
  echo "Aborted by user."; exit 0
fi

# Safety: do not overwrite critical existing repo unless user agrees
if [ -d "$BASE/.git" ]; then
  echo "[unicore-setup] Git repo already exists in $BASE"
  read -rp "Use existing repo and continue (will add files and commit)? [Y/n] " R2
  R2=${R2:-Y}
  if [[ "$R2" =~ ^[Nn] ]]; then
    echo "Aborted."; exit 0
  fi
fi

# Create directories
mkdir -p "$BASE/build/archiso/airootfs/etc/systemd/system"
mkdir -p "$BASE/build/archiso/airootfs/usr/local/bin"
mkdir -p "$BASE/build/archiso/loader/entries"
mkdir -p "$BASE/build/archiso/airootfs/usr/share/unicore/kexts"
mkdir -p "$BASE/build/archiso/airootfs/usr/share/unicore/theme/gtk-3.0"
mkdir -p "$BASE/installer"
mkdir -p "$BASE/pkgbuild/unicore-plistd"
mkdir -p "$BASE/pkgbuild/unicore-kextd"
mkdir -p "$BASE/pkgbuild/unicore-theme"
mkdir -p "$BASE/system/services"
mkdir -p "$BASE/system/modules"
mkdir -p "$BASE/docs"

echo "[unicore-setup] Creating files..."

# README
cat > "$BASE/README.md" <<'MD'
# UniCoreLinux (UEFI-only) - Scaffold

UEFI-only ArchISO-based scaffold for UniCore Linux (no GRUB; uses systemd-boot).
This repository contains an ArchISO profile, installer, tools (kextd, plistd, session-restore, theme-engine),
and PKGBUILD skeletons to package components.

Test in a VM before using on real hardware.
MD

# .gitignore
cat > "$BASE/.gitignore" <<'GIT'
# ignore keys & local scripts
git@Wahyud1
git@Wahyud1.pub
sync.sh

# build artifacts
*.iso
build/archiso/out/
build/archiso/work/
out/
work/
GIT

# LICENSE
cat > "$BASE/LICENSE" <<'LIC'
MIT License
Copyright (c) 2025 UniCore contributors
Permission is hereby granted, free of charge, to any person obtaining a copy...
LIC

# build/build.sh
cat > "$BASE/build/build.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PROFILE_DIR="$HERE/archiso"
OUT_DIR="$PROFILE_DIR/out"
WORK_DIR="$PROFILE_DIR/work"

echo "[unicore-builder] cleaning previous build..."
sudo rm -rf "$OUT_DIR" "$WORK_DIR"
mkdir -p "$OUT_DIR" "$WORK_DIR"

if ! command -v mkarchiso >/dev/null 2>&1; then
  echo "mkarchiso not found. Install package 'archiso' first."
  exit 1
fi

echo "[unicore-builder] running mkarchiso profile: $PROFILE_DIR"
sudo mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"
echo "[unicore-builder] finished. ISO in: $OUT_DIR"
SH
chmod +x "$BASE/build/build.sh"

# build/profiledef.sh
cat > "$BASE/build/profiledef.sh" <<'PD'
profile_name="unicore-uefi"
iso_name="unicore-uefi"
iso_label="UNICORE_UEFI"
iso_publisher="UniCore Project"
iso_application="UniCore Linux Live Installer (UEFI)"
buildmodes=('iso')
arch="x86_64"
bootmodes=('uefi-x64.systemd-boot')
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz')
PD

# systemd unit files (airootfs)
cat > "$BASE/build/archiso/airootfs/etc/systemd/system/kextd.service" <<'KEXTSVC'
[Unit]
Description=UniCore kext loader (kextd)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/kextd auto
Restart=on-failure

[Install]
WantedBy=multi-user.target
KEXTSVC

cat > "$BASE/build/archiso/airootfs/etc/systemd/system/plistd.service" <<'PLISTSVC'
[Unit]
Description=UniCore plist daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/plistd watch
Restart=on-failure

[Install]
WantedBy=multi-user.target
PLISTSVC

cat > "$BASE/build/archiso/airootfs/etc/systemd/system/session-restore.service" <<'SESSVC'
[Unit]
Description=UniCore Session Restore
After=graphical.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/session-restore restore
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
SESSVC

# systemd-boot loader entry (airootfs loader entry - live system)
cat > "$BASE/build/archiso/loader/entries/unicore.conf" <<'LOADER'
title UniCore Live (UEFI)
linux /vmlinuz-linux
initrd /initramfs-linux.img
options archisobasedir=arch archiso_http_srv=
LOADER

# airootfs tools: kextd, plistd, session-restore, theme-engine
cat > "$BASE/build/archiso/airootfs/usr/local/bin/kextd" <<'KEXT'
#!/usr/bin/env bash
set -e
KEXT_DIR="/usr/share/unicore/kexts"

load_kext() {
  local k="$1"
  local ko="$KEXT_DIR/$k/$k.ko"
  if [ ! -f "$ko" ]; then
    echo "[kextd] module not found: $ko" >&2
    return 1
  fi
  echo "[kextd] loading $ko"
  modprobe --ignore-install $(basename "$ko" .ko) || insmod "$ko"
}

case "$1" in
  load) load_kext "$2" ;;
  list) ls -1 "$KEXT_DIR" ;;
  auto)
    lspci -nn | grep -E 'VGA|3D' | while read -r line; do
      if echo "$line" | grep -qi nvidia; then load_kext "nvidia"; fi
      if echo "$line" | grep -qi amd; then load_kext "amdgpu"; fi
      if echo "$line" | grep -qi intel; then load_kext "i915"; fi
    done
    ;;
  *) echo "Usage: kextd {load <name>|list|auto}"; exit 1 ;;
esac
KEXT
chmod +x "$BASE/build/archiso/airootfs/usr/local/bin/kextd"

cat > "$BASE/build/archiso/airootfs/usr/local/bin/plistd" <<'PLIST'
#!/usr/bin/env bash
set -e
WATCH_DIR="/etc/unicore/launchd"

start_plist() {
  local f="$1"
  if command -v plistutil >/dev/null 2>&1; then
    cmd=$(plistutil -i "$f" -o json | jq -r '.ProgramArguments[0] // .Program // empty')
  elif command -v plutil >/dev/null 2>&1; then
    cmd=$(plutil -convert json -o - "$f" 2>/dev/null | jq -r '.ProgramArguments[0] // .Program // empty')
  else
    echo "[plistd] no plist parser installed." >&2
    return 1
  fi
  if [ -n "$cmd" ]; then
    echo "[plistd] launching: $cmd"
    $cmd &
  else
    echo "[plistd] no Program in $f"
  fi
}

case "$1" in
  watch)
    mkdir -p "$WATCH_DIR"
    for p in "$WATCH_DIR"/*.plist; do
      [ -f "$p" ] && start_plist "$p"
    done
    ;;
  read)
    cat "$2"
    ;;
  *)
    echo "Usage: plistd watch|read <file>"
    ;;
esac
PLIST
chmod +x "$BASE/build/archiso/airootfs/usr/local/bin/plistd"

cat > "$BASE/build/archiso/airootfs/usr/local/bin/session-restore" <<'SESS'
#!/usr/bin/env bash
set -e
SESSION_DIR="$HOME/.local/share/unicore/session"
save_session(){
  mkdir -p "$SESSION_DIR"
  wmctrl -lG > "$SESSION_DIR/windows.txt"
  echo "[session] saved"
}
restore_session(){
  [ -f "$SESSION_DIR/windows.txt" ] || { echo "[session] no saved session"; exit 1; }
  while read -r ln; do
    wid=$(echo "$ln" | awk '{print $1}')
    x=$(echo "$ln" | awk '{print $3}')
    y=$(echo "$ln" | awk '{print $4}')
    w=$(echo "$ln" | awk '{print $5}')
    h=$(echo "$ln" | awk '{print $6}')
    wmctrl -i -r "$wid" -e "0,$x,$y,$w,$h" || true
  done < "$SESSION_DIR/windows.txt"
  echo "[session] restored"
}
case "$1" in
  save) save_session ;;
  restore) restore_session ;;
  *) echo "Usage: session-restore save|restore"; exit 1 ;;
esac
SESS
chmod +x "$BASE/build/archiso/airootfs/usr/local/bin/session-restore"

cat > "$BASE/build/archiso/airootfs/usr/local/bin/theme-engine" <<'THEME'
#!/usr/bin/env bash
set -e
THEME_DIR="/usr/share/unicore/theme"
GTK_CONF="$HOME/.config/gtk-3.0"
case "$1" in
  apply)
    mkdir -p "$GTK_CONF"
    if [ -d "$THEME_DIR/gtk-3.0" ]; then
      cp -a "$THEME_DIR/gtk-3.0/"* "$GTK_CONF/" || true
    fi
    echo "[theme] applied (if theme exists)" ;;
  list) ls -1 "$THEME_DIR" ;;
  *) echo "Usage: theme-engine apply|list" ;;
esac
THEME
chmod +x "$BASE/build/archiso/airootfs/usr/local/bin/theme-engine"

# installer (UEFI)
cat > "$BASE/installer/install.sh" <<'INST'
#!/usr/bin/env bash
set -euo pipefail
echo "UniCore Interactive Installer (UEFI-only)"
read -rp "Target disk (e.g. /dev/sda): " DISK
echo "Partitioning ${DISK} (EFI + ROOT)..."
sgdisk -Z "$DISK"
sgdisk -n1:0:+512M -t1:ef00 "$DISK"
sgdisk -n2:0:0 -t2:8300 "$DISK"
mkfs.fat -F32 "${DISK}1"
mkfs.btrfs -f "${DISK}2"
mount "${DISK}2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt
mount -o subvol=@ "${DISK}2" /mnt
mkdir -p /mnt/{boot,home}
mount "${DISK}1" /mnt/boot
echo "Installing base system..."
pacstrap /mnt base base-devel linux linux-firmware networkmanager sudo
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/UTC /etc/localtime; echo en_US.UTF-8 UTF-8 > /etc/locale.gen; locale-gen"
echo "Installing systemd-boot to target..."
arch-chroot /mnt /bin/bash -c "bootctl --path=/boot install || true; mkdir -p /boot/loader/entries; cat > /boot/loader/entries/unicore.conf <<EOF
title UniCore Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=PARTLABEL=UNICORE_ROOT rw
EOF"
echo "Installation finished. Reboot into installed system."
INST
chmod +x "$BASE/installer/install.sh"

# PKGBUILD samples
cat > "$BASE/pkgbuild/unicore-plistd/PKGBUILD" <<'PKG1'
pkgname=unicore-plistd
pkgver=0.1
pkgrel=1
arch=('any')
depends=('python' 'jq')
source=('unicore-plistd.py')
license=('MIT')
build() { :; }
package() {
  install -Dm755 unicore-plistd.py "$pkgdir/usr/bin/unicore-plistd"
  install -Dm644 ../../system/services/plistd.service "$pkgdir/usr/lib/systemd/system/plistd.service"
}
PKG1

cat > "$BASE/pkgbuild/unicore-kextd/PKGBUILD" <<'PKG2'
pkgname=unicore-kextd
pkgver=0.1
pkgrel=1
arch=('x86_64')
depends=('bash' 'kmod')
source=('kextd')
license=('MIT')
build() { :; }
package() {
  install -Dm755 kextd "$pkgdir/usr/bin/kextd"
  install -Dm644 ../../system/services/kextd.service "$pkgdir/usr/lib/systemd/system/kextd.service"
}
PKG2

cat > "$BASE/pkgbuild/unicore-theme/PKGBUILD" <<'PKG3'
pkgname=unicore-theme
pkgver=0.1
pkgrel=1
arch=('any')
depends=()
source=('theme')
license=('MIT')
build() { :; }
package() {
  install -dm755 "$pkgdir/usr/share/unicore/theme"
  cp -a theme/* "$pkgdir/usr/share/unicore/theme/"
}
PKG3

# system scripts
cat > "$BASE/system/unicore-plistd.py" <<'PY'
#!/usr/bin/env python3
import plistlib, json, sys
from pathlib import Path
PREF_DIR = Path('/etc/unicore/launchd')
PREF_DIR.mkdir(parents=True, exist_ok=True)
def read(name):
    p = PREF_DIR / f"{name}.plist"
    if not p.exists():
        print('{}')
        return
    with p.open('rb') as f:
        data = plistlib.load(f)
        print(json.dumps(data))
def write(name, data):
    p = PREF_DIR / f"{name}.plist"
    with p.open('wb') as f:
        plistlib.dump(data, f)
if __name__=='__main__':
    if len(sys.argv)<3:
        print('usage: unicore-plistd.py read|write name [json]')
        sys.exit(1)
    cmd=sys.argv[1]; name=sys.argv[2]
    if cmd=='read':
        read(name)
    elif cmd=='write':
        import json
        data=json.loads(sys.argv[3]) if len(sys.argv)>3 else {}
        write(name,data)
    else:
        print('unknown cmd')
PY
chmod +x "$BASE/system/unicore-plistd.py"

cat > "$BASE/system/services/kextd.service" <<'KS'
[Unit]
Description=UniCore Kext Loader
After=network.target

[Service]
ExecStart=/usr/bin/kextd auto
Restart=on-failure

[Install]
WantedBy=multi-user.target
KS

cat > "$BASE/system/services/plistd.service" <<'PS'
[Unit]
Description=UniCore Plist Daemon
After=network.target

[Service]
ExecStart=/usr/bin/plistd watch
Restart=on-failure

[Install]
WantedBy=multi-user.target
PS

# placeholder theme & kext example
echo "/* placeholder gtk css */" > "$BASE/build/archiso/airootfs/usr/share/unicore/theme/gtk-3.0/gtk.css"
echo "placeholder for binary module" > "$BASE/build/archiso/airootfs/usr/share/unicore/kexts/nvidia/nvidia.ko"

# docs
cat > "$BASE/docs/NOTES.md" <<'NOTES'
UniCoreLinux UEFI-only scaffold
- Use build/build.sh to create ISO (requires archiso)
- Installer expects UEFI + systemd-boot
NOTES

echo "[unicore-setup] All files created."

# Initialize git if not exists
if [ ! -d "$BASE/.git" ]; then
  echo "[unicore-setup] Initializing git repository..."
  git init
fi

# ensure .gitignore present
git add .gitignore || true

# Add everything except sensitive files
git add -A
git commit -m "Initial UniCore UEFI-only scaffold" || echo "[unicore-setup] nothing to commit."

# set remote if not set
if git remote get-url origin >/dev/null 2>&1; then
  echo "[unicore-setup] Remote origin exists: $(git remote get-url origin)"
else
  if git remote -v | grep -q "$REPO_REMOTE_EXPECTED"; then
    git remote add origin "$REPO_REMOTE_EXPECTED" || true
  else
    echo "[unicore-setup] No origin configured. Adding expected remote: $REPO_REMOTE_EXPECTED"
    git remote add origin "$REPO_REMOTE_EXPECTED" || true
  fi
fi

# push
if $GIT_PUSH; then
  echo "[unicore-setup] Pushing to remote origin main (will create main branch if needed)..."
  # create main branch if not exists locally
  git branch -M main || true
  if git ls-remote --exit-code origin main >/dev/null 2>&1; then
    git push origin main
  else
    git push -u origin main
  fi
  echo "[unicore-setup] Push complete (if auth allowed)."
else
  echo "[unicore-setup] Skipping git push (GIT_PUSH=false)."
fi

echo "[unicore-setup] Done. Next: install 'archiso' and run 'build/build.sh' to build the ISO."
