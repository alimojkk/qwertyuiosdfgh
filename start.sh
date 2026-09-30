#!/bin/bash
# ============================================================
#  ManixShop Panel (3x-ui) on Railway — startup / راه‌اندازی
# ============================================================
set -uo pipefail

GREEN='\033[1;32m'; CYAN='\033[1;36m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
say()  { echo -e "${CYAN}[ manixshop ]${NC} $1"; }
ok()   { echo -e "${GREEN}[ manixshop ✔ ]${NC} $1"; }
warn() { echo -e "${YELLOW}[ manixshop ! ]${NC} $1"; }
bad()  { echo -e "${RED}[ manixshop ✘ ]${NC} $1"; }

echo ""
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}   __  __             _       ____  _                ${NC}"
echo -e "${GREEN}  |  \/  | __ _ _ __ (_)_  __/ ___|| |__   ___  _ __ ${NC}"
echo -e "${GREEN}  | |\/| |/ _\` | '_ \| \ \/ /\___ \| '_ \ / _ \| '_ \\${NC}"
echo -e "${GREEN}  | |  | | (_| | | | | |>  <  ___) | | | | (_) | |_) |${NC}"
echo -e "${GREEN}  |_|  |_|\__,_|_| |_|_/_/\_\|____/|_| |_|\___/| .__/ ${NC}"
echo -e "${GREEN}      ManixShop Panel  •  3x-ui on Railway           ${NC}"
echo -e "${GREEN}==============================================${NC}"
echo ""

hostname manixshop 2>/dev/null || true
grep -q manixshop /etc/hosts 2>/dev/null || echo "127.0.0.1 manixshop" >> /etc/hosts

say "سیستم‌عامل / OS: $(. /etc/os-release && echo "$PRETTY_NAME")"
say "معماری / Arch: $(uname -m) | هسته / CPU: $(nproc) | رم / RAM: $(free -m | awk '/Mem:/{print $2}') MB"
say "زمان / Time: $(date '+%Y-%m-%d %H:%M:%S') (${TZ:-UTC})"
echo ""

PANEL_PORT="${PORT:-8080}"
SSH_PORT="${SSH_PORT:-22}"

# ---------- persistent storage / فضای ماندگار ----------
if mountpoint -q /data 2>/dev/null; then
  ok "Volume روی /data وصل است / persistent volume mounted."
else
  warn "Volume وصل نیست! دیتابیس پنل با هر ری‌دیپلوی پاک می‌شود."
  warn "No volume: the panel database resets on every redeploy."
  warn "Railway → + New → Volume → Mount path: /data"
fi

mkdir -p /data/x-ui /data/xray
# keep the x-ui database on the volume
if [ ! -e /data/x-ui/x-ui.db ] && [ -e /etc/x-ui/x-ui.db ]; then
  cp /etc/x-ui/x-ui.db /data/x-ui/x-ui.db 2>/dev/null || true
fi
rm -rf /etc/x-ui
ln -sfn /data/x-ui /etc/x-ui
ok "دیتابیس پنل روی /data/x-ui قرار گرفت / database linked to volume."

# ---------- credentials / اطلاعات ورود ----------
CRED_FILE="/data/x-ui/.manixshop_admin"
if [ -n "${PANEL_USERNAME:-}" ] || [ -n "${PANEL_PASSWORD:-}" ]; then
  PU="${PANEL_USERNAME:-admin}"
  PP="${PANEL_PASSWORD:-}"
  if [ -z "$PP" ]; then PP="Manix-$((RANDOM%9000+1000))"; fi
  ok "اطلاعات ورود از متغیرها خوانده شد / credentials from variables."
elif [ -f "$CRED_FILE" ]; then
  PU="$(sed -n 1p "$CRED_FILE")"
  PP="$(sed -n 2p "$CRED_FILE")"
  ok "اطلاعات ورود قبلی بازیابی شد / credentials restored from volume."
else
  W1=(manix nova orbit delta turbo cyber pixel); W2=(falcon dragon comet tiger eagle viper panda)
  PU="admin"
  PP="${W1[$((RANDOM%7))]^}-${W2[$((RANDOM%7))]^}-$((RANDOM%9000+1000))"
  warn "اطلاعات ورود خودکار ساخته شد / credentials auto-generated."
fi
printf '%s\n%s\n' "$PU" "$PP" > "$CRED_FILE" 2>/dev/null && chmod 600 "$CRED_FILE" 2>/dev/null || true

# ---------- web base path / مسیر پنل ----------
if [ -n "${PANEL_PATH:-}" ]; then
  WBP="/${PANEL_PATH#/}"
elif [ -f /data/x-ui/.manixshop_path ]; then
  WBP="$(cat /data/x-ui/.manixshop_path)"
else
  WBP="/manixshop$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  echo "$WBP" > /data/x-ui/.manixshop_path 2>/dev/null || true
fi
WBP="${WBP%/}/"

# ---------- apply settings to x-ui / اعمال تنظیمات ----------
say "اعمال تنظیمات پنل / Applying panel settings ..."
cd /usr/local/x-ui
./x-ui setting -username "$PU" -password "$PP" >/dev/null 2>&1 \
  && ok "نام کاربری و رمز تنظیم شد / username & password set." \
  || bad "تنظیم نام کاربری ناموفق بود / failed to set credentials."
./x-ui setting -port "$PANEL_PORT" >/dev/null 2>&1 \
  && ok "پورت پنل روی ${PANEL_PORT} تنظیم شد / panel port set." \
  || bad "تنظیم پورت ناموفق بود / failed to set port."
./x-ui setting -webBasePath "$WBP" >/dev/null 2>&1 \
  && ok "مسیر امن پنل تنظیم شد / secure base path set." \
  || warn "این نسخه webBasePath را پشتیبانی نمی‌کند / not supported by this build."

# ---------- ssh (optional) ----------
if [ -n "${ROOT_PASSWORD:-}" ]; then
  echo "root:${ROOT_PASSWORD}" | chpasswd
  ssh-keygen -A >/dev/null 2>&1
  [ -n "${SSH_PUBLIC_KEY:-}" ] && { echo "$SSH_PUBLIC_KEY" > /root/.ssh/authorized_keys; chmod 600 /root/.ssh/authorized_keys; }
  /usr/sbin/sshd -e -p "$SSH_PORT" 2>/dev/null && ok "SSH روی پورت ${SSH_PORT} فعال شد / SSH enabled." \
    || warn "sshd اجرا نشد / sshd failed."
else
  say "SSH غیرفعال است (برای فعال‌سازی ROOT_PASSWORD را ست کن)."
fi

# ---------- final info / اطلاعات نهایی ----------
DOMAIN="${RAILWAY_PUBLIC_DOMAIN:-${RAILWAY_STATIC_URL:-}}"
if [ -n "$DOMAIN" ]; then
  LINK="https://${DOMAIN#https://}${WBP}"
else
  LINK="(دامنه ساخته نشده / Settings → Networking → Generate Domain)"
fi

echo ""
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}  پنل manixshop آماده است ✅                  ${NC}"
echo -e "${GREEN}  ManixShop panel is ready ✅                 ${NC}"
echo -e "${GREEN}==============================================${NC}"
echo ""
echo -e "${CYAN}🌐  آدرس پنل / Panel URL:${NC} ${LINK}"
echo -e "${CYAN}👤  نام کاربری / Username:${NC} ${PU}"
echo -e "${CYAN}🔑  رمز عبور / Password:${NC} ${PP}"
echo -e "${CYAN}🎯  Target Port دامنه باید ${PANEL_PORT} باشد / domain target port must be ${PANEL_PORT}${NC}"
echo ""
echo -e "${YELLOW}📌 راهنمای ساخت اینباند / Inbound guide:${NC}"
echo -e "   Protocol: ${CYAN}VLESS${NC}  |  Network: ${CYAN}ws${NC}  |  Security: ${CYAN}none${NC}"
echo -e "   Port: ${CYAN}${PANEL_PORT}${NC}  |  Path: ${CYAN}/ws${NC}  (روی همین دامنه، TLS را Railway می‌دهد)"
echo -e "   در کلاینت: Address=دامنه، Port=${CYAN}443${NC}، TLS=${CYAN}on${NC}، SNI=دامنه، Path=${CYAN}/ws${NC}"
echo ""
echo -e "${YELLOW}⚠️  فقط TCP/WebSocket کار می‌کند — UDP، Hysteria و TUIC روی Railway ممکن نیست.${NC}"
echo -e "${YELLOW}⚠️  Only TCP/WS works — no UDP, Hysteria or TUIC on Railway.${NC}"
echo ""
say "اجرای پنل / Starting 3x-ui ..."
echo ""

exec /usr/local/x-ui/x-ui run
