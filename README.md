# 🛡 ManixShop Panel — 3x-ui on Railway

**EN:** A 3x-ui panel running on Railway, no Docker-in-Docker, no systemd.
**FA:** پنل 3x-ui روی ریلوی، بدون داکر داخلی و بدون systemd.

---

## ⚠️ Read this first / اول این را بخوان

| EN | FA |
|---|---|
| Railway's ToS forbids using it as a proxy/VPN. Your account may be suspended. | قوانین ریلوی استفاده به‌عنوان پروکسی/VPN را ممنوع کرده؛ اکانتت ممکن است بن شود. |
| **TCP only.** No UDP → no Hysteria, TUIC, QUIC, WireGuard. | **فقط TCP.** بدون UDP → Hysteria، TUIC، QUIC و WireGuard کار نمی‌کند. |
| One public HTTP port. Panel + inbounds share it via WebSocket paths. | یک پورت HTTP عمومی. پنل و اینباندها از طریق مسیرهای WebSocket همان را share می‌کنند. |
| Marzban/Pasargad need docker-compose/systemd → not usable here. | مرزبان و پاسارگاد به docker-compose/systemd نیاز دارند → اینجا قابل استفاده نیستند. |
| Without a Volume, your whole panel database is wiped on redeploy. | بدون Volume، کل دیتابیس پنل با ری‌دیپلوی پاک می‌شود. |

---

## 🚀 Install / نصب

1. **GitHub:** push this folder to a new repo (`Dockerfile` must be in the root).
   ریپوی جدید بساز و این پوشه را پوش کن (`Dockerfile` باید در ریشه باشد).
2. **Railway:** https://railway.com/new → Deploy from GitHub repo → 3–6 min build.
3. **Volume (ضروری):** + New → Volume → mount path **`/data`**.
4. **Domain:** Settings → Networking → Generate Domain → **Target Port `8080`**.
5. **Deploy Logs:** read the URL, username and password.

```
🌐  آدرس پنل / Panel URL: https://your-app.up.railway.app/manixshop3f9a2c/
👤  نام کاربری / Username: admin
🔑  رمز عبور / Password: Orbit-Falcon-3182
```

> **EN:** The panel lives on a random secret path so bots can't find it. It stays the same as long as the volume exists.
> **FA:** پنل روی یک مسیر مخفی تصادفی است تا ربات‌ها پیدایش نکنند و تا وقتی Volume هست ثابت می‌ماند.

---

## 🎛 Variables / متغیرها (all optional)

| Variable | Default | EN / FA |
|---|---|---|
| `PANEL_USERNAME` | `admin` | panel username / نام کاربری |
| `PANEL_PASSWORD` | auto | panel password / رمز پنل |
| `PANEL_PATH` | random | secret base path / مسیر مخفی |
| `ROOT_PASSWORD` | — | set it to enable SSH / برای فعال‌سازی SSH |
| `SSH_PUBLIC_KEY` | — | key login / ورود با کلید |
| `TZ` | `Asia/Tehran` | timezone |

---

## 🔧 Creating a working inbound / ساخت اینباند درست

**EN:** Railway terminates TLS for you, so the inbound itself must be plain WebSocket.
**FA:** TLS را خود ریلوی هندل می‌کند، پس خود اینباند باید WebSocket ساده باشد.

**In the panel / در پنل:**
| Field | Value |
|---|---|
| Protocol | `VLESS` |
| Port | `8080` (same as `$PORT`) |
| Network | `ws` |
| Security | `none` ← **not** tls |
| Path | `/ws` |

**In your client / در کلاینت:**
| Field | Value |
|---|---|
| Address | `your-app.up.railway.app` |
| Port | `443` |
| TLS | `on` |
| SNI / Host | `your-app.up.railway.app` |
| Network | `ws` |
| Path | `/ws` |

> **EN:** The panel path and the inbound path must differ (`/manixshop…` vs `/ws`).
> **FA:** مسیر پنل و مسیر اینباند باید متفاوت باشند.

---

## 🖥 SSH (optional / اختیاری)

**EN:** Set `ROOT_PASSWORD`, then Settings → Networking → TCP Proxy → port `22`.
**FA:** متغیر `ROOT_PASSWORD` را ست کن، بعد TCP Proxy روی پورت `22`.

```bash
ssh root@containers-us-west-x.railway.app -p 12345
x-ui   # panel management CLI
```

---

## 🧪 Tests / تست

```bash
bash test/run-tests.sh   # 44 tests, no Docker needed
```

---

## 🆘 Troubleshooting / رفع اشکال

| Problem | Fix |
|---|---|
| `502 Bad Gateway` | Target Port دامنه را `8080` کن |
| صفحه `404` | مسیر مخفی را از لاگ بردار و کامل وارد کن |
| رمز کار نمی‌کند | آخرین Deploy Log را ببین، یا `PANEL_PASSWORD` را ست کن |
| بعد از ری‌دیپلوی همه‌چیز پاک شد | Volume روی `/data` وصل نکردی |
| کلاینت وصل نمی‌شود | Security اینباند باید `none` و در کلاینت TLS روشن، پورت `443` |
| اتصال قطع‌وصل می‌شود | ریلوی برای ترافیک پروکسی ساخته نشده — همین است |

---

**ManixShop Panel** — use responsibly / با مسئولیت خودت استفاده کن ⚠️
