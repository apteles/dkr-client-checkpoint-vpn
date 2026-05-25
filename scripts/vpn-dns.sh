#!/bin/bash
# Configura split-DNS no host para intranet.mpgo via systemd-resolved.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

ACTION="${1:-up}"

setup_dns() {
  require_root
  load_env

  if ! command -v resolvectl >/dev/null 2>&1; then
    die "systemd-resolved (resolvectl) não encontrado. Instale/configure systemd-resolved."
  fi

  if [ -z "${VPN_DNS:-}" ] || [ -z "${VPN_SEARCH_DOMAIN:-}" ]; then
    die "VPN_DNS e VPN_SEARCH_DOMAIN devem estar definidos em $ENV_FILE"
  fi

  mkdir -p "$(dirname "$RESOLVED_DROPIN")"
  cat > "$RESOLVED_DROPIN" <<EOF
[Resolve]
DNS=$VPN_DNS
Domains=~$VPN_SEARCH_DOMAIN
EOF

  systemctl restart systemd-resolved
  log "Split-DNS configurado: ~$VPN_SEARCH_DOMAIN -> $VPN_DNS"
  resolvectl status | grep -E "DNS|Domain|Current" || true
}

teardown_dns() {
  require_root

  if [ -f "$RESOLVED_DROPIN" ]; then
    rm -f "$RESOLVED_DROPIN"
    systemctl restart systemd-resolved
    log "Split-DNS removido."
  else
    log "Split-DNS não estava configurado."
  fi
}

case "$ACTION" in
  up) setup_dns ;;
  down) teardown_dns ;;
  *)
    echo "Uso: $0 {up|down}"
    exit 1
    ;;
esac
