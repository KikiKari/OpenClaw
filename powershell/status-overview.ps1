#!/usr/bin/env pwsh
# status-overview.css — portiert nach powershell
# Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview.css
# Erzeugt: 2026-11-01 durch ABSTRACTIONS_MANAGER.py

param(
    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

# Funktion zum Erstellen eines CSS-Regelobjekts
function New-CssRule {
    param(
        [string]$Selector,
        [hashtable]$Properties
    )
    return @{
        Selector = $Selector
        Properties = $Properties
    }
}

# Funktion zum Konvertieren eines CSS-Regelobjekts in einen String
function Convert-CssRuleToString {
    param(
        [hashtable]$Rule
    )
    $properties = ($Rule.Properties.GetEnumerator() | ForEach-Object {
        "$($_.Key):$($_.Value)"
    }) -join ';'
    return "$($Rule.Selector){$properties}"
}

# Erstellen der CSS-Regeln
$cssRules = @()

# Universelle Regel
$cssRules += New-CssRule -Selector "*" -Properties @{
    "box-sizing" = "border-box"
}

# HTML und Body Regeln
$cssRules += New-CssRule -Selector "html,body" -Properties @{
    "margin" = "0"
    "min-height" = "100%"
    "background" = "#101015"
    "color" = "#fff"
    "font" = "14px system-ui,sans-serif"
}

# Body spezifische Regeln
$cssRules += New-CssRule -Selector "body" -Properties @{
    "display" = "flex"
    "flex-direction" = "column"
    "height" = "100vh"
}

# Header Regeln
$cssRules += New-CssRule -Selector "header" -Properties @{
    "display" = "flex"
    "gap" = "1em"
    "align-items" = "baseline"
    "padding" = "0 12px"
}

# Überschrift im Header
$cssRules += New-CssRule -Selector "h1" -Properties @{
    "font-size" = "17px"
    "margin" = "8px 0"
}

# Absatz im Header
$cssRules += New-CssRule -Selector "header p" -Properties @{
    "font-size" = "12px"
    "color" = "#bbb"
    "margin" = "0"
}

# Hauptbereich
$cssRules += New-CssRule -Selector "main" -Properties @{
    "flex" = "1"
    "min-height" = "0"
    "display" = "grid"
    "grid-template-columns" = "repeat(3,minmax(0,1fr))"
    "grid-template-rows" = "repeat(3,minmax(0,1fr))"
    "gap" = "4px"
    "padding" = "0"
}

# Kachel-Stil
$cssRules += New-CssRule -Selector ".tile" -Properties @{
    "min-width" = "0"
    "min-height" = "0"
    "display" = "flex"
    "flex-direction" = "column"
    "background" = "#202026"
    "border" = "1px solid #393940"
}

# Überschrift in Kachel
$cssRules += New-CssRule -Selector ".tile h2" -Properties @{
    "font-size" = "13px"
    "margin" = "3px 8px"
}

# Video in Kachel
$cssRules += New-CssRule -Selector ".tile video" -Properties @{
    "min-height" = "0"
    "width" = "100%"
    "flex" = "1"
    "object-fit" = "contain"
    "background" = "#000"
}

# Absatz in Kachel
$cssRules += New-CssRule -Selector ".tile p" -Properties @{
    "font-size" = "11px"
    "margin" = "3px 8px"
    "color" = "#ddd"
}

# Alternative Grid-Konfiguration
$cssRules += New-CssRule -Selector "main.grid2" -Properties @{
    "grid-template-columns" = "repeat(2,minmax(0,1fr))"
    "grid-template-rows" = "repeat(2,minmax(0,1fr))"
}

# Versteckte Kachel
$cssRules += New-CssRule -Selector ".tile[hidden]" -Properties @{
    "display" = "none"
}

# Generiere den CSS-Inhalt
$cssContent = ($cssRules | ForEach-Object { Convert-CssRuleToString -Rule $_ }) -join ""

# Schreibe den Inhalt in die angegebene Datei
Set-Content -Path $OutputPath -Value $cssContent -Encoding UTF8
