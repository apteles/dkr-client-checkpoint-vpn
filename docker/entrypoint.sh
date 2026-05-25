#!/bin/bash
set -euo pipefail

TUN_IF="${TUN_IF:-snx-tun}"
VPN_NO_DNS="${VPN_NO_DNS:-true}"
VPN_ALLOW_FORWARDING="${VPN_ALLOW_FORWARDING:-false}"

echo "========================================"
echo "    client-checkpoint-vpn              "
echo "========================================"

if [ -z "${VPN_SERVER:-}" ]; then
  echo "[ERRO] VPN_SERVER não definida."
  exit 1
fi

if [ -z "${VPN_LOGIN_TYPE:-}" ]; then
  echo "[ERRO] VPN_LOGIN_TYPE não definida."
  exit 1
fi

echo "[*] Servidor: $VPN_SERVER"
echo "[*] Login type: $VPN_LOGIN_TYPE"
echo "[*] Interface túnel: $TUN_IF"
echo "[*] DNS pelo snx-rs: $([ "$VPN_NO_DNS" = "true" ] && echo "não" || echo "sim")"
echo "[*] Forwarding pelo snx-rs: $VPN_ALLOW_FORWARDING"
echo "----------------------------------------"

wait_for_tun() {
  local timeout=300
  local elapsed=0

  while ! ip link show "$TUN_IF" &>/dev/null; do
    sleep 1
    elapsed=$((elapsed + 1))
    if [ "$elapsed" -ge "$timeout" ]; then
      echo "[ERRO] Timeout aguardando interface $TUN_IF."
      echo "[*] Complete a autenticação SAML se ainda não o fez."
      return 1
    fi
  done
}

cleanup() {
  local pid="${SNX_PID:-}"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

echo "[*] Iniciando snx-rs (SSL)..."
echo "[*] OTP SAML escuta em 127.0.0.1:7779"
snx-rs -s "$VPN_SERVER" -o "$VPN_LOGIN_TYPE" -e ssl \
  --if-name "$TUN_IF" \
  --default-route false \
  --no-dns "$VPN_NO_DNS" \
  --allow-forwarding "$VPN_ALLOW_FORWARDING" \
  --log-level info &
SNX_PID=$!

wait_for_tun
echo "[*] Túnel $TUN_IF ativo."

wait "$SNX_PID"
