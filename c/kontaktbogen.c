// abstraction-provenance: {"artifact_sha256": "95f8c25e70db5dbd2bf18f39194005ad0b83f4bbdd80d4f4a9900172a308bf29", "source_sha256": "ca574d779b67b58a38559123215e116d8c6e2ef4c122350bb69958e8a6423187", "target_language": "c"}
// kontaktbogen.html — portiert nach c
// Quelle: html, Onboarding@main:development/contactsheets/v1/kontaktbogen.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Struktur für ein Bild
typedef struct {
    char* src;
    char* alt;
    char* name;
    char* dims;
    char* size;
    char* code;
    char* prompt;
} Image;

// Struktur für eine Kategorie
typedef struct {
    char* id;
    char* title;
    char* tag_class;
    char* tag_text;
    char* count_text;
    char* subtitle;
    Image* images;
    int image_count;
} Category;

// Funktion zum Freigeben von Speicher für eine Kategorie
void free_category(Category* cat) {
    if (cat->id) free(cat->id);
    if (cat->title) free(cat->title);
    if (cat->tag_class) free(cat->tag_class);
    if (cat->tag_text) free(cat->tag_text);
    if (cat->count_text) free(cat->count_text);
    if (cat->subtitle) free(cat->subtitle);
    
    for (int i = 0; i < cat->image_count; i++) {
        Image* img = &cat->images[i];
        if (img->src) free(img->src);
        if (img->alt) free(img->alt);
        if (img->name) free(img->name);
        if (img->dims) free(img->dims);
        if (img->size) free(img->size);
        if (img->code) free(img->code);
        if (img->prompt) free(img->prompt);
    }
    
    if (cat->images) free(cat->images);
}

// Funktion zum Erstellen eines Bildes
Image create_image(const char* src, const char* alt, const char* name, 
                   const char* dims, const char* size, const char* code, const char* prompt) {
    Image img;
    img.src = src ? strdup(src) : NULL;
    img.alt = alt ? strdup(alt) : NULL;
    img.name = name ? strdup(name) : NULL;
    img.dims = dims ? strdup(dims) : NULL;
    img.size = size ? strdup(size) : NULL;
    img.code = code ? strdup(code) : NULL;
    img.prompt = prompt ? strdup(prompt) : NULL;
    return img;
}

// Funktion zum Erstellen einer Kategorie
Category create_category(const char* id, const char* title, 
                         const char* tag_class, const char* tag_text,
                         const char* count_text, const char* subtitle,
                         Image* images, int image_count) {
    Category cat;
    cat.id = id ? strdup(id) : NULL;
    cat.title = title ? strdup(title) : NULL;
    cat.tag_class = tag_class ? strdup(tag_class) : NULL;
    cat.tag_text = tag_text ? strdup(tag_text) : NULL;
    cat.count_text = count_text ? strdup(count_text) : NULL;
    cat.subtitle = subtitle ? strdup(subtitle) : NULL;
    cat.images = images;
    cat.image_count = image_count;
    return cat;
}

// Funktion zum Schreiben einer Zeichenkette in die Datei
void write_string(FILE* file, const char* str) {
    if (str) {
        fputs(str, file);
    }
}

// Hauptfunktion zur Generierung der HTML-Datei
void generate_html(const char* filename) {
    FILE* file = fopen(filename, "w");
    if (!file) {
        fprintf(stderr, "Fehler beim Öffnen der Datei %s\n", filename);
        return;
    }

    // HTML-Kopf und CSS
    write_string(file,
"<!DOCTYPE html>\n"
"<html lang=\"de\"><head><meta charset=\"utf-8\"><title>Kontaktbogen — Project-Landingpage Assets</title>\n"
"<style>\n"
"  :root{--bg:#FAF8F4;--ink:#1B1A17;--muted:#6E6A61;--line:#E5E1D8;--accent:#A8542F;--accent-2:#2E7D7B;--surface:#fff}\n"
"  *{box-sizing:border-box}\n"
"  body{margin:0;font-family:'Hanken Grotesk',system-ui,sans-serif;background:var(--bg);color:var(--ink);line-height:1.5}\n"
"  header{padding:2.5rem 2rem 1rem;border-bottom:1px solid var(--line);background:var(--surface);position:sticky;top:0;z-index:10}\n"
"  header h1{margin:0 0 .5rem;font-family:'Newsreader',Georgia,serif;font-weight:400;font-size:2.25rem}\n"
"  header p{margin:.25rem 0;color:var(--muted);max-width:80ch}\n"
"  .legend{display:flex;gap:1rem;flex-wrap:wrap;margin-top:.75rem;font-size:.8125rem}\n"
"  .pill{padding:.15rem .6rem;border-radius:999px;border:1px solid var(--line);background:#fff}\n"
"  .pill.pflicht{border-color:var(--accent);color:var(--accent);font-weight:600}\n"
"  .pill.auswahl{border-color:var(--accent-2);color:var(--accent-2);font-weight:600}\n"
"  main{padding:2rem;max-width:1400px;margin:0 auto}\n"
"  section{margin:2.5rem 0}\n"
"  section h2{font-family:'Newsreader',serif;font-weight:400;font-size:1.5rem;margin:0 0 .25rem;display:flex;align-items:center;gap:.75rem}\n"
"  section .sub{color:var(--muted);font-size:.875rem;margin:0 0 1.25rem}\n"
"  .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:1rem}\n"
"  .card{background:var(--surface);border:1px solid var(--line);border-radius:10px;overflow:hidden;display:flex;flex-direction:column}\n"
"  .card .imgwrap{aspect-ratio:1;background:#f1eee7;display:flex;align-items:center;justify-content:center;overflow:hidden}\n"
"  .card img{width:100%;height:100%;object-fit:contain;background:#fff}\n"
"  .card .meta{padding:.6rem .75rem .75rem;font-size:.78125rem}\n"
"  .card .name{font-family:'JetBrains Mono',monospace;font-size:.6875rem;color:var(--muted);word-break:break-all;line-height:1.3;margin-bottom:.35rem}\n"
"  .card .dims{color:var(--muted);font-size:.6875rem;margin-bottom:.35rem}\n"
"  .card .prompt{color:var(--ink);font-size:.75rem;line-height:1.35;font-style:italic;border-top:1px solid var(--line);padding-top:.4rem;margin-top:.35rem;max-height:5.5em;overflow:hidden}\n"
"  .tag{display:inline-block;padding:.1rem .45rem;border-radius:999px;font-size:.6875rem;background:#F1EEE7;color:var(--muted);margin-right:.25rem}\n"
"  .tag.p{background:#F1E5DD;color:var(--accent)}\n"
"  .tag.a{background:#DEEDEC;color:var(--accent-2)}\n"
"</style></head>\n"
"<body>\n");

    // Header
    write_string(file,
"<header>\n"
"  <h1>Kontaktbogen — Project-Landingpage Bildbestand</h1>\n"
"  <p>Alle vorhandenen HighRes-Bilder aus deiner Design-Referenz, dem laufenden Codex-Repo und den Anhängen. Kategorisiert nach Verwendungszweck. Bitte markiere pro Kategorie welche Assets in die finale Umsetzung sollen und wo du Erweiterung wünschst.</p>\n"
"  <div class=\"legend\">\n"
"    <span class=\"pill pflicht\">PFLICHT — muss ins finale Design</span>\n"
"    <span class=\"pill auswahl\">AUSWAHL nötig — mehrere Kandidaten</span>\n"
"    <span class=\"pill\">Referenz — nur Ästhetik, nicht direkt verwendet</span>\n"
"    <span class=\"pill\">Vorhanden — schon im Repo eingebaut</span>\n"
"  </div>\n"
"</header>\n");

    // Main Content
    write_string(file, "<main>\n");

    // Kategorien und Bilder - hier vereinfacht nur einige Beispiele
    
    // Beispiel für eine Kategorie mit Bildern
    Image seerosen_images[] = {
        create_image(
            "thumbs/thumb_water_lily_01_pixabay_1510707_original.webp",
            "water_lily_01_pixabay_1510707_original.jpg",
            "water_lily_01_pixabay_1510707_original.jpg",
            "5184×3456 px",
            "1253 KB",
            "examples",
            NULL
        ),
        create_image(
            "thumbs/thumb_candidate-10-pixabay-4602155-wide-real-pond-lily-pads.webp",
            "candidate-10-pixabay-4602155-wide-real-pond-lily-pads.jpg",
            "candidate-10-pixabay-4602155-wide-real-pond-lily-pads.jpg",
            "1280×960 px",
            "570 KB",
            "pending-approval",
            NULL
        )
    };

    Category seerosen_cat = create_category(
        "cat-seerose",
        "Seerosen (Pixabay/Unsplash)",
        "a",
        "AUSWAHL nötig",
        "5 Bilder",
        "Kandidaten für 3D-Textur / Alpha",
        seerosen_images,
        2
    );

    // Weitere Kategorien könnten hier hinzugefügt werden...

    // Beispiel für eine weitere Kategorie
    Image wavespeed_hero_images[] = {
        create_image(
            "thumbs/thumb_hero-meadow.webp",
            "hero-meadow.png",
            "hero-meadow.png",
            "5504×3072 px",
            "18908 KB",
            "media",
            "Preserve the dense botanical meadow composition and teal, moss, cream and restrained amber palette. Create an elegant cinematic 4K landing-page background with realistic flowers, g..."
        ),
        create_image(
            "thumbs/thumb_hero-meadow.webp",
            "hero-meadow.webp",
            "hero-meadow.webp",
            "5504×3072 px",
            "836 KB",
            "media",
            "Preserve the dense botanical meadow composition and teal, moss, cream and restrained amber palette. Create an elegant cinematic 4K landing-page background with realistic flowers, g..."
        )
    };

    Category wavespeed_hero_cat = create_category(
        "cat-wavespeed_hero",
        "WaveSpeed 4K Hero",
        "p",
        "PFLICHT-Kandidat",
        "2 Bilder",
        "Bereits generierter Hero-Hintergrund",
        wavespeed_hero_images,
        2
    );

    // Array aller Kategorien
    Category categories[] = {seerosen_cat, wavespeed_hero_cat};
    int category_count = sizeof(categories) / sizeof(Category);

    // Generiere HTML für jede Kategorie
    for (int c = 0; c < category_count; c++) {
        Category* cat = &categories[c];
        
        fprintf(file, "<section id=\"%s\">", cat->id);
        fprintf(file, "<h2>%s", cat->title);
        
        if (cat->tag_class && cat->tag_text) {
            fprintf(file, " <span class=\"tag %s\">%s</span>", cat->tag_class, cat->tag_text);
        }
        
        if (cat->count_text) {
            fprintf(file, " <span class=\"tag\">%s</span>", cat->count_text);
        }
        
        fprintf(file, "</h2>");
        
        if (cat->subtitle) {
            fprintf(file, "<p class=\"sub\">%s</p>", cat->subtitle);
        }
        
        write_string(file, "<div class=\"grid\">\n");
        
        // Generiere HTML für jedes Bild in der Kategorie
        for (int i = 0; i < cat->image_count; i++) {
            Image* img = &cat->images[i];
            
            write_string(file, "      <div class=\"card\">\n");
            
            if (img->src && strcmp(img->src, "") != 0) {
                fprintf(file, "        <div class=\"imgwrap\"><img src=\"%s\" alt=\"%s\" loading=\"lazy\"></div>\n", img->src, img->alt);
            } else {
                write_string(file, "        <div class=\"imgwrap\"><div style=\"color:#999\">kein Thumbnail</div></div>\n");
            }
            
            write_string(file, "        <div class=\"meta\">\n");
            fprintf(file, "          <div class=\"name\">%s</div>\n", img->name);
            fprintf(file, "          <div class=\"dims\">%s · %s · <code>%s</code></div>\n", img->dims, img->size, img->code);
            
            if (img->prompt && strcmp(img->prompt, "") != 0) {
                fprintf(file, "          <div class=\"prompt\">%s</div>\n", img->prompt);
            }
            
            write_string(file, "        </div>\n");
            write_string(file, "      </div>\n");
        }
        
        write_string(file, "</div></section>");
    }

    // Footer und Ende der HTML-Datei
    write_string(file, "</main></body></html>");

    fclose(file);
    
    // Speicher freigeben
    for (int i = 0; i < category_count; i++) {
        free_category(&categories[i]);
    }
    
    printf("HTML-Datei erfolgreich generiert: %s\n", filename);
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Verwendung: %s <ausgabedatei.html>\n", argv[0]);
        return 1;
    }
    
    generate_html(argv[1]);
    
    return 0;
}
