#!/usr/bin/env bash
# ManixShop Panel (3x-ui) — test suite / تست پنل
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
G='\033[1;32m'; R='\033[1;31m'; C='\033[1;36m'; N='\033[0m'
t_ok(){ echo -e "  ${G}✔${N} $1"; PASS=$((PASS+1)); }
t_bad(){ echo -e "  ${R}✘${N} $1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then t_ok "$1"; else t_bad "$1"; fi; }
grep_ok(){ if grep -q -- "$2" "$3" 2>/dev/null; then t_ok "$1"; else t_bad "$1 (missing: $2)"; fi; }
section(){ echo -e "\n${C}▸ $1${N}"; }

MOCK="$(mktemp -d)"; trap 'rm -rf "$MOCK"' EXIT
mkdir -p "$MOCK/bin" "$MOCK/etc" "$MOCK/data/x-ui" "$MOCK/xui" "$MOCK/root/.ssh"
mk(){ printf '#!/usr/bin/env bash\n%s\n' "$2" > "$MOCK/bin/$1"; chmod +x "$MOCK/bin/$1"; }
mk hostname 'exit 0'
mk free     'echo "        total"; echo "Mem:     2048"'
mk nproc    'echo 2'
mk mountpoint 'exit 1'
mk chpasswd 'cat > "$MOCKDIR/chpasswd.in"'
mk ssh-keygen 'exit 0'
mk sshd     'echo "sshd $*" >> "$MOCKDIR/calls.log"'
# fake x-ui binary: records every subcommand, "run" just exits
printf '#!/usr/bin/env bash\necho "x-ui $*" >> "$MOCKDIR/xui.log"\nexit 0\n' > "$MOCK/xui/x-ui"
chmod +x "$MOCK/xui/x-ui"
mkdir -p "$MOCK/usr/sbin"; cp "$MOCK/bin/sshd" "$MOCK/usr/sbin/sshd"

run_panel(){
  rm -f "$MOCK/xui.log" "$MOCK/calls.log" "$MOCK/chpasswd.in"; : > "$MOCK/etc/hosts"
  sed -e "s#/usr/local/x-ui#$MOCK/xui#g" \
      -e "s#/etc/x-ui#$MOCK/etc/x-ui#g" \
      -e "s#/data#$MOCK/data#g" \
      -e "s#/etc/hosts#$MOCK/etc/hosts#g" \
      -e "s#/root/.ssh#$MOCK/root/.ssh#g" \
      -e "s#/usr/sbin/sshd#sshd#g" \
      "$ROOT/start.sh" > "$MOCK/p.sh"
  env -i PATH="$MOCK/bin:/usr/bin:/bin" HOME="$MOCK/root" MOCKDIR="$MOCK" TERM=xterm "$@" \
    bash "$MOCK/p.sh" > "$MOCK/out.log" 2>&1
}

echo -e "${C}╔══════════════════════════════════════════╗${N}"
echo -e "${C}║  ManixShop Panel (3x-ui) — Test Suite    ║${N}"
echo -e "${C}╚══════════════════════════════════════════╝${N}"

section "1. Files & syntax / فایل‌ها و سینتکس"
for f in Dockerfile start.sh railway.json .dockerignore; do check "$f exists" "[ -f '$ROOT/$f' ]"; done
check "start.sh valid bash" "bash -n '$ROOT/start.sh'"
check "railway.json valid"  "python3 -c \"import json;json.load(open('$ROOT/railway.json'))\""

section "2. Dockerfile / داکرفایل"
D="$ROOT/Dockerfile"
grep_ok "ubuntu base"             "FROM ubuntu" "$D"
grep_ok "downloads 3x-ui"         "3x-ui/releases" "$D"
grep_ok "handles amd64 + arm64"   "arm64) XARCH=arm64" "$D"
grep_ok "symlinks x-ui to PATH"   "/usr/bin/x-ui" "$D"
grep_ok "EXPOSE 8080"             "EXPOSE 8080" "$D"
grep_ok "ENV PORT=8080"           "ENV PORT=8080" "$D"
grep_ok "CMD start.sh"            'CMD \["/start.sh"\]' "$D"
if [ "$(grep -c '^EXPOSE' "$D")" = "1" ]; then t_ok "exactly one EXPOSE (no 502 port mismatch)"; else t_bad "one EXPOSE only"; fi

section "3. Default boot / اجرای پیش‌فرض"
run_panel
O="$MOCK/out.log"
grep_ok "banner"                    "ManixShop Panel" "$O"
grep_ok "no-volume warning"         "No volume" "$O"
grep_ok "db linked to volume"       "linked to volume" "$O"
grep_ok "auto credentials"          "auto-generated" "$O"
grep_ok "panel ready banner"        "ManixShop panel is ready" "$O"
grep_ok "shows panel URL label"     "Panel URL" "$O"
grep_ok "target port hint"          "target port must be 8080" "$O"
grep_ok "inbound guide shown"       "VLESS" "$O"
grep_ok "udp limitation warning"    "no UDP" "$O"
grep_ok "generate domain hint"      "Generate Domain" "$O"

section "4. x-ui commands / دستورات پنل"
X="$MOCK/xui.log"
grep_ok "sets username+password"    "setting -username" "$X"
grep_ok "sets port"                 "setting -port 8080" "$X"
grep_ok "sets webBasePath"          "setting -webBasePath" "$X"
grep_ok "starts the panel"          "x-ui run" "$X"
if [ "$(tail -1 "$X")" = "x-ui run" ]; then t_ok "'run' is the final command"; else t_bad "'run' is final"; fi

section "5. Persistence / ماندگاری"
check "credentials file saved"      "[ -s '$MOCK/data/x-ui/.manixshop_admin' ]"
check "base path saved"             "[ -s '$MOCK/data/x-ui/.manixshop_path' ]"
SAVED_PW="$(sed -n 2p "$MOCK/data/x-ui/.manixshop_admin")"
SAVED_PATH="$(cat "$MOCK/data/x-ui/.manixshop_path")"
run_panel
grep_ok "credentials restored"      "restored from volume" "$MOCK/out.log"
if grep -q "$SAVED_PW" "$MOCK/out.log"; then t_ok "same password after restart"; else t_bad "password changed on restart"; fi
if [ "$(cat "$MOCK/data/x-ui/.manixshop_path")" = "$SAVED_PATH" ]; then t_ok "base path stable across restarts"; else t_bad "base path changed"; fi
if [[ "$SAVED_PATH" == /manixshop* ]]; then t_ok "base path is randomized & prefixed"; else t_bad "base path format: $SAVED_PATH"; fi

section "6. Custom env / متغیرهای سفارشی"
run_panel PANEL_USERNAME=manix PANEL_PASSWORD='Sup3r!Pass' PANEL_PATH='mypanel' \
          PORT=9000 RAILWAY_PUBLIC_DOMAIN='p.up.railway.app' ROOT_PASSWORD='rootpw' SSH_PORT=2222
O="$MOCK/out.log"
grep_ok "custom user applied"       "setting -username manix" "$MOCK/xui.log"
grep_ok "custom port applied"       "setting -port 9000" "$MOCK/xui.log"
grep_ok "custom base path"          "webBasePath /mypanel/" "$MOCK/xui.log"
grep_ok "full URL with path"        "https://p.up.railway.app/mypanel/" "$O"
grep_ok "root password set"         "root:rootpw" "$MOCK/chpasswd.in"
grep_ok "sshd on custom port"       "sshd -e -p 2222" "$MOCK/calls.log"
grep_ok "credentials shown"         "Sup3r!Pass" "$O"

section "7. SSH disabled by default / پیش‌فرض بدون SSH"
run_panel PANEL_PASSWORD=x
grep_ok "ssh off message"           "SSH غیرفعال است" "$MOCK/out.log"
if [ -f "$MOCK/calls.log" ]; then t_bad "sshd should not run"; else t_ok "sshd not started without ROOT_PASSWORD"; fi

echo ""
TOTAL=$((PASS+FAIL))
echo -e "${C}══════════════════════════════════════════${N}"
if [ "$FAIL" -eq 0 ]; then echo -e "${G}  ✅  ALL $TOTAL TESTS PASSED / همه تست‌ها موفق${N}";
else echo -e "${R}  ❌  $FAIL of $TOTAL failed${N} ${G}($PASS passed)${N}"; fi
echo -e "${C}══════════════════════════════════════════${N}"
exit $([ "$FAIL" -eq 0 ] && echo 0 || echo 1)
