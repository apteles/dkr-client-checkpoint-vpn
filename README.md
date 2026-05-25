# client-checkpoint-vpn

Cliente Check Point VPN para MPGO usando [snx-rs](https://github.com/ancwrd1/snx-rs) em container Docker. O container roda em `--network host --privileged`, replicando o comportamento do comando local `sudo snx-rs`, com split-DNS configurado no host após a conexão.

## Arquitetura

```
Host (Arch/Ubuntu)                    Container Docker
┌─────────────────────┐              ┌──────────────────────┐
│  apps / browser     │              │  snx-rs (SSL)        │
│  rotas no host      │◀ host net ──▶│  interface snx-tun   │
│  split-DNS          │   privileged │                      │
└─────────────────────┘              └──────────┬───────────┘
                                                │
                                                ▼
                                     mpsec.mpgo.mp.br (VPN MPGO)
```

## Requisitos

- Arch Linux ou Ubuntu (Debian derivados compatíveis)
- Docker
- `systemd-resolved` (para split-DNS)
- `sudo` para configurar DNS no host

## Instalação rápida

```bash
curl -fsSL https://raw.githubusercontent.com/<org>/client-checkpoint-vpn/main/install.sh | bash
```

Com parâmetros:

```bash
VPN_SERVER=mpsec.mpgo.mp.br \
VPN_LOGIN_TYPE=vpn_VPN_STI \
curl -fsSL https://raw.githubusercontent.com/<org>/client-checkpoint-vpn/main/install.sh | bash
```

O script clona o repositório em `~/.local/share/client-checkpoint-vpn`, instala pré-requisitos e imprime os próximos passos.

## Uso via clone do repositório

### 1. Pré-requisitos

**Arch Linux:**

```bash
./scripts/host-setup-arch.sh
```

**Ubuntu / Debian:**

```bash
./scripts/host-setup-ubuntu.sh
```

### 2. Configuração

```bash
cp config/vpn.env.example config/vpn.env
# Edite config/vpn.env se necessário
```

### 3. Conectar

```bash
./scripts/vpn-up.sh
```

O script gera a imagem `client-checkpoint-vpn:latest`, inicia o container e aguarda o túnel `snx-tun`.

### 4. Autenticação SAML

```bash
docker logs -f client-checkpoint-vpn
```

Abra a URL SAML no navegador. O callback OTP vai para `127.0.0.1:7779`.

### 5. Desligar

```bash
./scripts/vpn-down.sh
```

## Uso manual com Docker

Build:

```bash
docker build --network=host -t client-checkpoint-vpn:latest docker
```

> Use `--network=host` no build se o Docker não resolver DNS durante `apt-get`.

Run interativo:

```bash
docker run --rm -it \
  --name client-checkpoint-vpn \
  --network host \
  --privileged \
  -e VPN_SERVER=mpsec.mpgo.mp.br \
  -e VPN_LOGIN_TYPE=vpn_VPN_STI \
  -e TUN_IF=snx-tun \
  -e VPN_NO_DNS=true \
  -e VPN_ALLOW_FORWARDING=false \
  client-checkpoint-vpn:latest
```

Com arquivo de configuração:

```bash
docker run --rm -it \
  --name client-checkpoint-vpn \
  --network host \
  --privileged \
  --env-file config/vpn.env \
  client-checkpoint-vpn:latest
```

Após conectar manualmente, aplique split-DNS no host:

```bash
sudo ./scripts/vpn-dns.sh up
```

## Configuração (`config/vpn.env`)

| Variável | Descrição | Valor padrão |
|----------|-----------|--------------|
| `VPN_SERVER` | Servidor Check Point | `mpsec.mpgo.mp.br` |
| `VPN_LOGIN_TYPE` | Tipo de login | `vpn_VPN_STI` |
| `TUN_IF` | Interface do túnel SSL | `snx-tun` |
| `CONTAINER_NAME` | Nome do container Docker | `client-checkpoint-vpn` |
| `VPN_IMAGE` | Imagem Docker local | `client-checkpoint-vpn:latest` |
| `VPN_NO_DNS` | Impede o snx-rs de escrever DNS no container | `true` |
| `VPN_ALLOW_FORWARDING` | Repassa `--allow-forwarding` ao snx-rs | `false` |
| `VPN_DNS` | Servidor DNS interno (split-DNS no host) | `10.234.11.11` |
| `VPN_SEARCH_DOMAIN` | Domínio split-DNS | `intranet.mpgo` |

O container usa `--network host --privileged` porque o `snx-rs` precisa configurar `snx-tun`, rotas e callback SAML diretamente no namespace de rede do host. Sem `--privileged`, ocorre erro `Read-only file system` após o OTP.

O split-DNS (`intranet.mpgo` → `10.234.11.11`) é aplicado no host pelo `vpn-up.sh` após o túnel subir.

## Validação

```bash
ip link show snx-tun
ip route show dev snx-tun
ip route show table 18000
resolvectl status snx-tun
curl -I https://gitlab.intranet.mpgo/users/sign_in
```

## Troubleshooting

### `Unable to acquire OTP from the browser`

- Complete a autenticação SAML nos logs: `docker logs -f client-checkpoint-vpn`
- Confirme que a porta 7779 está livre: `ss -tlnp | grep 7779`

### `Read-only file system` após OTP

Use `--privileged` (já é o padrão em `vpn-up.sh`).

### Timeout aguardando `snx-tun`

- Verifique se completou o SAML
- Se interrompeu o `vpn-up.sh` após conectar, reaplique DNS: `./scripts/vpn-up.sh dns`

### GitLab / intranet não abre

1. Confirme túnel: `ip link show snx-tun`
2. Reaplique DNS: `./scripts/vpn-up.sh dns`
3. Teste DNS: `dig +short gitlab.intranet.mpgo`
4. Teste rota: `ip route get $(dig +short gitlab.intranet.mpgo | head -1)`

### Erro de certificado TLS

Adicione ao `docker/entrypoint.sh` (não recomendado em produção):

```bash
--ignore-server-cert true
```

## Limitações

- Túnel SSL (mais lento que IPSec)
- Autenticação SAML manual a cada sessão
- Split-DNS depende de `systemd-resolved`
- Container precisa permanecer em execução enquanto usa a VPN

## Segurança

- **Nunca** commite `config/vpn.env` (está no `.gitignore`)
- `--privileged` concede acesso amplo ao host — use apenas em máquinas confiáveis
- Credenciais SAML são gerenciadas pelo IdP

## Estrutura do repositório

```
├── install.sh
├── config/
│   └── vpn.env.example
├── docker/
│   ├── Dockerfile
│   └── entrypoint.sh
├── scripts/
│   ├── lib/common.sh
│   ├── host-setup-arch.sh
│   ├── host-setup-ubuntu.sh
│   ├── vpn-up.sh
│   ├── vpn-down.sh
│   └── vpn-dns.sh
└── README.md
```

## Referências

- [snx-rs](https://github.com/ancwrd1/snx-rs)
- [Repositório APT snx-rs](https://ancwrd1.github.io/snx-rs/)
