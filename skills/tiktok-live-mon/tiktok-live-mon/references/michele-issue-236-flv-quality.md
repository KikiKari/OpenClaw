# Michele0303 tiktok-live-recorder Issue #236 - FLV Quality
**Quelle:** https://github.com/Michele0303/tiktok-live-recorder/issues/236
**Titel:** Recorded video quality after patch 6.2

## Problem
Nach Patch 6.2 werden Streams als `_uhd.flv` aufgezeichnet statt `_or4.flv` (Origin/höchste Qualität).

## FLV Quality Suffixes
- `_uhd.flv` - Ultra HD
- `_or4.flv` - Origin (höchste Qualität)
- `FULL_HD1` - Full HD
- `HD1` - HD
- `SD2` - Standard Definition
- `SD1` - Low Definition

## Workaround
- Repo https://github.com/roju/tiktok-live-recorder liefert `_or4.flv`
- Kommando: `ttlr.py -user USERNAME -mode auto -out_dir OUTPUT -ffmpeg -combine`

## Relevant für unser System
- Bei FLV-URL Extraktion: Prüfen ob `_or4.flv` oder `_uhd.flv` im URL
- Qualitäts-Suffix kann durch URL-Manipulation gewählt werden
