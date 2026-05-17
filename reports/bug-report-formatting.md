# BUG REPORT — Darstellungsfehler

(aktualisiert am 2026-04-10)

**Datum:** 2026-04-09  
**Gemeldet von:** User  
**Status:** BESTÄTIGT

---

## FEHLER BESCHREIBUNG

Die Ausgabe von technischen Befehlen wird nicht in der gewünschten Struktur dargestellt.

---

## IST-ZUSTAND (Falsch)

```
Node 1 (Gateway)
Benutzer: root → openclaw

chown openclaw:openclaw /home/openclaw/.config/openclaw/pws && chmod 400 /home/openclaw/.config/openclaw/pws
```

**Probleme:**
- Node und Benutzer in einer Zeile vermischt
- Pfeil-Notation statt klaren Labels
- Keine visuelle Trennung zwischen Metadaten und Befehl
- Kein "Copy"-Button/Indikator

---

## SOLL-ZUSTAND (Richtig)

```
NODE 1
Benutzer: openclaw

[Copy]
openclaw chmod 400 /home/openclaw/.config/openclaw/pws
```

**Erforderliche Struktur:**
1. **NODE** (Gross, als Überschrift)
2. **Benutzer:** (Label + Wert in separater Zeile)
3. **[Copy]** (Button/Indikator)
4. **Befehl** (In Codebox, mit Benutzer-Prefix)

---

## BEISPIELE FÜR RICHTIGE FORMATIERUNG

### Beispiel 1:
```
NODE 1
Benutzer: openclaw

[Copy]
openclaw chmod 400 /home/openclaw/.config/openclaw/pws
```

### Beispiel 2:
```
NODE 1
Benutzer: openclaw

[Copy]
openclaw chmod 400 /home/openclaw/.config/openclaw/sud
```

### Beispiel 3:
```
NODE 1
Benutzer: openclaw

[Copy]
openclaw chmod 444 /home/openclaw/.ssh/config
```

---

## ANFORDERUNGEN

### Jede technische Ausgabe MUSS enthalten:

1. **NODE X** als Überschrift (gross, fett wenn möglich)
2. **Benutzer:** in separater Zeile nach der Node-Angabe
3. **[Copy]** als visueller Indikator (wenn möglich)
4. **Befehl** in klarer Code-Darstellung
5. **Keine Vermischung** von Node-Info und Benutzer-Info

---

## FEHLVERHALTEN DES SYSTEMS

Das System (Artii) liefert:
- Vermischte Informationen
- Unklare Hierarchien
- Fehlende visuelle Trennung
- Falsche Syntax-Beispiele

---

## KORREKTURMASSNAHMEN

### Sofort umzusetzen:

1. **Struktur einhalten:**
   ```
   NODE [Nummer]
   Benutzer: [Username]
   
   [Copy]
   [Befehl]
   ```

2. **Keine Alternativen** anbieten wenn klare Vorgabe existiert

3. **Keine Erklärungen** zusätzlich zur Formatierung

4. **Nur das Gewünschte** ausgeben, nichts anderes

---

## TESTFALL

**Eingabe:** "Syntax für chmod 400 auf pws Datei"

**Erwartete Ausgabe:**
```
NODE 1
Benutzer: openclaw

[Copy]
openclaw chmod 400 /home/openclaw/.config/openclaw/pws
```

**Tatsächliche Ausgabe (falsch):**
```
Node 1 (Gateway)
Benutzer: root → openclaw

chown openclaw:openclaw /home/openclaw/.config/openclaw/pws && chmod 400 /home/openclaw/.config/openclaw/pws
```

---

## SCHLUSSFOLGERUNG

Das System muss:
- Weniger reden
- Klare Struktur einhalten
- Exakt das liefern was verlangt wird
- Keine eigenen Interpretationen hinzufügen

**Priorität:** KRITISCH  
**Auswirkung:** User-Frustration, Zeitverlust, Fehlfunktionen  

---

**Erstellt:** 2026-04-09  
**Status:** Offen — Korrektur ausstehend
