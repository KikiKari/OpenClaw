#!/usr/bin/env pwsh
# App.css — portiert nach powershell
# Quelle: css, OpenClaw@main:src/App.css
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

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
        "  $($_.Key): $($_.Value);"
    }) -join "`n"
    
    return "$($Rule.Selector) {`n$properties`n}"
}

# Erstellen der CSS-Regeln als Objekte
$cssRules = @(
    New-CssRule -Selector ":root" -Properties @{
        "color-scheme" = "dark"
        "font-family" = "Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, `"Segoe UI`", sans-serif"
        "background" = "#0b1020"
        "color" = "#eef2ff"
    }

    New-CssRule -Selector "*" -Properties @{
        "box-sizing" = "border-box"
    }

    New-CssRule -Selector "body" -Properties @{
        "margin" = "0"
        "min-width" = "320px"
        "min-height" = "100vh"
        "background" = "radial-gradient(circle at 20% 20%, rgba(56, 189, 248, 0.22), transparent 30rem), radial-gradient(circle at 80% 10%, rgba(168, 85, 247, 0.2), transparent 28rem), linear-gradient(135deg, #050816 0%, #111827 55%, #172033 100%)"
    }

    New-CssRule -Selector ".page-shell" -Properties @{
        "min-height" = "100vh"
        "display" = "grid"
        "place-items" = "center"
        "padding" = "2rem"
    }

    New-CssRule -Selector ".hero-card" -Properties @{
        "width" = "min(100%, 56rem)"
        "padding" = "clamp(2rem, 6vw, 4.5rem)"
        "border" = "1px solid rgba(148, 163, 184, 0.28)"
        "border-radius" = "2rem"
        "background" = "rgba(15, 23, 42, 0.72)"
        "box-shadow" = "0 2rem 6rem rgba(0, 0, 0, 0.35)"
        "backdrop-filter" = "blur(18px)"
    }

    New-CssRule -Selector ".eyebrow" -Properties @{
        "margin" = "0 0 1rem"
        "color" = "#67e8f9"
        "font-size" = "0.8rem"
        "font-weight" = "700"
        "letter-spacing" = "0.18em"
        "text-transform" = "uppercase"
    }

    New-CssRule -Selector "h1" -Properties @{
        "margin" = "0"
        "max-width" = "12ch"
        "font-size" = "clamp(2.75rem, 8vw, 6rem)"
        "line-height" = "0.95"
        "letter-spacing" = "-0.06em"
    }

    New-CssRule -Selector ".lead" -Properties @{
        "margin" = "1.5rem 0 0"
        "max-width" = "42rem"
        "color" = "#cbd5e1"
        "font-size" = "clamp(1.05rem, 2vw, 1.35rem)"
        "line-height" = "1.65"
    }

    New-CssRule -Selector ".link-grid" -Properties @{
        "display" = "grid"
        "gap" = "0.85rem"
        "margin-top" = "2rem"
    }

    New-CssRule -Selector ".link-grid a" -Properties @{
        "display" = "flex"
        "align-items" = "center"
        "justify-content" = "space-between"
        "gap" = "1rem"
        "padding" = "1rem 1.15rem"
        "border" = "1px solid rgba(148, 163, 184, 0.25)"
        "border-radius" = "1rem"
        "color" = "#f8fafc"
        "text-decoration" = "none"
        "background" = "rgba(255, 255, 255, 0.06)"
    }

    New-CssRule -Selector ".link-grid a:hover, .link-grid a:focus-visible" -Properties @{
        "border-color" = "rgba(103, 232, 249, 0.75)"
        "outline" = "none"
        "background" = "rgba(103, 232, 249, 0.12)"
    }
)

# Konvertiere alle Regeln in einen CSS-String
$cssContent = ($cssRules | ForEach-Object { Convert-CssRuleToString -Rule $_ }) -join "`n`n"

# Schreibe den Inhalt in die Ausgabedatei
$cssContent | Out-File -FilePath $OutputPath -Encoding UTF8

Write-Host "CSS file successfully written to $OutputPath"
