#!/bin/bash
# Pré-requisitos do host — Arch Linux.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

echo "[*] Instalando dependências (Arch Linux)..."
pacman -Sy --needed --noconfirm docker iproute2

echo "[*] Habilitando serviço Docker..."
systemctl enable --now docker

if [ -n "${SUDO_USER:-}" ]; then
  usermod -aG docker "$SUDO_USER"
  echo "[*] Usuário $SUDO_USER adicionado ao grupo docker."
  echo "[!] Faça logout/login para usar docker sem sudo."
fi

if lsmod | grep -q "^tun "; then
  echo "[*] Módulo tun carregado."
else
  modprobe tun 2>/dev/null || echo "[!] Módulo tun não carregado — verifique se /dev/net/tun existe."
fi

echo "[*] Setup Arch concluído."
