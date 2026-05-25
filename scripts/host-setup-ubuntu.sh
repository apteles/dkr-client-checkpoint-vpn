#!/bin/bash
# Pré-requisitos do host — Ubuntu / Debian.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

need_docker=false
need_iproute2=false

if command -v docker >/dev/null 2>&1; then
  echo "[*] Docker já instalado: $(docker --version)"
else
  need_docker=true
fi

if command -v ip >/dev/null 2>&1; then
  echo "[*] iproute2 já instalado."
else
  need_iproute2=true
fi

if ! $need_docker && ! $need_iproute2; then
  echo "[*] Dependências satisfeitas — pulando apt-get update."
else
  echo "[*] Instalando dependências faltantes (Ubuntu/Debian)..."
  packages=()
  $need_docker && packages+=(docker.io)
  $need_iproute2 && packages+=(iproute2)

  apt-get update
  apt-get install -y "${packages[@]}"
fi

echo "[*] Habilitando serviço Docker..."
systemctl enable --now docker

if [ -n "${SUDO_USER:-}" ]; then
  usermod -aG docker "$SUDO_USER"
  echo "[*] Usuário $SUDO_USER adicionado ao grupo docker."
  echo "[!] Faça logout/login para usar docker sem sudo."
fi

if [ -c /dev/net/tun ]; then
  echo "[*] Dispositivo /dev/net/tun disponível."
else
  echo "[!] /dev/net/tun não encontrado — verifique módulo tun."
fi

echo "[*] Setup Ubuntu concluído."
