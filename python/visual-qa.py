#!/usr/bin/env python3
# visual-qa.mjs — portiert nach python
# Quelle: javascript, Onboarding@main:scripts/visual-qa.mjs
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

"""
Visual-QA-Tool der Sandbox — rendert eine laufende Seite in echten Browsern
bei mehreren Auflösungen und legt Screenshots ab, damit Claude das Ergebnis
SELBST betrachten kann, bevor es weiterverwendet wird.

Warum echtes Chrome: Der Playwright-Bundle-Chromium hat keine proprietären
Codecs (H.264/AAC) → Videos bleiben schwarz. Google Chrome Stable
(channel/executablePath) dekodiert die MP4-Hero-Videos korrekt.

Nutzung:
  xvfb-run -a python3 visual-qa.py [URL] [--engines chrome,firefox,webkit]
    [--out <dir>] [--click "<aria-name>"] [--wait <ms>] [--full]
    
Auflösungen: Desktop 1920x1080 & 1366x768, Laptop 1440x900,
             Tablet 1024x768, Mobile 390x844 (iPhone-Klasse).
"""
import argparse
import asyncio
import os
from pathlib import Path
from playwright.async_api import async_playwright

CHROME_PATHS = ["/usr/bin/google-chrome-stable", "/usr/bin/google-chrome"]
RESOLUTIONS = [
    {"name": "desktop-1920", "width": 1920, "height": 1080},
    {"name": "desktop-1366", "width": 1366, "height": 768},
    {"name": "laptop-1440", "width": 1440, "height": 900},
    {"name": "tablet-1024", "width": 1024, "height": 768},
    {"name": "mobile-390", "width": 390, "height": 844},
]

def parse_args():
    parser = argparse.ArgumentParser(description="Visual QA Tool")
    parser.add_argument("url", nargs="?", default="http://localhost:3000", help="URL to test")
    parser.add_argument("--engines", default="chrome", help="Comma-separated list of engines (chrome,firefox,webkit)")
    parser.add_argument("--out", default="/tmp/visual-qa", help="Output directory")
    parser.add_argument("--click", help="ARIA name of element to click")
    parser.add_argument("--wait", type=int, default=3500, help="Wait time in milliseconds")
    parser.add_argument("--full", action="store_true", help="Take full page screenshot")
    return parser.parse_args()

async def launch_browser(playwright, engine):
    proxy_server = os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy")
    
    if engine == "chrome":
        # Find first existing chrome path
        chrome_path = None
        for path in CHROME_PATHS:
            if os.path.exists(path):
                chrome_path = path
                break
        
        args = [
            "--autoplay-policy=no-user-gesture-required",
            "--no-sandbox"
        ]
        
        if proxy_server:
            args.append("--ssl-version-max=tls1.2")
            
        return await playwright.chromium.launch(
            executable_path=chrome_path,
            proxy={"server": proxy_server, "bypass": "localhost,127.0.0.1,::1"} if proxy_server else None,
            args=args
        )
    elif engine == "firefox":
        return await playwright.firefox.launch()
    elif engine == "webkit":
        return await playwright.webkit.launch()
    else:
        raise ValueError(f"Unbekannte Engine: {engine}")

async def take_screenshots(engine, browser, url, out_dir, wait_time, click_element, full_page, manifest):
    for res in RESOLUTIONS:
        context = await browser.new_context(
            viewport={"width": res["width"], "height": res["height"]},
            device_scale_factor=1
        )
        page = await context.new_page()
        
        try:
            await page.goto(url, wait_until="networkidle", timeout=60000)
            await page.wait_for_timeout(wait_time)
            
            if click_element:
                try:
                    button = page.get_by_role("button", name=click_element).first
                    await button.click(timeout=8000)
                    await page.wait_for_timeout(2000)
                except Exception as e:
                    print(f"[{engine}/{res['name']}] Klick '{click_element}' fehlgeschlagen: {str(e)}")
            
            filename = f"{engine}-{res['name']}.png"
            filepath = os.path.join(out_dir, filename)
            await page.screenshot(path=filepath, full_page=full_page)
            
            try:
                phase = await page.locator("[data-pond-phase]").get_attribute("data-pond-phase")
            except:
                phase = None
                
            manifest.append({
                "engine": engine,
                "res": res["name"],
                "file": filepath,
                "phase": phase
            })
            
            print(f"OK  {engine:<8} {res['name']:<13} phase={phase or '-'}  {filepath}")
            
        except Exception as e:
            print(f"ERR {engine}/{res['name']}: {str(e)}")
        finally:
            await context.close()

async def main():
    args = parse_args()
    engines = [e.strip() for e in args.engines.split(",")]
    
    # Create output directory
    Path(args.out).mkdir(parents=True, exist_ok=True)
    
    manifest = []
    
    async with async_playwright() as playwright:
        for engine in engines:
            try:
                browser = await launch_browser(playwright, engine)
            except Exception as e:
                print(f"[{engine}] Start fehlgeschlagen: {str(e)}")
                continue
                
            try:
                await take_screenshots(
                    engine, browser, args.url, args.out, 
                    args.wait, args.click, args.full, manifest
                )
            finally:
                await browser.close()
    
    print(f"\n{len(manifest)} Screenshots in {args.out}")

if __name__ == "__main__":
    asyncio.run(main())
