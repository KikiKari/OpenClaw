#!/usr/bin/env python3
# browser-session.mjs — portiert nach python
# Quelle: javascript, Onboarding@main:scripts/browser-session.mjs
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

"""
Persistente Browser-Sitzung der Sandbox.

Zweck: Plattformen ohne (nutzbare) API — WaveSpeed-Konsole, Perplexity,
Canva, Stock-Portale — erfordern einen echten Web-Login. Diese Sitzung
speichert Cookies/LocalStorage DAUERHAFT in einem user-data-dir, akzeptiert
Cookie-Banner automatisch und bleibt über Skript-Läufe hinweg angemeldet.

Profil-Verzeichnis: <repo>/.browser-profile (gitignored — enthält Secrets).

Nutzung (immer unter Xvfb, damit echtes Chrome mit Codecs läuft):
  xvfb-run -a python3 browser_session.py open <URL>          # öffnen, Cookies akzeptieren, Screenshot
  xvfb-run -a python3 browser_session.py login <URL> [--user-field ..] [--pass-field ..] [--env-user X] [--env-pass Y]
  xvfb-run -a python3 browser_session.py shot <URL> [--out file.png] [--wait ms] [--full]
  xvfb-run -a python3 browser_session.py state                 # gespeicherte Cookies auflisten (Domains)

Die Sitzung wird NICHT geschlossen-und-verworfen: das Profil bleibt auf Platte.
"""
import asyncio
import os
import sys
from pathlib import Path
import argparse

try:
    from playwright.async_api import async_playwright
except ImportError:
    print("Fehler: playwright nicht gefunden. Installiere mit: pip install playwright")
    sys.exit(1)

REPO = Path(__file__).parent.parent.resolve()
PROFILE = os.environ.get("BROWSER_PROFILE_DIR", str(REPO / ".browser-profile"))
CHROME_PATHS = ["/usr/bin/google-chrome-stable", "/usr/bin/google-chrome"]
CHROME = next((p for p in CHROME_PATHS if os.path.exists(p)), None)

def parse_flags(args):
    """Parses command-line flags like --name value"""
    flags = {}
    i = 0
    while i < len(args):
        if args[i].startswith("--"):
            key = args[i][2:]
            if i + 1 < len(args) and not args[i+1].startswith("--"):
                flags[key] = args[i+1]
                i += 2
            else:
                flags[key] = True
                i += 1
        else:
            i += 1
    return flags

def load_env():
    """Lade .env Datei für Login-Credentials; nichts wird geloggt"""
    env_file = REPO / ".env"
    if not env_file.exists():
        return {}
    
    out = {}
    with open(env_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and "=" in line and not line.startswith("#"):
                parts = line.split("=", 1)
                key = parts[0].strip()
                value = parts[1].strip().strip('"')
                out[key] = value
    return out

async def accept_cookies(page):
    """Häufige Cookie-Consent-Buttons klicken (mehrsprachig, best effort)."""
    labels = [
        "Accept all", "Accept All", "Alle akzeptieren", "Accept all cookies",
        "Alle Cookies akzeptieren", "I agree", "Ich stimme zu", "Zustimmen",
        "Allow all", "Akzeptieren", "Accept", "Got it", "Agree",
    ]
    for name in labels:
        try:
            btn = page.get_by_role("button", name=name, exact=False).first
            if await btn.is_visible(timeout=800):
                await btn.click(timeout=1500)
                return name
        except:
            continue
    
    # Generische Consent-IDs
    selectors = [
        "#onetrust-accept-btn-handler",
        "[aria-label*='accept' i]",
        "button[title*='accept' i]"
    ]
    for sel in selectors:
        try:
            el = page.locator(sel).first
            if await el.is_visible(timeout=500):
                await el.click(timeout=1500)
                return sel
        except:
            continue
    return None

async def main():
    if len(sys.argv) < 2:
        print("Befehle: open <URL> | shot <URL> | login <URL> | state")
        return

    cmd = sys.argv[1]
    target = sys.argv[2] if len(sys.argv) > 2 else None
    rest_args = sys.argv[3:] if len(sys.argv) > 3 else []
    flags = parse_flags(rest_args)
    
    def flag(name, default=None):
        return flags.get(name, default)
    
    def has(name):
        return name in flags

    os.makedirs(PROFILE, exist_ok=True)

    # Sandbox-Egress läuft über den Agent-Proxy (MITM mit CA in /root/.ccr).
    # Chrome muss den Proxy nutzen; die CA ist zuvor via certutil in ~/.pki/nssdb
    # importiert (siehe docs/VISUAL_QA.md), damit TLS ohne Fehler verifiziert.
    # --socks <server>: leitet den Browser über einen SOCKS5-Proxy (z. B. den
    # Tailscale-Userspace-Proxy localhost:1055) — sauberer Egress am Agent-MITM-
    # Proxy vorbei, nötig für github.com/Codespaces. Sonst der Agent-HTTPS-Proxy.
    socks = flag("socks")
    proxy_server = (
        f"socks5://{socks}" if socks 
        else (os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy"))
    )

    async with async_playwright() as p:
        context = await p.chromium.launch_persistent_context(
            PROFILE,
            headless=False,
            executable_path=CHROME,
            viewport={"width": 1440, "height": 900},
            accept_downloads=True,
            ignore_https_errors=has("insecure"),
            proxy={
                "server": proxy_server,
                "bypass": "localhost,127.0.0.1,::1"
            } if proxy_server else None,
            args=[
                "--no-sandbox",
                "--autoplay-policy=no-user-gesture-required",
                "--disable-blink-features=AutomationControlled",
                *(["--ssl-version-max=tls1.2"] if proxy_server else [])
            ]
        )

        page = context.pages[0] if context.pages else await context.new_page()

        try:
            if cmd == "state":
                cookies = await context.cookies()
                domains = sorted(list(set(c["domain"] for c in cookies)))
                print(f"Profil: {PROFILE}")
                print(f"{len(cookies)} Cookies über {len(domains)} Domains:")
                for domain in domains:
                    print(f"  {domain}")
            
            elif cmd in ["open", "shot"]:
                if not target:
                    raise Exception("URL fehlt")
                
                await page.goto(target, wait_until="domcontentloaded", timeout=60000)
                wait_time = int(flag("wait", "2500"))
                await page.wait_for_timeout(wait_time)
                
                accepted = await accept_cookies(page)
                if accepted:
                    print(f"Cookie-Consent bestätigt via: {accepted}")
                
                await page.wait_for_timeout(1000)
                out = flag("out", f"/tmp/browser-{int(asyncio.get_event_loop().time() * 1000)}.png")
                await page.screenshot(path=out, full_page=has("full"))
                print(f"Screenshot: {out}")
                print(f"URL final: {page.url}")
            
            elif cmd == "login":
                if not target:
                    raise Exception("URL fehlt")
                
                env_vars = load_env()
                user = env_vars.get(flag("env-user", ""), "") or flag("user", "")
                password = env_vars.get(flag("env-pass", ""), "") or flag("pass", "")
                
                await page.goto(target, wait_until="domcontentloaded", timeout=60000)
                await page.wait_for_timeout(2500)
                await accept_cookies(page)
                
                if user:
                    uf = flag("user-field", "input[type=email], input[name=email], input[name=username], input[id*=email i]")
                    await page.locator(uf).first.fill(user, timeout=8000)
                
                if password:
                    pf = flag("pass-field", "input[type=password]")
                    await page.locator(pf).first.fill(password, timeout=8000)
                
                out = flag("out", f"/tmp/login-{int(asyncio.get_event_loop().time() * 1000)}.png")
                await page.screenshot(path=out)
                print(f"Login-Formular ausgefüllt (user={'gesetzt' if user else '-'}, pass={'gesetzt' if password else '-'}). Screenshot: {out}")
                print("Absenden bewusst NICHT automatisch — nächster Schritt nach Sichtprüfung.")
            
            else:
                print("Befehle: open <URL> | shot <URL> | login <URL> | state")
        
        finally:
            await context.close()  # Profil (Cookies) bleibt auf Platte erhalten

if __name__ == "__main__":
    asyncio.run(main())
