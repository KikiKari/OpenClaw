// abstraction-provenance: {"artifact_sha256": "bee0e4179e7467d3b172c93cf4986b7bdbb8b52ff32e10baeafe4ff47afcd145", "source_sha256": "ca574d779b67b58a38559123215e116d8c6e2ef4c122350bb69958e8a6423187", "target_language": "fsharp"}
// kontaktbogen.html — portiert nach fsharp
// Quelle: html, Onboarding@main:development/contactsheets/v1/kontaktbogen.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Text

type Tag = { text: string; isPflicht: bool; isAuswahl: bool }
type ImageMeta = { name: string; dims: string; size: string; folder: string; prompt: string option }
type Card = { thumbSrc: string; alt: string; meta: ImageMeta }
type Section = { id: string; title: string; tags: Tag list; subtitle: string; cards: Card list }

let createTag text isPflicht isAuswahl = { text = text; isPflicht = isPflicht; isAuswahl = isAuswahl }
let createImageMeta name dims size folder prompt = { name = name; dims = dims; size = size; folder = folder; prompt = prompt }
let createCard thumbSrc alt meta = { thumbSrc = thumbSrc; alt = alt; meta = meta }
let createSection id title tags subtitle cards = { id = id; title = title; tags = tags; subtitle = subtitle; cards = cards }

let sections = [
  createSection "cat-seerose" "Seerosen (Pixabay/Unsplash)" 
    [createTag "AUSWAHL nötig" false true; createTag "5 Bilder" false false]
    "Kandidaten für 3D-Textur / Alpha"
    [
      createCard "thumbs/thumb_water_lily_01_pixabay_1510707_original.webp" "water_lily_01_pixabay_1510707_original.jpg" 
        (createImageMeta "water_lily_01_pixabay_1510707_original.jpg" "5184×3456 px" "1253 KB" "examples" None);
      createCard "thumbs/thumb_candidate-10-pixabay-4602155-wide-real-pond-lily-pads.webp" "candidate-10-pixabay-4602155-wide-real-pond-lily-pads.jpg" 
        (createImageMeta "candidate-10-pixabay-4602155-wide-real-pond-lily-pads.jpg" "1280×960 px" "570 KB" "pending-approval" None);
      createCard "thumbs/thumb_candidate-11-pixabay-5904414-giant-water-lily-3d-depth.webp" "candidate-11-pixabay-5904414-giant-water-lily-3d-depth.jpg" 
        (createImageMeta "candidate-11-pixabay-5904414-giant-water-lily-3d-depth.jpg" "1280×951 px" "495 KB" "pending-approval" None);
      createCard "thumbs/thumb_candidate-12-unsplash-Z9h4Fl6iCuU-pond-lily-pads.webp" "candidate-12-unsplash-Z9h4Fl6iCuU-pond-lily-pads.jpg" 
        (createImageMeta "candidate-12-unsplash-Z9h4Fl6iCuU-pond-lily-pads.jpg" "2400×1600 px" "425 KB" "pending-approval" None);
      createCard "thumbs/thumb_candidate-09-pixabay-6403860-red-water-lily-water-closeup.webp" "candidate-09-pixabay-6403860-red-water-lily-water-closeup.jpg" 
        (createImageMeta "candidate-09-pixabay-6403860-red-water-lily-water-closeup.jpg" "1280×853 px" "248 KB" "pending-approval" None)
    ];
  
  createSection "cat-wavespeed_hero" "WaveSpeed 4K Hero" 
    [createTag "PFLICHT-Kandidat" true false; createTag "2 Bilder" false false]
    "Bereits generierter Hero-Hintergrund"
    [
      createCard "thumbs/thumb_hero-meadow.webp" "hero-meadow.png" 
        (createImageMeta "hero-meadow.png" "5504×3072 px" "18908 KB" "media" 
          (Some "Preserve the dense botanical meadow composition and teal, moss, cream and restrained amber palette. Create an elegant cinematic 4K landing-page background with realistic flowers, g..."));
      createCard "thumbs/thumb_hero-meadow.webp" "hero-meadow.webp" 
        (createImageMeta "hero-meadow.webp" "5504×3072 px" "836 KB" "media" 
          (Some "Preserve the dense botanical meadow composition and teal, moss, cream and restrained amber palette. Create an elegant cinematic 4K landing-page background with realistic flowers, g..."))
    ];
  
  createSection "cat-wavespeed_orb" "WaveSpeed 4K Glaskugel" 
    [createTag "PFLICHT-Kandidat" true false; createTag "2 Bilder" false false]
    "Referenz-Glaskugel für 3D-Material"
    [
      createCard "thumbs/thumb_glass-orb.webp" "glass-orb.png" 
        (createImageMeta "glass-orb.png" "4096×4096 px" "18805 KB" "media" 
          (Some "Preserve the transparent glass sphere as the single subject. Refine it into a premium luminous crystal orb in a botanical meadow, soft white and pale teal refractions, restrained h..."));
      createCard "thumbs/thumb_glass-orb.webp" "glass-orb.webp" 
        (createImageMeta "glass-orb.webp" "4096×4096 px" "730 KB" "media" 
          (Some "Preserve the transparent glass sphere as the single subject. Refine it into a premium luminous crystal orb in a botanical meadow, soft white and pale teal refractions, restrained h..."))
    ];
  
  createSection "cat-wavespeed_projects" "WaveSpeed 4K Sektionen" 
    [createTag "Vorhanden" false false; createTag "6 Bilder" false false]
    "Section-Backgrounds (Claude/Perplexity)"
    [
      createCard "thumbs/thumb_perplexity-projects.webp" "perplexity-projects.png" 
        (createImageMeta "perplexity-projects.png" "4800×3584 px" "21947 KB" "media" 
          (Some "Create an abstract premium visual for research, weather and computer-vision projects. Fine observation grids, atmospheric map contours, optical glass details, teal and pale blue ac..."));
      createCard "thumbs/thumb_claude-projects.webp" "claude-projects.png" 
        (createImageMeta "claude-projects.png" "4800×3584 px" "20711 KB" "media" 
          (Some "Create an abstract premium visual for a family of automation, security and publishing tools. Layered paper-like systems, fine technical lines, small warm copper accents, botanical ..."));
      createCard "thumbs/thumb_og-projects.webp" "og-projects.png" 
        (createImageMeta "og-projects.png" "5504×3072 px" "18199 KB" "media" 
          (Some "Create a strong social preview image: luminous glass orb floating above a cinematic botanical meadow, quiet technical linework inside the sphere, ivory, moss, teal and copper palet..."));
      createCard "thumbs/thumb_perplexity-projects.webp" "perplexity-projects.webp" 
        (createImageMeta "perplexity-projects.webp" "4800×3584 px" "1805 KB" "media" 
          (Some "Create an abstract premium visual for research, weather and computer-vision projects. Fine observation grids, atmospheric map contours, optical glass details, teal and pale blue ac..."));
      createCard "thumbs/thumb_claude-projects.webp" "claude-projects.webp" 
        (createImageMeta "claude-projects.webp" "4800×3584 px" "1114 KB" "media" 
          (Some "Create an abstract premium visual for a family of automation, security and publishing tools. Layered paper-like systems, fine technical lines, small warm copper accents, botanical ..."));
      createCard "thumbs/thumb_og-projects.webp" "og-projects.webp" 
        (createImageMeta "og-projects.webp" "5504×3072 px" "819 KB" "media" 
          (Some "Create a strong social preview image: luminous glass orb floating above a cinematic botanical meadow, quiet technical linework inside the sphere, ivory, moss, teal and copper palet..."))
    ];
  
  createSection "cat-wavespeed_section" "WaveSpeed 4K Zusatz" 
    [createTag "Vorhanden" false false; createTag "4 Bilder" false false]
    "CTA / Feature-Spotlight"
    [
      createCard "thumbs/thumb_feature-spotlight.webp" "feature-spotlight.png" 
        (createImageMeta "feature-spotlight.png" "4800×3584 px" "18688 KB" "media" 
          (Some "Combine the botanical meadow and glass sphere into a polished editorial technology image. The glass orb reveals subtle scientific line patterns and biodiversity details, balanced n..."));
      createCard "thumbs/thumb_cta-background.webp" "cta-background.png" 
        (createImageMeta "cta-background.png" "5504×3072 px" "15543 KB" "media" 
          (Some "Transform the botanical meadow into a very light, spacious call-to-action background. Soft radial teal, amber and copper blooms around empty central space, subtle organic detail, h..."));
      createCard "thumbs/thumb_feature-spotlight.webp" "feature-spotlight.webp" 
        (createImageMeta "feature-spotlight.webp" "4800×3584 px" "1315 KB" "media" 
          (Some "Combine the botanical meadow and glass sphere into a polished editorial technology image. The glass orb reveals subtle scientific line patterns and biodiversity details, balanced n..."));
      createCard "thumbs/thumb_cta-background.webp" "cta-background.webp" 
        (createImageMeta "cta-background.webp" "5504×3072 px" "730 KB" "media" 
          (Some "Transform the botanical meadow into a very light, spacious call-to-action background. Soft radial teal, amber and copper blooms around empty central space, subtle organic detail, h..."))
    ];
  
  createSection "cat-studio_variant" "Studio-Varianten Glaskugel" 
    [createTag "Referenz" false false; createTag "8 Bilder" false false]
    "Beleuchtungsstudien für Glas"
    [
      createCard "thumbs/thumb_var6_flat_lay.webp" "var6_flat_lay.png" 
        (createImageMeta "var6_flat_lay.png" "1672×941 px" "3173 KB" "examples" None);
      createCard "thumbs/thumb_var8_natural_light_outdoor.webp" "var8_natural_light_outdoor.png" 
        (createImageMeta "var8_natural_light_outdoor.png" "1672×941 px" "2481 KB" "examples" None);
      createCard "thumbs/thumb_var5_closeup_detail.webp" "var5_closeup_detail.png" 
        (createImageMeta "var5_closeup_detail.png" "1672×941 px" "1863 KB" "examples" None);
      createCard "thumbs/thumb_var4_dramatic_lighting.webp" "var4_dramatic_lighting.png" 
        (createImageMeta "var4_dramatic_lighting.png" "1672×941 px" "1573 KB" "examples" None);
      createCard "thumbs/thumb_var2_studio_white2.webp" "var2_studio_white2.png" 
        (createImageMeta "var2_studio_white2.png" "1672×941 px" "1285 KB" "examples" None);
      createCard "thumbs/thumb_var1_studio_white.webp" "var1_studio_white.png" 
        (createImageMeta "var1_studio_white.png" "1672×941 px" "1259 KB" "examples" None);
      createCard "thumbs/thumb_var8_natural_light_outdoor.webp" "var8_natural_light_outdoor.jpg" 
        (createImageMeta "var8_natural_light_outdoor.jpg" "1672×941 px" "800 KB" "7634afec188f40caa502423fce3ef2ea" None);
      createCard "thumbs/thumb_var4_dramatic_lighting.webp" "var4_dramatic_lighting.jpg" 
        (createImageMeta "var4_dramatic_lighting.jpg" "1672×941 px" "386 KB" "7634afec188f40caa502423fce3ef2ea" None)
    ];
  
  createSection "cat-glasobjekt" "Glasobjekt-Referenz" 
    [createTag "Referenz" false false; createTag "2 Bilder" false false]
    "Materialstudie Glas"
    [
      createCard "thumbs/thumb_element_01_glass_bowl.webp" "element_01_glass_bowl.png" 
        (createImageMeta "element_01_glass_bowl.png" "1024×1024 px" "1485 KB" "examples" None);
      createCard "thumbs/thumb_element_01_glass_bowl.webp" "element_01_glass_bowl.jpg" 
        (createImageMeta "element_01_glass_bowl.jpg" "1024×1024 px" "126 KB" "7634afec188f40caa502423fce3ef2ea" None)
    ];
  
  createSection "cat-perle" "Perlen/Beads" 
    [createTag "Referenz" false false; createTag "4 Bilder" false false]
    "Materialstudie klein/rund"
    [
      createCard "thumbs/thumb_element_02_beads_group.webp" "element_02_beads_group.png" 
        (createImageMeta "element_02_beads_group.png" "1024×1024 px" "1751 KB" "examples" None);
      createCard "thumbs/thumb_element_03_single_bead.webp" "element_03_single_bead.png" 
        (createImageMeta "element_03_single_bead.png" "1024×1024 px" "1473 KB" "examples" None);
      createCard "thumbs/thumb_element_02_beads_group.webp" "element_02_beads_group.jpg" 
        (createImageMeta "element_02_beads_group.jpg" "1024×1024 px" "284 KB" "7634afec188f40caa502423fce3ef2ea" None);
      createCard "thumbs/thumb_element_03_single_bead.webp" "element_03_single_bead.jpg" 
        (createImageMeta "element_03_single_bead.jpg" "1024×1024 px" "127 KB" "7634afec188f40caa502423fce3ef2ea" None)
    ];
  
  createSection "cat-peonie_ref" "Pfingstrosen-Kompositionen" 
    [createTag "Referenz" false false; createTag "4 Bilder" false false]
    "Referenz-Look; nicht direkt nutzbar"
    [
      createCard "thumbs/thumb_comp_02_peonies_warm.webp" "comp_02_peonies_warm.png" 
        (createImageMeta "comp_02_peonies_warm.png" "1024×1536 px" "2500 KB" "examples" None);
      createCard "thumbs/thumb_comp_01_peonies_dark.webp" "comp_01_peonies_dark.png" 
        (createImageMeta "comp_01_peonies_dark.png" "1024×1535 px" "2124 KB" "examples" None);
      createCard "thumbs/thumb_comp_02_peonies_warm.webp" "comp_02_peonies_warm.jpg" 
        (createImageMeta "comp_02_peonies_warm.jpg" "1024×1536 px" "761 KB" "7634afec188f40caa502423fce3ef2ea" None);
      createCard "thumbs/thumb_comp_01_peonies_dark.webp" "comp_01_peonies_dark.jpg" 
        (createImageMeta "comp_01_peonies_dark.jpg" "1024×1535 px" "642 KB" "7634afec188f40caa502423fce3ef2ea" None)
    ];
  
  createSection "cat-feder" "Feder" 
    [createTag "Referenz" false false; createTag "1 Bilder" false false]
    "Referenz Element"
    [
      createCard "thumbs/thumb_element_04_feather.webp" "element_04_feather.png" 
        (createImageMeta "element_04_feather.png" "1024×1536 px" "2384 KB" "examples" None)
    ];
  
  createSection "cat-ref_unsplash" "Unsplash Referenzen" 
    [createTag "Referenz" false false; createTag "3 Bilder" false false]
    "Ästhetik-Referenz"
    [
      createCard "thumbs/thumb_katya-azimova-j945b6ttc7s-unsplash.webp" "katya-azimova-j945b6ttc7s-unsplash.jpg" 
        (createImageMeta "katya-azimova-j945b6ttc7s-unsplash.jpg" "4659×6989 px" "8535 KB" "examples" None);
      createCard "thumbs/thumb_anita-austvika-GnO2S8c7slQ-unsplash.webp" "anita-austvika-GnO2S8c7slQ-unsplash.jpg" 
        (createImageMeta "anita-austvika-GnO2S8c7slQ-unsplash.jpg" "4912×7360 px" "7049 KB" "examples" None);
      createCard "thumbs/thumb_salvus-CiH1lH1u4dc-unsplash.webp" "salvus-CiH1lH1u4dc-unsplash.jpg" 
        (createImageMeta "salvus-CiH1lH1u4dc-unsplash.jpg" "3840×2160 px" "530 KB" "examples" None)
    ];
  
  createSection "cat-sonstiges" "Sonstiges" 
    [createTag "" false false; createTag "1 Bilder" false false]
    ""
    [
      createCard "thumbs/thumb_candidate-08-pixabay-1510707-original.webp" "candidate-08-pixabay-1510707-original.jpg" 
        (createImageMeta "candidate-08-pixabay-1510707-original.jpg" "5184×3456 px" "1253 KB" "pending-approval" None)
    ];
  
  createSection "cat-globe_frame" "Weltkugel-Frames" 
    [createTag "Vorhanden (Frames)" false false; createTag "9 Bilder" false false]
    "Bereits verwendet in globe-hero"
    [
      { thumbSrc = ""; alt = ""; meta = createImageMeta "frame-02.png" "?×? px" "98 KB" "media" None };
      { thumbSrc = ""; alt = ""; meta = createImageMeta "frame-01.png" "?×? px" "92 KB" "media" None };
      { thumbSrc = ""; alt = ""; meta = createImageMeta "frame-04.png" "?×? px" "86 KB" "media" None };
      { thumbSrc = ""; alt = ""; meta = createImageMeta "frame-05.png" "?×? px" "73 KB" "media" None };
      { thumbSrc = ""; alt = ""; meta = createImageMeta "frame-03.png" "?×? px" "71 KB" "media" None };
      { thumbSrc = ""; alt = ""; meta = createImageMeta "frame-06.png" "?×? px" "37 KB" "media" None };
      { thumbSrc = ""; alt = ""; meta = createImageMeta "frame-09.png" "?×? px" "37 KB" "media" None };
      { thumbSrc = ""; alt = ""; meta = createImageMeta "frame-08.png" "?×? px" "29 KB" "media" None };
      { thumbSrc = ""; alt = ""; meta = createImageMeta "frame-07.png" "?×? px" "27 KB" "media" None }
    ];
  
  createSection "cat-screenshot" "Screenshots" 
    [createTag "Referenz" false false; createTag "4 Bilder" false false]
    "Referenz aus Anhang"
    [
      { thumbSrc = ""; alt = ""; meta = createImageMeta "image-3.jpg" "?×? px" "121 KB" "7634afec188f40caa502423fce3ef2ea" None };
      { thumbSrc = ""; alt = ""; meta = createImageMeta "image-4.jpg" "?×? px" "118 KB" "7634afec188f40caa502423fce3ef2ea" None };
      { thumbSrc = ""; alt = ""; meta = createImageMeta "image-2.jpg" "?×? px" "109 KB" "7634afec188f40caa502423fce3ef2ea" None };
      { thumbSrc = ""; alt = ""; meta = createImageMeta "image.jpg" "?×? px" "104 KB" "7634afec188f40caa502423fce3ef2ea" None }
    ]
]

let generateHTML() =
  let sb = StringBuilder()
  
  sb.Append("<!DOCTYPE html>") |> ignore
  sb.Append("<html lang=\"de\"><head><meta charset=\"utf-8\"><title>Kontaktbogen — Project-Landingpage Assets</title>") |> ignore
  sb.Append("<style>") |> ignore
  sb.Append(":root{--bg:#FAF8F4;--ink:#1B1A17;--muted:#6E6A61;--line:#E5E1D8;--accent:#A8542F;--accent-2:#2E7D7B;--surface:#fff}") |> ignore
  sb.Append("*{box-sizing:border-box}") |> ignore
  sb.Append("body{margin:0;font-family:'Hanken Grotesk',system-ui,sans-serif;background:var(--bg);color:var(--ink);line-height:1.5}") |> ignore
  sb.Append("header{padding:2.5rem 2rem 1rem;border-bottom:1px solid var(--line);background:var(--surface);position:sticky;top:0;z-index:10}") |> ignore
  sb.Append("header h1{margin:0 0 .5rem;font-family:'Newsreader',Georgia,serif;font-weight:400;font-size:2.25rem}") |> ignore
  sb.Append("header p{margin:.25rem 0;color:var(--muted);max-width:80ch}") |> ignore
  sb.Append(".legend{display:flex;gap:1rem;flex-wrap:wrap;margin-top:.75rem;font-size:.8125rem}") |> ignore
  sb.Append(".pill{padding:.15rem .6rem;border-radius:999px;border:1px solid var(--line);background:#fff}") |> ignore
  sb.Append(".pill.pflicht{border-color:var(--accent);color:var(--accent);font-weight:600}") |> ignore
  sb.Append(".pill.auswahl{border-color:var(--accent-2);color:var(--accent-2);font-weight:600}") |> ignore
  sb.Append("main{padding:2rem;max-width:1400px;margin:0 auto}") |> ignore
  sb.Append("section{margin:2.5rem 0}") |> ignore
  sb.Append("section h2{font-family:'Newsreader',serif;font-weight:400;font-size:1.5rem;margin:0 0 .25rem;display:flex;align-items:center;gap:.75rem}") |> ignore
  sb.Append("section .sub{color:var(--muted);font-size:.875rem;margin:0 0 1.25rem}") |> ignore
  sb.Append(".grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:1rem}") |> ignore
  sb.Append(".card{background:var(--surface);border:1px solid var(--line);border-radius:10px;overflow:hidden;display:flex;flex-direction:column}") |> ignore
  sb.Append(".card .imgwrap{aspect-ratio:1;background:#f1eee7;display:flex;align-items:center;justify-content:center;overflow:hidden}") |> ignore
  sb.Append(".card img{width:100%;height:100%;object-fit:contain;background:#fff}") |> ignore
  sb.Append(".card .meta{padding:.6rem .75rem .75rem;font-size:.78125rem}") |> ignore
  sb.Append(".card .name{font-family:'JetBrains Mono',monospace;font-size:.6875rem;color:var(--muted);word-break:break-all;line-height:1.3;margin-bottom:.35rem}") |> ignore
  sb.Append(".card .dims{color:var(--muted);font-size:.6875rem;margin-bottom:.35rem}") |> ignore
  sb.Append(".card .prompt{color:var(--ink);font-size:.75rem;line-height:1.35;font-style:italic;border-top:1px solid var(--line);padding-top:.4rem;margin-top:.35rem;max-height:5.5em;overflow:hidden}") |> ignore
  sb.Append(".tag{display:inline-block;padding:.1rem .45rem;border-radius:999px;font-size:.6875rem;background:#F1EEE7;color:var(--muted);margin-right:.25rem}") |> ignore
  sb.Append(".tag.p{background:#F1E5DD;color:var(--accent)}") |> ignore
  sb.Append(".tag.a{background:#DEEDEC;color:var(--accent-2)}") |> ignore
  sb.Append("</style></head>") |> ignore
  sb.Append("<body>") |> ignore
  
  // Header
  sb.Append("<header>") |> ignore
  sb.Append("<h1>Kontaktbogen — Project-Landingpage Bildbestand</h1>") |> ignore
  sb.Append("<p>Alle vorhandenen HighRes-Bilder aus deiner Design-Referenz, dem laufenden Codex-Repo und den Anhängen. Kategorisiert nach Verwendungszweck. Bitte markiere pro Kategorie welche Assets in die finale Umsetzung sollen und wo du Erweiterung wünschst.</p>") |> ignore
  sb.Append("<div class=\"legend\">") |> ignore
  sb.Append("<span class=\"pill pflicht\">PFLICHT — muss ins finale Design</span>") |> ignore
  sb.Append("<span class=\"pill auswahl\">AUSWAHL nötig — mehrere Kandidaten</span>") |> ignore
  sb.Append("<span class=\"pill\">Referenz — nur Ästhetik, nicht direkt verwendet</span>") |> ignore
  sb.Append("<span class=\"pill\">Vorhanden — schon im Repo eingebaut</span>") |> ignore
  sb.Append("</div>") |> ignore
  sb.Append("</header>") |> ignore
  
  // Main content
  sb.Append("<main>") |> ignore
  
  for section in sections do
    sb.AppendFormat("<section id=\"{0}\">", section.id) |> ignore
    sb.Append("<h2>") |> ignore
    sb.Append(section.title)
    for tag in section.tags do
      let cssClass = 
        if tag.isPflicht then "tag p"
        elif tag.isAuswahl then "tag a"
        else "tag"
      sb.AppendFormat("<span class=\"{0}\">{1}</span>", cssClass, tag.text) |> ignore
    sb.Append("</h2>") |> ignore
    sb.AppendFormat("<p class=\"sub\">{0}</p>", section.subtitle) |> ignore
    sb.Append("<div class=\"grid\">") |> ignore
    
    for card in section.cards do
      sb.Append("<div class=\"card\">") |> ignore
      if not(String.IsNullOrEmpty(card.thumbSrc)) then
        sb.Append("<div class=\"imgwrap\">") |> ignore
        sb.AppendFormat("<img src=\"{0}\" alt=\"{1}\" loading=\"lazy\">", card.thumbSrc, card.alt) |> ignore
        sb.Append("</div>") |> ignore
      else
        sb.Append("<div class=\"imgwrap\"><div style=\"color:#999\">kein Thumbnail</div></div>") |> ignore
      
      sb.Append("<div class=\"meta\">") |> ignore
      sb.AppendFormat("<div class=\"name\">{0}</div>", card.meta.name) |> ignore
      sb.AppendFormat("<div class=\"dims\">{0} · {1} · <code>{2}</code></div>", card.meta.dims, card.meta.size, card.meta.folder) |> ignore
      match card.meta.prompt with
      | Some prompt -> sb.AppendFormat("<div class=\"prompt\">{0}</div>", prompt) |> ignore
      | None -> ()
      sb.Append("</div>") |> ignore
      sb.Append("</div>") |> ignore
    sb.Append("</div>") |> ignore
    sb.Append("</section>") |> ignore
  
  sb.Append("</main>") |> ignore
  sb.Append("</body></html>") |> ignore
  
  sb.ToString()

[<EntryPoint>]
let main argv =
  if argv.Length <> 1 then
    printfn "Usage: program <output-file>"
    1
  else
    let outputFile = argv.[0]
    let htmlContent = generateHTML()
    File.WriteAllText(outputFile, htmlContent, Encoding.UTF8)
    0
