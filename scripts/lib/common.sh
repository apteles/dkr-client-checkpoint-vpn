#!/bin/bash
# Funções compartilhadas para client-checkpoint-vpn.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_ROOT/config/vpn.env}"
DOCKER_DIR="$REPO_ROOT/docker"
RESOLVED_DROPIN="/etc/systemd/resolved.conf.d/client-checkpoint-vpn.conf"

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
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Comando obrigatório não encontrado: $cmd"
}

load_env() {
  if [ ! -f "$ENV_FILE" ]; then
    die "Arquivo de configuração não encontrado: $ENV_FILE (copie config/vpn.env.example)"
  fi

  # shellcheck disable=SC1090
  set -a
  source "$ENV_FILE"
  set +a

  TUN_IF="${TUN_IF:-snx-tun}"
  CONTAINER_NAME="${CONTAINER_NAME:-client-checkpoint-vpn}"
  VPN_IMAGE="${VPN_IMAGE:-client-checkpoint-vpn:latest}"
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "Este comando requer privilégios de root (sudo)."
  fi
}

build_image() {
  log "Gerando imagem Docker $VPN_IMAGE..."
  docker build --network=host -t "$VPN_IMAGE" "$DOCKER_DIR"
}

remove_container_if_exists() {
  if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    docker rm -f "$CONTAINER_NAME" >/dev/null
  fi
}

run_vpn_container() {
  remove_container_if_exists

  log "Iniciando container $CONTAINER_NAME (--network host --privileged)..."
  docker run -d \
    --name "$CONTAINER_NAME" \
    --network host \
    --privileged \
    --env-file "$ENV_FILE" \
    "$VPN_IMAGE" >/dev/null
}

tunnel_is_up() {
  ip link show "$TUN_IF" >/dev/null 2>&1
}

wait_for_tunnel() {
  local timeout="${1:-300}"
  local elapsed=0

  log "Aguardando túnel $TUN_IF (timeout ${timeout}s)..."
  echo ""
  echo "  1. Em outro terminal: docker logs -f $CONTAINER_NAME"
  echo "  2. Abra a URL SAML no navegador e complete o login"
  echo "  3. O browser redireciona OTP para 127.0.0.1:7779"
  echo "  4. Não interrompa este script até o túnel subir"
  echo ""

  while ! tunnel_is_up; do
    sleep 2
    elapsed=$((elapsed + 2))
    if [ "$elapsed" -ge "$timeout" ]; then
      die "Timeout aguardando $TUN_IF. Verifique docker logs e se completou o SAML."
    fi
  done

  log "Túnel $TUN_IF ativo."
}

apply_post_connect_config() {
  local script_dir="$1"

  log "Configurando split-DNS no host..."
  "$script_dir/vpn-dns.sh" up
}

ensure_env_file() {
  if [ ! -f "$ENV_FILE" ]; then
    cp "$REPO_ROOT/config/vpn.env.example" "$ENV_FILE"
    log "Criado $ENV_FILE a partir do template."
  fi
}
