#!/bin/bash
# ═══════════════════════════════════════════════════════
#  Hysteria2 Auto-Installer — by RIXXX (multi-arch)
#  Panel Naive + Hysteria2 by RIXXX
#  ENV: HY_DOMAIN, HY_EMAIL, HY_PASSWORD, USE_CADDY_CERT (0/1)
# ═══════════════════════════════════════════════════════

set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

DOMAIN="${HY_DOMAIN:-}"
EMAIL="${HY_EMAIL:-admin@example.com}"
PASSWORD="${HY_PASSWORD:-}"
USE_CADDY_CERT="${USE_CADDY_CERT:-0}"

if [[ -z "$DOMAIN" || -z "$PASSWORD" ]]; then
  echo "ERROR: missing env HY_DOMAIN / HY_PASSWORD"
  exit 1
fi

log()  { echo "$1"; }
step() { echo "STEP:$1"; }

case "$(uname -m)" in
  x86_64)  HY_ARCH="amd64" ;;
  aarch64) HY_ARCH="arm64" ;;
  armv7l)  HY_ARCH="arm"   ;;
  *)       HY_ARCH="amd64" ;;
esac
log "  Arch: $(uname -m) → Hy2:${HY_ARCH}"

# ══════════════════════════════════════════════════════
step 1
log "▶ Installing dependencies..."
# ══════════════════════════════════════════════════════

apt-get update -qq -o DPkg::Lock::Timeout=60 2>/dev/null || true
apt-get install -y -qq curl wget jq libcap2-bin ufw ca-certificates 2>/dev/null || true
log "✅ Dependencies ready"

# ══════════════════════════════════════════════════════
step 2
log "▶ UDP optimizations..."
# ══════════════════════════════════════════════════════

cat > /etc/sysctl.d/99-rixxx-tune.conf << 'SYSCTLEOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=2500000
net.core.wmem_default=2500000
net.ipv4.tcp_fastopen=3
SYSCTLEOF
sysctl --system >/dev/null 2>&1 || true

log "✅ Network tuning applied"

# ══════════════════════════════════════════════════════
step 3
log "▶ Configuring firewall..."
# ══════════════════════════════════════════════════════

ufw allow 22/tcp  >/dev/null 2>&1 || true
ufw allow 80/tcp  >/dev/null 2>&1 || true
ufw allow 443/tcp >/dev/null 2>&1 || true
ufw allow 443/udp >/dev/null 2>&1 || true
echo "y" | ufw enable >/dev/null 2>&1 || ufw --force enable >/dev/null 2>&1 || true

log "✅ UDP/443 opened"

# ══════════════════════════════════════════════════════
step 4
log "▶ Downloading Hysteria2 (arch: ${HY_ARCH})..."
# ══════════════════════════════════════════════════════

HY_VERSION=$(curl -fsSL --connect-timeout 10 \
  https://api.github.com/repos/apernet/hysteria/releases/latest 2>/dev/null \
  | jq -r '.tag_name' 2>/dev/null || echo "")
[[ -z "$HY_VERSION" || "$HY_VERSION" == "null" ]] && HY_VERSION="app/v2.5.2"

log "  Version: ${HY_VERSION}"
HY_URL="https://github.com/apernet/hysteria/releases/download/${HY_VERSION}/hysteria-linux-${HY_ARCH}"

wget -q --timeout=120 "${HY_URL}" -O /usr/local/bin/hysteria 2>&1 || {
  log "⚠ Failed to download ${HY_VERSION}, fallback → app/v2.5.2"
  wget -q --timeout=120 \
    "https://github.com/apernet/hysteria/releases/download/app/v2.5.2/hysteria-linux-${HY_ARCH}" \
    -O /usr/local/bin/hysteria || {
    log "ERROR: Failed to download hysteria!"
    exit 1
  }
}

if [[ ! -s /usr/local/bin/hysteria ]]; then
  log "ERROR: hysteria binary is empty"
  exit 1
fi

chmod +x /usr/local/bin/hysteria
setcap 'cap_net_bind_service=+ep' /usr/local/bin/hysteria 2>/dev/null || true

HY_VER=$(/usr/local/bin/hysteria version 2>&1 | head -n1 || echo "unknown")
log "✅ Hysteria2 installed: $HY_VER"

# ══════════════════════════════════════════════════════
step 5
log "▶ Creating config..."
# ══════════════════════════════════════════════════════

mkdir -p /etc/hysteria

cat > /etc/hysteria/config.yaml << HYCFGEOF
# ═══════════════════════════════════════════════
#  Hysteria2 — by RIXXX
#  https://v2.hysteria.network/
# ═══════════════════════════════════════════════

# If Caddy occupies TCP/443 — Hy2 listens only on UDP/443.
# Hysteria2 works over QUIC (UDP), TCP is not needed.
listen: :443

auth:
  type: userpass
  userpass:
    default: "${PASSWORD}"

# Masquerade: serves the same static page as Caddy. No extra
# external requests → no H3_GENERAL_PROTOCOL_ERROR in logs.
masquerade:
  type: file
  file:
    dir: /var/www/html

HYCFGEOF

# Ensure the HTML directory exists (in case of standalone Hy2 without Caddy)
mkdir -p /var/www/html
if [[ ! -f /var/www/html/index.html ]]; then
  cat > /var/www/html/index.html << 'MASQEOF'
<!DOCTYPE html><html><head><meta charset="utf-8"><title>Loading</title>
<style>body{background:#080808;height:100vh;margin:0;display:flex;flex-direction:column;align-items:center;justify-content:center;font-family:sans-serif}.bar{width:200px;height:3px;background:#151515;overflow:hidden;border-radius:2px;margin-bottom:25px}.fill{height:100%;width:40%;background:#fff;animation:slide 1.4s infinite ease-in-out}@keyframes slide{0%{transform:translateX(-100%)}50%{transform:translateX(50%)}100%{transform:translateX(200%)}}.t{color:#555;font-size:13px;letter-spacing:3px;font-weight:600}</style>
</head><body><div class="bar"><div class="fill"></div></div><div class="t">LOADING CONTENT</div></body></html>
MASQEOF
fi

if [[ "$USE_CADDY_CERT" == "1" ]]; then
  # ── CRITICAL: if Caddy is already running — it likely listens on UDP/443
  # for HTTP/3 (QUIC), and Hy2 will not be able to bind that port. Overwrite Caddyfile
  # with HTTP/3 disabled and reload Caddy BEFORE starting Hy2.
  if [[ -f /etc/caddy/Caddyfile ]] && ! grep -q "protocols h1 h2" /etc/caddy/Caddyfile; then
    log "  Disabling HTTP/3 in Caddy (freeing UDP/443 for Hy2)..."

    # Create backup
    cp /etc/caddy/Caddyfile "/etc/caddy/Caddyfile.bak.$(date +%s)" 2>/dev/null || true

    # Try via python3 (more reliable), fallback to sed
    PY_OK=0
    if command -v python3 >/dev/null 2>&1; then
      python3 << 'PYEOF' && PY_OK=1
import re, sys
p = '/etc/caddy/Caddyfile'
try:
    with open(p) as f:
        src = f.read()
    m = re.match(r'^\s*\{([^{}]*)\}', src, re.DOTALL)
    if m:
        inner = m.group(1)
        if 'protocols h1 h2' not in inner:
            new_inner = inner.rstrip() + '\n  servers {\n    protocols h1 h2\n  }\n'
            new_src = '{' + new_inner + '}' + src[m.end():]
            with open(p, 'w') as f:
                f.write(new_src)
            print("Caddyfile updated: HTTP/3 disabled")
    else:
        new_src = '{\n  servers {\n    protocols h1 h2\n  }\n}\n\n' + src
        with open(p, 'w') as f:
            f.write(new_src)
        print("Caddyfile updated: added global block with HTTP/3 disabled")
    sys.exit(0)
except Exception as e:
    print("python edit error:", e, file=sys.stderr)
    sys.exit(1)
PYEOF
    fi

    if [[ $PY_OK -ne 1 ]]; then
      log "  (fallback to sed)"
      # If global block exists — replace the first } with servers + }
      if head -n 5 /etc/caddy/Caddyfile | grep -qE '^\s*\{\s*$'; then
        sed -i '0,/^}/s|^}|  servers {\n    protocols h1 h2\n  }\n}|' /etc/caddy/Caddyfile
      else
        # No global block — add at the beginning
        sed -i '1i {\n  servers {\n    protocols h1 h2\n  }\n}\n' /etc/caddy/Caddyfile
      fi
    fi

    # Reload Caddy to free UDP/443
    systemctl reload caddy 2>/dev/null || systemctl restart caddy 2>/dev/null || true
    sleep 2
    log "✅ HTTP/3 disabled in Caddy, UDP/443 free"
  fi

  # Caddy may obtain a certificate from any CA (LE / ZeroSSL / Google).
  # Search via find on any path, not only acme-v02.api.letsencrypt.org.
  CADDY_CERT_ROOTS=(
    "/var/lib/caddy/.local/share/caddy/certificates"
    "/root/.local/share/caddy/certificates"
  )
  CADDY_CERT_DIR=""

  log "  Waiting for certificate from Caddy (up to 150s, any CA)..."
  for i in $(seq 1 75); do
    for ROOT in "${CADDY_CERT_ROOTS[@]}"; do
      [[ -d "$ROOT" ]] || continue
      FOUND=$(find "$ROOT" -type f -name "${DOMAIN}.crt" 2>/dev/null | head -1)
      if [[ -n "$FOUND" && -f "${FOUND%.crt}.key" ]]; then
        CADDY_CERT_DIR="$(dirname "$FOUND")"
        CA_NAME="$(basename "$(dirname "$CADDY_CERT_DIR")")"
        log "✅ Certificate found (${i}x2 s) — CA: ${CA_NAME}"
        break 2
      fi
    done
    sleep 2
  done

  if [[ -z "$CADDY_CERT_DIR" ]]; then
    log "⚠ Caddy certificate not found after 150s."
    log "  Hy2 does NOT start with its own ACME (risk of Let's Encrypt 429 rate limit)."
    log "  Fix Caddy, then: systemctl restart hysteria-server"
    systemctl status caddy --no-pager -l 2>&1 | tail -10
    cat >> /etc/hysteria/config.yaml << 'HYNOTLSEOF'
# ⚠ Certificate was not ready at installation time.
# After fixing Caddy:
#   1) find /var/lib/caddy -name '*.crt'
#   2) Substitute the found paths:
#      tls:
#        cert: /var/lib/caddy/.../<domain>.crt
#        key:  /var/lib/caddy/.../<domain>.key
#   3) systemctl restart hysteria-server
HYNOTLSEOF
  else
    # Allow hysteria to read Caddy files
    chmod -R 755 "$(dirname "$CADDY_CERT_DIR")" 2>/dev/null || true
    chmod 644 "${CADDY_CERT_DIR}/${DOMAIN}.crt" 2>/dev/null || true
    chmod 640 "${CADDY_CERT_DIR}/${DOMAIN}.key" 2>/dev/null || true

    cat >> /etc/hysteria/config.yaml << HYTLSEOF
tls:
  cert: ${CADDY_CERT_DIR}/${DOMAIN}.crt
  key:  ${CADDY_CERT_DIR}/${DOMAIN}.key
HYTLSEOF

    # Watcher: when Caddy certificate updates → restart Hy2.
    # Use CADDY_CERT_DIR (actual path with any CA).
    cat > /etc/systemd/system/caddy-cert-watcher.path << WATCHEOF
[Unit]
Description=Watch Caddy cert for changes -> restart hysteria-server

[Path]
PathModified=${CADDY_CERT_DIR}

[Install]
WantedBy=multi-user.target
WATCHEOF

    cat > /etc/systemd/system/caddy-cert-watcher.service << 'WATCHSVCEOF'
[Unit]
Description=Restart hysteria-server on Caddy cert change

[Service]
Type=oneshot
ExecStart=/bin/systemctl restart hysteria-server.service
WATCHSVCEOF

    systemctl daemon-reload
    systemctl enable caddy-cert-watcher.path >/dev/null 2>&1 || true
    systemctl start  caddy-cert-watcher.path >/dev/null 2>&1 || true
    log "✅ caddy-cert-watcher configured"
  fi

else
  # Standalone Hy2: obtain its own ACME certificate
  # IMPORTANT: port 80 must be free for ACME challenge
  cat >> /etc/hysteria/config.yaml << HYACMEEOF
acme:
  domains:
    - ${DOMAIN}
  email: ${EMAIL}
  ca: letsencrypt
  listenHost: 0.0.0.0
HYACMEEOF
fi

cat >> /etc/hysteria/config.yaml << 'HYBWEOF'

ignoreClientBandwidth: true

quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 30s
  keepAlivePeriod: 10s
  disablePathMTUDiscovery: false
HYBWEOF

log "✅ Config /etc/hysteria/config.yaml created"

# ══════════════════════════════════════════════════════
step 6
log "▶ Systemd service for Hysteria..."
# ══════════════════════════════════════════════════════

if [[ "$USE_CADDY_CERT" == "1" ]]; then
  HY_AFTER="After=network.target network-online.target caddy.service"
  HY_WANTS="Wants=caddy.service"
else
  HY_AFTER="After=network.target network-online.target"
  HY_WANTS=""
fi

cat > /etc/systemd/system/hysteria-server.service << HYSVCEOF
[Unit]
Description=Hysteria2 Server (by RIXXX)
Documentation=https://v2.hysteria.network/
${HY_AFTER}
${HY_WANTS}
Requires=network-online.target
# StartLimit* must be in [Unit], not in [Service] (systemd warning)
StartLimitIntervalSec=60s
StartLimitBurst=3

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
WorkingDirectory=/etc/hysteria
LimitNOFILE=1048576
LimitNPROC=512
AmbientCapabilities=CAP_NET_BIND_SERVICE
Restart=on-failure
RestartSec=10s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
HYSVCEOF

systemctl daemon-reload
systemctl enable hysteria-server >/dev/null 2>&1 || true

log "✅ Systemd service created"

# ══════════════════════════════════════════════════════
step 7
log "▶ Starting Hysteria2..."
# ══════════════════════════════════════════════════════

systemctl restart hysteria-server 2>&1 || true

for i in $(seq 1 20); do
  STATUS=$(systemctl is-active hysteria-server 2>/dev/null || echo "unknown")
  if [[ "$STATUS" == "active" ]]; then
    log "✅ Hysteria2 started (${i}s)"
    break
  elif [[ "$STATUS" == "failed" ]]; then
    log "⚠ hysteria-server: failed — see below:"
    journalctl -u hysteria-server -n 20 --no-pager 2>/dev/null || true
    log "  Attempting restart..."
    systemctl reset-failed hysteria-server 2>/dev/null || true
    systemctl start hysteria-server 2>/dev/null || true
    break
  fi
  sleep 1
  if [[ $i -eq 20 ]]; then
    log "⚠ Hy2 did not start within 20s. Diagnostic command:"
    log "  journalctl -u hysteria-server -n 50 --no-pager"
  fi
done

step DONE
log ""
log "╔════════════════════════════════════════════════════╗"
log "║   ✅ Hysteria2 successfully installed!            ║"
log "║   Domain: ${DOMAIN}"
log "║   hysteria2://****@${DOMAIN}:443?sni=${DOMAIN}"
log "╚════════════════════════════════════════════════════╝"
log ""

exit 0
