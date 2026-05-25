# Stage 1: Builder (Ubuntu)
FROM ubuntu:24.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
    && curl -fsSL -o /etc/apt/sources.list.d/snx-rs.sources \
       https://ancwrd1.github.io/snx-rs/snx-rs.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends snx-rs \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: Runtime
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    iproute2 \
    procps \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

COPY --from=builder /usr/bin/snx-rs /usr/local/bin/snx-rs

ENV TUN_IF=snx-tun

WORKDIR /vpn
COPY entrypoint.sh /vpn/entrypoint.sh
RUN chmod +x /vpn/entrypoint.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD ip link show snx-tun || exit 1

ENTRYPOINT ["/vpn/entrypoint.sh"]
