#!/usr/bin/env python3
# websearch-monitor.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/websearch-monitor.sh
# auch in: OpenClaw@gateway2:scripts/websearch-monitor.sh
# Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

# Web Search Script: Server-Monitoring mit Tavily
# Verwendung: ./websearch-monitor.py [TOPIC]

import sys
import subprocess
import requests
import json
import urllib.parse

def main():
    topic = sys.argv[1] if len(sys.argv) > 1 else "Linux kernel security updates"
    
    # Security-News prüfen
    print(f"Prüfe: {topic}")
    
    # Versuche zuerst Tavily CLI
    try:
        result = subprocess.run(['tvly', 'search', topic, 
                                '--topic', 'news',
                                '--time-range', 'week',
                                '--max-results', '5',
                                '--include-answer', 'advanced'],
                               capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            data = json.loads(result.stdout)
            answer = data.get('answer')
            if answer:
                print(answer)
            else:
                print("Keine Zusammenfassung verfügbar")
        else:
            raise FileNotFoundError
                
    except (FileNotFoundError, subprocess.TimeoutExpired, json.JSONDecodeError):
        # Fallback zu einfacher Web-Suche
        try:
            encoded_topic = urllib.parse.quote_plus(topic)
            response = requests.get(
                f"http://localhost:8888/search?q={encoded_topic}&format=json",
                timeout=30
            )
            response.raise_for_status()
            
            data = response.json()
            results = data.get('results', [])[:3]
            
            if results:
                for item in results:
                    print(item.get('title', ''))
                    print(item.get('url', ''))
                    print()
            else:
                print("SearXNG nicht verfügbar")
                
        except (requests.RequestException, json.JSONDecodeError):
            print("SearXNG nicht verfügbar")

if __name__ == "__main__":
    main()
