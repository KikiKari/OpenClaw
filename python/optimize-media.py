#!/usr/bin/env python3
# optimize-media.mjs — portiert nach python
# Quelle: javascript, Onboarding@main:scripts/optimize-media.mjs
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import asyncio
import os
from pathlib import Path
from urllib.parse import urljoin
from urllib.request import url2pathname
from urllib.parse import urlparse
import aiofiles
from PIL import Image

async def main():
    # Bestimme das Verzeichnis relativ zum Skriptverzeichnis
    script_dir = Path(__file__).parent
    media_dir = script_dir.parent / 'public' / 'media'
    
    # Liste alle Dateien im Verzeichnis auf
    files = os.listdir(media_dir)
    
    for file in files:
        if not file.endswith(".png"):
            continue
            
        source_path = media_dir / file
        stem = Path(file).stem
        
        # Konvertiere zu WebP
        webp_path = media_dir / f"{stem}.webp"
        with Image.open(source_path) as img:
            img.save(webp_path, 'webp', quality=84)
        
        # Konvertiere zu AVIF (falls unterstützt)
        avif_path = media_dir / f"{stem}.avif"
        with Image.open(source_path) as img:
            img.save(avif_path, 'avif', quality=58)
    
    print("WebP- und AVIF-Derivate erzeugt.")

if __name__ == "__main__":
    asyncio.run(main())
