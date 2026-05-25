#!/bin/bash
# Sobe o client-checkpoint-vpn e configura split-DNS no host.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

require_command docker
require_command ip

ensure_env_file
load_env

if [ "$(id -u)" -ne 0 ]; then
  exec sudo -E "$0" "$@"
fi

case "${1:-up}" in
  dns)
    if ! tunnel_is_up; then
      die "Túnel $TUN_IF não está ativo. Conecte a VPN primeiro."
    fi
    apply_post_connect_config "$SCRIPT_DIR"
    log "Split-DNS reaplicado."
    exit 0
    ;;
  up) ;;
  *)
    echo "Uso: $0 [up|dns]"
    echo "  up  — build, run, aguarda SAML e configura split-DNS (padrão)"
    echo "  dns — reaplica split-DNS se VPN já conectada"
    exit 1
    ;;
esac

log "Subindo $CONTAINER_NAME..."
build_image
run_vpn_container

wait_for_tunnel 300
apply_post_connect_config "$SCRIPT_DIR"

echo ""
echo "========================================"
echo "  client-checkpoint-vpn ativo"
echo "========================================"
echo "  Container:  $CONTAINER_NAME"
echo "  Imagem:     $VPN_IMAGE"
echo "  Túnel:      $TUN_IF"
echo "  DNS:        $VPN_DNS ($VPN_SEARCH_DOMAIN)"
echo ""
echo "  Teste:      curl -I https://gitlab.intranet.mpgo/users/sign_in"
echo "  Logs:       docker logs -f $CONTAINER_NAME"
echo "  Re-DNS:     $0 dns"
echo "  Desligar:   $SCRIPT_DIR/vpn-down.sh"
echo "========================================"
