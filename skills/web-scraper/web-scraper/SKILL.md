---
name: web-scraper
description: Targeted web data extraction and scraping. Extracts specific data from web pages (prices, contacts, structured data) for further processing. Not just crawling - precise extraction.
---

# Web Scraper

Gezielte Web-Datenextraktion und Scraping - nicht nur Crawling.

## Unterschied: Crawler vs. Scraper

| | Web-Crawler | Web-Scraper (dieser Skill) |
|---|---|---|
| **Zweck** | Findet und indexiert Seiten | Extrahiert gezielt spezifische Daten |
| **Ausgabe** | Seitenstruktur, Links | Preise, Kontaktdaten, strukturierte Daten |
| **Tiefe** | Breit (viele Seiten) | Tief (spezifische Elemente) |
| **Beispiel** | Google Index | Amazon Preis-Tracking |

## Anwendungsfälle

### 1. Preis-Monitoring
```javascript
// Extrahiert aktuellen Preis von Produktseite
const price = await webScraper.extract({
  url: "https://shop.example.com/product/123",
  selector: ".price-current",
  format: "number"
});
```

### 2. Kontaktdaten-Extraktion
```javascript
// Sammelt E-Mails und Telefonnummern
const contacts = await webScraper.extract({
  url: "https://company.example.com/contact",
  selectors: {
    email: "a[href^='mailto:']",
    phone: ".phone-number"
  }
});
```

### 3. Strukturierte Daten
```javascript
// JSON-LD, Microdata, RDFa
const structuredData = await webScraper.getStructuredData({
  url: "https://recipe.example.com/pasta",
  type: "Recipe"
});
```

## Provider-Stack (Priorität)

| Priorität | Provider | Methode | Use Case |
|-----------|----------|---------|----------|
| 1 | **Firecrawl** | `extract()` | Markdown + Struktur |
| 2 | **Playwright** | Browser Automation | JavaScript-lastige Seiten |
| 3 | **Tavily** | API | KI-gestützte Extraktion |
| 4 | **SearXNG** | Local | Private/Datenschutz |

## API

### Einfache Extraktion
```bash
web-scraper extract \
  --url "https://example.com" \
  --selector ".product-price" \
  --output json
```

### Batch-Scraping
```javascript
const results = await webScraper.batch({
  urls: ["https://site1.com", "https://site2.com"],
  template: "ecommerce-product",
  rateLimit: "1req/2sec"
});
```

### Monitoring-Modus
```bash
# Prüft alle 30 Minuten auf Änderungen
web-scraper monitor \
  --url "https://shop.example.com/price" \
  --selector ".price" \
  --interval 30m \
  --on-change "notify.sh"
```

## Templates

| Template | Beschreibung |
|----------|--------------|
| `ecommerce-product` | Preis, Verfügbarkeit, Bewertungen |
| `news-article` | Titel, Author, Datum, Content |
| `contact-page` | E-Mail, Telefon, Adresse |
| `job-listing` | Titel, Firma, Ort, Beschreibung |

## Integration

```javascript
// In anderen Skills nutzen
const { webScraper } = require('web-scraper');

const data = await webScraper.extract({
  url: targetUrl,
  schema: 'product'
});

// Speichern in docs.db
await docsDb.insert('scraped_data', data);
```

## Ethik & Robots.txt

- Respektiert `robots.txt`
- Rate-Limiting (max. 1 Anfrage/2 Sekunden)
- User-Agent Identifikation
- Kein Scraping von geschützten/gesperrten Seiten

## Konfiguration

```json
{
  "web-scraper": {
    "defaultProvider": "firecrawl",
    "rateLimit": "1req/2sec",
    "respectRobotsTxt": true,
    "userAgent": "OpenClaw-WebScraper/1.0",
    "timeout": 30000
  }
}
```
