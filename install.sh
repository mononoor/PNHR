#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════
#  Panel Naive + Hysteria2 by RIXXX — Full installer
#  Installs: control panel + NaiveProxy (Caddy) + Hysteria2
#  Run:
#    bash <(curl -fsSL https://raw.githubusercontent.com/cwash797-cmd/Panel---Naive-Hy2---by---RIXXX/main/install.sh)
#  Requirements: Ubuntu 22.04 / 24.04 / Debian 11+ / root / amd64|arm64|armv7
# ═══════════════════════════════════════════════════════════════════════

set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

REPO_URL="https://github.com/cwash797-cmd/Panel---Naive-Hy2---by---RIXXX"
REPO_BRANCH="${REPO_BRANCH:-main}"
PANEL_DIR="/opt/panel-naive-hy2"
SERVICE_NAME="panel-naive-hy2"
INTERNAL_PORT=3000

# ── Colors ──────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'
BOLD='\033[1m'; RESET='\033[0m'

header() {
  clear
  echo ""
  echo -e "${PURPLE}${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${PURPLE}${BOLD}║   Panel Naive + Hysteria2 by RIXXX — Installer          ║${RESET}"
  echo -e "${PURPLE}${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

log_step() { echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"; }
log_ok()   { echo -e "${GREEN}✅ $1${RESET}"; }
log_warn() { echo -e "${YELLOW}⚠  $1${RESET}"; }
log_err()  { echo -e "${RED}❌ $1${RESET}"; }
log_info() { echo -e "   ${BLUE}$1${RESET}"; }

header

# ── Root check ──────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  log_err "Run the script as root: sudo bash install.sh"
  exit 1
fi

# ── OS check ────────────────────────────────────────────────────────────
if ! command -v apt-get &>/dev/null; then
  log_err "Only Ubuntu/Debian (apt-based) are supported"
  log_info "If you have CentOS/RHEL/Fedora/Alpine — use a different VPS system"
  exit 1
fi

# Detect distribution
OS_ID=""; OS_VER=""; OS_CODENAME=""
if [[ -f /etc/os-release ]]; then
  OS_ID=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
  OS_VER=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
  OS_CODENAME=$(grep -E '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
fi
log_info "OS: ${OS_ID:-unknown} ${OS_VER:-?} (${OS_CODENAME:-?})"

# Recommend Ubuntu 22.04/24.04 and Debian 11/12
case "$OS_ID" in
  ubuntu)
    case "$OS_VER" in
      22.04|24.04) : ;;
      20.04) log_warn "Ubuntu 20.04 — works, but 22.04+ is recommended (newer kernel)" ;;
      *) log_warn "Ubuntu $OS_VER — non‑standard version, may have surprises" ;;
    esac ;;
  debian)
    case "$OS_VER" in
      11|12) : ;;
      *) log_warn "Debian $OS_VER — recommended: 11 (bullseye) or 12 (bookworm)" ;;
    esac ;;
  *)
    log_warn "Distribution '$OS_ID' is not officially tested, but if apt works — we'll try."
    log_info "Supported: Ubuntu 22.04/24.04, Debian 11/12 (amd64/arm64)."
    ;;
esac

# Check kernel version for BBR (>=4.9)
KERNEL_MAJ=$(uname -r | awk -F. '{print $1}')
KERNEL_MIN=$(uname -r | awk -F. '{print $2}')
if [[ "${KERNEL_MAJ}" -lt 4 ]] || { [[ "${KERNEL_MAJ}" -eq 4 ]] && [[ "${KERNEL_MIN}" -lt 9 ]]; }; then
  log_warn "Kernel $(uname -r) < 4.9 — BBR unavailable, TCP speed will be worse"
fi

# ── Arch detection ──────────────────────────────────────────────────────
MACHINE_ARCH="$(uname -m)"
case "$MACHINE_ARCH" in
  x86_64)  GO_ARCH="amd64";  HY_ARCH="amd64"  ;;
  aarch64) GO_ARCH="arm64";  HY_ARCH="arm64"  ;;
  armv7l)  GO_ARCH="armv6l"; HY_ARCH="arm"    ;;
  *)       log_warn "Unknown architecture ${MACHINE_ARCH}, using amd64"
           GO_ARCH="amd64";  HY_ARCH="amd64"  ;;
esac
log_info "Architecture: ${MACHINE_ARCH} → Go:${GO_ARCH} Hy2:${HY_ARCH}"

# ── IP detection ────────────────────────────────────────────────────────
SERVER_IP=$(curl -4 -s --connect-timeout 8 ifconfig.me 2>/dev/null \
  || curl -4 -s --connect-timeout 8 icanhazip.com 2>/dev/null \
  || hostname -I | awk '{print $1}')

echo -e "   ${BLUE}Server IP: ${BOLD}${SERVER_IP}${RESET}"
echo ""

# ════════════════════════════════════════════════════════════════════════
# SECTION A — INTERACTIVE SETTINGS
# ════════════════════════════════════════════════════════════════════════

# ── A1. Choose stack ─────────────────────────────────────────────────────
echo -e "${BOLD}Which protocols to install?${RESET}"
echo ""
echo -e "  ${CYAN}1)${RESET} ${BOLD}NaiveProxy${RESET} (TCP/443, masquerading as HTTPS)"
echo -e "  ${CYAN}2)${RESET} ${BOLD}Hysteria2${RESET}  (UDP/443, QUIC, maximum speed)"
echo -e "  ${CYAN}3)${RESET} ${BOLD}Both at once${RESET}    ${GREEN}(recommended — one domain, one certificate)${RESET}"
echo ""
read -rp "Your choice [1/2/3]: " STACK_MODE
STACK_MODE="${STACK_MODE:-3}"

case "$STACK_MODE" in
  1) INSTALL_NAIVE=1; INSTALL_HY2=0 ;;
  2) INSTALL_NAIVE=0; INSTALL_HY2=1 ;;
  *) INSTALL_NAIVE=1; INSTALL_HY2=1 ;;
esac

# ── A2. Panel access method ─────────────────────────────────────────────
echo ""
echo -e "${BOLD}Access method for the control panel:${RESET}"
echo ""
echo -e "  ${CYAN}1)${RESET} Via Nginx on port ${BOLD}8080${RESET} ${GREEN}(recommended — port 3000 not exposed)${RESET}"
echo -e "  ${CYAN}2)${RESET} Directly on port ${BOLD}3000${RESET} (simpler, but port is visible)"
echo -e "  ${CYAN}3)${RESET} On a ${BOLD}separate subdomain${RESET} + HTTPS (maximum security)"
echo -e "      ${YELLOW}→ you need a SEPARATE subdomain for the panel (not the same as the proxy)${RESET}"
echo ""
read -rp "Your choice [1/2/3]: " ACCESS_MODE
ACCESS_MODE="${ACCESS_MODE:-1}"

PANEL_DOMAIN=""
PANEL_EMAIL_SSL=""
if [[ "$ACCESS_MODE" == "3" ]]; then
  echo ""
  echo -e "${YELLOW}  ⚠  This must be a DIFFERENT subdomain, not the one where NaiveProxy/Hy2 runs.${RESET}"
  echo -e "${YELLOW}     The A record of the subdomain must point to ${SERVER_IP}${RESET}"
  echo ""
  read -rp "  Subdomain for the panel (e.g. panel.yourdomain.com): " PANEL_DOMAIN
  read -rp "  Email for Let's Encrypt (SSL for panel): " PANEL_EMAIL_SSL
fi

# ── A2.1. SSH-only mode (panel accessible only via SSH tunnel) ──────────
echo ""
echo -e "${BOLD}Make the panel accessible only via SSH tunnel?${RESET}"
echo -e "  ${YELLOW}→ The panel will bind to 127.0.0.1:${INTERNAL_PORT:-3000} and will not be visible from the Internet.${RESET}"
echo -e "  ${YELLOW}→ For access: ${BOLD}ssh -L 8080:127.0.0.1:${INTERNAL_PORT:-3000} root@${SERVER_IP}${RESET}${YELLOW}, then http://localhost:8080${RESET}"
echo -e "  ${YELLOW}→ This is maximum protection: the panel cannot be brute‑forced from outside.${RESET}"
echo ""
read -rp "Enable SSH-only mode? [y/N]: " _SSH_ONLY
SSH_ONLY="0"
LISTEN_HOST="0.0.0.0"
if [[ "${_SSH_ONLY,,}" == "y" || "${_SSH_ONLY,,}" == "yes" ]]; then
  SSH_ONLY="1"
  LISTEN_HOST="127.0.0.1"
  log_info "SSH-only mode enabled: panel will listen only on 127.0.0.1"
  # SSH-only is incompatible with Nginx proxy on 8080: nginx would bind to 0.0.0.0
  # and an UFW-allow would open the port externally. Force switch to direct
  # bind on 127.0.0.1:3000 (accessible only locally / via SSH tunnel).
  if [[ "$ACCESS_MODE" == "1" ]]; then
    log_info "SSH-only + Nginx(8080) are incompatible — skipping Nginx,"
    log_info "panel will listen only on 127.0.0.1:${INTERNAL_PORT:-3000}."
    ACCESS_MODE="2"
  fi
  if [[ "$ACCESS_MODE" == "3" ]]; then
    echo ""
    echo -e "${YELLOW}  ⚠  ACCESS_MODE=3 + SSH-only:${RESET}"
    echo -e "${YELLOW}     Subdomain ${PANEL_DOMAIN} will NOT be added to Caddyfile,${RESET}"
    echo -e "${YELLOW}     the panel will be accessible ONLY via SSH tunnel.${RESET}"
    echo -e "${YELLOW}     To restore public access later:${RESET}"
    echo -e "${BOLD}        bash update.sh --expose ${PANEL_DOMAIN}${RESET}"
    echo ""
    read -rp "Continue? [y/N]: " _CONFIRM_SSH3
    if [[ "${_CONFIRM_SSH3,,}" != "y" && "${_CONFIRM_SSH3,,}" != "yes" ]]; then
      log_info "Cancelled by user."
      exit 1
    fi
  fi
fi

# ── A3. Proxy parameters ────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Proxy parameters:${RESET}"
echo -e "${YELLOW}  ⚠  Make sure the A record of the domain points to ${SERVER_IP}${RESET}"
echo ""
read -rp "  Domain (e.g. vpn.yourdomain.com): " PROXY_DOMAIN
read -rp "  Email for Let's Encrypt (TLS): " PROXY_EMAIL

# ── A4. Masquerade (domain camouflage) ──────────────────────────────────
echo ""
echo -e "${BOLD}🎭 Masquerade (domain camouflage):${RESET}"
echo ""
echo -e "  ${CYAN}1)${RESET} Local ${BOLD}«Loading»${RESET} page ${GREEN}(reliable, no external dependencies)${RESET}"
echo -e "      ${YELLOW}→ Simple static HTML page, always works.${RESET}"
echo -e "  ${CYAN}2)${RESET} ${BOLD}Mirroring${RESET} an external site (reverse_proxy)"
echo -e "      ${YELLOW}→ Caddy and Hy2 will serve the content of the specified URL.${RESET}"
echo -e "      ${RED}⚠  If the site becomes unavailable — visitors will get a 502.${RESET}"
echo -e "      ${YELLOW}→ Recommended: https://www.iana.org, https://www.ietf.org, https://demo.nginx.com${RESET}"
echo ""
read -rp "Your choice [1/2, default 1]: " MASQUERADE_MODE_INPUT
MASQUERADE_MODE_INPUT="${MASQUERADE_MODE_INPUT:-1}"
MASQUERADE_MODE="local"
MASQUERADE_URL=""
if [[ "$MASQUERADE_MODE_INPUT" == "2" ]]; then
  echo ""
  echo -e "${RED}${BOLD}⚠  WARNING:${RESET} ${RED}Large sites (GitHub, Apple, Cloudflare, etc.) block${RESET}"
  echo -e "   ${RED}using them as a dummy — NaiveProxy clients will get 502 / EOF.${RESET}"
  echo -e "   ${YELLOW}We recommend small static sites or your own subdomain.${RESET}"
  echo ""
  read -rp "  URL for mirroring (e.g. https://www.iana.org): " MASQUERADE_URL
  if [[ ! "$MASQUERADE_URL" =~ ^https?:// ]]; then
    log_warn "URL must start with http:// or https://. Using default https://www.iana.org"
    MASQUERADE_URL="https://www.iana.org"
  fi
  MASQUERADE_MODE="mirror"
  log_info "Masquerade: mirroring ${MASQUERADE_URL}"
else
  log_info "Masquerade: local «Loading» page"
fi

# Verify that the panel domain (if set) differs from the proxy domain.
if [[ "$ACCESS_MODE" == "3" && -n "$PANEL_DOMAIN" && "$PANEL_DOMAIN" == "$PROXY_DOMAIN" ]]; then
  log_err "Panel subdomain (${PANEL_DOMAIN}) matches the proxy domain (${PROXY_DOMAIN})!"
  log_info "Both would listen on 443/tcp via Caddy — that's a conflict."
  log_info "Specify different subdomains, e.g. vpn.example.com (proxy) and panel.example.com (panel)."
  exit 1
fi

# Generate credentials
NAIVE_LOGIN=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 16)
NAIVE_PASS=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 24)
HY2_PASS=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 24)

echo ""
echo -e "${GREEN}  ✅ Generated credentials:${RESET}"
[[ $INSTALL_NAIVE -eq 1 ]] && {
  log_info "NaiveProxy → ${NAIVE_LOGIN} : ${NAIVE_PASS}"
}
[[ $INSTALL_HY2 -eq 1 ]] && {
  log_info "Hysteria2  → password: ${HY2_PASS}"
}
echo ""
echo -e "${YELLOW}  ⚠  Remember these credentials! They will also be shown at the end.${RESET}"
echo ""
read -rp "Everything correct? Start installation? [Enter / Ctrl+C to cancel]: " _CONFIRM

echo ""

# ════════════════════════════════════════════════════════════════════════
# SECTION B — INSTALLATION
# ════════════════════════════════════════════════════════════════════════

TOTAL_STEPS=15
[[ $INSTALL_HY2 -eq 1 ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
STEP_NUM=0
next_step() { STEP_NUM=$((STEP_NUM + 1)); log_step "[${STEP_NUM}/${TOTAL_STEPS}] $1"; }

# ── B1. Fix apt-locks + update ──────────────────────────────────────────
next_step "Preparing the system (fix apt-lock, needrestart)..."

systemctl stop unattended-upgrades 2>/dev/null || true
systemctl disable unattended-upgrades 2>/dev/null || true
pkill -9 unattended-upgrades 2>/dev/null || true
sleep 1

rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock \
      /var/cache/apt/archives/lock /var/lib/apt/lists/lock 2>/dev/null || true
dpkg --configure -a >/dev/null 2>&1 || true

if [ -f /etc/needrestart/needrestart.conf ]; then
  sed -i "s/#\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/" \
    /etc/needrestart/needrestart.conf 2>/dev/null || true
  sed -i "s/\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/" \
    /etc/needrestart/needrestart.conf 2>/dev/null || true
  log_info "needrestart → auto mode"
fi

apt-get update -qq -o DPkg::Lock::Timeout=60 2>/dev/null || true
apt-get install -y -qq \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  -o DPkg::Lock::Timeout=60 \
  curl wget git openssl ufw ca-certificates jq 2>/dev/null || true

log_ok "System prepared"

# ── B2. BBR + UDP buffers ───────────────────────────────────────────────
next_step "Enabling BBR and UDP optimization..."

cat > /etc/sysctl.d/99-rixxx-tune.conf << 'SYSCTLEOF'
# by RIXXX — network tuning for Naive (TCP) + Hy2 (UDP)
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
# UDP buffers for Hysteria2 (recommended by apernet)
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=2500000
net.core.wmem_default=2500000
# FastOpen + ipv6
net.ipv4.tcp_fastopen=3
net.ipv6.conf.all.disable_ipv6=0
SYSCTLEOF

sysctl --system >/dev/null 2>&1 || true
log_ok "BBR + UDP optimizations applied"

# ── B3. Install Go (multi-arch) ─────────────────────────────────────────
if [[ $INSTALL_NAIVE -eq 1 ]]; then
  next_step "Installing Go (arch: ${GO_ARCH})..."

  rm -rf /usr/local/go

  GO_VERSION=""
  for attempt in 1 2 3; do
    GO_VERSION=$(curl -fsSL --connect-timeout 10 'https://go.dev/VERSION?m=text' 2>/dev/null | head -n1 | tr -d '[:space:]' || true)
    [[ -n "$GO_VERSION" && "$GO_VERSION" == go* ]] && break
    sleep 2
  done
  [[ -z "$GO_VERSION" || "$GO_VERSION" != go* ]] && GO_VERSION="go1.22.5"

  log_info "Downloading ${GO_VERSION}.linux-${GO_ARCH}..."
  wget -q --show-progress --timeout=180 \
    "https://go.dev/dl/${GO_VERSION}.linux-${GO_ARCH}.tar.gz" \
    -O /tmp/go.tar.gz 2>&1 || {
      log_err "Failed to download Go!"
      exit 1
    }

  if [[ ! -s /tmp/go.tar.gz ]]; then
    log_err "Go file is empty, check your internet"
    exit 1
  fi

  tar -C /usr/local -xzf /tmp/go.tar.gz
  rm -f /tmp/go.tar.gz

  export GOROOT=/usr/local/go
  export GOPATH=/root/go
  export PATH=$GOROOT/bin:$GOPATH/bin:$PATH

  grep -q "/usr/local/go/bin" /root/.profile 2>/dev/null || {
    echo 'export GOROOT=/usr/local/go' >> /root/.profile
    echo 'export GOPATH=/root/go' >> /root/.profile
    echo 'export PATH=$GOROOT/bin:$GOPATH/bin:$PATH' >> /root/.profile
  }

  GO_VER=$(/usr/local/go/bin/go version 2>/dev/null || echo "unknown")
  log_ok "Go installed: ${GO_VER}"

  # ── B4. Build Caddy with naive plugin ────────────────────────────────
  next_step "Building Caddy + naive forward proxy (3-7 minutes)..."

  export GOROOT=/usr/local/go
  export GOPATH=/root/go
  export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
  export TMPDIR=/root/tmp
  export GOPROXY=https://proxy.golang.org,direct
  mkdir -p /root/tmp /root/go

  log_info "Installing xcaddy..."
  /usr/local/go/bin/go install \
    github.com/caddyserver/xcaddy/cmd/xcaddy@latest 2>&1 | tail -2

  if [[ ! -f /root/go/bin/xcaddy ]]; then
    log_err "xcaddy failed to install! Check your internet."
    exit 1
  fi
  log_info "xcaddy installed, building Caddy..."

  rm -f /root/caddy
  cd /root

  /root/go/bin/xcaddy build \
    --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive \
    2>&1 | while IFS= read -r line; do
      [[ -n "$line" ]] && echo "    $line"
    done

  if [[ ! -f /root/caddy ]]; then
    log_err "Caddy build failed! Check the output above."
    exit 1
  fi

  mv /root/caddy /usr/bin/caddy
  chmod +x /usr/bin/caddy
  setcap 'cap_net_bind_service=+ep' /usr/bin/caddy 2>/dev/null || true

  CADDY_VER=$(/usr/bin/caddy version 2>/dev/null || echo "unknown")
  log_ok "Caddy built: ${CADDY_VER}"

  # ── B5. Camouflage page + Caddyfile ──────────────────────────────────
  next_step "Creating Caddyfile and camouflage page..."

  mkdir -p /var/www/html /etc/caddy

  cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html><html><head><meta charset="utf-8"><title>Loading</title>
<style>body{background:#080808;height:100vh;margin:0;display:flex;flex-direction:column;align-items:center;justify-content:center;font-family:sans-serif}.bar{width:200px;height:3px;background:#151515;overflow:hidden;border-radius:2px;margin-bottom:25px}.fill{height:100%;width:40%;background:#fff;animation:slide 1.4s infinite ease-in-out}@keyframes slide{0%{transform:translateX(-100%)}50%{transform:translateX(50%)}100%{transform:translateX(200%)}}.t{color:#555;font-size:13px;letter-spacing:3px;font-weight:600}</style>
</head><body><div class="bar"><div class="fill"></div></div><div class="t">LOADING CONTENT</div></body></html>
HTMLEOF

  # IMPORTANT: If Hy2 is installed alongside, disable HTTP/3 in Caddy,
  # otherwise Caddy will occupy UDP/443 for QUIC and Hy2 will not be able to bind.
  {
    printf '{\n'
    printf '  order forward_proxy before file_server\n'
    if [[ $INSTALL_HY2 -eq 1 ]]; then
      printf '  servers {\n'
      printf '    protocols h1 h2\n'
      printf '  }\n'
    fi
    printf '}\n\n'
    printf ':443, %s {\n' "${PROXY_DOMAIN}"
    printf '  tls %s\n\n' "${PROXY_EMAIL}"
    printf '  forward_proxy {\n'
    printf '    basic_auth %s %s\n' "${NAIVE_LOGIN}" "${NAIVE_PASS}"
    printf '    hide_ip\n'
    printf '    hide_via\n'
    printf '    probe_resistance\n'
    printf '  }\n\n'
    if [[ "$MASQUERADE_MODE" == "mirror" && -n "$MASQUERADE_URL" ]]; then
      printf '  reverse_proxy %s {\n' "${MASQUERADE_URL}"
      printf '    header_up Host {upstream_hostport}\n'
      printf '  }\n'
    else
      printf '  file_server {\n'
      printf '    root /var/www/html\n'
      printf '  }\n'
    fi
    printf '}\n'

    if [[ "$ACCESS_MODE" == "3" && -n "$PANEL_DOMAIN" && "$SSH_ONLY" != "1" ]]; then
      printf '\n'
      printf '%s {\n' "${PANEL_DOMAIN}"
      printf '  tls %s\n' "${PANEL_EMAIL_SSL:-${PROXY_EMAIL}}"
      printf '  encode gzip\n'
      printf '  reverse_proxy 127.0.0.1:%s\n' "${INTERNAL_PORT}"
      printf '}\n'
    fi
  } > /etc/caddy/Caddyfile

  /usr/bin/caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1 \
    && log_ok "Caddyfile is valid" \
    || log_warn "Caddyfile — warning (SSL will be obtained at start)"

  # ── B6. Caddy systemd service ─────────────────────────────────────────
  next_step "Caddy systemd service..."

  systemctl stop caddy 2>/dev/null || true
  pkill -x caddy 2>/dev/null || true
  sleep 1

  cat > /etc/systemd/system/caddy.service << 'SVCEOF'
[Unit]
Description=Caddy with NaiveProxy (by RIXXX)
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=root
Group=root
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE
Restart=always
RestartSec=5s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

  systemctl daemon-reload
  systemctl enable caddy >/dev/null 2>&1 || true

  # ── B7. Start Caddy ──────────────────────────────────────────────────
  next_step "Starting Caddy (obtaining TLS certificate)..."

  systemctl start caddy 2>&1 || {
    log_warn "systemctl start returned an error, trying fallback..."
    pkill -f "caddy run" 2>/dev/null || true
    sleep 1
    nohup /usr/bin/caddy run --config /etc/caddy/Caddyfile \
      > /var/log/caddy.log 2>&1 &
  }

  CADDY_OK=0
  for i in $(seq 1 30); do
    if systemctl is-active --quiet caddy 2>/dev/null || pgrep -x caddy >/dev/null 2>/dev/null; then
      log_ok "Caddy started (${i}s)"
      CADDY_OK=1
      break
    fi
    sleep 1
  done

  [[ $CADDY_OK -eq 0 ]] && log_warn "Caddy is starting slowly — check: systemctl status caddy"
fi

# ── B8. Install Hysteria2 ───────────────────────────────────────────────
if [[ $INSTALL_HY2 -eq 1 ]]; then
  next_step "Installing Hysteria2 (arch: ${HY_ARCH})..."

  # Get the latest release
  HY_VERSION=$(curl -fsSL --connect-timeout 10 \
    https://api.github.com/repos/apernet/hysteria/releases/latest 2>/dev/null \
    | jq -r '.tag_name' 2>/dev/null || echo "")
  [[ -z "$HY_VERSION" || "$HY_VERSION" == "null" ]] && HY_VERSION="app/v2.5.2"

  log_info "Downloading Hysteria ${HY_VERSION} (linux-${HY_ARCH})..."
  HY_URL="https://github.com/apernet/hysteria/releases/download/${HY_VERSION}/hysteria-linux-${HY_ARCH}"

  wget -q --show-progress --timeout=120 "${HY_URL}" -O /usr/local/bin/hysteria 2>&1 || {
    log_warn "Failed to download ${HY_VERSION}, trying fallback app/v2.5.2..."
    wget -q --show-progress --timeout=120 \
      "https://github.com/apernet/hysteria/releases/download/app/v2.5.2/hysteria-linux-${HY_ARCH}" \
      -O /usr/local/bin/hysteria 2>&1 || {
      log_err "Failed to download hysteria!"
      exit 1
    }
  }

  if [[ ! -s /usr/local/bin/hysteria ]]; then
    log_err "hysteria binary is empty"
    exit 1
  fi

  chmod +x /usr/local/bin/hysteria
  setcap 'cap_net_bind_service=+ep' /usr/local/bin/hysteria 2>/dev/null || true

  HY_VER=$(/usr/local/bin/hysteria version 2>&1 | head -n1 || echo "unknown")
  log_ok "Hysteria installed: ${HY_VER}"

  # Hy2 config
  mkdir -p /etc/hysteria

  if [[ $INSTALL_NAIVE -eq 1 ]]; then
    HY_TLS_MODE="caddy"
    log_info "Hy2 will use Caddy's certificate (shared domain)"
  else
    HY_TLS_MODE="acme"
    log_info "Hy2 will obtain its own ACME certificate"
  fi

  cat > /etc/hysteria/config.yaml << HYCFGEOF
# ═══════════════════════════════════════════════
#  Hysteria2 config — by RIXXX
#  https://v2.hysteria.network/
# ═══════════════════════════════════════════════

listen: :443

# Authentication (single default password; add users via panel)
auth:
  type: userpass
  userpass:
    default: "${HY2_PASS}"

# Traffic masquerade: serves THE SAME page as Caddy on TCP.
# Mode is chosen interactively during installation (see MASQUERADE_MODE).
HYCFGEOF

  # Append masquerade section depending on chosen mode.
  if [[ "$MASQUERADE_MODE" == "mirror" && -n "$MASQUERADE_URL" ]]; then
    cat >> /etc/hysteria/config.yaml << HYMASQEOF
masquerade:
  type: proxy
  proxy:
    url: ${MASQUERADE_URL}
    rewriteHost: true

# TLS
HYMASQEOF
  else
    cat >> /etc/hysteria/config.yaml << HYMASQEOF
masquerade:
  type: file
  file:
    dir: /var/www/html

# TLS
HYMASQEOF
  fi

  if [[ "$HY_TLS_MODE" == "caddy" ]]; then
    CADDY_CERT_ROOTS=(
      "/var/lib/caddy/.local/share/caddy/certificates"
      "/root/.local/share/caddy/certificates"
    )
    CADDY_CERT_DIR=""

    log_info "Waiting for certificate from Caddy (up to 150s, any CA: LE/ZeroSSL/Google)..."
    for i in $(seq 1 75); do
      for ROOT in "${CADDY_CERT_ROOTS[@]}"; do
        [[ -d "$ROOT" ]] || continue
        FOUND=$(find "$ROOT" -type f -name "${PROXY_DOMAIN}.crt" 2>/dev/null | head -1)
        if [[ -n "$FOUND" && -f "${FOUND%.crt}.key" ]]; then
          CADDY_CERT_DIR="$(dirname "$FOUND")"
          CA_NAME="$(basename "$(dirname "$CADDY_CERT_DIR")")"
          log_ok "Certificate found (${i}x2s) — CA: ${CA_NAME}"
          log_info "  path: ${CADDY_CERT_DIR}"
          break 2
        fi
      done
      sleep 2
    done

    if [[ -z "$CADDY_CERT_DIR" ]]; then
      log_warn "Caddy certificate not found after 150s."
      log_info "Diagnostics (installer will run):"
      systemctl status caddy --no-pager -l 2>&1 | tail -15 | sed 's/^/  /'
      journalctl -u caddy -n 20 --no-pager 2>&1 | tail -20 | sed 's/^/  /'
      log_info "Check that ${PROXY_DOMAIN} has an A record pointing to ${SERVER_IP}"
      log_warn "⚠ Hy2 will NOT use its own ACME (risk of rate limit)."
      log_warn "  Instead, Hy2 is stopped. Start it after fixing Caddy:"
      log_warn "  systemctl restart caddy ; sleep 30 ; systemctl restart hysteria-server"
      cat >> /etc/hysteria/config.yaml << HYNOTLSEOF
# ⚠ Caddy certificate was not ready at installation time.
# After Caddy gets the cert, replace this comment with:
#   tls:
#     cert: /var/lib/caddy/.local/share/caddy/certificates/<CA>/${PROXY_DOMAIN}/${PROXY_DOMAIN}.crt
#     key:  /var/lib/caddy/.local/share/caddy/certificates/<CA>/${PROXY_DOMAIN}/${PROXY_DOMAIN}.key
# and run: systemctl restart hysteria-server
HYNOTLSEOF
    else
      chmod -R 755 "$(dirname "$CADDY_CERT_DIR")" 2>/dev/null || true
      chmod 644 "${CADDY_CERT_DIR}/${PROXY_DOMAIN}.crt" 2>/dev/null || true
      chmod 640 "${CADDY_CERT_DIR}/${PROXY_DOMAIN}.key" 2>/dev/null || true

      cat >> /etc/hysteria/config.yaml << HYTLSEOF
tls:
  cert: ${CADDY_CERT_DIR}/${PROXY_DOMAIN}.crt
  key:  ${CADDY_CERT_DIR}/${PROXY_DOMAIN}.key
HYTLSEOF

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
      log_ok "caddy-cert-watcher configured (${CADDY_CERT_DIR})"
    fi

  else
    cat >> /etc/hysteria/config.yaml << HYACMEEOF
acme:
  domains:
    - ${PROXY_DOMAIN}
  email: ${PROXY_EMAIL}
  ca: letsencrypt
  listenHost: 0.0.0.0
HYACMEEOF
  fi

  cat >> /etc/hysteria/config.yaml << 'HYBWEOF'

# Bandwidth (Brutal congestion). Specify actual link speed if known.
# Default — ignoreClientBandwidth: true (server auto‑adapts)
ignoreClientBandwidth: true

# QUIC tuning
quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 30s
  keepAlivePeriod: 10s
  disablePathMTUDiscovery: false
HYBWEOF

  if [[ $INSTALL_NAIVE -eq 1 ]]; then
    HY_UNIT_AFTER="After=network.target network-online.target caddy.service"
    HY_UNIT_WANTS="Wants=caddy.service"
  else
    HY_UNIT_AFTER="After=network.target network-online.target"
    HY_UNIT_WANTS=""
  fi

  cat > /etc/systemd/system/hysteria-server.service << HYSVCEOF
[Unit]
Description=Hysteria2 Server (by RIXXX)
Documentation=https://v2.hysteria.network/
${HY_UNIT_AFTER}
${HY_UNIT_WANTS}
Requires=network-online.target
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
  systemctl enable caddy-cert-watcher.path >/dev/null 2>&1 || true
  systemctl start  caddy-cert-watcher.path >/dev/null 2>&1 || true

  systemctl start hysteria-server 2>&1 || log_warn "hysteria-server start: possible issues, see journalctl -u hysteria-server"

  HY_OK=0
  for i in $(seq 1 20); do
    HY_STATUS=$(systemctl is-active hysteria-server 2>/dev/null || echo "unknown")
    if [[ "$HY_STATUS" == "active" ]]; then
      log_ok "Hysteria2 started (${i}s)"
      HY_OK=1
      break
    elif [[ "$HY_STATUS" == "failed" ]]; then
      log_warn "hysteria-server: failed — diagnostics:"
      journalctl -u hysteria-server -n 20 --no-pager 2>/dev/null || true
      log_warn "Attempting restart..."
      systemctl reset-failed hysteria-server 2>/dev/null || true
      systemctl start hysteria-server 2>/dev/null || true
      break
    fi
    sleep 1
  done
  [[ $HY_OK -eq 0 ]] && log_warn "Hy2 did not start within 20s — diagnostic command: journalctl -u hysteria-server -n 50 --no-pager"
fi

# ── B9. Node.js ─────────────────────────────────────────────────────────
next_step "Installing Node.js 20..."

if ! command -v node &>/dev/null || [[ "$(node -v 2>/dev/null | cut -d. -f1 | tr -d 'v')" -lt 18 ]]; then
  log_info "Downloading NodeSource..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 2>&1 | grep -E "^##|^Running|error" || true
  apt-get install -y -qq nodejs \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" 2>/dev/null || true
fi
NODE_VER=$(node -v 2>/dev/null || echo "not found")
log_ok "Node.js: ${NODE_VER}"

# ── B10. PM2 ────────────────────────────────────────────────────────────
next_step "Installing PM2..."
npm install -g pm2 --silent 2>&1 | grep -v "^npm warn" | tail -2 || true
PM2_VER=$(pm2 -v 2>/dev/null || echo "ok")
log_ok "PM2: ${PM2_VER}"

# ── B11. Nginx (if needed) ──────────────────────────────────────────────
NGINX_OK=0
if [[ "$ACCESS_MODE" == "1" || "$ACCESS_MODE" == "3" ]]; then
  next_step "Installing Nginx..."

  apt-get update -qq 2>&1 | tail -2 || true

  if command -v nginx >/dev/null 2>&1; then
    log_ok "Nginx already installed: $(nginx -v 2>&1 | head -1)"
    NGINX_OK=1
  else
    apt-get install -y nginx \
      -o Dpkg::Options::="--force-confdef" \
      -o Dpkg::Options::="--force-confold" 2>&1 | tail -15
    APT_RC=${PIPESTATUS[0]}

    if [[ $APT_RC -eq 0 ]] && command -v nginx >/dev/null 2>&1; then
      log_ok "Nginx installed: $(nginx -v 2>&1 | head -1)"
      NGINX_OK=1
    else
      log_err "Nginx failed to install (exit=$APT_RC). Trying second attempt with snap/apt and unlock..."
      systemctl stop unattended-upgrades 2>/dev/null || true
      fuser -k /var/lib/dpkg/lock-frontend 2>/dev/null || true
      fuser -k /var/lib/dpkg/lock 2>/dev/null || true
      dpkg --configure -a 2>&1 | tail -5 || true
      sleep 2
      if apt-get install -y nginx 2>&1 | tail -10 && command -v nginx >/dev/null 2>&1; then
        log_ok "Nginx installed on second attempt"
        NGINX_OK=1
      else
        log_err "Nginx still failed to install. Panel will be available only on port ${INTERNAL_PORT}."
        log_info "  Diagnostics: apt-cache policy nginx ; dpkg -l | grep nginx"
        NGINX_OK=0
      fi
    fi
  fi

  if [[ $NGINX_OK -eq 0 ]]; then
    log_warn "ACCESS_MODE switched from Nginx to direct access on port ${INTERNAL_PORT}"
    ACCESS_MODE="2"
  fi
fi

# ── B12. Clone panel ────────────────────────────────────────────────────
next_step "Downloading control panel..."

if [[ -d "${PANEL_DIR}/.git" ]]; then
  log_warn "Panel already installed — updating..."
  cd "${PANEL_DIR}" && git fetch --all && git reset --hard "origin/${REPO_BRANCH}" 2>&1 | tail -2 || true
else
  rm -rf "${PANEL_DIR}"
  git clone -b "${REPO_BRANCH}" "${REPO_URL}" "${PANEL_DIR}" 2>&1 || {
    log_err "Failed to clone repository"
    exit 1
  }
fi

cd "${PANEL_DIR}/panel"
npm install --omit=dev 2>&1 | grep -v "^npm warn" | tail -3 || true
mkdir -p "${PANEL_DIR}/panel/data"

log_ok "Panel downloaded to ${PANEL_DIR}"

# ── Write initial config.json ────────────────────────────────────────
if [[ ! -f "${PANEL_DIR}/panel/data/config.json" ]]; then
  NAIVE_USERS_JSON="[]"
  HY2_USERS_JSON="[]"
  CREATED_AT="$(date -u +%FT%TZ)"

  if [[ $INSTALL_NAIVE -eq 1 ]]; then
    NAIVE_USERS_JSON="[{\"username\":\"${NAIVE_LOGIN}\",\"password\":\"${NAIVE_PASS}\",\"createdAt\":\"${CREATED_AT}\"}]"
  fi
  if [[ $INSTALL_HY2 -eq 1 ]]; then
    HY2_USERS_JSON="[{\"username\":\"default\",\"password\":\"${HY2_PASS}\",\"createdAt\":\"${CREATED_AT}\"}]"
  fi

  [[ $INSTALL_NAIVE -eq 1 ]] && STACK_NAIVE="true" || STACK_NAIVE="false"
  [[ $INSTALL_HY2   -eq 1 ]] && STACK_HY2="true"   || STACK_HY2="false"

  cat > "${PANEL_DIR}/panel/data/config.json" << CONFIGEOF
{
  "installed": true,
  "stack": {
    "naive": ${STACK_NAIVE},
    "hy2":   ${STACK_HY2}
  },
  "domain": "${PROXY_DOMAIN}",
  "email": "${PROXY_EMAIL}",
  "panelDomain": "${PANEL_DOMAIN}",
  "panelEmail":  "${PANEL_EMAIL_SSL}",
  "accessMode":  "${ACCESS_MODE}",
  "sshOnly":     ${SSH_ONLY:-0},
  "listenHost":  "${LISTEN_HOST:-0.0.0.0}",
  "masqueradeMode": "${MASQUERADE_MODE:-local}",
  "masqueradeUrl":  "${MASQUERADE_URL:-}",
  "serverIp": "${SERVER_IP}",
  "arch": "${MACHINE_ARCH}",
  "adminPassword": "",
  "naiveUsers": ${NAIVE_USERS_JSON},
  "hy2Users":   ${HY2_USERS_JSON}
}
CONFIGEOF
  log_ok "config.json written"
else
  log_warn "config.json already exists — not overwriting"
fi

# ── B13. UFW (basic ports) ──────────────────────────────────────────────
next_step "Configuring UFW firewall (basic ports)..."

ufw allow 22/tcp  >/dev/null 2>&1 || true
ufw allow 80/tcp  >/dev/null 2>&1 || true
ufw allow 443/tcp >/dev/null 2>&1 || true
ufw allow 443/udp >/dev/null 2>&1 || true

echo "y" | ufw enable >/dev/null 2>&1 || ufw --force enable >/dev/null 2>&1 || true
log_ok "UFW: 22, 80, 443/tcp, 443/udp opened"

if [[ "$SSH_ONLY" == "1" ]]; then
  ufw deny 3000/tcp >/dev/null 2>&1 || true
  ufw deny 8080/tcp >/dev/null 2>&1 || true
  log_info "SSH-only: 3000/tcp and 8080/tcp closed on UFW (deny)"
fi

# ── B14. Start panel via PM2 ────────────────────────────────────────────
next_step "Starting panel via PM2..."

cd "${PANEL_DIR}/panel"
pm2 delete "${SERVICE_NAME}" 2>/dev/null || true
sleep 1

PM2_ENV_LISTEN="LISTEN_HOST=${LISTEN_HOST:-0.0.0.0}"
LISTEN_HOST="${LISTEN_HOST:-0.0.0.0}" \
pm2 start server/index.js \
  --name "${SERVICE_NAME}" \
  --time \
  --restart-delay=3000 \
  --update-env \
  2>&1 | tail -3

pm2 save --force >/dev/null 2>&1 || true

PM2_STARTUP=$(pm2 startup systemd -u root --hp /root 2>/dev/null | grep "^sudo" || true)
[[ -n "$PM2_STARTUP" ]] && eval "$PM2_STARTUP" >/dev/null 2>&1 || true

sleep 2

if pm2 describe "${SERVICE_NAME}" 2>/dev/null | grep -q "online"; then
  log_ok "Panel started via PM2"
else
  log_warn "PM2 did not start the panel. Trying systemd fallback..."

  cat > /etc/systemd/system/panel-naive-hy2.service << SVCFALLBACKEOF
[Unit]
Description=Panel Naive + Hy2 by RIXXX (fallback)
After=network.target

[Service]
Type=simple
WorkingDirectory=${PANEL_DIR}/panel
ExecStart=/usr/bin/node server/index.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production
Environment=PORT=${INTERNAL_PORT}
Environment=LISTEN_HOST=${LISTEN_HOST:-0.0.0.0}
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCFALLBACKEOF
  systemctl daemon-reload
  systemctl enable panel-naive-hy2 >/dev/null 2>&1 || true
  systemctl restart panel-naive-hy2 2>&1 || true
  sleep 2
  if systemctl is-active --quiet panel-naive-hy2; then
    log_ok "Panel started via systemd (fallback)"
  else
    log_err "Panel failed to start. Diagnostics: journalctl -u panel-naive-hy2 -n 50"
  fi
fi

sleep 2
if curl -fsS --max-time 5 "http://127.0.0.1:${INTERNAL_PORT}/" >/dev/null 2>&1; then
  log_ok "Panel responds on http://127.0.0.1:${INTERNAL_PORT} ✓"
else
  log_warn "Panel does NOT respond on port ${INTERNAL_PORT}!"
  log_info "  pm2 logs ${SERVICE_NAME} --lines 30   — logs via PM2"
  log_info "  journalctl -u panel-naive-hy2 -n 30   — logs via systemd"
  log_info "  cd ${PANEL_DIR}/panel && node server/index.js   — manual run for debugging"
fi

# ── Configure Nginx ─────────────────────────────────────────────────────
if [[ "$ACCESS_MODE" == "1" ]]; then
  if ! command -v nginx >/dev/null 2>&1; then
    log_err "Nginx not found (command -v nginx). Skipping configuration."
    log_warn "Panel is available only on port ${INTERNAL_PORT}."
    ACCESS_MODE="2"
  elif [[ ! -d /etc/nginx/sites-available ]]; then
    log_err "/etc/nginx/sites-available does not exist (broken install?)."
    log_warn "Panel is available only on port ${INTERNAL_PORT}."
    ACCESS_MODE="2"
  fi
fi

if [[ "$ACCESS_MODE" == "1" ]]; then
  log_info "Configuring Nginx (8080 → 3000)..."
  mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
  cat > /etc/nginx/sites-available/panel-naive-hy2 << NGINXEOF
server {
    listen 8080;
    server_name _;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    location / {
        proxy_pass http://127.0.0.1:${INTERNAL_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }
}
NGINXEOF
  ln -sf /etc/nginx/sites-available/panel-naive-hy2 \
    /etc/nginx/sites-enabled/panel-naive-hy2 2>/dev/null || true
  rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

  if nginx -t 2>&1 | tee /tmp/nginx-test.log | grep -q "successful"; then
    systemctl restart nginx 2>&1 || log_warn "systemctl restart nginx fail"
    systemctl enable nginx >/dev/null 2>&1 || true
    log_ok "Nginx configured (8080 → 3000)"
  else
    log_err "Nginx config invalid! Output of nginx -t:"
    cat /tmp/nginx-test.log
    log_warn "Panel will be available directly on port ${INTERNAL_PORT} (3000)"
  fi

  sleep 1
  if ss -tlnp 2>/dev/null | grep -q ':8080 '; then
    log_ok "Port 8080 is listening ✓"
  else
    log_warn "Port 8080 is NOT listening! Check: ss -tlnp | grep 8080"
    log_warn "  Possibly nginx is not running. Commands: systemctl status nginx; nginx -t"
  fi

elif [[ "$ACCESS_MODE" == "3" && -n "$PANEL_DOMAIN" ]]; then
  if [[ $INSTALL_NAIVE -eq 1 ]] && command -v caddy >/dev/null 2>&1; then
    log_info "Panel via Caddy at https://${PANEL_DOMAIN} (NaiveProxy alongside on same 443)"
    if command -v nginx >/dev/null 2>&1; then
      rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
      systemctl stop nginx 2>/dev/null || true
      systemctl disable nginx 2>/dev/null || true
    fi

    if caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1; then
      systemctl reload caddy 2>/dev/null || systemctl restart caddy 2>/dev/null || true
      log_info "Caddy reloaded — waiting for LE cert for ${PANEL_DOMAIN} (up to 60s)..."

      PANEL_CERT_OK=0
      for i in $(seq 1 30); do
        if find /root/.local/share/caddy /var/lib/caddy/.local/share/caddy \
             -type f -name "${PANEL_DOMAIN}.crt" 2>/dev/null | grep -q .; then
          PANEL_CERT_OK=1
          log_ok "Certificate for ${PANEL_DOMAIN} obtained (${i}x2s)"
          break
        fi
        sleep 2
      done
      if [[ $PANEL_CERT_OK -eq 0 ]]; then
        log_warn "Certificate for ${PANEL_DOMAIN} not yet obtained."
        log_info "  Check: A record ${PANEL_DOMAIN} -> ${SERVER_IP}"
        log_info "  Logs:  journalctl -u caddy -n 40 --no-pager"
        log_info "  The cert will come in the background — open https://${PANEL_DOMAIN} in a couple of minutes."
      fi
    else
      log_err "Caddyfile is invalid! Panel on domain will not work."
      log_info "  caddy validate --config /etc/caddy/Caddyfile"
      ACCESS_MODE="2"
    fi

  elif ! command -v nginx >/dev/null 2>&1; then
    log_err "Nginx is not installed — SSL configuration impossible. Panel available on port ${INTERNAL_PORT}."
    ACCESS_MODE="2"
  else
    log_info "Configuring Nginx + SSL for ${PANEL_DOMAIN} (without NaiveProxy)..."
    mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
    apt-get install -y -qq python3-certbot-nginx 2>&1 | tail -3 || log_warn "certbot-nginx not installed, trying without it"

    cat > /etc/nginx/sites-available/panel-naive-hy2 << NGINXEOF
server {
    listen 80;
    server_name ${PANEL_DOMAIN};
    location / {
        proxy_pass http://127.0.0.1:${INTERNAL_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 86400;
    }
}
NGINXEOF
    ln -sf /etc/nginx/sites-available/panel-naive-hy2 \
      /etc/nginx/sites-enabled/panel-naive-hy2 2>/dev/null || true
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
    nginx -t >/dev/null 2>&1 && systemctl restart nginx && systemctl enable nginx >/dev/null 2>&1 || true

    certbot --nginx -d "${PANEL_DOMAIN}" \
      --email "${PANEL_EMAIL_SSL:-admin@${PANEL_DOMAIN}}" \
      --agree-tos --non-interactive 2>&1 | tail -4 \
      || log_warn "SSL for panel: check DNS record"

    log_ok "Nginx + SSL configured for ${PANEL_DOMAIN}"
  fi
fi

# ── B15. UFW for panel port (final — after Nginx) ───────────────────────
log_info "UFW: opening panel port according to access mode..."
if [[ "$SSH_ONLY" == "1" ]]; then
  ufw deny 8080/tcp >/dev/null 2>&1 || true
  ufw deny ${INTERNAL_PORT}/tcp >/dev/null 2>&1 || true
  log_ok "UFW (SSH-only): 8080/tcp and ${INTERNAL_PORT}/tcp closed (deny)"
elif [[ "$ACCESS_MODE" == "1" ]]; then
  ufw allow 8080/tcp >/dev/null 2>&1 || true
  ufw deny  ${INTERNAL_PORT}/tcp >/dev/null 2>&1 || true
  log_ok "UFW: 8080/tcp opened, ${INTERNAL_PORT}/tcp closed"
elif [[ "$ACCESS_MODE" == "2" ]]; then
  ufw allow ${INTERNAL_PORT}/tcp >/dev/null 2>&1 || true
  log_ok "UFW: ${INTERNAL_PORT}/tcp opened (direct access)"
elif [[ "$ACCESS_MODE" == "3" ]]; then
  ufw deny  ${INTERNAL_PORT}/tcp >/dev/null 2>&1 || true
  log_ok "UFW: ${INTERNAL_PORT}/tcp closed, access via domain (443/tcp)"
fi

# ════════════════════════════════════════════════════════════════════════
# FINAL SELF-CHECK
# ════════════════════════════════════════════════════════════════════════
next_step "Final self-check of the panel..."

sleep 2
PANEL_LOCAL_OK=0
if curl -fsS --max-time 5 "http://127.0.0.1:${INTERNAL_PORT}/" >/dev/null 2>&1; then
  log_ok "Panel responds on http://127.0.0.1:${INTERNAL_PORT}"
  PANEL_LOCAL_OK=1
else
  log_err "Panel does NOT respond on 127.0.0.1:${INTERNAL_PORT}!"
  log_info "  pm2 status ; pm2 logs ${SERVICE_NAME} --lines 40"
fi

if [[ "$ACCESS_MODE" == "1" ]]; then
  if ss -tlnp 2>/dev/null | grep -q ':8080 '; then
    log_ok "Port 8080 (Nginx) is listening"
    if curl -fsS --max-time 5 "http://127.0.0.1:8080/" >/dev/null 2>&1; then
      log_ok "Nginx responds on :8080 and proxies to the panel ✓"
    else
      log_warn "Nginx listens on :8080 but proxying does not work. Check: nginx -t; systemctl status nginx"
    fi
  else
    log_err "Port 8080 is NOT listening!"
    log_warn "Nginx may have failed to start. Trying fallback: open direct access to :${INTERNAL_PORT}..."
    ufw allow ${INTERNAL_PORT}/tcp >/dev/null 2>&1 || true
    ACCESS_MODE="2"
  fi
elif [[ "$ACCESS_MODE" == "2" ]]; then
  if ss -tlnp 2>/dev/null | grep -q ":${INTERNAL_PORT} "; then
    log_ok "Port ${INTERNAL_PORT} is listening, panel available directly"
  else
    log_err "Port ${INTERNAL_PORT} is NOT listening!"
  fi
elif [[ "$ACCESS_MODE" == "3" && -n "$PANEL_DOMAIN" ]]; then
  if [[ $INSTALL_NAIVE -eq 1 ]] && command -v caddy >/dev/null 2>&1; then
    if ss -tlnp 2>/dev/null | grep -q ':443 '; then
      log_ok "Port 443 (Caddy) is listening — serves proxy and panel by SNI"
    else
      log_err "Port 443 is NOT listening! Check: systemctl status caddy"
    fi
    if curl -fsSk --max-time 8 -H "Host: ${PANEL_DOMAIN}" "https://127.0.0.1/" >/dev/null 2>&1; then
      log_ok "Caddy responds on https://${PANEL_DOMAIN} ✓"
    else
      log_warn "Caddy does not yet respond on https://${PANEL_DOMAIN}."
      log_info "  Possibly the LE certificate is still being issued. Retry in 1–2 minutes:"
      log_info "    curl -I https://${PANEL_DOMAIN}/"
    fi
  else
    if ss -tlnp 2>/dev/null | grep -q ':443 '; then
      log_ok "Port 443 (Nginx) is listening"
    else
      log_err "Port 443 is NOT listening! Check: systemctl status nginx"
    fi
  fi
fi

# ════════════════════════════════════════════════════════════════════════
# SMOKE-TEST — automatic verification after installation (PR #4)
# ════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}${BOLD}▶ Smoke-test: verifying functionality${RESET}"

SMOKE_FAILS=0
SMOKE_WARNS=0

if [[ $INSTALL_NAIVE -eq 1 ]]; then
  if [[ -f /etc/caddy/Caddyfile ]]; then
    if caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1; then
      log_ok "Caddyfile is valid"
    else
      log_err "Caddyfile did NOT pass validation — check: caddy validate --config /etc/caddy/Caddyfile"
      SMOKE_FAILS=$((SMOKE_FAILS+1))
    fi
  else
    log_warn "Caddyfile missing (/etc/caddy/Caddyfile)"
    SMOKE_WARNS=$((SMOKE_WARNS+1))
  fi
fi

check_service() {
  local svc="$1"
  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    log_ok "${svc}: active"
    return 0
  fi
  return 1
}

if [[ $INSTALL_NAIVE -eq 1 ]]; then
  check_service caddy || { log_err "caddy not running — journalctl -u caddy --no-pager -n 30"; SMOKE_FAILS=$((SMOKE_FAILS+1)); }
fi
if [[ $INSTALL_HY2 -eq 1 ]]; then
  check_service hysteria-server || { log_err "hysteria-server not running — journalctl -u hysteria-server --no-pager -n 30"; SMOKE_FAILS=$((SMOKE_FAILS+1)); }
fi

if pm2 describe "${SERVICE_NAME}" 2>/dev/null | grep -q online; then
  log_ok "${SERVICE_NAME}: online (pm2)"
elif check_service "${SERVICE_NAME}"; then
  :
else
  log_err "Panel ${SERVICE_NAME} not running — pm2 logs ${SERVICE_NAME} --nostream"
  SMOKE_FAILS=$((SMOKE_FAILS+1))
fi

if curl -fsSL --max-time 5 -o /dev/null "http://127.0.0.1:${INTERNAL_PORT}/" 2>/dev/null; then
  log_ok "Panel responds on http://127.0.0.1:${INTERNAL_PORT}/"
else
  log_warn "Panel did not respond on http://127.0.0.1:${INTERNAL_PORT}/ (this is normal if it is still warming up)"
  SMOKE_WARNS=$((SMOKE_WARNS+1))
fi

if [[ $INSTALL_NAIVE -eq 1 && -n "${PROXY_DOMAIN:-}" ]]; then
  if curl -fsSL --max-time 8 -o /dev/null "https://${PROXY_DOMAIN}/" 2>/dev/null; then
    log_ok "https://${PROXY_DOMAIN}/ responds (TLS OK)"
  else
    log_warn "https://${PROXY_DOMAIN}/ does not respond yet — usually LE issues the certificate within 1–2 minutes"
    log_info "  Check in a minute: curl -I https://${PROXY_DOMAIN}/"
    SMOKE_WARNS=$((SMOKE_WARNS+1))
  fi
fi

if [[ "$ACCESS_MODE" == "3" && -n "${PANEL_DOMAIN:-}" && "$SSH_ONLY" != "1" ]]; then
  if curl -fsSL --max-time 8 -o /dev/null "https://${PANEL_DOMAIN}/" 2>/dev/null; then
    log_ok "https://${PANEL_DOMAIN}/ responds (TLS OK)"
  else
    log_warn "https://${PANEL_DOMAIN}/ does not respond yet — LE may be issuing the certificate for 1–2 minutes"
    SMOKE_WARNS=$((SMOKE_WARNS+1))
  fi
fi

if [[ $SMOKE_FAILS -eq 0 && $SMOKE_WARNS -eq 0 ]]; then
  log_ok "Smoke-test: all checks passed"
elif [[ $SMOKE_FAILS -eq 0 ]]; then
  log_warn "Smoke-test: ${SMOKE_WARNS} warnings (non‑critical — usually temporary)"
else
  log_err "Smoke-test: ${SMOKE_FAILS} errors, ${SMOKE_WARNS} warnings"
  log_info "Diagnostics: bash update.sh --status"
  log_info "Recovery: bash update.sh --repair"
fi

# ════════════════════════════════════════════════════════════════════════
# FINAL OUTPUT
# ════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${PURPLE}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${PURPLE}${BOLD}║   ✅  Installation completed!                              ║${RESET}"
echo -e "${PURPLE}${BOLD}╠══════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${PURPLE}${BOLD}║   🌐  CONTROL PANEL                                          ║${RESET}"

if [[ "$SSH_ONLY" == "1" ]]; then
  echo -e "${PURPLE}${BOLD}║   🔒  SSH-only mode (panel not accessible from Internet)    ║${RESET}"
  echo -e "${PURPLE}${BOLD}║   ➜   On your local machine, run:                           ║${RESET}"
  echo -e "${PURPLE}${BOLD}║       ssh -L 8080:127.0.0.1:${INTERNAL_PORT} root@${SERVER_IP}${RESET}"
  echo -e "${PURPLE}${BOLD}║   ➜   Then open: http://localhost:8080${RESET}"
  if [[ "$ACCESS_MODE" == "3" && -n "$PANEL_DOMAIN" ]]; then
    echo -e "${PURPLE}${BOLD}║   ℹ   Subdomain ${PANEL_DOMAIN} NOT configured in Caddy.   ║${RESET}"
    echo -e "${PURPLE}${BOLD}║       Open publicly: bash update.sh --expose ${PANEL_DOMAIN}${RESET}"
  fi
elif [[ "$ACCESS_MODE" == "1" ]]; then
  echo -e "${PURPLE}${BOLD}║   ➜   http://${SERVER_IP}:8080${RESET}"
elif [[ "$ACCESS_MODE" == "3" && -n "$PANEL_DOMAIN" ]]; then
  echo -e "${PURPLE}${BOLD}║   ➜   https://${PANEL_DOMAIN}${RESET}"
else
  echo -e "${PURPLE}${BOLD}║   ➜   http://${SERVER_IP}:${INTERNAL_PORT}${RESET}"
fi

echo -e "${PURPLE}${BOLD}║   👤  admin / admin  (⚠ CHANGE IN SETTINGS!)                 ║${RESET}"
echo -e "${PURPLE}${BOLD}╠══════════════════════════════════════════════════════════════╣${RESET}"

if [[ $INSTALL_NAIVE -eq 1 ]]; then
  NAIVE_LINK="naive+https://${NAIVE_LOGIN}:${NAIVE_PASS}@${PROXY_DOMAIN}:443"
  echo -e "${PURPLE}${BOLD}║   🔒  NaiveProxy                                              ║${RESET}"
  echo -e "${PURPLE}${BOLD}║   Domain: ${PROXY_DOMAIN}${RESET}"
  echo -e "${PURPLE}${BOLD}║   Login:  ${NAIVE_LOGIN}${RESET}"
  echo -e "${PURPLE}${BOLD}║   Password: ${NAIVE_PASS}${RESET}"
  echo -e "${PURPLE}${BOLD}║   Link:${RESET}"
  echo -e "${CYAN}   ${NAIVE_LINK}${RESET}"
fi

if [[ $INSTALL_HY2 -eq 1 ]]; then
  HY2_LINK="hysteria2://default:${HY2_PASS}@${PROXY_DOMAIN}:443?sni=${PROXY_DOMAIN}&insecure=0#RIXXX"
  echo -e "${PURPLE}${BOLD}║                                                               ║${RESET}"
  echo -e "${PURPLE}${BOLD}║   ⚡  Hysteria2                                               ║${RESET}"
  echo -e "${PURPLE}${BOLD}║   Domain: ${PROXY_DOMAIN}                                     ║${RESET}"
  echo -e "${PURPLE}${BOLD}║   Password: ${HY2_PASS}${RESET}"
  echo -e "${PURPLE}${BOLD}║   Link:${RESET}"
  echo -e "${CYAN}   ${HY2_LINK}${RESET}"
fi

echo -e "${PURPLE}${BOLD}╠══════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${PURPLE}${BOLD}║   📌  Useful commands:                                       ║${RESET}"
echo -e "${PURPLE}${BOLD}║   pm2 status                    — panel status              ║${RESET}"
echo -e "${PURPLE}${BOLD}║   pm2 logs ${SERVICE_NAME}     — panel logs              ║${RESET}"
[[ $INSTALL_NAIVE -eq 1 ]] && echo -e "${PURPLE}${BOLD}║   systemctl status caddy        — NaiveProxy                 ║${RESET}"
[[ $INSTALL_HY2 -eq 1 ]] && echo -e "${PURPLE}${BOLD}║   systemctl status hysteria-server — Hysteria2               ║${RESET}"
echo -e "${PURPLE}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""

# ── Write patch version ─────────────────────────────────────────────────
PANEL_PATCH_VERSION="1.0.0"
mkdir -p /etc/rixxx-panel
echo "$PANEL_PATCH_VERSION" > /etc/rixxx-panel/version
chmod 644 /etc/rixxx-panel/version
log_info "Patch version: ${PANEL_PATCH_VERSION} (see /etc/rixxx-panel/version)"
log_info "For future updates: bash <(curl -fsSL https://raw.githubusercontent.com/cwash797-cmd/Panel---Naive-Hy2---by---RIXXX/main/update.sh)"
echo ""

echo -e "${GREEN}${BOLD}   Good luck! Telegram: https://t.me/russian_paradice_vpn${RESET}"
echo ""
