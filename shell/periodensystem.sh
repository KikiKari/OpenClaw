#!/bin/bash
# periodensystem.html — portiert nach shell
# Quelle: html, Onboarding@main:docs/reference-library/examples/periodensystem.html
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Parameter prüfen
if [[ $# -ne 1 ]]; then
    echo "Verwendung: $0 <ausgabedatei>" >&2
    exit 1
fi

output_file="$1"

# HTML-Grundstruktur erzeugen
{
    echo '<!DOCTYPE html>'
    echo '<html lang="de">'
    echo '<head>'
    echo '<meta charset="UTF-8">'
    echo '<meta name="viewport" content="width=device-width, initial-scale=1.0">'
    echo '<title>Interaktives Periodensystem</title>'
    echo '<style>'
    echo '* { box-sizing: border-box; margin: 0; padding: 0; }'
    echo ':root {'
    echo '  --bg: #fafaf7;'
    echo '  --surface: #ffffff;'
    echo '  --border: rgba(0,0,0,0.12);'
    echo '  --text: #1a1a1a;'
    echo '  --text-muted: #666;'
    echo '}'
    echo '@media (prefers-color-scheme: dark) {'
    echo '  :root {'
    echo '    --bg: #1a1a1a;'
    echo '    --surface: #242424;'
    echo '    --border: rgba(255,255,255,0.15);'
    echo '    --text: #f0f0f0;'
    echo '    --text-muted: #aaa;'
    echo '  }'
    echo '}'
    echo 'body {'
    echo '  font-family: -apple-system, BlinkMacSystemFont, '\''Segoe UI'\'', system-ui, sans-serif;'
    echo '  background: var(--bg);'
    echo '  color: var(--text);'
    echo '  padding: 24px;'
    echo '  max-width: 1100px;'
    echo '  margin: 0 auto;'
    echo '  line-height: 1.5;'
    echo '}'
    echo 'h1 { font-size: 22px; font-weight: 500; margin-bottom: 4px; }'
    echo '.subtitle { color: var(--text-muted); font-size: 14px; margin-bottom: 20px; }'
    echo '.detail {'
    echo '  background: var(--surface);'
    echo '  border: 1px solid var(--border);'
    echo '  border-radius: 12px;'
    echo '  padding: 16px 20px;'
    echo '  min-height: 110px;'
    echo '  display: flex;'
    echo '  align-items: center;'
    echo '  gap: 20px;'
    echo '  margin-bottom: 16px;'
    echo '}'
    echo '.detail-empty {'
    echo '  color: var(--text-muted);'
    echo '  font-size: 14px;'
    echo '  text-align: center;'
    echo '  width: 100%;'
    echo '}'
    echo '.symbol-box {'
    echo '  font-size: 40px;'
    echo '  font-weight: 500;'
    echo '  line-height: 1;'
    echo '  width: 80px;'
    echo '  height: 80px;'
    echo '  display: flex;'
    echo '  align-items: center;'
    echo '  justify-content: center;'
    echo '  border-radius: 8px;'
    echo '  flex-shrink: 0;'
    echo '}'
    echo '.info-name { font-size: 20px; font-weight: 500; margin-bottom: 8px; }'
    echo '.info-meta {'
    echo '  font-size: 13px;'
    echo '  color: var(--text-muted);'
    echo '  display: grid;'
    echo '  grid-template-columns: repeat(2, minmax(0, 1fr));'
    echo '  gap: 4px 24px;'
    echo '}'
    echo '.info-meta b { font-weight: 500; color: var(--text); margin-left: 6px; }'
    echo '.grid {'
    echo '  display: grid;'
    echo '  grid-template-columns: repeat(18, minmax(0, 1fr));'
    echo '  gap: 3px;'
    echo '}'
    echo '.fgrid { margin-top: 8px; }'
    echo '.cell {'
    echo '  aspect-ratio: 1;'
    echo '  border-radius: 4px;'
    echo '  padding: 3px;'
    echo '  display: flex;'
    echo '  flex-direction: column;'
    echo '  align-items: center;'
    echo '  justify-content: center;'
    echo '  cursor: pointer;'
    echo '  font-family: inherit;'
    echo '  line-height: 1;'
    echo '  transition: transform 0.12s ease;'
    echo '  border: 0;'
    echo '  position: relative;'
    echo '  overflow: hidden;'
    echo '}'
    echo '.cell:hover { transform: scale(1.18); z-index: 5; box-shadow: 0 2px 8px rgba(0,0,0,0.15); }'
    echo '.cell:focus-visible { outline: 2px solid var(--text); outline-offset: 1px; }'
    echo '.cell.active { outline: 2px solid var(--text); outline-offset: 1px; z-index: 4; }'
    echo '.cell .num { font-size: 9px; opacity: 0.75; align-self: flex-start; line-height: 1; padding-left: 2px; }'
    echo '.cell .sym { font-size: 14px; font-weight: 500; margin-top: 2px; }'
    echo '.cell-marker {'
    echo '  cursor: default;'
    echo '  font-size: 9px;'
    echo '  font-weight: 500;'
    echo '  border: 1px dashed currentColor;'
    echo '  background: transparent !important;'
    echo '}'
    echo '.cell-marker:hover { transform: none; box-shadow: none; }'
    echo '.cat-am { background: #FCEBEB; color: #501313; }'
    echo '.cat-em { background: #FAEEDA; color: #412402; }'
    echo '.cat-tm { background: #E6F1FB; color: #042C53; }'
    echo '.cat-ptm { background: #F1EFE8; color: #2C2C2A; }'
    echo '.cat-hm { background: #E1F5EE; color: #04342C; }'
    echo '.cat-nm { background: #EAF3DE; color: #173404; }'
    echo '.cat-h { background: #EEEDFE; color: #26215C; }'
    echo '.cat-eg { background: #FBEAF0; color: #4B1528; }'
    echo '.cat-la { background: #FAECE7; color: #4A1B0C; }'
    echo '.cat-ac { background: #F5C4B3; color: #4A1B0C; }'
    echo '@media (prefers-color-scheme: dark) {'
    echo '  .cat-am { background: #791F1F; color: #F7C1C1; }'
    echo '  .cat-em { background: #633806; color: #FAC775; }'
    echo '  .cat-tm { background: #0C447C; color: #B5D4F4; }'
    echo '  .cat-ptm { background: #444441; color: #D3D1C7; }'
    echo '  .cat-hm { background: #085041; color: #9FE1CB; }'
    echo '  .cat-nm { background: #27500A; color: #C0DD97; }'
    echo '  .cat-h { background: #3C3489; color: #CECBF6; }'
    echo '  .cat-eg { background: #72243E; color: #F4C0D1; }'
    echo '  .cat-la { background: #712B13; color: #F5C4B3; }'
    echo '  .cat-ac { background: #993C1D; color: #F5C4B3; }'
    echo '}'
    echo '.legend {'
    echo '  display: grid;'
    echo '  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));'
    echo '  gap: 8px 16px;'
    echo '  margin-top: 24px;'
    echo '  font-size: 12px;'
    echo '  color: var(--text-muted);'
    echo '}'
    echo '.legend-item { display: flex; align-items: center; gap: 8px; }'
    echo '.legend-swatch { width: 14px; height: 14px; border-radius: 3px; flex-shrink: 0; }'
    echo '</style>'
    echo '</head>'
    echo '<body>'
    echo '<h1>Periodensystem der Elemente</h1>'
    echo '<p class="subtitle">Klicke auf ein Element, um Details zu sehen.</p>'
    echo '<div class="detail" id="detail"><div class="detail-empty">Klicke auf ein Element, um Details zu sehen</div></div>'
    echo '<div class="grid" id="main"></div>'
    echo '<div class="grid fgrid" id="fblock"></div>'
    echo '<div class="legend" id="legend"></div>'
    echo '<script>'
} > "$output_file"

# JavaScript-Datenarrays generieren
{
    echo 'const E = ['
    # Elementdaten (jeweils eine Zeile pro Element)
    echo "[1,'H','Wasserstoff','1,008','nm',1,1],[2,'He','Helium','4,003','eg',1,18],"
    echo "[3,'Li','Lithium','6,94','am',2,1],[4,'Be','Beryllium','9,012','em',2,2],"
    echo "[5,'B','Bor','10,81','hm',2,13],[6,'C','Kohlenstoff','12,011','nm',2,14],"
    echo "[7,'N','Stickstoff','14,007','nm',2,15],[8,'O','Sauerstoff','15,999','nm',2,16],"
    echo "[9,'F','Fluor','18,998','h',2,17],[10,'Ne','Neon','20,180','eg',2,18],"
    echo "[11,'Na','Natrium','22,990','am',3,1],[12,'Mg','Magnesium','24,305','em',3,2],"
    echo "[13,'Al','Aluminium','26,982','ptm',3,13],[14,'Si','Silicium','28,085','hm',3,14],"
    echo "[15,'P','Phosphor','30,974','nm',3,15],[16,'S','Schwefel','32,06','nm',3,16],"
    echo "[17,'Cl','Chlor','35,45','h',3,17],[18,'Ar','Argon','39,948','eg',3,18],"
    echo "[19,'K','Kalium','39,098','am',4,1],[20,'Ca','Calcium','40,078','em',4,2],"
    echo "[21,'Sc','Scandium','44,956','tm',4,3],[22,'Ti','Titan','47,867','tm',4,4],"
    echo "[23,'V','Vanadium','50,942','tm',4,5],[24,'Cr','Chrom','51,996','tm',4,6],"
    echo "[25,'Mn','Mangan','54,938','tm',4,7],[26,'Fe','Eisen','55,845','tm',4,8],"
    echo "[27,'Co','Cobalt','58,933','tm',4,9],[28,'Ni','Nickel','58,693','tm',4,10],"
    echo "[29,'Cu','Kupfer','63,546','tm',4,11],[30,'Zn','Zink','65,38','tm',4,12],"
    echo "[31,'Ga','Gallium','69,723','ptm',4,13],[32,'Ge','Germanium','72,630','hm',4,14],"
    echo "[33,'As','Arsen','74,922','hm',4,15],[34,'Se','Selen','78,971','nm',4,16],"
    echo "[35,'Br','Brom','79,904','h',4,17],[36,'Kr','Krypton','83,798','eg',4,18],"
    echo "[37,'Rb','Rubidium','85,468','am',5,1],[38,'Sr','Strontium','87,62','em',5,2],"
    echo "[39,'Y','Yttrium','88,906','tm',5,3],[40,'Zr','Zirconium','91,224','tm',5,4],"
    echo "[41,'Nb','Niob','92,906','tm',5,5],[42,'Mo','Molybdän','95,95','tm',5,6],"
    echo "[43,'Tc','Technetium','98','tm',5,7],[44,'Ru','Ruthenium','101,07','tm',5,8],"
    echo "[45,'Rh','Rhodium','102,906','tm',5,9],[46,'Pd','Palladium','106,42','tm',5,10],"
    echo "[47,'Ag','Silber','107,868','tm',5,11],[48,'Cd','Cadmium','112,414','tm',5,12],"
    echo "[49,'In','Indium','114,818','ptm',5,13],[50,'Sn','Zinn','118,710','ptm',5,14],"
    echo "[51,'Sb','Antimon','121,760','hm',5,15],[52,'Te','Tellur','127,60','hm',5,16],"
    echo "[53,'I','Iod','126,904','h',5,17],[54,'Xe','Xenon','131,293','eg',5,18],"
    echo "[55,'Cs','Caesium','132,905','am',6,1],[56,'Ba','Barium','137,327','em',6,2],"
    echo "[57,'La','Lanthan','138,905','la',8,3],[58,'Ce','Cer','140,116','la',8,4],"
    echo "[59,'Pr','Praseodym','140,908','la',8,5],[60,'Nd','Neodym','144,242','la',8,6],"
    echo "[61,'Pm','Promethium','145','la',8,7],[62,'Sm','Samarium','150,36','la',8,8],"
    echo "[63,'Eu','Europium','151,964','la',8,9],[64,'Gd','Gadolinium','157,25','la',8,10],"
    echo "[65,'Tb','Terbium','158,925','la',8,11],[66,'Dy','Dysprosium','162,500','la',8,12],"
    echo "[67,'Ho','Holmium','164,930','la',8,13],[68,'Er','Erbium','167,259','la',8,14],"
    echo "[69,'Tm','Thulium','168,934','la',8,15],[70,'Yb','Ytterbium','173,045','la',8,16],"
    echo "[71,'Lu','Lutetium','174,967','la',8,17],"
    echo "[72,'Hf','Hafnium','178,486','tm',6,4],[73,'Ta','Tantal','180,948','tm',6,5],"
    echo "[74,'W','Wolfram','183,84','tm',6,6],[75,'Re','Rhenium','186,207','tm',6,7],"
    echo "[76,'Os','Osmium','190,23','tm',6,8],[77,'Ir','Iridium','192,217','tm',6,9],"
    echo "[78,'Pt','Platin','195,084','tm',6,10],[79,'Au','Gold','196,967','tm',6,11],"
    echo "[80,'Hg','Quecksilber','200,592','tm',6,12],[81,'Tl','Thallium','204,38','ptm',6,13],"
    echo "[82,'Pb','Blei','207,2','ptm',6,14],[83,'Bi','Bismut','208,980','ptm',6,15],"
    echo "[84,'Po','Polonium','209','ptm',6,16],[85,'At','Astat','210','h',6,17],"
    echo "[86,'Rn','Radon','222','eg',6,18],"
    echo "[87,'Fr','Francium','223','am',7,1],[88,'Ra','Radium','226','em',7,2],"
    echo "[89,'Ac','Actinium','227','ac',9,3],[90,'Th','Thorium','232,038','ac',9,4],"
    echo "[91,'Pa','Protactinium','231,036','ac',9,5],[92,'U','Uran','238,029','ac',9,6],"
    echo "[93,'Np','Neptunium','237','ac',9,7],[94,'Pu','Plutonium','244','ac',9,8],"
    echo "[95,'Am','Americium','243','ac',9,9],[96,'Cm','Curium','247','ac',9,10],"
    echo "[97,'Bk','Berkelium','247','ac',9,11],[98,'Cf','Californium','251','ac',9,12],"
    echo "[99,'Es','Einsteinium','252','ac',9,13],[100,'Fm','Fermium','257','ac',9,14],"
    echo "[101,'Md','Mendelevium','258','ac',9,15],[102,'No','Nobelium','259','ac',9,16],"
    echo "[103,'Lr','Lawrencium','266','ac',9,17],"
    echo "[104,'Rf','Rutherfordium','267','tm',7,4],[105,'Db','Dubnium','268','tm',7,5],"
    echo "[106,'Sg','Seaborgium','269','tm',7,6],[107,'Bh','Bohrium','270','tm',7,7],"
    echo "[108,'Hs','Hassium','270','tm',7,8],[109,'Mt','Meitnerium','278','tm',7,9],"
    echo "[110,'Ds','Darmstadtium','281','tm',7,10],[111,'Rg','Roentgenium','282','tm',7,11],"
    echo "[112,'Cn','Copernicium','285','tm',7,12],[113,'Nh','Nihonium','286','ptm',7,13],"
    echo "[114,'Fl','Flerovium','289','ptm',7,14],[115,'Mc','Moscovium','289','ptm',7,15],"
    echo "[116,'Lv','Livermorium','293','ptm',7,16],[117,'Ts','Tenness','294','h',7,17],"
    echo "[118,'Og','Oganesson','294','eg',7,18]"
    echo '];'
    
    # Kategorien definieren
    echo 'const CAT = {'
    echo "  am:'Alkalimetall', em:'Erdalkalimetall', tm:'Übergangsmetall',"
    echo "  ptm:'Metall (Hauptgr.)', hm:'Halbmetall', nm:'Nichtmetall',"
    echo "  h:'Halogen', eg:'Edelgas', la:'Lanthanoid', ac:'Actinoid'"
    echo '};'
    
    echo 'const CATPL = {'
    echo "  am:'Alkalimetalle', em:'Erdalkalimetalle', tm:'Übergangsmetalle',"
    echo "  ptm:'Metalle (Hauptgr.)', hm:'Halbmetalle', nm:'Nichtmetalle',"
    echo "  h:'Halogene', eg:'Edelgase', la:'Lanthanoide', ac:'Actinoide'"
    echo '};'
    
    # Funktionen definieren
    echo 'function showDetail(el) {'
    echo '  const [z, sym, name, mass, cat, row, col] = el;'
    echo '  const period = row >= 8 ? (row === 8 ? 6 : 7) : row;'
    echo '  const group = row >= 8 ? '\''f-Block'\'' : col;'
    echo '  document.getElementById('\''detail'\'').innerHTML = `'
    echo '    <div class="symbol-box cat-${cat}">${sym}</div>'
    echo '    <div style="flex:1;min-width:0">'
    echo '      <div class="info-name">${name}</div>'
    echo '      <div class="info-meta">'
    echo '        <span>Ordnungszahl:<b>${z}</b></span>'
    echo '        <span>Atommasse:<b>${mass} u</b></span>'
    echo '        <span>Periode:<b>${period}</b></span>'
    echo '        <span>Gruppe:<b>${group}</b></span>'
    echo '        <span style="grid-column:1/-1">Kategorie:<b>${CAT[cat]}</b></span>'
    echo '      </div>'
    echo '    </div>`;'
    echo '  document.querySelectorAll('\''\.cell\.active'\'').forEach(c => c.classList.remove('\''active'\''));'
    echo '  const cell = document.querySelector(`[data-z="${z}"]`);'
    echo '  if (cell) cell.classList.add('\''active'\'');'
    echo '}'
    
    echo 'function makeCell(el) {'
    echo '  const [z, sym, name, mass, cat, row, col] = el;'
    echo '  const c = document.createElement('\''button'\'');'
    echo '  c.className = `cell cat-${cat}`;'
    echo '  c.style.gridColumn = col;'
    echo '  c.style.gridRow = row >= 8 ? row - 7 : row;'
    echo '  c.dataset.z = z;'
    echo '  c.title = `${name} (${sym})`;'
    echo '  c.innerHTML = `<span class="num">${z}</span><span class="sym">${sym}</span>`;'
    echo '  c.onclick = () => showDetail(el);'
    echo '  return c;'
    echo '}'
    
    # Hauptlogik
    echo 'const main = document.getElementById('\''main'\'');'
    echo 'const fblock = document.getElementById('\''fblock'\'');'
    echo '[[6, '\''la'\'', '\''57-71'\''], [7, '\''ac'\'', '\''89-103'\'']].forEach(([r, cat, txt]) => {'
    echo '  const m = document.createElement('\''div'\'');'
    echo '  m.className = `cell cell-marker cat-${cat}`;'
    echo '  m.style.gridColumn = 3;'
    echo '  m.style.gridRow = r;'
    echo '  m.textContent = txt;'
    echo '  main.appendChild(m);'
    echo '});'
    
    echo 'E.forEach(el => {'
    echo '  const c = makeCell(el);'
    echo '  if (el[5] >= 8) fblock.appendChild(c);'
    echo '  else main.appendChild(c);'
    echo '});'
    
    echo 'const legend = document.getElementById('\''legend'\'');'
    echo 'Object.entries(CATPL).forEach(([k, v]) => {'
    echo '  const item = document.createElement('\''div'\'');'
    echo '  item.className = '\''legend-item'\'';'
    echo '  item.innerHTML = `<span class="legend-swatch cat-${k}"></span><span>${v}</span>`;'
    echo '  legend.appendChild(item);'
    echo '});'
    
    echo '</script>'
    echo '</body>'
    echo '</html>'
} >> "$output_file"

echo "HTML-Datei wurde erfolgreich erstellt: $output_file"
