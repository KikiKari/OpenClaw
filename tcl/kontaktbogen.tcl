#!/usr/bin/env tclsh
# kontaktbogen.html — portiert nach tcl
# Quelle: html, Onboarding@main:development/contactsheets/v1/kontaktbogen.html
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

# kontaktbogen.tcl - Erzeugt die HTML-Datei kontaktbogen.html
# Portiert von HTML nach Tcl 8.6

# Datenstruktur für die Kategorien und Bilder
set categories {
    {
        id "cat-seerose"
        title "Seerosen (Pixabay/Unsplash)"
        tag "AUSWAHL nötig"
        tagclass "a"
        count "5 Bilder"
        subtitle "Kandidaten für 3D-Textur / Alpha"
        images {
            {
                thumb "thumbs/thumb_water_lily_01_pixabay_1510707_original.webp"
                alt "water_lily_01_pixabay_1510707_original.jpg"
                name "water_lily_01_pixabay_1510707_original.jpg"
                dims "5184×3456 px · 1253 KB"
                code "examples"
            }
            {
                thumb "thumbs/thumb_candidate-10-pixabay-4602155-wide-real-pond-lily-pads.webp"
                alt "candidate-10-pixabay-4602155-wide-real-pond-lily-pads.jpg"
                name "candidate-10-pixabay-4602155-wide-real-pond-lily-pads.jpg"
                dims "1280×960 px · 570 KB"
                code "pending-approval"
            }
            {
                thumb "thumbs/thumb_candidate-11-pixabay-5904414-giant-water-lily-3d-depth.webp"
                alt "candidate-11-pixabay-5904414-giant-water-lily-3d-depth.jpg"
                name "candidate-11-pixabay-5904414-giant-water-lily-3d-depth.jpg"
                dims "1280×951 px · 495 KB"
                code "pending-approval"
            }
            {
                thumb "thumbs/thumb_candidate-12-unsplash-Z9h4Fl6iCuU-pond-lily-pads.webp"
                alt "candidate-12-unsplash-Z9h4Fl6iCuU-pond-lily-pads.jpg"
                name "candidate-12-unsplash-Z9h4Fl6iCuU-pond-lily-pads.jpg"
                dims "2400×1600 px · 425 KB"
                code "pending-approval"
            }
            {
                thumb "thumbs/thumb_candidate-09-pixabay-6403860-red-water-lily-water-closeup.webp"
                alt "candidate-09-pixabay-6403860-red-water-lily-water-closeup.jpg"
                name "candidate-09-pixabay-6403860-red-water-lily-water-closeup.jpg"
                dims "1280×853 px · 248 KB"
                code "pending-approval"
            }
        }
    }
    {
        id "cat-wavespeed_hero"
        title "WaveSpeed 4K Hero"
        tag "PFLICHT-Kandidat"
        tagclass "p"
        count "2 Bilder"
        subtitle "Bereits generierter Hero-Hintergrund"
        images {
            {
                thumb "thumbs/thumb_hero-meadow.webp"
                alt "hero-meadow.png"
                name "hero-meadow.png"
                dims "5504×3072 px · 18908 KB"
                code "media"
                prompt "Preserve the dense botanical meadow composition and teal, moss, cream and restrained amber palette. Create an elegant cinematic 4K landing-page background with realistic flowers, g..."
            }
            {
                thumb "thumbs/thumb_hero-meadow.webp"
                alt "hero-meadow.webp"
                name "hero-meadow.webp"
                dims "5504×3072 px · 836 KB"
                code "media"
                prompt "Preserve the dense botanical meadow composition and teal, moss, cream and restrained amber palette. Create an elegant cinematic 4K landing-page background with realistic flowers, g..."
            }
        }
    }
    {
        id "cat-wavespeed_orb"
        title "WaveSpeed 4K Glaskugel"
        tag "PFLICHT-Kandidat"
        tagclass "p"
        count "2 Bilder"
        subtitle "Referenz-Glaskugel für 3D-Material"
        images {
            {
                thumb "thumbs/thumb_glass-orb.webp"
                alt "glass-orb.png"
                name "glass-orb.png"
                dims "4096×4096 px · 18805 KB"
                code "media"
                prompt "Preserve the transparent glass sphere as the single subject. Refine it into a premium luminous crystal orb in a botanical meadow, soft white and pale teal refractions, restrained h..."
            }
            {
                thumb "thumbs/thumb_glass-orb.webp"
                alt "glass-orb.webp"
                name "glass-orb.webp"
                dims "4096×4096 px · 730 KB"
                code "media"
                prompt "Preserve the transparent glass sphere as the single subject. Refine it into a premium luminous crystal orb in a botanical meadow, soft white and pale teal refractions, restrained h..."
            }
        }
    }
    {
        id "cat-wavespeed_projects"
        title "WaveSpeed 4K Sektionen"
        tag "Vorhanden"
        tagclass ""
        count "6 Bilder"
        subtitle "Section-Backgrounds (Claude/Perplexity)"
        images {
            {
                thumb "thumbs/thumb_perplexity-projects.webp"
                alt "perplexity-projects.png"
                name "perplexity-projects.png"
                dims "4800×3584 px · 21947 KB"
                code "media"
                prompt "Create an abstract premium visual for research, weather and computer-vision projects. Fine observation grids, atmospheric map contours, optical glass details, teal and pale blue ac..."
            }
            {
                thumb "thumbs/thumb_claude-projects.webp"
                alt "claude-projects.png"
                name "claude-projects.png"
                dims "4800×3584 px · 20711 KB"
                code "media"
                prompt "Create an abstract premium visual for a family of automation, security and publishing tools. Layered paper-like systems, fine technical lines, small warm copper accents, botanical ..."
            }
            {
                thumb "thumbs/thumb_og-projects.webp"
                alt "og-projects.png"
                name "og-projects.png"
                dims "5504×3072 px · 18199 KB"
                code "media"
                prompt "Create a strong social preview image: luminous glass orb floating above a cinematic botanical meadow, quiet technical linework inside the sphere, ivory, moss, teal and copper palet..."
            }
            {
                thumb "thumbs/thumb_perplexity-projects.webp"
                alt "perplexity-projects.webp"
                name "perplexity-projects.webp"
                dims "4800×3584 px · 1805 KB"
                code "media"
                prompt "Create an abstract premium visual for research, weather and computer-vision projects. Fine observation grids, atmospheric map contours, optical glass details, teal and pale blue ac..."
            }
            {
                thumb "thumbs/thumb_claude-projects.webp"
                alt "claude-projects.webp"
                name "claude-projects.webp"
                dims "4800×3584 px · 1114 KB"
                code "media"
                prompt "Create an abstract premium visual for a family of automation, security and publishing tools. Layered paper-like systems, fine technical lines, small warm copper accents, botanical ..."
            }
            {
                thumb "thumbs/thumb_og-projects.webp"
                alt "og-projects.webp"
                name "og-projects.webp"
                dims "5504×3072 px · 819 KB"
                code "media"
                prompt "Create a strong social preview image: luminous glass orb floating above a cinematic botanical meadow, quiet technical linework inside the sphere, ivory, moss, teal and copper palet..."
            }
        }
    }
    {
        id "cat-wavespeed_section"
        title "WaveSpeed 4K Zusatz"
        tag "Vorhanden"
        tagclass ""
        count "4 Bilder"
        subtitle "CTA / Feature-Spotlight"
        images {
            {
                thumb "thumbs/thumb_feature-spotlight.webp"
                alt "feature-spotlight.png"
                name "feature-spotlight.png"
                dims "4800×3584 px · 18688 KB"
                code "media"
                prompt "Combine the botanical meadow and glass sphere into a polished editorial technology image. The glass orb reveals subtle scientific line patterns and biodiversity details, balanced n..."
            }
            {
                thumb "thumbs/thumb_cta-background.webp"
                alt "cta-background.png"
                name "cta-background.png"
                dims "5504×3072 px · 15543 KB"
                code "media"
                prompt "Transform the botanical meadow into a very light, spacious call-to-action background. Soft radial teal, amber and copper blooms around empty central space, subtle organic detail, h..."
            }
            {
                thumb "thumbs/thumb_feature-spotlight.webp"
                alt "feature-spotlight.webp"
                name "feature-spotlight.webp"
                dims "4800×3584 px · 1315 KB"
                code "media"
                prompt "Combine the botanical meadow and glass sphere into a polished editorial technology image. The glass orb reveals subtle scientific line patterns and biodiversity details, balanced n..."
            }
            {
                thumb "thumbs/thumb_cta-background.webp"
                alt "cta-background.webp"
                name "cta-background.webp"
                dims "5504×3072 px · 730 KB"
                code "media"
                prompt "Transform the botanical meadow into a very light, spacious call-to-action background. Soft radial teal, amber and copper blooms around empty central space, subtle organic detail, h..."
            }
        }
    }
    {
        id "cat-studio_variant"
        title "Studio-Varianten Glaskugel"
        tag "Referenz"
        tagclass ""
        count "8 Bilder"
        subtitle "Beleuchtungsstudien für Glas"
        images {
            {
                thumb "thumbs/thumb_var6_flat_lay.webp"
                alt "var6_flat_lay.png"
                name "var6_flat_lay.png"
                dims "1672×941 px · 3173 KB"
                code "examples"
            }
            {
                thumb "thumbs/thumb_var8_natural_light_outdoor.webp"
                alt "var8_natural_light_outdoor.png"
                name "var8_natural_light_outdoor.png"
                dims "1672×941 px · 2481 KB"
                code "examples"
            }
            {
                thumb "thumbs/thumb_var5_closeup_detail.webp"
                alt "var5_closeup_detail.png"
                name "var5_closeup_detail.png"
                dims "1672×941 px · 1863 KB"
                code "examples"
            }
            {
                thumb "thumbs/thumb_var4_dramatic_lighting.webp"
                alt "var4_dramatic_lighting.png"
                name "var4_dramatic_lighting.png"
                dims "1672×941 px · 1573 KB"
                code "examples"
            }
            {
                thumb "thumbs/thumb_var2_studio_white2.webp"
                alt "var2_studio_white2.png"
                name "var2_studio_white2.png"
                dims "1672×941 px · 1285 KB"
                code "examples"
            }
            {
                thumb "thumbs/thumb_var1_studio_white.webp"
                alt "var1_studio_white.png"
                name "var1_studio_white.png"
                dims "1672×941 px · 1259 KB"
                code "examples"
            }
            {
                thumb "thumbs/thumb_var8_natural_light_outdoor.webp"
                alt "var8_natural_light_outdoor.jpg"
                name "var8_natural_light_outdoor.jpg"
                dims "1672×941 px · 800 KB"
                code "7634afec188f40caa502423fce3ef2ea"
            }
            {
                thumb "thumbs/thumb_var4_dramatic_lighting.webp"
                alt "var4_dramatic_lighting.jpg"
                name "var4_dramatic_lighting.jpg"
                dims "1672×941 px · 386 KB"
                code "7634afec188f40caa502423fce3ef2ea"
            }
        }
    }
    {
        id "cat-glasobjekt"
        title "Glasobjekt-Referenz"
        tag "Referenz"
        tagclass ""
        count "2 Bilder"
        subtitle "Materialstudie Glas"
        images {
            {
                thumb "thumbs/thumb_element_01_glass_bowl.webp"
                alt "element_01_glass_bowl.png"
                name "element_01_glass_bowl.png"
                dims "1024×1024 px · 1485 KB"
                code "examples"
            }
            {
                thumb "thumbs/thumb_element_01_glass_bowl.webp"
                alt "element_01_glass_bowl.jpg"
                name "element_01_glass_bowl.jpg"
                dims "1024×1024 px · 126 KB"
                code "7634afec188f40caa502423fce3ef2ea"
            }
        }
    }
    {
        id "cat-perle"
        title "Perlen/Beads"
        tag "Referenz"
        tagclass ""
        count "4 Bilder"
        subtitle "Materialstudie klein/rund"
        images {
            {
                thumb "thumbs/thumb_element_02_beads_group.webp"
                alt "element_02_beads_group.png"
                name "element_02_beads_group.png"
                dims "1024×1024 px · 1751 KB"
                code "examples"
            }
            {
                thumb "thumbs/thumb_element_03_single_bead.webp"
                alt "element_03_single_bead.png"
                name "element_03_single_bead.png"
                dims "1024×1024 px · 1473 KB"
                code "examples"
            }
            {
                thumb "thumbs/thumb_element_02_beads_group.webp"
                alt "element_02_beads_group.jpg"
                name "element_02_beads_group.jpg"
                dims "1024×1024 px · 284 KB"
                code "7634afec188f40caa502423fce3ef2ea"
            }
            {
                thumb "thumbs/thumb_element_03_single_bead.webp"
                alt "element_03_single_bead.jpg"
                name "element_03_single_bead.jpg"
                dims "1024×1024 px · 127 KB"
                code "7634afec188f40caa502423fce3ef2ea"
            }
        }
    }
    {
        id "cat-peonie_ref"
        title "Pfingstrosen-Kompositionen"
        tag "Referenz"
        tagclass ""
        count "4 Bilder"
        subtitle "Referenz-Look; nicht direkt nutzbar"
        images {
            {
                thumb "thumbs/thumb_comp_02_peonies_warm.webp"
                alt "comp_02_peonies_warm.png"
                name "comp_02_peonies_warm.png"
                dims "1024×1536 px · 2500 KB"
                code "examples"
            }
            {
                thumb "thumbs/thumb_comp_01_peonies_dark.webp"
                alt "comp_01_peonies_dark.png"
                name "comp_01_peonies_dark.png"
                dims "1024×1535 px · 2124 KB"
                code "examples"
            }
            {
                thumb "thumbs/thumb_comp_02_peonies_warm.webp"
                alt "comp_02_peonies_warm.jpg"
                name "comp_02_peonies_warm.jpg"
                dims "1024×1536 px · 761 KB"
                code "7634afec188f40caa502423fce3ef2ea"
            }
            {
                thumb "thumbs/thumb_comp_01_peonies_dark.webp"
                alt "comp_01_peonies_dark.jpg"
                name "comp_01_peonies_dark.jpg"
                dims "1024×1535 px · 642 KB"
                code "7634afec188f40caa502423fce3ef2ea"
            }
        }
    }
    {
        id "cat-feder"
        title "Feder"
        tag "Referenz"
        tagclass ""
        count "1 Bilder"
        subtitle "Referenz Element"
        images {
            {
                thumb "thumbs/thumb_element_04_feather.webp"
                alt "element_04_feather.png"
                name "element_04_feather.png"
                dims "1024×1536 px · 2384 KB"
                code "examples"
            }
        }
    }
    {
        id "cat-ref_unsplash"
        title "Unsplash Referenzen"
        tag "Referenz"
        tagclass ""
        count "3 Bilder"
        subtitle "Ästhetik-Referenz"
        images {
            {
                thumb "thumbs/thumb_katya-azimova-j945b6ttc7s-unsplash.webp"
                alt "katya-azimova-j945b6ttc7s-unsplash.jpg"
                name "katya-azimova-j945b6ttc7s-unsplash.jpg"
                dims "4659×6989 px · 8535 KB"
                code "examples"
            }
            {
                thumb "thumbs/thumb_anita-austvika-GnO2S8c7slQ-unsplash.webp"
                alt "anita-austvika-GnO2S8c7slQ-unsplash.jpg"
                name "anita-austvika-GnO2S8c7slQ-unsplash.jpg"
                dims "4912×7360 px · 7049 KB"
                code "examples"
            }
            {
                thumb "thumbs/thumb_salvus-CiH1lH1u4dc-unsplash.webp"
                alt "salvus-CiH1lH1u4dc-unsplash.jpg"
                name "salvus-CiH1lH1u4dc-unsplash.jpg"
                dims "3840×2160 px · 530 KB"
                code "examples"
            }
        }
    }
    {
        id "cat-sonstiges"
        title "Sonstiges"
        tag ""
        tagclass ""
        count "1 Bilder"
        subtitle ""
        images {
            {
                thumb "thumbs/thumb_candidate-08-pixabay-1510707-original.webp"
                alt "candidate-08-pixabay-1510707-original.jpg"
                name "candidate-08-pixabay-1510707-original.jpg"
                dims "5184×3456 px · 1253 KB"
                code "pending-approval"
            }
        }
    }
    {
        id "cat-globe_frame"
        title "Weltkugel-Frames"
        tag "Vorhanden (Frames)"
        tagclass ""
        count "9 Bilder"
        subtitle "Bereits verwendet in globe-hero"
        images {
            {
                name "frame-02.png"
                dims "?×? px · 98 KB"
                code "media"
                nothumb true
            }
            {
                name "frame-01.png"
                dims "?×? px · 92 KB"
                code "media"
                nothumb true
            }
            {
                name "frame-04.png"
                dims "?×? px · 86 KB"
                code "media"
                nothumb true
            }
            {
                name "frame-05.png"
                dims "?×? px · 73 KB"
                code "media"
                nothumb true
            }
            {
                name "frame-03.png"
                dims "?×? px · 71 KB"
                code "media"
                nothumb true
            }
            {
                name "frame-06.png"
                dims "?×? px · 37 KB"
                code "media"
                nothumb true
            }
            {
                name "frame-09.png"
                dims "?×? px · 37 KB"
                code "media"
                nothumb true
            }
            {
                name "frame-08.png"
                dims "?×? px · 29 KB"
                code "media"
                nothumb true
            }
            {
                name "frame-07.png"
                dims "?×? px · 27 KB"
                code "media"
                nothumb true
            }
        }
    }
    {
        id "cat-screenshot"
        title "Screenshots"
        tag "Referenz"
        tagclass ""
        count "4 Bilder"
        subtitle "Referenz aus Anhang"
        images {
            {
                name "image-3.jpg"
                dims "?×? px · 121 KB"
                code "7634afec188f40caa502423fce3ef2ea"
                nothumb true
            }
            {
                name "image-4.jpg"
                dims "?×? px · 118 KB"
                code "7634afec188f40caa502423fce3ef2ea"
                nothumb true
            }
            {
                name "image-2.jpg"
                dims "?×? px · 109 KB"
                code "7634afec188f40caa502423fce3ef2ea"
                nothumb true
            }
            {
                name "image.jpg"
                dims "?×? px · 104 KB"
                code "7634afec188f40caa502423fce3ef2ea"
                nothumb true
            }
        }
    }
}

# Funktion zum Erzeugen der HTML-Datei
proc generate_html {categories filename} {
    set fp [open $filename w]
    
    # HTML-Kopf
    puts $fp {<!DOCTYPE html>}
    puts $fp {<html lang="de"><head><meta charset="utf-8"><title>Kontaktbogen — Project-Landingpage Assets</title>}
    puts $fp {<style>}
    puts $fp {  :root{--bg:#FAF8F4;--ink:#1B1A17;--muted:#6E6A61;--line:#E5E1D8;--accent:#A8542F;--accent-2:#2E7D7B;--surface:#fff}}
    puts $fp {  *{box-sizing:border-box}}
    puts $fp {  body{margin:0;font-family:'Hanken Grotesk',system-ui,sans-serif;background:var(--bg);color:var(--ink);line-height:1.5}}
    puts $fp {  header{padding:2.5rem 2rem 1rem;border-bottom:1px solid var(--line);background:var(--surface);position:sticky;top:0;z-index:10}}
    puts $fp {  header h1{margin:0 0 .5rem;font-family:'Newsreader',Georgia,serif;font-weight:400;font-size:2.25rem}}
    puts $fp {  header p{margin:.25rem 0;color:var(--muted);max-width:80ch}}
    puts $fp {  .legend{display:flex;gap:1rem;flex-wrap:wrap;margin-top:.75rem;font-size:.8125rem}}
    puts $fp {  .pill{padding:.15rem .6rem;border-radius:999px;border:1px solid var(--line);background:#fff}}
    puts $fp {  .pill.pflicht{border-color:var(--accent);color:var(--accent);font-weight:600}}
    puts $fp {  .pill.auswahl{border-color:var(--accent-2);color:var(--accent-2);font-weight:600}}
    puts $fp {  main{padding:2rem;max-width:1400px;margin:0 auto}}
    puts $fp {  section{margin:2.5rem 0}}
    puts $fp {  section h2{font-family:'Newsreader',serif;font-weight:400;font-size:1.5rem;margin:0 0 .25rem;display:flex;align-items:center;gap:.75rem}}
    puts $fp {  section .sub{color:var(--muted);font-size:.875rem;margin:0 0 1.25rem}}
    puts $fp {  .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:1rem}}
    puts $fp {  .card{background:var(--surface);border:1px solid var(--line);border-radius:10px;overflow:hidden;display:flex;flex-direction:column}}
    puts $fp {  .card .imgwrap{aspect-ratio:1;background:#f1eee7;display:flex;align-items:center;justify-content:center;overflow:hidden}}
    puts $fp {  .card img{width:100%;height:100%;object-fit:contain;background:#fff}}
    puts $fp {  .card .meta{padding:.6rem .75rem .75rem;font-size:.78125rem}}
    puts $fp {  .card .name{font-family:'JetBrains Mono',monospace;font-size:.6875rem;color:var(--muted);word-break:break-all;line-height:1.3;margin-bottom:.35rem}}
    puts $fp {  .card .dims{color:var(--muted);font-size:.6875rem;margin-bottom:.35rem}}
    puts $fp {  .card .prompt{color:var(--ink);font-size:.75rem;line-height:1.35;font-style:italic;border-top:1px solid var(--line);padding-top:.4rem;margin-top:.35rem;max-height:5.5em;overflow:hidden}}
    puts $fp {  .tag{display:inline-block;padding:.1rem .45rem;border-radius:999px;font-size:.6875rem;background:#F1EEE7;color:var(--muted);margin-right:.25rem}}
    puts $fp {  .tag.p{background:#F1E5DD;color:var(--accent)}}
    puts $fp {  .tag.a{background:#DEEDEC;color:var(--accent-2)}}
    puts $fp {</style></head>}
    puts $fp {<body>}
    
    # Header
    puts $fp {<header>}
    puts $fp {  <h1>Kontaktbogen — Project-Landingpage Bildbestand</h1>}
    puts $fp {  <p>Alle vorhandenen HighRes-Bilder aus deiner Design-Referenz, dem laufenden Codex-Repo und den Anhängen. Kategorisiert nach Verwendungszweck. Bitte markiere pro Kategorie welche Assets in die finale Umsetzung sollen und wo du Erweiterung wünschst.</p>}
    puts $fp {  <div class="legend">}
    puts $fp {    <span class="pill pflicht">PFLICHT — muss ins finale Design</span>}
    puts $fp {    <span class="pill auswahl">AUSWAHL nötig — mehrere Kandidaten</span>}
    puts $fp {    <span class="pill">Referenz — nur Ästhetik, nicht direkt verwendet</span>}
    puts $fp {    <span class="pill">Vorhanden — schon im Repo eingebaut</span>}
    puts $fp {  </div>}
    puts $fp {</header>}
    
    # Main Content
    puts $fp {<main>}
    
    # Durch alle Kategorien iterieren
    foreach cat $categories {
        set id [dict get $cat id]
        set title [dict get $cat title]
        set tag [dict get $cat tag]
        set tagclass [dict get $cat tagclass]
        set count [dict get $cat count]
        set subtitle [dict get $cat subtitle]
        set images [dict get $cat images]
        
        puts $fp "<section id=\"$id\"><h2>$title"
        if {$tag ne ""} {
            set cls ""
            if {$tagclass ne ""} {
                set cls " $tagclass"
            }
            puts -nonewline $fp " <span class=\"tag$cls\">$tag</span>"
        }
        puts $fp " <span class=\"tag\">$count</span></h2>"
        if {$subtitle ne ""} {
            puts $fp "<p class=\"sub\">$subtitle</p>"
        } else {
            puts $fp "<p class=\"sub\"></p>"
        }
        puts $fp {<div class="grid">}
        
        # Durch alle Bilder der Kategorie iterieren
        foreach img $images {
            puts $fp {      <div class="card">}
            
            # Thumbnail-Bereich
            if {[dict exists $img nothumb] && [dict get $img nothumb]} {
                puts $fp {        <div class="imgwrap"><div style="color:#999">kein Thumbnail</div></div>}
            } else {
                set thumb [dict get $img thumb]
                set alt [dict get $img alt]
                puts $fp "        <div class=\"imgwrap\"><img src=\"$thumb\" alt=\"$alt\" loading=\"lazy\"></div>"
            }
            
            # Metadaten-Bereich
            puts $fp {        <div class="meta">}
            set name [dict get $img name]
            puts $fp "          <div class=\"name\">$name</div>"
            set dims [dict get $img dims]
            puts $fp "          <div class=\"dims\">$dims</div>"
            set code [dict get $img code]
            puts $fp "          <div><code>$code</code></div>"
            if {[dict exists $img prompt]} {
                set prompt [dict get $img prompt]
                puts $fp "          <div class=\"prompt\">$prompt</div>"
            }
            puts $fp {        </div>}
            puts $fp {      </div>}
        }
        
        puts $fp {</div></section>}
    }
    
    puts $fp {</main></body></html>}
    close $fp
}

# Hauptprogramm
if {$argc != 1} {
    puts stderr "Verwendung: [info script] <ausgabedatei>"
    exit 1
}

set output_file [lindex $argv 0]
generate_html $categories $output_file
