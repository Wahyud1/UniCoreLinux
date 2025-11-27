#!/usr/bin/env bash

set -e

PROJECT_DIR="$HOME/Downloads/project-git/UniCoreLinux"
CONTAINER_NAME="archbuilder"
IMAGE_NAME="archlinux:latest"

echo "=== 1. CHECKING DOCKER INSTALLATION ==="
if ! command -v docker >/dev/null 2>&1; then
    echo "[+] Installing Docker..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl enable --now docker
else
    echo "[OK] Docker already installed."
fi

echo
echo "=== 2. ADDING USER TO DOCKER GROUP ==="
if ! groups $USER | grep -q docker; then
    echo "[+] Adding $USER to docker group..."
    sudo usermod -aG docker $USER
    echo "[!] You MUST logout/login or run 'newgrp docker' before next step."
    echo "    After re-login, run this script again."
    exit 1
else
    echo "[OK] User already in docker group."
fi

echo
echo "=== 3. PULLING ARCH LINUX BASE IMAGE ==="
docker pull $IMAGE_NAME

echo
echo "=== 4. REMOVING OLD CONTAINER (IF EXISTS) ==="
docker rm -f $CONTAINER_NAME >/dev/null 2>&1 || true

echo
echo "=== 5. STARTING ARCH CONTAINER WITH PROJECT MOUNTED ==="
docker run -it \
    --name $CONTAINER_NAME \
    -v "$PROJECT_DIR":/root/UniCoreLinux \
    $IMAGE_NAME bash -c "

    echo '=== Inside Arch Container: Installing build tools ==='
    pacman -Sy --noconfirm archiso git base-devel

    echo '=== Building ISO ==='
    cd /root/UniCoreLinux/builder

    chmod +x build.sh
    ./build.sh

    echo '=== DONE ==='
    "

echo
echo "=== 6. ISO BUILD COMPLETED ==="
echo "Cek hasil ISO di folder: UniCoreLinux/out/"
