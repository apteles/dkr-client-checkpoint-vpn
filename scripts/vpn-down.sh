#!/bin/bash
# Para o client-checkpoint-vpn e remove split-DNS do host.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

require_command docker

if [ -f "$ENV_FILE" ]; then
  load_env
else
  CONTAINER_NAME="client-checkpoint-vpn"
fi

if [ "$(id -u)" -ne 0 ]; then
  exec sudo -E "$0" "$@"
fi

log "Removendo split-DNS..."
"$SCRIPT_DIR/vpn-dns.sh" down || warn "Falha ao remover split-DNS."

log "Parando container..."
remove_container_if_exists

log "VPN desligada."
