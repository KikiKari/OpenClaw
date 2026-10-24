#!/usr/bin/env python3
# websearch-crawl.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/websearch-crawl.sh
# auch in: OpenClaw@gateway2:scripts/websearch-crawl.sh
# Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

# Web Search Script: Website Crawling mit Firecrawl
# Verwendung: ./websearch-crawl.py <URL> [OUTPUT_DIR]

import os
import sys
import json
import time
import subprocess
from datetime import datetime
import requests

def get_firecrawl_api_key():
    """API-Schlüssel aus Umgebungsvariable oder openclaw-Konfiguration laden"""
    api_key = os.environ.get('FIRECRAWL_API_KEY')
    if api_key:
        return api_key
    
    # Fallback: Aus openclaw.env laden
    config_path = os.path.expanduser('~/.openclaw/openclaw.env')
    try:
        with open(config_path, 'r') as f:
            for line in f:
                if line.startswith('OPENROUTER'):
                    # Extrahiere Wert zwischen Anführungszeichen
                    parts = line.strip().split('"')
                    if len(parts) >= 2:
                        return parts[1]
    except FileNotFoundError:
        pass
    
    return None

def main():
    if len(sys.argv) < 2:
        print("Verwendung: {} <URL> [OUTPUT_DIR]".format(sys.argv[0]))
        sys.exit(1)
    
    website_url = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else './crawled'
    firecrawl_api_key = get_firecrawl_api_key()
    
    if not firecrawl_api_key:
        print("Fehler: FIRECRAWL_API_KEY nicht gefunden")
        sys.exit(1)
    
    os.makedirs(output_dir, exist_ok=True)
    print(f"Crawling {website_url}...")
    
    # Crawl starten
    headers = {
        "Authorization": f"Bearer {firecrawl_api_key}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "url": website_url,
        "limit": 100,
        "scrapeOptions": {"formats": ["markdown"]}
    }
    
    try:
        response = requests.post(
            "https://api.firecrawl.dev/v1/crawl",
            headers=headers,
            json=payload
        )
        response.raise_for_status()
        crawl_response = response.json()
    except requests.RequestException as e:
        print(f"Fehler bei API-Anfrage: {e}")
        sys.exit(1)
    except json.JSONDecodeError:
        print("Fehler: Ungültige JSON-Antwort")
        print(response.text)
        sys.exit(1)
    
    crawl_id = crawl_response.get('id')
    if not crawl_id:
        print("Fehler: Crawl konnte nicht gestartet werden")
        print(json.dumps(crawl_response, indent=2))
        sys.exit(1)
    
    print(f"Crawl ID: {crawl_id}")
    
    # Status prüfen
    while True:
        try:
            status_response = requests.get(
                f"https://api.firecrawl.dev/v1/crawl/{crawl_id}",
                headers=headers
            )
            status_response.raise_for_status()
            status_data = status_response.json()
        except requests.RequestException as e:
            print(f"Fehler bei Statusabfrage: {e}")
            sys.exit(1)
        except json.JSONDecodeError:
            print("Fehler: Ungültige JSON-Antwort beim Statuscheck")
            print(status_response.text)
            sys.exit(1)
        
        status = status_data.get('status', 'unknown')
        print(f"Status: {status}")
        
        if status == 'completed':
            timestamp = datetime.now().strftime('%Y%m%d')
            output_file = os.path.join(output_dir, f"{timestamp}_crawl.json")
            with open(output_file, 'w') as f:
                json.dump(status_data, f, indent=2)
            print(f"Gespeichert in {output_dir}")
            break
        elif status == 'failed':
            print("Crawl fehlgeschlagen")
            sys.exit(1)
        
        time.sleep(5)

if __name__ == '__main__':
    main()
