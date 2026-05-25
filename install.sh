#!/bin/bash
# Instala client-checkpoint-vpn e imprime próximos passos.
#
# Uso remoto:
#   curl -fsSL https://raw.githubusercontent.com/<org>/client-checkpoint-vpn/main/install.sh | bash
#
# Com overrides:
#   VPN_SERVER=mpsec.mpgo.mp.br VPN_LOGIN_TYPE=vpn_VPN_STI \
#   curl -fsSL https://raw.githubusercontent.com/<org>/client-checkpoint-vpn/main/install.sh | bash

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/mpgo/client-checkpoint-vpn.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
INSTALL_DIR="${INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/client-checkpoint-vpn}"

log() {
  echo "[*] $*"
}

warn() {
  echo "[!] $*" >&2
}

die() {
  echo "[ERRO] $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Comando obrigatório não encontrado: $1"
}

detect_distro() {
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${ID:-unknown}"
  else
    echo "unknown"
  fi
}

run_host_setup() {
  local distro="$1"
  local setup_script=""

  case "$distro" in
    arch|manjaro)
      setup_script="$INSTALL_DIR/scripts/host-setup-arch.sh"
      ;;
    ubuntu|debian|linuxmint|pop)
      setup_script="$INSTALL_DIR/scripts/host-setup-ubuntu.sh"
      ;;
    *)
      warn "Distro '$distro' não reconhecida. Instale manualmente: docker, iproute2, systemd-resolved."
      return 0
      ;;
  esac

  if [ ! -f "$setup_script" ]; then
    warn "Script de setup não encontrado: $setup_script"
    return 0
  fi

  log "Executando pré-requisitos do host ($distro)..."
  if [ "$(id -u)" -eq 0 ]; then
    bash "$setup_script"
  else
    sudo bash "$setup_script"
  fi
}

clone_or_update_repo() {
  if [ -d "$INSTALL_DIR/.git" ]; then
    log "Atualizando repositório em $INSTALL_DIR..."
    git -C "$INSTALL_DIR" fetch origin "$REPO_BRANCH"
    git -C "$INSTALL_DIR" checkout "$REPO_BRANCH"
    git -C "$INSTALL_DIR" pull --ff-only origin "$REPO_BRANCH"
  elif [ -d "$INSTALL_DIR" ]; then
    die "Diretório $INSTALL_DIR existe mas não é um clone git. Remova ou defina INSTALL_DIR."
  else
    require_command git
    log "Clonando repositório em $INSTALL_DIR..."
    git clone --branch "$REPO_BRANCH" --depth 1 "$REPO_URL" "$INSTALL_DIR"
  fi
}

ensure_config_file() {
  local env_file="$INSTALL_DIR/config/vpn.env"
  local example="$INSTALL_DIR/config/vpn.env.example"

  if [ ! -f "$env_file" ]; then
    cp "$example" "$env_file"
    log "Criado $env_file a partir do template."
  fi

  apply_env_overrides "$env_file"
}

apply_env_overrides() {
  local env_file="$1"
  local key value

  if [ -n "${VPN_CONTAINER_NAME:-}" ] && [ -z "${CONTAINER_NAME:-}" ]; then
    CONTAINER_NAME="$VPN_CONTAINER_NAME"
  fi

  for key in VPN_SERVER VPN_LOGIN_TYPE VPN_IMAGE CONTAINER_NAME VPN_DNS VPN_SEARCH_DOMAIN TUN_IF; do
    value="${!key:-}"
    [ -n "$value" ] || continue

    if grep -q "^${key}=" "$env_file"; then
      sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
    else
      echo "${key}=${value}" >> "$env_file"
    fi
    log "Override aplicado: ${key}=${value}"
  done
}

print_next_steps() {
  cat <<EOF

========================================
  Instalação concluída
========================================

Repositório:  $INSTALL_DIR
Configuração: $INSTALL_DIR/config/vpn.env

Próximos passos:

  1. Revise a configuração (se necessário):
     nano $INSTALL_DIR/config/vpn.env

  2. Conecte a VPN:
     cd $INSTALL_DIR
     ./scripts/vpn-up.sh

  3. Acompanhe os logs e abra a URL SAML quando aparecer:
     docker logs -f client-checkpoint-vpn

  4. Valide após autenticar:
     ip link show snx-tun
     curl -I https://gitlab.intranet.mpgo/users/sign_in

  5. Desligar:
     cd $INSTALL_DIR
     ./scripts/vpn-down.sh

Execução manual (sem scripts):

  cd $INSTALL_DIR
  docker build --network=host -t client-checkpoint-vpn:latest docker
  docker run --rm -it \\
    --name client-checkpoint-vpn \\
    --network host \\
    --privileged \\
    --env-file config/vpn.env \\
    client-checkpoint-vpn:latest

========================================
EOF
}

main() {
  local distro

  log "Instalando client-checkpoint-vpn..."
  clone_or_update_repo
  ensure_config_file

  distro="$(detect_distro)"
  run_host_setup "$distro"

  print_next_steps
}

main "$@"
