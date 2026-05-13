**پست اول (ادامه در پست بعد)**


# Panel Naive + Hysteria2 by RIXXX

> Web panel for quick installation and management of **NaiveProxy** and **Hysteria2** on a single VPS — in **2 clicks**

---

## 🚀 Quick installation
```markdown
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mononoor/PNHR/main/install.sh)
```

After installation, the panel will be available at:
```
http://YOUR_SERVER_IP:3000
```

**Default login:** `admin` / `admin` — **change it immediately!**

---

## 🔄 Updating an existing installation

To apply new patches (improvements, new options) **without a full reinstall**, use `update.sh`:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/cwash797-cmd/Panel---Naive-Hy2---by---RIXXX/main/update.sh)
```

**What the script does:**
- ✅ Applies only new changes since the last run (versioning via `/etc/rixxx-panel/version`)
- ✅ **Does NOT touch** existing users, passwords, domains, certificates, sysctl settings
- ✅ At the end, outputs a summary: what was updated, what was skipped, version before/after
- ✅ Safe to run repeatedly (idempotent — already applied migrations are skipped)

**Useful flags:**
```bash
bash update.sh --dry-run               # show what would be done, make no changes
bash update.sh --force                 # re-run migrations even if version matches
bash update.sh --expose <panel.domain> # restore public access to the panel after SSH-only
bash update.sh --masquerade            # change masquerade mode (local | mirror)
bash update.sh --repair                # regenerate Caddyfile + Hy2 config from config.json
                                       # (with auto-backup and rollback on error)
bash update.sh --status                # diagnostics: version, services, TLS, ports
                                       # (read-only, works even without root)
bash update.sh --help                  # help
```

If the installation hasn't been done yet, the script will exit gracefully with a prompt to run `install.sh`.

---

## 🔒 SSH-only mode (panel accessible only via SSH tunnel)

This is the **most secure** mode: the panel binds to `127.0.0.1:3000` and is not visible from the Internet. Access can only be obtained via an SSH tunnel, making it impossible to brute-force or scan.

**Enabling during installation:**

When running `install.sh`, after choosing the panel access method, you will see the question:

```
Make the panel accessible only via SSH tunnel? [y/N]:
```

If you answer `y`:
- The panel will bind only to `127.0.0.1` (inside the server).
- Ports `3000/tcp` and `8080/tcp` will be closed on UFW (`deny`).
- If mode 3 (subdomain) is selected — the site block for the subdomain is **not** added to Caddyfile (the subdomain will not be publicly accessible).

**Access from your local machine:**

```bash
# 1) Open an SSH tunnel (keep the terminal open)
ssh -L 8080:127.0.0.1:3000 root@YOUR_SERVER_IP

# 2) In your local machine's browser
http://localhost:8080
```

**What to do if you need to restore public access:**

```bash
bash update.sh --expose panel.yourdomain.com
```

The command:
- Adds a site block `panel.yourdomain.com` to Caddyfile (TLS + reverse_proxy to `127.0.0.1:3000`).
- Removes UFW-deny from ports `3000/tcp` and `8080/tcp`.
- Updates `config.json`: `panelDomain`, `sshOnly=0`.
- Reloads Caddy and the panel.

The LE certificate will be issued automatically on the first request to the domain.

---

ادامه در پست بعد
```

**پست دوم (ادامه از پست قبل - ادامه در پست بعد)**

```markdown
## 🎭 Domain masquerade

Masquerade is what a random visitor sees when they open the domain in a browser (HTTPS) or what a third-party client sees when it sends a request to UDP/443 without proper authentication. The goal is to make the server look like an ordinary website, not a VPN endpoint.

During installation (`install.sh`), after entering the proxy parameters, you will see the question:

```
🎭 Masquerade (domain camouflage):

  1) Local "Loading" page (reliable, no external dependencies)
      → Simple static HTML page, always works.
  2) Mirroring an external site (reverse_proxy)
      → Caddy and Hy2 will serve the content of the specified URL.
      ⚠  If the site becomes unavailable — visitors will get a 502.
      → Recommended: https://www.apple.com, https://github.com, https://www.amd.com

Your choice [1/2, default 1]:
```

**Option 1 — local "Loading" page** (default):
- Caddy: `file_server { root /var/www/html }` (static HTML page).
- Hy2: `masquerade.type: file` (same folder).
- Pros: no external dependencies, always works, minimal resources.
- Cons: when scanned, something "non-standard" is visible (though it looks like a placeholder site).

**Option 2 — mirroring an external site** (reverse_proxy):
- Caddy: `reverse_proxy <url> { header_up Host {upstream_hostport} }`.
- Hy2: `masquerade.type: proxy, proxy.url: <url>, rewriteHost: true`.
- Pros: to a random visitor, the domain looks **exactly like** apple.com / github.com / any other site.
- Cons: **if the upstream becomes unavailable — all visitors will get a 502 error** (but proxy clients will continue to work, as they go through `forward_proxy`/QUIC).
- Recommended sites: stable large resources (apple.com, github.com, amd.com).

**Change masquerade on an existing installation:**

```bash
bash update.sh --masquerade
```

The command:
- Interactively asks for the mode (1=local, 2=mirror + URL).
- Rewrites `Caddyfile` and `/etc/hysteria/config.yaml` for the new mode.
- Updates `config.json`: `masqueradeMode`, `masqueradeUrl`.
- Reload Caddy + restart Hysteria2 + restart the panel.
- Does NOT touch: users, domain, email, certificates.

---

## 💡 Project idea

**Both protocols are brought up simultaneously** on a single server:

| Protocol    | Transport | Port       | Purpose                                                 |
|-------------|-----------|------------|---------------------------------------------------------|
| NaiveProxy  | TCP       | 443        | Masquerading as HTTPS, HTTP/2 forward-proxy (Caddy)     |
| Hysteria2   | UDP       | 443        | High-speed QUIC proxy with its own congestion control   |

**Both run on the same port 443** (TCP + UDP — different sockets, no conflict). Hysteria2 uses **Caddy's certificate** — one domain, one certificate, two protocols. To an external observer, the server looks like a normal HTTPS website with HTTP/3 support.

---

## 📋 Server requirements

### Supported OS
| OS | Version | Status |
|---|---|---|
| **Ubuntu** | 24.04 LTS | ✅ Recommended (primary for testing) |
| **Ubuntu** | 22.04 LTS | ✅ Fully supported |
| **Ubuntu** | 20.04 LTS | ⚠️ Works, but the kernel is old (BBR may be slower) |
| **Debian** | 12 (bookworm) | ✅ Fully supported |
| **Debian** | 11 (bullseye) | ✅ Fully supported |
| Other `apt`-based (Mint, Pop!_OS, …) | — | ⚠️ Should work, but not tested |
| CentOS / RHEL / Fedora / Alpine / Arch | — | ❌ Not supported (script requires `apt`) |

### Architectures
| Arch | `uname -m` | Status |
|---|---|---|
| x86_64 | `x86_64` | ✅ Primary case (99% of VPS) |
| ARM 64-bit | `aarch64` | ✅ Oracle Cloud Free ARM, AWS Graviton — works |
| ARM 32-bit | `armv7l` | ✅ Raspberry Pi 3/4 (32-bit mode) |

The script automatically detects the architecture and downloads the appropriate Hysteria2 / Go / Caddy binaries. Previously there were issues with ARM — they have been fixed in the current version (works on Oracle ARM).

### Other
- **Domain:** A record pointing to the server's IP (e.g., `vpn.yourdomain.com`) — otherwise Let's Encrypt won't issue a certificate
- **Ports:** 22/tcp (SSH), 80/tcp (ACME), 443/tcp (Naive), 443/udp (Hy2), 3000/tcp or 8080/tcp (panel)
- **RAM:** minimum **1 GB** (for building Caddy from source). For 512 MB, use swap.
- **Root access:** required
- **Kernel:** 4.9+ (for BBR). In Ubuntu 20.04+ — always newer.

---

## 🎛️ Panel features

| Feature | Description |
|---------|-------------|
| 🟢 **2-click installation** | Choose the stack (Naive / Hy2 / Both) → domain + email → done |
| 👥 **Separate users** | Separate lists for NaiveProxy and Hysteria2 |
| ⏱️ **Key expiration** | 1/3/7/14/30/90/180/365 days or unlimited. Automatic deactivation upon expiry (check every 5 min). One-click renewal. |
| 🇷🇺 **Bypass (split-tunneling)** | Load a list of Russian IPs (1000+ networks) — traffic to them goes directly, bypassing the VPN. Supported by Hysteria2 via native ACL. |
| 📊 **Smart dashboard** | Status of both services, user counter, IP, domain |
| 🔗 **Connection links** | Ready-made `naive+https://...` and `hysteria2://...` links |
| 🔄 **Service management** | Start / stop / restart Caddy and Hysteria individually |
| ⚡ **Network tuning** | Apply BBR + UDP buffers with one button |
| 🔍 **Diagnostics** | Check TCP/UDP port 443, service logs, certificate status, Hy2 config content |
| 🔒 **Panel password change** | bcrypt hashed storage |

---

## 🔌 Client software for connection

### NaiveProxy
| Platform | Application |
|----------|-------------|
| iOS      | [Karing](https://apps.apple.com/app/karing/id6472431552) |
| Android  | [NekoBox](https://github.com/MatsuriDayo/NekoBoxForAndroid/releases) / Karing |
| Windows  | Karing / [NekoRay](https://github.com/MatsuriDayo/nekoray/releases) / [v2rayN](https://github.com/2dust/v2rayN/releases) |

### Hysteria2
| Platform | Application |
|----------|-------------|
| iOS      | [Karing](https://apps.apple.com/app/karing/id6472431552) / Shadowrocket |
| Android  | [NekoBox](https://github.com/MatsuriDayo/NekoBoxForAndroid/releases) / Karing |
| Windows  | [Nekoray](https://github.com/MatsuriDayo/nekoray/releases) / v2rayN / [Hiddify](https://github.com/hiddify/hiddify-app/releases) |
| macOS    | Karing / Hiddify |
| Linux    | [hysteria CLI](https://github.com/apernet/hysteria/releases) |

**Link format:**
```
naive+https://LOGIN:PASSWORD@your.domain.com:443
hysteria2://PASSWORD@your.domain.com:443?sni=your.domain.com
```

---

ادامه در پست بعد
```

**پست سوم (ادامه از پست قبل)**

```markdown
## ⚙️ Management

```bash
# Panel
pm2 status
pm2 logs panel-naive-hy2
pm2 restart panel-naive-hy2

# NaiveProxy (Caddy)
systemctl status caddy
systemctl restart caddy
journalctl -u caddy -f

# Hysteria2
systemctl status hysteria-server
systemctl restart hysteria-server
journalctl -u hysteria-server -f
```

---

## ⏱️ Key expiration

When adding a user, you can choose the duration: `1 day / 3 / 7 / 14 / 30 / 90 / 180 / 365 days` or **unlimited**. The panel checks for expired keys every 5 minutes and automatically:

- **For NaiveProxy** — removes the `basic_auth` line from `Caddyfile` and reloads Caddy. The user receives `407 Proxy Authentication Required`.
- **For Hysteria2** — removes the entry from `auth.userpass` in `/etc/hysteria/config.yaml` and restarts `hysteria-server`. The client gets an auth reject and stops connecting.

The user table displays a colored badge:
- 🟢 **Unlimited** — gray
- 🟢 **X days** — green (>24 hours)
- 🟡 **X hours** — yellow (<24 hours until expiry)
- 🔴 **Expired** — red + line-through

The "⏰ Renew" button in the user row opens a modal to select a new duration from the current moment. An unlimited key can be made time-limited and vice versa.

---

## 🇷🇺 Bypass — direct traffic to Russian services

Some sites (banks, government services, marketplaces, banks) **block foreign IPs**. If all traffic goes through a foreign VPN, they won't open. The solution is to send traffic to them **bypassing the VPN** (split tunneling).

### In the panel: **Bypass (direct traffic)** section

1. Download the current list in JSON: for example from [antifilter.download](https://antifilter.download/) or [github.com/zapret-info](https://github.com/zapret-info/z-i)
2. Paste it into the text field and click **"Upload and enable"**
3. Formats:
   - `{"service.ru": ["1.2.3.0/24", ...], ...}` — by service
   - `["1.2.3.0/24", ...]` — just an array of CIDRs
4. The ACL file is created at `/etc/hysteria/bypass-ru.acl`, included in the Hy2 config as `acl.file: ...`, and Hy2 is restarted automatically.

### Limitations

| Protocol | Server-side bypass | Note |
|---|---|---|
| **Hysteria2** | ✅ Works via ACL | Configured once on the server, for all clients |
| **NaiveProxy** | ❌ Not supported by Caddy forward_proxy | Configured on the client (Karing / Happ / v2rayN support it) |

For NaiveProxy, the client needs to specify the bypass list locally — in Karing this is done in the "Outbound rules" section, in Happ via importing a config with rules.

---

## 🔐 Security

- Panel user passwords are stored as **bcrypt hashes**
- Proxy user passwords are encrypted when saved to disk (AES-256-GCM)
- CORS is restricted to `localhost:3000`
- Session secret is generated on first startup
- UFW is enabled automatically, unnecessary ports are closed

---

## 🔧 Troubleshooting

The panel has a **"Diagnostics"** page (in the sidebar) where you can:
- View Caddy and Hysteria2 logs without SSH
- Check who is listening on port 443/TCP and 443/UDP
- Read common reasons why Hy2 fails to start

If something is wrong — go there first.

### From the command line: `update.sh --status`

One command shows the entire installation state — patch version, service status (caddy/hysteria/panel), TLS certificates and their expiration, open ports, masquerade mode, and panel access mode:

```bash
sudo bash update.sh --status
# or without root at all (read-only):
bash update.sh --status
```

Example output:
```
  Patch version:  1.3.0  (target: 1.3.0)
  NaiveProxy:     yes
  Hysteria2:      yes
  Panel access:
    mode 3 — separate subdomain (Caddy + LE)
    SSH-only: off
  Masquerade:
    mode: mirror → https://www.apple.com
  Services:
    ● caddy: active
    ● hysteria-server: active
    ● panel-naive-hy2: active
  Caddy TLS certificates:
    • example.com: until Jul 27 12:34:56 2026 GMT
    • panel.example.com: until Jul 27 12:34:56 2026 GMT
```

### Recovery: `update.sh --repair`

If something breaks (e.g., Caddyfile corrupted by manual edits, or the panel stops responding), this command regenerates `Caddyfile` and `/etc/hysteria/config.yaml` **from `config.json`**, without touching users, domains, and certificates:

```bash
sudo bash update.sh --repair
```

**What happens:**
1. **Auto-backup** to `/etc/rixxx-panel/backups/YYYY-MM-DD-HHMMSS-repair/` — saves Caddyfile, hysteria config, panel config, systemd unit. Keeps the last 10 backups, older ones are deleted.
2. **Regeneration** of Caddyfile and Hy2 config from templates based on the current `config.json`.
3. **Validation** — `caddy validate` for Caddyfile, YAML parsing for Hy2. If the new config is invalid → automatic rollback from backup.
4. **Atomic rename** of temporary files to working paths (on ext4/xfs this is an atomic operation).
5. **Reload** services: caddy, hysteria-server, panel.
6. **Smoke-test** — `systemctl is-active` for all services.

### Smoke-test after installation

`install.sh` now automatically checks at the very end that everything works:
- `caddy validate --config /etc/caddy/Caddyfile`
- `systemctl is-active caddy / hysteria-server / panel-naive-hy2`
- `curl http://127.0.0.1:3000/` (panel responds locally)
- `curl https://<proxy.domain>/` and `https://<panel.domain>/` (TLS works)

If problems are found, a **specific error** and a hint are displayed: `bash update.sh --repair` or `bash update.sh --status`.

---

## 📜 Changelog

### v1.4.1 — `--ssh-only` flag (PR #9)
- 🆕 **`bash update.sh --ssh-only`** — switch an already running installation to SSH-only mode with a single command, without reinstalling. Symmetrical to the existing `--expose <domain>`.
- 🛡️ **Preserved when switching**: NaiveProxy/Hysteria2 users (with all passwords and links), proxy domain and its TLS certificate, masquerade mode (mirror/local), Hysteria2 config, `panelDomain` in config.json.
- 🚪 **What it does**: interactively shows the current state and asks for confirmation → `auto_backup "ssh-only"` (rollback point) → removes the panel block from Caddyfile (if it existed) with validation and rollback → UFW deny 8080/tcp + 3000/tcp → stops nginx → writes `sshOnly=1, listenHost=127.0.0.1` into config.json → systemd Environment + PM2 delete+start with explicit env (lesson from PR #8) → reload Caddy → curl-check that the panel responds on `127.0.0.1:3000`.
- 🔄 **Symmetrical rollback**: `bash update.sh --expose <the same panelDomain>` restores public access.
- 🤖 **Non-interactive mode**: `bash update.sh --ssh-only --yes` (for automation).
- 🔮 **Regression protection when issuing keys**: backend `writeCaddyfile()` now respects `cfg.sshOnly === 1` (since PR #4) — when adding new Naive users, the panel block is NOT restored, so the panel reliably stays hidden.

### v1.4.0 — Hotfix: SSH-only mode (PR #7)
- 🔒 **Closed a hole in SSH-only mode**: with `ACCESS_MODE=1 + SSH_ONLY=1`, the final UFW block in `install.sh` overwrote the early `deny` with `ufw allow 8080/tcp`, and Nginx bound to `0.0.0.0:8080` — the panel remained accessible from the Internet despite `LISTEN_HOST=127.0.0.1` on the backend. Now `SSH_ONLY=1` forcibly switches the installation to direct bind mode on `127.0.0.1:${INTERNAL_PORT}` (without Nginx), and the final UFW block checks `SSH_ONLY` as the highest priority and permanently closes 8080/tcp + 3000/tcp.
- 🔧 **Migration 1.4.0** (`migrate_ssh_only_close_ports`) — for already installed servers with `sshOnly=1`: automatically closes 8080/tcp and 3000/tcp in UFW (and removes old `allow` rules), stops and disables `nginx`, ensures `LISTEN_HOST=127.0.0.1` in systemd unit and PM2 env, restarts the panel and finally checks that the external IP does not respond on those ports. Applied with a single command: `bash <(curl -fsSL https://raw.githubusercontent.com/cwash797-cmd/Panel---Naive-Hy2---by---RIXXX/main/update.sh)`.
- ✅ **Migration contract**: if `sshOnly=0` — migration is no-op (the legitimate public mode `ACCESS_MODE=1` via Nginx proxy is not broken).

### v1.3.2 — Hotfix: masquerade (PR #6)
- 🐞 **`update.sh --masquerade` crashed with `Cannot find module 'js-yaml'`**: Node script was run from `/root/`, where there is no `node_modules`. Now all three Node calls in `update.sh` (`do_masquerade()`, `do_repair()`, YAML validation in atomic write) are wrapped in `(cd "$PANEL_DIR/panel" && node -e "...")` — modules resolve correctly.
- 🐞 **Mirror on large sites (GitHub, Apple, Cloudflare, etc.) did not work**: they block `reverse_proxy` requests from foreign servers, NaiveProxy clients got `502 / EOF`. In the recommendations of `install.sh` and `update.sh --masquerade`, examples have been replaced with static sites: `iana.org`, `ietf.org`, `demo.nginx.com`. Default on empty input is now `https://www.iana.org`.
- ⚠️ **Warning in the installer**: when choosing mirror mode, an explicit message about large sites and the risk of 502/EOF is now shown — users will no longer accidentally set github.com.

### v1.3.1 — UI hotfix (PR #5)
- 🆕 **Dynamic version in the panel**: new endpoint `GET /api/system/version` reads `/etc/rixxx-panel/version`, the "Settings → Panel Information" page now displays the actual version (previously it was hardcoded to `1.0.0`).
- 🆕 **Hints in "Diagnostics"**: added a CLI tools block with links to `bash update.sh --status` and `sudo bash update.sh --repair` (with a `--dry-run` example).
- ⚠️ **Note in the Bypass section**: explicit warning that the feature is under active testing — be sure to test on your own client before using in production.

### v1.3 — Stability and diagnostics (PR #4)
- 🆕 **`update.sh --repair`** — regenerate Caddyfile + Hy2 config from `config.json` with auto-backup, validation, and rollback on error
- 🆕 **`update.sh --status`** — one command shows the entire state (version, services, TLS, ports, modes); works without root
- 🆕 **Auto-backup** in `/etc/rixxx-panel/backups/` — all key files are saved before changes, keeps the last 10
- 🆕 **Smoke-test in `install.sh`** — after installation, functionality is automatically verified (caddy validate, systemctl is-active, curl to domains)
- 🐞 **Atomic protection for `writeCaddyfile()`**: write via temp file → `caddy validate` → `atomic rename`. On any error — automatic rollback from `.last` backup. This finally closes the bug with losing the panel block when adding Naive users.
- 🐞 **Atomic protection for `writeHysteriaConfig()`**: temp file + self-validate (yaml.load) + atomic rename + rollback from `.last`.
- 🐞 **`writeCaddyfile()` respects `sshOnly=1`** — panel block is not added in SSH-only mode even during regeneration (previously it could be restored when adding users).

### v1.2 — Fix for concurrent operation of Naive + Hy2
- 🐞 **Hy2 did not start when Naive was present**: Caddy by default occupied UDP/443 for HTTP/3 (QUIC), preventing Hy2 from binding. Now when installing both protocols, `servers { protocols h1 h2 }` is added to `Caddyfile` — HTTP/3 is disabled in Caddy, UDP/443 is free for Hy2.
- 🆕 **"Diagnostics" page** in the panel — logs + port checking
- 🆕 The `install_hysteria.sh` script now patches an already installed Caddyfile when installing Hy2 on top of Naive
- 🆕 Final checks in `install.sh`: panel responds on `:3000`, nginx listens on `:8080`
- 🆕 Systemd fallback if PM2 fails to start the panel
- 🐞 `writeCaddyfile` in the backend now preserves the directive to disable HTTP/3 when adding/removing Naive users

### v1.1 — Concurrent startup of Naive + Hy2 (4 fixes)
- Hysteria2 now starts after Caddy (`After=caddy.service`)
- Read existing `/etc/hysteria/config.yaml` when modifying users (previously it would overwrite the TLS section)
- Search for Caddy certificate in both possible paths
- Valid JSON `config.json` (heredoc + variables)

### v1.0 — First release
- Multi-arch Go (amd64 / arm64 / armv6l)
- 2-click installation of both protocols
- Unified panel for Naive + Hy2
- BBR + UDP tuning

---

*by RIXXX — multi-protocol proxy panel with a user-friendly interface*
```


--------------------------------------
```markdown
# پنل Naive + Hysteria2 اثر RIXXX

> پنل وب برای نصب و مدیریت سریع **NaiveProxy** و **Hysteria2** روی یک VPS — در **۲ کلیک**

---

## 🚀 نصب سریع
```markdown
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mononoor/PNHR/main/install.sh)
```

بعد از نصب، پنل در آدرس زیر در دسترس است:
```
http://IP_سرور_شما:3000
```

**نام کاربری و رمز عبور پیش‌فرض:** `admin` / `admin` — **بلافاصله تغییر دهید!**

---

## 🔄 بروزرسانی نصب موجود

برای اعمال وصله‌های جدید (بهبودها، گزینه‌های جدید) **بدون نصب مجدد کامل** از `update.sh` استفاده کنید:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/cwash797-cmd/Panel---Naive-Hy2---by---RIXXX/main/update.sh)
```

**کارهایی که اسکریپت انجام می‌دهد:**
- ✅ فقط تغییرات جدید از آخرین اجرا را اعمال می‌کند (نسخه‌گذاری از طریق `/etc/rixxx-panel/version`)
- ✅ **به** کاربران، رمزهای عبور، دامنه‌ها، گواهی‌ها، تنظیمات sysctl **دست نمی‌زند**
- ✅ در پایان خلاصه‌ای نشان می‌دهد: چه چیزی به‌روز شد، چه چیزی رد شد، نسخه قبل/بعد
- ✅ اجرای مجدد بی‌خطر است (idempotent — مهاجرت‌های قبلی تکرار نمی‌شوند)

**پرچم‌های مفید:**
```bash
bash update.sh --dry-run               # نشان می‌دهد چه کاری انجام می‌شود، هیچ تغییری اعمال نمی‌کند
bash update.sh --force                 # مهاجرت‌ها را حتی اگر نسخه یکی باشد دوباره اجرا می‌کند
bash update.sh --expose <panel.domain> # برگرداندن دسترسی عمومی به پنل بعد از حالت SSH-only
bash update.sh --masquerade            # تغییر حالت پنهان‌سازی (local | mirror)
bash update.sh --repair                # بازتولید Caddyfile و Hy2 config از روی config.json
                                       # (با پشتیبان‌گیری خودکار و برگشت در صورت خطا)
bash update.sh --status                # عیب‌یابی: نسخه، سرویس‌ها، TLS، پورت‌ها
                                       # (فقط خواندنی، حتی بدون root کار می‌کند)
bash update.sh --help                  # راهنما
```

اگر نصب انجام نشده باشد، اسکریپت با آرامش خارج می‌شود و راهنمای اجرای `install.sh` را نشان می‌دهد.

---

## 🔒 حالت SSH-only (پنل فقط از طریق تونل SSH قابل دسترس)

این **بیشترین سطح امنیت** را دارد: پنل روی `127.0.0.1:3000` متصل می‌شود و از اینترنت قابل مشاهده نیست. دسترسی فقط از طریق تونل SSH امکان‌پذیر است که حمله brute-force یا اسکن را غیرممکن می‌کند.

**فعال‌سازی هنگام نصب:**

هنگام اجرای `install.sh`، بعد از انتخاب روش دسترسی به پنل، این سوال را می‌بینید:

```
آیا پنل فقط از طریق تونل SSH قابل دسترس باشد؟ [y/N]:
```

اگر `y` پاسخ دهید:
- پنل فقط به `127.0.0.1` (داخل سرور) متصل می‌شود.
- پورت‌های `3000/tcp` و `8080/tcp` روی UFW بسته می‌شوند (`deny`).
- اگر حالت ۳ (زیردامنه) انتخاب شده باشد — بلوک سایت زیردامنه به Caddyfile **اضافه نمی‌شود** (زیردامنه به صورت عمومی در دسترس نخواهد بود).

**دسترسی از ماشین محلی:**

```bash
# ۱) باز کردن تونل SSH (ترمینال را باز نگه دارید)
ssh -L 8080:127.0.0.1:3000 root@IP_سرور_شما

# ۲) در مرورگر روی ماشین محلی
http://localhost:8080
```

**اگر نیاز به بازگرداندن دسترسی عمومی دارید:**

```bash
bash update.sh --expose panel.yourdomain.com
```

این دستور:
- بلوک سایت `panel.yourdomain.com` را به Caddyfile اضافه می‌کند (TLS + reverse_proxy به `127.0.0.1:3000`).
- ممنوعیت UFW را از پورت‌های `3000/tcp` و `8080/tcp` برمی‌دارد.
- `config.json` را به‌روز می‌کند: `panelDomain`، `sshOnly=0`.
- Caddy و پنل را دوباره بارگیری می‌کند.

گواهی LE به طور خودکار در اولین درخواست به دامنه صادر می‌شود.

---

## 🎭 پنهان‌سازی دامنه (masquerade)

پنهان‌سازی همان چیزی است که یک بازدیدکننده تصادفی هنگام باز کردن دامنه در مرورگر (HTTPS) یا یک کلاینت شخص ثالث که درخواستی به UDP/443 بدون احراز هویت صحیح می‌فرستد، می‌بیند. هدف این است که سرور شبیه یک وب‌سایت معمولی به نظر برسد، نه یک endpoint VPN.

هنگام نصب (`install.sh`)، بعد از وارد کردن پارامترهای پروکسی، این سوال را می‌بینید:

```
🎭 پنهان‌سازی (استتار دامنه):

  ۱) صفحه محلی «Loading» (قابل اعتماد، بدون وابستگی خارجی)
      → یک صفحه HTML استاتیک ساده، همیشه کار می‌کند.
  ۲) آینه‌سازی یک سایت خارجی (reverse_proxy)
      → Caddy و Hy2 محتوای URL مشخص شده را ارائه می‌دهند.
      ⚠  اگر سایت در دسترس نباشد — بازدیدکنندگان خطای 502 می‌گیرند.
      → پیشنهادی: https://www.apple.com, https://github.com, https://www.amd.com

انتخاب شما [1/2، پیش‌فرض ۱]:
```

**گزینه ۱ — صفحه محلی «Loading»** (پیش‌فرض):
- Caddy: `file_server { root /var/www/html }` (صفحه HTML استاتیک).
- Hy2: `masquerade.type: file` (همان پوشه).
- مزایا: بدون وابستگی خارجی، همیشه کار می‌کند، حداقل منابع.
- معایب: هنگام اسکن، چیزی «غیر استاندارد» دیده می‌شود (اگرچه شبیه یک سایت جایگزین به نظر می‌رسد).

**گزینه ۲ — آینه‌سازی یک سایت خارجی** (reverse_proxy):
- Caddy: `reverse_proxy <url> { header_up Host {upstream_hostport} }`.
- Hy2: `masquerade.type: proxy, proxy.url: <url>, rewriteHost: true`.
- مزایا: برای یک بازدیدکننده تصادفی، دامنه **دقیقاً شبیه** apple.com / github.com / هر سایت دیگری به نظر می‌رسد.
- معایب: **اگر upstream در دسترس نباشد — همه بازدیدکنندگان خطای 502 می‌گیرند** (اما کلاینت‌های پروکسی به کار خود ادامه می‌دهند، زیرا از `forward_proxy`/QUIC عبور می‌کنند).
- سایت‌های پیشنهادی: منابع پایدار بزرگ (apple.com, github.com, amd.com).

**تغییر پنهان‌سازی روی نصب موجود:**

```bash
bash update.sh --masquerade
```

دستور:
- به صورت تعاملی حالت را می‌پرسد (۱=محلی، ۲=آینه + URL).
- `Caddyfile` و `/etc/hysteria/config.yaml` را برای حالت جدید بازنویسی می‌کند.
- `config.json` را به‌روز می‌کند: `masqueradeMode`، `masqueradeUrl`.
- Caddy را بارگیری مجدد + Hysteria2 را راه‌اندازی مجدد + پنل را راه‌اندازی مجدد می‌کند.
- **به** کاربران، دامنه، ایمیل، گواهی‌ها **دست نمی‌زند**.

---

## 💡 ایده پروژه

**هر دو پروتکل به طور همزمان** روی یک سرور راه‌اندازی می‌شوند:

| پروتکل     | ترابری | پورت | هدف |
|------------|--------|------|------|
| NaiveProxy | TCP    | 443  | استتار به عنوان HTTPS، HTTP/2 forward-proxy (Caddy) |
| Hysteria2  | UDP    | 443  | پروکسی پرسرعت QUIC با کنترل ازدحام اختصاصی |

**هر دو روی یک پورت 443 کار می‌کنند** (TCP + UDP — سوکت‌های متفاوت، تداخلی وجود ندارد). Hysteria2 از **گواهی Caddy** استفاده می‌کند — یک دامنه، یک گواهی، دو پروتکل. برای یک ناظر خارجی، سرور مانند یک وب‌سایت عادی HTTPS با پشتیبانی HTTP/3 به نظر می‌رسد.

---

## 📋 الزامات سرور

### سیستم‌عامل‌های پشتیبانی شده

| سیستم‌عامل | نسخه | وضعیت |
|------------|------|--------|
| **Ubuntu** | 24.04 LTS | ✅ توصیه می‌شود (اصلی برای تست) |
| **Ubuntu** | 22.04 LTS | ✅ به طور کامل پشتیبانی می‌شود |
| **Ubuntu** | 20.04 LTS | ⚠️ کار می‌کند، اما کرنل قدیمی است (BBR ممکن است کندتر باشد) |
| **Debian** | 12 (bookworm) | ✅ به طور کامل پشتیبانی می‌شود |
| **Debian** | 11 (bullseye) | ✅ به طور کامل پشتیبانی می‌شود |
| سایر توزیع‌های مبتنی بر `apt` (Mint، Pop!_OS، …) | — | ⚠️ باید کار کنند، اما تست نشده‌اند |
| CentOS / RHEL / Fedora / Alpine / Arch | — | ❌ پشتیبانی نمی‌شوند (اسکریپت نیاز به `apt` دارد) |

### معماری‌ها

| معماری | `uname -m` | وضعیت |
|--------|------------|--------|
| x86_64 | `x86_64` | ✅ حالت اصلی (۹۹٪ VPSها) |
| ARM 64-bit | `aarch64` | ✅ Oracle Cloud Free ARM، AWS Graviton — کار می‌کند |
| ARM 32-bit | `armv7l` | ✅ Raspberry Pi 3/4 (حالت ۳۲ بیتی) |

اسکریپت به طور خودکار معماری را تشخیص می‌دهد و باینری‌های مناسب Hysteria2 / Go / Caddy را دانلود می‌کند. قبلاً مشکلاتی با ARM وجود داشت — در نسخه فعلی برطرف شده است (روی Oracle ARM کار می‌کند).

### سایر موارد

- **دامنه:** رکورد A به سمت IP سرور (مثلاً `vpn.yourdomain.com`) — در غیر این صورت Let's Encrypt گواهی صادر نمی‌کند
- **پورت‌ها:** 22/tcp (SSH)، 80/tcp (ACME)، 443/tcp (Naive)، 443/udp (Hy2)، 3000/tcp یا 8080/tcp (پنل)
- **RAM:** حداقل **۱ گیگابایت** (برای کامپایل Caddy از سورس). برای ۵۱۲ مگابایت از swap استفاده کنید.
- **دسترسی root:** الزامی است
- **کرنل:** ۴.۹+ (برای BBR). در اوبونتو ۲۰.۰۴+ — همیشه جدیدتر است.

---

## 🎛️ قابلیت‌های پنل

| قابلیت | توضیحات |
|--------|----------|
| 🟢 **نصب در ۲ کلیک** | پشته (Naive / Hy2 / هر دو) → دامنه + ایمیل → انجام شد |
| 👥 **کاربران جداگانه** | لیست‌های جداگانه برای NaiveProxy و Hysteria2 |
| ⏱️ **انقضای کلیدها** | ۱/۳/۷/۱۴/۳۰/۹۰/۱۸۰/۳۶۵ روز یا نامحدود. غیرفعال‌سازی خودکار پس از انقضا (بررسی هر ۵ دقیقه). تمدید با یک کلیک. |
| 🇷🇺 **Bypass (مسیریابی انتخابی)** | بارگیری لیست IPهای روسی (۱۰۰۰+ شبکه) — ترافیک آنها مستقیماً و بدون عبور از VPN می‌رود. توسط Hysteria2 از طریق ACL بومی پشتیبانی می‌شود. |
| 📊 **داشبورد هوشمند** | وضعیت هر دو سرویس، تعداد کاربران، IP، دامنه |
| 🔗 **لینک‌های اتصال** | لینک‌های آماده `naive+https://...` و `hysteria2://...` |
| 🔄 **مدیریت سرویس‌ها** | شروع / توقف / راه‌اندازی مجدد Caddy و Hysteria به صورت جداگانه |
| ⚡ **تنظیمات شبکه** | اعمال BBR + بافرهای UDP با یک دکمه |
| 🔍 **عیب‌یابی** | بررسی پورت TCP/UDP 443، لاگ سرویس‌ها، وضعیت گواهی‌ها، محتوای تنظیمات Hy2 |
| 🔒 **تغییر رمز پنل** | ذخیره‌سازی هش شده با bcrypt |

---

## 🔌 نرم‌افزار کلاینت برای اتصال

### NaiveProxy

| پلتفرم | برنامه |
|--------|--------|
| iOS | [Karing](https://apps.apple.com/app/karing/id6472431552) |
| Android | [NekoBox](https://github.com/MatsuriDayo/NekoBoxForAndroid/releases) / Karing |
| Windows | Karing / [NekoRay](https://github.com/MatsuriDayo/nekoray/releases) / [v2rayN](https://github.com/2dust/v2rayN/releases) |

### Hysteria2

| پلتفرم | برنامه |
|--------|--------|
| iOS | [Karing](https://apps.apple.com/app/karing/id6472431552) / Shadowrocket |
| Android | [NekoBox](https://github.com/MatsuriDayo/NekoBoxForAndroid/releases) / Karing |
| Windows | [Nekoray](https://github.com/MatsuriDayo/nekoray/releases) / v2rayN / [Hiddify](https://github.com/hiddify/hiddify-app/releases) |
| macOS | Karing / Hiddify |
| Linux | [hysteria CLI](https://github.com/apernet/hysteria/releases) |

**فرمت لینک‌ها:**
```
naive+https://LOGIN:PASSWORD@your.domain.com:443
hysteria2://PASSWORD@your.domain.com:443?sni=your.domain.com
```

---

## ⚙️ مدیریت

```bash
# پنل
pm2 status
pm2 logs panel-naive-hy2
pm2 restart panel-naive-hy2

# NaiveProxy (Caddy)
systemctl status caddy
systemctl restart caddy
journalctl -u caddy -f

# Hysteria2
systemctl status hysteria-server
systemctl restart hysteria-server
journalctl -u hysteria-server -f
```

---

## ⏱️ انقضای کلیدها

هنگام افزودن کاربر می‌توانید مدت زمان را انتخاب کنید: `1 day / 3 / 7 / 14 / 30 / 90 / 180 / 365 days` یا **نامحدود**. پنل هر ۵ دقیقه کاربران منقضی شده را بررسی می‌کند و به طور خودکار:

- **برای NaiveProxy** — خط `basic_auth` را از `Caddyfile` حذف کرده و Caddy را بارگیری مجدد می‌کند. کاربر خطای `407 Proxy Authentication Required` دریافت می‌کند.
- **برای Hysteria2** — ورودی را از `auth.userpass` در `/etc/hysteria/config.yaml` حذف کرده و `hysteria-server` را راه‌اندازی مجدد می‌کند. کلاینت auth reject دریافت کرده و اتصال قطع می‌شود.

در جدول کاربران، نشان رنگی نمایش داده می‌شود:
- 🟢 **نامحدود** — خاکستری
- 🟢 **X روز** — سبز (بیش از ۲۴ ساعت)
- 🟡 **X ساعت** — زرد (کمتر از ۲۴ ساعت تا انقضا)
- 🔴 **منقضی شده** — قرمز + خط خورده

دکمه «⏰ تمدید» در ردیف کاربر، یک پنجره بازشو برای انتخاب مدت جدید از لحظه فعلی باز می‌کند. یک کلید نامحدود را می‌توان موقت کرد و بالعکس.

---

## 🇷🇺 Bypass — ترافیک مستقیم به سرویس‌های روسی

برخی از سایت‌ها (بانک‌ها، خدمات دولتی، بازارهای آنلاین، بانک‌ها) **IPهای خارجی را مسدود می‌کنند**. اگر تمام ترافیک از طریق VPN خارجی عبور کند، باز نمی‌شوند. راه حل این است که ترافیک مربوط به آنها **بدون عبور از VPN** فرستاده شود (مسیریابی انتخابی).

### در پنل: بخش **Bypass (ترافیک مستقیم)**

۱. لیست فعلی را با فرمت JSON دانلود کنید: مثلاً از [antifilter.download](https://antifilter.download/) یا [github.com/zapret-info](https://github.com/zapret-info/z-i)
۲. در قسمت متنی قرار داده و روی **«بارگذاری و فعال‌سازی»** کلیک کنید
۳. فرمت‌ها:
   - `{"service.ru": ["1.2.3.0/24", ...], ...}` — بر اساس سرویس
   - `["1.2.3.0/24", ...]` — فقط آرایه‌ای از CIDRها
۴. فایل ACL در مسیر `/etc/hysteria/bypass-ru.acl` ایجاد می‌شود، در تنظیمات Hy2 به عنوان `acl.file: ...` قرار می‌گیرد و Hy2 به طور خودکار راه‌اندازی مجدد می‌شود.

### محدودیت‌ها

| پروتکل | پشتیبانی سمت سرور | توضیح |
|--------|-------------------|-------|
| **Hysteria2** | ✅ از طریق ACL کار می‌کند | یک بار روی سرور پیکربندی می‌شود، برای همه کلاینت‌ها |
| **NaiveProxy** | ❌ توسط Caddy forward_proxy پشتیبانی نمی‌شود | روی کلاینت پیکربندی می‌شود (Karing / Happ / v2rayN پشتیبانی می‌کنند) |

برای NaiveProxy، کلاینت باید لیست bypass را به صورت محلی مشخص کند — در Karing این کار در بخش «Outbound rules» انجام می‌شود، در Happ از طریق وارد کردن کانفیگ با rules.

---

## 🔐 امنیت

- رمزهای عبور کاربران پنل به صورت **bcrypt hash** ذخیره می‌شوند
- رمزهای عبور کاربران پروکسی هنگام ذخیره روی دیسک رمزگذاری می‌شوند (AES-256-GCM)
- CORS به `localhost:3000` محدود شده است
- کلید نشست در اولین راه‌اندازی تولید می‌شود
- UFW به طور خودکار فعال می‌شود، پورت‌های اضافی بسته می‌شوند

---

## 🔧 عیب‌یابی

پنل یک صفحه **«عیب‌یابی»** (در منوی کناری) دارد که در آن می‌توانید:
- لاگ‌های Caddy و Hysteria2 را بدون SSH مشاهده کنید
- بررسی کنید چه کسی به پورت 443/TCP و 443/UDP گوش می‌دهد
- دلایل رایج عدم راه‌اندازی Hy2 را بخوانید

اگر مشکلی وجود دارد — اول به آنجا مراجعه کنید.

### از خط فرمان: `update.sh --status`

یک دستور وضعیت کامل نصب را نشان می‌دهد — نسخه وصله، وضعیت سرویس‌ها (caddy/hysteria/panel)، گواهی‌های TLS و تاریخ انقضای آنها، پورت‌های باز، حالت پنهان‌سازی و حالت دسترسی به پنل:

```bash
sudo bash update.sh --status
# یا بدون root (فقط خواندنی):
bash update.sh --status
```

نمونه خروجی:
```
  Patch version:  1.3.0  (target: 1.3.0)
  NaiveProxy:     yes
  Hysteria2:      yes
  Panel access:
    mode 3 — separate subdomain (Caddy + LE)
    SSH-only: off
  Masquerade:
    mode: mirror → https://www.apple.com
  Services:
    ● caddy: active
    ● hysteria-server: active
    ● panel-naive-hy2: active
  Caddy TLS certificates:
    • example.com: until Jul 27 12:34:56 2026 GMT
    • panel.example.com: until Jul 27 12:34:56 2026 GMT
```

### بازیابی: `update.sh --repair`

اگر چیزی خراب شد (مثلاً Caddyfile با ویرایش دستی خراب شده، یا پنل پاسخ نمی‌دهد)، این دستور `Caddyfile` و `/etc/hysteria/config.yaml` را **از روی `config.json`** بازتولید می‌کند، بدون اینکه به کاربران، دامنه‌ها و گواهی‌ها دست بزند:

```bash
sudo bash update.sh --repair
```

**چه اتفاقی می‌افتد:**
۱. **پشتیبان‌گیری خودکار** در `/etc/rixxx-panel/backups/YYYY-MM-DD-HHMMSS-repair/` — Caddyfile، کانفیگ hysteria، کانفیگ پنل، واحد systemd ذخیره می‌شوند. آخرین ۱۰ پشتیبان نگهداری می‌شوند، پشتیبان‌های قدیمی حذف می‌شوند.
۲. **بازتولید** Caddyfile و Hy2 config از روی قالب‌ها بر اساس `config.json` فعلی.
۳. **اعتبارسنجی** — `caddy validate` برای Caddyfile، تجزیه YAML برای Hy2. اگر کانفیگ جدید نامعتبر باشد → برگشت خودکار از پشتیبان.
۴. **تغییر نام اتمیک** فایل‌های موقت به مسیرهای کاری (در ext4/xfs این یک عملیات اتمیک است).
۵. **بارگیری مجدد** سرویس‌ها: caddy، hysteria-server، پنل.
۶. **آزمون پایداری** — `systemctl is-active` برای همه سرویس‌ها.

### آزمون پایداری بعد از نصب

`install.sh` اکنون در انتها به طور خودکار بررسی می‌کند که همه چیز کار می‌کند:
- `caddy validate --config /etc/caddy/Caddyfile`
- `systemctl is-active caddy / hysteria-server / panel-naive-hy2`
- `curl http://127.0.0.1:3000/` (پنل به صورت محلی پاسخ می‌دهد)
- `curl https://<proxy.domain>/` و `https://<panel.domain>/` (TLS کار می‌کند)

اگر مشکلی یافت شود، **خطای خاص** و یک راهنما نمایش داده می‌شود: `bash update.sh --repair` یا `bash update.sh --status`.

---

## 📜 تاریخچه تغییرات

### v1.4.1 — پرچم `--ssh-only` (PR #9)
- 🆕 **`bash update.sh --ssh-only`** — تغییر یک نصب در حال اجرا به حالت SSH-only با یک دستور، بدون نصب مجدد. متقارن با `--expose <domain>` موجود.
- 🛡️ **هنگام تغییر حفظ می‌شوند**: کاربران NaiveProxy/Hysteria2 (با تمام رمزها و لینک‌ها)، دامنه پروکسی و گواهی TLS آن، حالت پنهان‌سازی (mirror/local)، کانفیگ Hysteria2، `panelDomain` در config.json.
- 🚪 **چه کاری انجام می‌دهد**: به صورت تعاملی وضعیت فعلی را نشان می‌دهد و تأیید می‌خواهد → `auto_backup "ssh-only"` (نقطه بازگشت) → بلوک پنل را از Caddyfile حذف می‌کند (اگر وجود داشت) با اعتبارسنجی و برگشت → UFW deny 8080/tcp + 3000/tcp → nginx را متوقف می‌کند → `sshOnly=1, listenHost=127.0.0.1` را در config.json می‌نویسد → systemd Environment و PM2 delete+start با env صریح (درس از PR #8) → Caddy را بارگیری مجدد می‌کند → بررسی curl که پنل روی `127.0.0.1:3000` پاسخ می‌دهد.
- 🔄 **بازگشت متقارن**: `bash update.sh --expose <همان panelDomain>` دسترسی عمومی را بازمی‌گرداند.
- 🤖 **حالت غیرتعاملی**: `bash update.sh --ssh-only --yes` (برای خودکارسازی).
- 🔮 **محافظت در برابر بازگشت هنگام صدور کلیدها**: backend `writeCaddyfile()` اکنون به `cfg.sshOnly === 1` احترام می‌گذارد (از PR #4) — هنگام افزودن کاربران جدید Naive، بلوک پنل بازگردانده نمی‌شود، بنابراین پنل به طور قابل اعتماد مخفی می‌ماند.

### v1.4.0 — رفع مشکل حالت SSH-only (PR #7)
- 🔒 **بستن یک حفره در حالت SSH-only**: با `ACCESS_MODE=1 + SSH_ONLY=1`، بلوک نهایی UFW در `install.sh` دستور اولیه `deny` را با `ufw allow 8080/tcp` بازنویسی می‌کرد و Nginx به `0.0.0.0:8080` متصل می‌شد — علی رغم `LISTEN_HOST=127.0.0.1` در backend، پنل از اینترنت قابل دسترس باقی می‌ماند. اکنون `SSH_ONLY=1` به زور نصب را به حالت bind مستقیم روی `127.0.0.1:${INTERNAL_PORT}` (بدون Nginx) تغییر می‌دهد و بلوک نهایی UFW `SSH_ONLY` را با بالاترین اولویت بررسی کرده و 8080/tcp + 3000/tcp را برای همیشه می‌بندد.
- 🔧 **مهاجرت 1.4.0** (`migrate_ssh_only_close_ports`) — برای سرورهای از قبل نصب شده با `sshOnly=1`: به طور خودکار 8080/tcp و 3000/tcp را در UFW می‌بندد (و قوانین قدیمی `allow` را حذف می‌کند)، `nginx` را متوقف و غیرفعال می‌کند، `LISTEN_HOST=127.0.0.1` را در systemd unit و PM2 env تضمین می‌کند، پنل را مجدداً راه‌اندازی می‌کند و در نهایت بررسی می‌کند که IP خارجی روی آن پورت‌ها پاسخ نمی‌دهد. با یک دستور اعمال می‌شود: `bash <(curl -fsSL https://raw.githubusercontent.com/cwash797-cmd/Panel---Naive-Hy2---by---RIXXX/main/update.sh)`.
- ✅ **قرارداد مهاجرت**: اگر `sshOnly=0` باشد — مهاجرت هیچ کاری انجام نمی‌دهد (حالت عمومی قانونی `ACCESS_MODE=1` از طریق پروکسی Nginx خراب نمی‌شود).

### v1.3.2 — رفع مشکل پنهان‌سازی (PR #6)
- 🐞 **`update.sh --masquerade` با خطای `Cannot find module 'js-yaml'` سقوط می‌کرد**: اسکریپت Node از `/root/` اجرا می‌شد، جایی که `node_modules` وجود ندارد. اکنون هر سه فراخوانی Node در `update.sh` (`do_masquerade()`، `do_repair()`، اعتبارسنجی YAML در write اتمیک) در `(cd "$PANEL_DIR/panel" && node -e "...")` پیچیده شده‌اند — ماژول‌ها به درستی حل می‌شوند.
- 🐞 **آینه‌سازی روی سایت‌های بزرگ (GitHub، Apple، Cloudflare و غیره) کار نمی‌کرد**: آنها درخواست‌های `reverse_proxy` از سرورهای خارجی را مسدود می‌کنند، کلاینت‌های NaiveProxy `502 / EOF` می‌گرفتند. در توصیه‌های `install.sh` و `update.sh --masquerade`، مثال‌ها با سایت‌های استاتیک جایگزین شده‌اند: `iana.org`، `ietf.org`، `demo.nginx.com`. پیش‌فرض در صورت ورودی خالی اکنون `https://www.iana.org` است.
- ⚠️ **اخطار در نصاب**: هنگام انتخاب حالت mirror، یک پیام واضح در مورد سایت‌های بزرگ و خطر 502/EOF نشان داده می‌شود — کاربران دیگر به طور تصادفی github.com را تنظیم نمی‌کنند.

### v1.3.1 — رفع سریع UI (PR #5)
- 🆕 **نسخه پویا در پنل**: endpoint جدید `GET /api/system/version` فایل `/etc/rixxx-panel/version` را می‌خواند، صفحه «تنظیمات → اطلاعات پنل» اکنون نسخه واقعی را نشان می‌دهد (قبلاً `1.0.0` سخت کد شده بود).
- 🆕 **راهنما در «عیب‌یابی»**: یک بلوک ابزارهای خط فرمان با لینک‌هایی به `bash update.sh --status` و `sudo bash update.sh --repair` (با مثال `--dry-run`) اضافه شد.
- ⚠️ **یادداشت در بخش Bypass**: هشدار صریح که این قابلیت در حال تست فعال است — حتماً قبل از استفاده در محیط تولید روی کلاینت خود تست کنید.

### v1.3 — پایداری و عیب‌یابی (PR #4)
- 🆕 **`update.sh --repair`** — بازتولید Caddyfile + Hy2 config از روی `config.json` با پشتیبان‌گیری خودکار، اعتبارسنجی و برگشت در صورت خطا
- 🆕 **`update.sh --status`** — یک دستور کل وضعیت را نشان می‌دهد (نسخه، سرویس‌ها، TLS، پورت‌ها، حالت‌ها)؛ بدون root کار می‌کند
- 🆕 **پشتیبان‌گیری خودکار** در `/etc/rixxx-panel/backups/` — همه فایل‌های کلیدی قبل از تغییرات ذخیره می‌شوند، آخرین ۱۰ نسخه نگهداری می‌شوند
- 🆕 **آزمون پایداری در `install.sh`** — بعد از نصب، عملکرد به طور خودکار بررسی می‌شود (`caddy validate`، `systemctl is-active`، curl به دامنه‌ها)
- 🐞 **محافظت اتمیک `writeCaddyfile()`**: نوشتن از طریق فایل موقت → `caddy validate` → `atomic rename`. در هر خطایی — برگشت خودکار از پشتیبان `.last`. این در نهایت باگ از دست رفتن بلوک پنل هنگام افزودن کاربران Naive را می‌بندد.
- 🐞 **محافظت اتمیک `writeHysteriaConfig()`**: فایل موقت + خود اعتبارسنجی (yaml.load) + تغییر نام اتمیک + برگشت از `.last`.
- 🐞 **`writeCaddyfile()` به `sshOnly=1` احترام می‌گذارد** — بلوک پنل در حالت SSH-only حتی در هنگام بازتولید اضافه نمی‌شود (قبلاً هنگام افزودن کاربران می‌توانست بازگردانده شود).

### v1.2 — رفع مشکل کار همزمان Naive + Hy2
- 🐞 **Hy2 زمانی که Naive وجود داشت راه‌اندازی نمی‌شد**: Caddy به طور پیش‌فرض UDP/443 را برای HTTP/3 (QUIC) اشغال می‌کرد و مانع از bind شدن Hy2 می‌شد. اکنون هنگام نصب هر دو پروتکل، `servers { protocols h1 h2 }` به `Caddyfile` اضافه می‌شود — HTTP/3 در Caddy غیرفعال می‌شود، UDP/443 برای Hy2 آزاد است.
- 🆕 **صفحه «عیب‌یابی»** در پنل — لاگ‌ها + بررسی پورت
- 🆕 اسکریپت `install_hysteria.sh` اکنون هنگام نصب Hy2 بر روی Naive موجود، Caddyfile نصب شده را وصله می‌کند
- 🆕 بررسی‌های نهایی در `install.sh`: پنل روی `:3000` پاسخ می‌دهد، nginx روی `:8080` گوش می‌دهد
- 🆕 fallback systemd اگر PM2 پنل را راه‌اندازی نکرد
- 🐞 `writeCaddyfile` در backend اکنون هنگام افزودن/حذف کاربران Naive، دستور غیرفعال کردن HTTP/3 را حفظ می‌کند

### v1.1 — راه‌اندازی همزمان Naive + Hy2 (۴ اصلاح)
- Hysteria2 اکنون بعد از Caddy شروع می‌شود (`After=caddy.service`)
- خواندن `/etc/hysteria/config.yaml` موجود هنگام تغییر کاربران (قبلاً بخش TLS را بازنویسی می‌کرد)
- جستجوی گواهی Caddy در هر دو مسیر ممکن
- `config.json` معتبر (heredoc + متغیرها)

### v1.0 — اولین انتشار
- Go چند معماری (amd64 / arm64 / armv6l)
- نصب ۲ کلیکی هر دو پروتکل
- پنل یکپارچه برای Naive + Hy2
- BBR + تنظیم UDP

---

*توسط RIXXX — پنل پروکسی چندپروتکلی با رابط کاربری آسان*
```
