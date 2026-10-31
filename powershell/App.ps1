#!/usr/bin/env pwsh
# App.css — portiert nach powershell
# Quelle: css, OpenClaw@main:src/App.css
# Erzeugt: 2026-10-31 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Generates the App.css content dynamically and writes it to a file.

.DESCRIPTION
This script generates CSS content equivalent to the original App.css file
and outputs it to a specified file path passed as a parameter.

.PARAMETER OutputPath
The file path where the generated CSS will be saved.

.EXAMPLE
.\Generate-AppCss.ps1 -OutputPath "App.css"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

# Define CSS rules as objects for structured generation
$cssRules = @(
    @{
        selector = ":root"
        properties = @{
            "color-scheme" = "dark"
            "font-family" = "Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, `"Segoe UI`", sans-serif"
            "background" = "#0b1020"
            "color" = "#eef2ff"
        }
    },
    @{
        selector = "*"
        properties = @{
            "box-sizing" = "border-box"
        }
    },
    @{
        selector = "body"
        properties = @{
            "margin" = "0"
            "min-width" = "320px"
            "min-height" = "100vh"
            "background" = @"
radial-gradient(circle at 20% 20%, rgba(56, 189, 248, 0.22), transparent 30rem),
    radial-gradient(circle at 80% 10%, rgba(168, 85, 247, 0.2), transparent 28rem),
    linear-gradient(135deg, #050816 0%, #111827 55%, #172033 100%)
"@
        }
    },
    @{
        selector = ".page-shell"
        properties = @{
            "min-height" = "100vh"
            "display" = "grid"
            "place-items" = "center"
            "padding" = "2rem"
        }
    },
    @{
        selector = ".hero-card"
        properties = @{
            "width" = "min(100%, 56rem)"
            "padding" = "clamp(2rem, 6vw, 4.5rem)"
            "border" = "1px solid rgba(148, 163, 184, 0.28)"
            "border-radius" = "2rem"
            "background" = "rgba(15, 23, 42, 0.72)"
            "box-shadow" = "0 2rem 6rem rgba(0, 0, 0, 0.35)"
            "backdrop-filter" = "blur(18px)"
        }
    },
    @{
        selector = ".eyebrow"
        properties = @{
            "margin" = "0 0 1rem"
            "color" = "#67e8f9"
            "font-size" = "0.8rem"
            "font-weight" = "700"
            "letter-spacing" = "0.18em"
            "text-transform" = "uppercase"
        }
    },
    @{
        selector = "h1"
        properties = @{
            "margin" = "0"
            "max-width" = "12ch"
            "font-size" = "clamp(2.75rem, 8vw, 6rem)"
            "line-height" = "0.95"
            "letter-spacing" = "-0.06em"
        }
    },
    @{
        selector = ".lead"
        properties = @{
            "margin" = "1.5rem 0 0"
            "max-width" = "42rem"
            "color" = "#cbd5e1"
            "font-size" = "clamp(1.05rem, 2vw, 1.35rem)"
            "line-height" = "1.65"
        }
    },
    @{
        selector = ".link-grid"
        properties = @{
            "display" = "grid"
            "gap" = "0.85rem"
            "margin-top" = "2rem"
        }
    },
    @{
        selector = ".link-grid a"
        properties = @{
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
    },
    @{
        selector = ".link-grid a:hover, .link-grid a:focus-visible"
        properties = @{
            "border-color" = "rgba(103, 232, 249, 0.75)"
            "outline" = "none"
            "background" = "rgba(103, 232, 249, 0.12)"
        }
    }
)

# Function to convert property dictionary to CSS string
function ConvertTo-CssDeclaration($properties) {
    $declarations = foreach ($key in $properties.Keys) {
        "  $($key): $($properties[$key]);"
    }
    return $declarations -join "`n"
}

# Generate CSS content
$cssContent = ""
foreach ($rule in $cssRules) {
    $declarations = ConvertTo-CssDeclaration -properties $rule.properties
    $cssContent += "$($rule.selector) {`n$declarations`n}`n`n"
}

# Write to file
Set-Content -Path $OutputPath -Value $cssContent.TrimEnd() -Encoding UTF8

Write-Host "CSS content successfully written to $OutputPath"
