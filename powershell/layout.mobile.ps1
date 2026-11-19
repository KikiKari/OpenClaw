#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "72ae0455dedb25b39b553070b08d5aba0b158887600a2610439d90659be24a68", "source_sha256": "5712dd46fb92b3dc310552cb9baf6971767b66e882a9cb77625ed4ead9a18a79", "target_language": "powershell"}
# layout.mobile.css — portiert nach powershell
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/layout.mobile.css
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Generates CSS content for mobile layouts as a PowerShell script output.

.DESCRIPTION
This script dynamically constructs the contents of a CSS file based on structured data,
then writes it to a specified output file. It mimics the structure and media queries
from the original CSS but represents them through PowerShell logic.

.PARAMETER OutputPath
The path where the generated CSS will be saved.

.EXAMPLE
.\Generate-MobileLayout.ps1 -OutputPath "layout.mobile.css"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

# Helper function to generate CSS rule blocks
function New-CssRule {
    param (
        [string[]]$Selectors,
        [hashtable]$Properties
    )
    $selectorString = ($Selectors | ForEach-Object { "  $_" }) -join ",`n"
    $propertyLines = $Properties.GetEnumerator() | ForEach-Object {
        "    $($_.Key): $($_.Value);"
    } | Sort-Object
    return "$selectorString {`n$($propertyLines -join "`n")`n  }"
}

# Main CSS generation logic
$cssContent = @()

# Header comment
$cssContent += "/* ===========================================`n   Mobile Layout`n   =========================================== */"

# Media Query: max-width 1100px
$cssContent += "@media (max-width: 1100px) {"

# Rules for shell and nav collapsing
$shellRules = @(
    @{
        Selectors = @(".shell", ".shell--nav-collapsed")
        Properties = @{
            "grid-template-columns" = "minmax(0, 1fr)"
            "grid-template-rows" = "var(--shell-topbar-height) minmax(0, 1fr)"
            "grid-template-areas" = '"topbar" "content"'
        }
    },
    @{
        Selectors = @(".shell--chat-focus")
        Properties = @{
            "grid-template-rows" = "var(--shell-topbar-height) minmax(0, 1fr)"
        }
    },
    @{
        Selectors = @(".shell-nav", ".shell--nav-collapsed .shell-nav")
        Properties = @{
            "position" = "fixed"
            "top" = "0"
            "bottom" = "0"
            "left" = "0"
            "z-index" = "70"
            "width" = "min(86vw, 320px)"
            "min-width" = "0"
            "border-right" = "none"
            "box-shadow" = "0 30px 80px color-mix(in srgb, black 40%, transparent)"
            "transform" = "translateX(-100%)"
            "opacity" = "0"
            "pointer-events" = "none"
            "transition" = "transform var(--shell-focus-duration) var(--shell-focus-ease), opacity var(--shell-focus-duration) var(--shell-focus-ease)"
        }
    },
    @{
        Selectors = @(".shell--nav-collapsed:not(.shell--nav-drawer-open) .shell-nav")
        Properties = @{
            "width" = "var(--shell-nav-rail-width)"
            "transform" = "translateX(0)"
            "opacity" = "1"
            "pointer-events" = "auto"
            "box-shadow" = "none"
        }
    },
    @{
        Selectors = @(".shell--nav-drawer-open .shell-nav", ".shell--nav-collapsed.shell--nav-drawer-open .shell-nav")
        Properties = @{
            "transform" = "translateX(0)"
            "opacity" = "1"
            "pointer-events" = "auto"
        }
    },
    @{
        Selectors = @(".shell-nav-backdrop")
        Properties = @{
            "display" = "block"
            "position" = "fixed"
            "inset" = "0"
            "z-index" = "65"
            "border" = "0"
            "background" = "color-mix(in srgb, black 52%, transparent)"
            "opacity" = "0"
            "pointer-events" = "none"
            "transition" = "opacity var(--shell-focus-duration) var(--shell-focus-ease)"
        }
    },
    @{
        Selectors = @(".shell--nav-drawer-open .shell-nav-backdrop")
        Properties = @{
            "opacity" = "1"
            "pointer-events" = "auto"
        }
    },
    @{
        Selectors = @(".topbar-nav-toggle")
        Properties = @{
            "display" = "inline-flex"
            "align-items" = "center"
            "justify-content" = "center"
            "width" = "38px"
            "height" = "38px"
            "padding" = "0"
            "border" = "1px solid color-mix(in srgb, var(--border) 84%, transparent)"
            "border-radius" = "var(--radius-full)"
            "background" = "color-mix(in srgb, var(--bg-elevated) 80%, transparent)"
            "color" = "var(--muted)"
            "box-shadow" = "inset 0 1px 0 color-mix(in srgb, white 8%, transparent)"
        }
    },
    @{
        Selectors = @(".sidebar", ".sidebar--collapsed")
        Properties = @{
            "width" = "100%"
            "min-width" = "0"
            "flex" = "1 1 auto"
            "flex-direction" = "column"
            "align-items" = "stretch"
            "border-right" = "none"
        }
    },
    @{
        Selectors = @(".sidebar-shell", ".sidebar--collapsed .sidebar-shell")
        Properties = @{
            "padding" = "18px 16px 14px"
            "border-radius" = "0"
        }
    },
    @{
        Selectors = @(".shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar-shell", ".shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar--collapsed .sidebar-shell")
        Properties = @{
            "padding" = "12px 8px 10px"
        }
    },
    @{
        Selectors = @(".sidebar-shell__header")
        Properties = @{
            "min-height" = "0"
            "padding" = "0 4px 16px"
        }
    },
    @{
        Selectors = @(".sidebar-shell__header .nav-collapse-toggle")
        Properties = @{
            "display" = "none"
        }
    },
    @{
        Selectors = @(".shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar-shell__header")
        Properties = @{
            "justify-content" = "center"
            "align-items" = "center"
            "gap" = "0"
            "padding" = "0 2px 16px"
        }
    },
    @{
        Selectors = @(".sidebar-nav", ".sidebar--collapsed .sidebar-nav")
        Properties = @{
            "flex" = "1 1 auto"
            "display" = "block"
            "padding" = "0"
            "overflow-x" = "hidden"
            "overflow-y" = "auto"
            "scrollbar-width" = "none"
        }
    },
    @{
        Selectors = @(".sidebar-nav::-webkit-scrollbar", ".sidebar--collapsed .sidebar-nav::-webkit-scrollbar")
        Properties = @{
            "display" = "none"
        }
    },
    @{
        Selectors = @(".nav-section", ".sidebar--collapsed .nav-section")
        Properties = @{
            "display" = "grid"
            "margin-bottom" = "16px"
        }
    },
    @{
        Selectors = @(".sidebar-nav .nav-section__label", ".sidebar--collapsed .nav-section__label")
        Properties = @{
            "display" = "flex"
        }
    },
    @{
        Selectors = @(".nav-item", ".sidebar--collapsed .nav-item")
        Properties = @{
            "margin" = "0"
            "min-height" = "40px"
            "padding" = "0 12px"
            "font-size" = "13px"
            "border-radius" = "var(--radius-md)"
            "white-space" = "nowrap"
            "flex" = "0 0 auto"
            "width" = "auto"
        }
    },
    @{
        Selectors = @(".shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar--collapsed .nav-item")
        Properties = @{
            "justify-content" = "center"
            "width" = "44px"
            "min-height" = "44px"
            "padding" = "0"
            "margin" = "0 auto"
            "border-radius" = "var(--radius-lg)"
        }
    },
    @{
        Selectors = @(".sidebar--collapsed .nav-item--active::before", ".sidebar--collapsed .nav-item.active::before")
        Properties = @{
            "content" = "none"
        }
    },
    @{
        Selectors = @(".sidebar--collapsed .nav-item__text", ".sidebar--collapsed .nav-item__external-icon")
        Properties = @{
            "display" = "inline-flex"
        }
    },
    @{
        Selectors = @(".shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar--collapsed .nav-item__text", ".shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar--collapsed .nav-item__external-icon")
        Properties = @{
            "display" = "none"
        }
    },
    @{
        Selectors = @(".shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar--collapsed .nav-item--active::before", ".shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar--collapsed .nav-item.active::before")
        Properties = @{
            "content" = '""'
            "position" = "absolute"
            "left" = "8px"
            "top" = "10px"
            "bottom" = "10px"
            "width" = "3px"
            "border-radius" = "var(--radius-full)"
            "background" = "color-mix(in srgb, var(--accent) 86%, transparent)"
            "box-shadow" = "0 0 14px color-mix(in srgb, var(--accent) 34%, transparent)"
        }
    },
    @{
        Selectors = @(".sidebar--collapsed .sidebar-shell__footer")
        Properties = @{
            "padding" = "12px 8px 0"
        }
    },
    @{
        Selectors = @(".sidebar--collapsed .sidebar-version")
        Properties = @{
            "width" = "auto"
            "min-height" = "40px"
            "padding" = "0 12px"
        }
    },
    @{
        Selectors = @(".shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar--collapsed .sidebar-shell__footer")
        Properties = @{
            "padding" = "8px 0 2px"
        }
    },
    @{
        Selectors = @(".shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar--collapsed .sidebar-version")
        Properties = @{
            "width" = "44px"
            "min-height" = "44px"
            "padding" = "0"
            "justify-content" = "center"
        }
    },
    @{
        Selectors = @(".shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar-mode-switch")
        Properties = @{
            "display" = "none"
        }
    }
)
foreach ($rule in $shellRules) {
    $cssContent += New-CssRule -Selectors $rule.Selectors -Properties $rule.Properties
}

$cssContent += "}"

# Media Query: max-width 768px
$cssContent += "@media (max-width: 768px) {"

$tabletRules = @(
    @{
        Selectors = @(":root")
        Properties = @{
            "--shell-pad" = "8px"
            "--shell-gap" = "8px"
        }
    },
    @{
        Selectors = @(".topbar")
        Properties = @{
            "padding" = "10px 12px"
            "min-height" = "auto"
        }
    },
    @{
        Selectors = @(".topnav-shell")
        Properties = @{
            "flex-wrap" = "wrap"
            "gap" = "10px"
        }
    },
    @{
        Selectors = @(".topnav-shell__actions")
        Properties = @{
            "min-width" = "0"
            "flex" = "1 1 auto"
            "justify-content" = "space-between"
            "gap" = "10px"
            "align-items" = "stretch"
        }
    },
    @{
        Selectors = @(".topnav-shell__content")
        Properties = @{
            "display" = "none"
            "width" = "100%"
        }
    },
    @{
        Selectors = @(".topbar-nav-toggle")
        Properties = @{
            "display" = "inline-flex"
            "align-items" = "center"
            "justify-content" = "center"
            "flex-shrink" = "0"
            "width" = "38px"
            "height" = "38px"
            "padding" = "0"
            "border" = "1px solid color-mix(in srgb, var(--border) 84%, transparent)"
            "border-radius" = "var(--radius-full)"
            "background" = "color-mix(in srgb, var(--bg-elevated) 80%, transparent)"
            "color" = "var(--muted)"
            "box-shadow" = "inset 0 1px 0 color-mix(in srgb, white 8%, transparent)"
        }
    },
    @{
        Selectors = @(".topbar-status")
        Properties = @{
            "gap" = "6px"
            "width" = "auto"
            "flex-wrap" = "nowrap"
        }
    },
    @{
        Selectors = @(".topbar-search")
        Properties = @{
            "min-width" = "0"
            "flex" = "1"
        }
    },
    @{
        Selectors = @(".topbar-theme-mode")
        Properties = @{
            "display" = "none"
        }
    },
    @{
        Selectors = @(".sidebar-mode-switch")
        Properties = @{
            "display" = "block"
        }
    },
    @{
        Selectors = @(".sidebar-mode-switch .topbar-theme-mode")
        Properties = @{
            "display" = "inline-flex"
            "width" = "100%"
            "justify-content" = "center"
        }
    },
    @{
        Selectors = @(".topbar-status .pill")
        Properties = @{
            "padding" = "4px 8px"
            "font-size" = "11px"
            "gap" = "4px"
        }
    },
    @{
        Selectors = @(".topbar-status .pill .mono")
        Properties = @{
            "display" = "none"
        }
    },
    @{
        Selectors = @(".topbar-status .pill span:nth-child(2)")
        Properties = @{
            "display" = "none"
        }
    },
    @{
        Selectors = @(".shell-nav", ".shell--nav-collapsed .shell-nav")
        Properties = @{
            "width" = "min(92vw, 320px)"
        }
    },
    @{
        Selectors = @(".shell--nav-collapsed:not(.shell--nav-drawer-open) .shell-nav")
        Properties = @{
            "width" = "78px"
        }
    },
    @{
        Selectors = @(".sidebar-shell", ".sidebar--collapsed .sidebar-shell")
        Properties = @{
            "padding" = "16px 14px 12px"
        }
    },
    @{
        Selectors = @(".nav-item", ".sidebar--collapsed .nav-item")
        Properties = @{
            "font-size" = "12px"
        }
    },
    @{
        Selectors = @(".content-header")
        Properties = @{
            "display" = "none"
        }
    },
    @{
        Selectors = @(".content--chat .content-header")
        Properties = @{
            "display" = "none"
        }
    },
    @{
        Selectors = @(".content--chat")
        Properties = @{
            "gap" = "2px"
        }
    },
    @{
        Selectors = @(".chat-mobile-controls-wrapper")
        Properties = @{
            "display" = "flex"
            "position" = "relative"
        }
    },
    @{
        Selectors = @(".chat-mobile-controls-wrapper .chat-controls-mobile-toggle")
        Properties = @{
            "display" = "flex"
        }
    },
    @{
        Selectors = @(".chat-mobile-controls-wrapper .chat-controls-dropdown")
        Properties = @{
            "display" = "none"
            "position" = "absolute"
            "top" = "100%"
            "right" = "0"
            "z-index" = "100"
            "background" = "var(--card, #161b22)"
            "border" = "1px solid var(--border, #30363d)"
            "border-radius" = "var(--radius-md)"
            "padding" = "8px"
            "box-shadow" = "0 8px 24px rgba(0, 0, 0, 0.4)"
            "flex-direction" = "column"
            "gap" = "4px"
            "min-width" = "220px"
        }
    },
    @{
        Selectors = @(".chat-mobile-controls-wrapper .chat-controls-dropdown.open")
        Properties = @{
            "display" = "flex"
        }
    },
    @{
        Selectors = @(".chat-mobile-controls-wrapper .chat-controls-dropdown .chat-controls")
        Properties = @{
            "display" = "flex"
            "flex-direction" = "column"
            "gap" = "4px"
            "width" = "100%"
        }
    },
    @{
        Selectors = @(".chat-mobile-controls-wrapper .chat-controls-dropdown .chat-controls__session")
        Properties = @{
            "min-width" = "unset"
            "max-width" = "unset"
            "width" = "100%"
        }
    },
    @{
        Selectors = @(".chat-mobile-controls-wrapper .chat-controls-dropdown .chat-controls__session select")
        Properties = @{
            "width" = "100%"
            "font-size" = "14px"
            "padding" = "10px 12px"
        }
    },
    @{
        Selectors = @(".chat-mobile-controls-wrapper .chat-controls-dropdown .chat-controls__thinking")
        Properties = @{
            "display" = "flex"
            "flex-direction" = "row"
            "gap" = "6px"
            "padding" = "4px 0"
            "justify-content" = "center"
        }
    },
    @{
        Selectors = @(".chat-mobile-controls-wrapper .chat-controls-dropdown .btn--icon")
        Properties = @{
            "min-width" = "44px"
            "height" = "44px"
        }
    },
    @{
        Selectors = @(".content")
        Properties = @{
            "padding" = "4px 4px 16px"
            "gap" = "12px"
        }
    },
    @{
        Selectors = @(".card")
        Properties = @{
            "padding" = "12px"
            "border-radius" = "var(--radius-md)"
        }
    },
    @{
        Selectors = @(".card-title")
        Properties = @{
            "font-size" = "13px"
        }
    },
    @{
        Selectors = @(".stat-grid")
        Properties = @{
            "gap" = "8px"
            "grid-template-columns" = "repeat(2, 1fr)"
        }
    },
    @{
        Selectors = @(".stat")
        Properties = @{
            "padding" = "10px"
            "border-radius" = "var(--radius-md)"
        }
    },
    @{
        Selectors = @(".stat-label")
        Properties = @{
            "font-size" = "11px"
        }
    },
    @{
        Selectors = @(".stat-value")
        Properties = @{
            "font-size" = "18px"
        }
    },
    @{
        Selectors = @(".note-grid")
        Properties = @{
            "grid-template-columns" = "1fr"
            "gap" = "8px"
        }
    },
    @{
        Selectors = @(".form-grid")
        Properties = @{
            "grid-template-columns" = "1fr"
            "gap" = "10px"
        }
    },
    @{
        Selectors = @(".field input", ".field textarea", ".field select")
        Properties = @{
            "padding" = "8px 10px"
            "border-radius" = "var(--radius-md)"
            "font-size" = "14px"
        }
    },
    @{
        Selectors = @(".btn")
        Properties = @{
            "padding" = "8px 12px"
            "font-size" = "12px"
        }
    },
    @{
        Selectors = @(".pill")
        Properties = @{
            "padding" = "4px 10px"
            "font-size" = "12px"
        }
    },
    @{
        Selectors = @(".chat-header")
        Properties = @{
            "flex-direction" = "column"
            "align-items" = "stretch"
            "gap" = "8px"
        }
    },
    @{
        Selectors = @(".chat-header__left")
        Properties = @{
            "flex-direction" = "column"
            "align-items" = "stretch"
        }
    },
    @{
        Selectors = @(".chat-header__right")
        Properties = @{
            "justify-content" = "space-between"
        }
    },
    @{
        Selectors = @(".chat-session")
        Properties = @{
            "min-width" = "unset"
            "width" = "100%"
        }
    },
    @{
        Selectors = @(".chat-thread")
        Properties = @{
            "margin-top" = "0"
            "padding" = "0 8px 12px"
        }
    },
    @{
        Selectors = @(".chat-msg")
        Properties = @{
            "max-width" = "90%"
        }
    },
    @{
        Selectors = @(".chat-bubble")
        Properties = @{
            "padding" = "8px 12px"
            "border-radius" = "var(--radius-md)"
        }
    },
    @{
        Selectors = @(".chat-compose")
        Properties = @{
            "gap" = "8px"
        }
    },
    @{
        Selectors = @(".chat-compose__field textarea")
        Properties = @{
            "min-height" = "60px"
            "padding" = "8px 10px"
            "border-radius" = "var(--radius-md)"
            "font-size" = "14px"
        }
    },
    @{
        Selectors = @(".agent-chat__input")
        Properties = @{
            "margin" = "0 8px 10px"
        }
    },
    @{
        Selectors = @(".agent-chat__toolbar")
        Properties = @{
            "padding" = "4px 8px"
        }
    },
    @{
        Selectors = @(".agent-chat__input-btn", ".agent-chat__toolbar .btn--ghost")
        Properties = @{
            "width" = "28px"
            "height" = "28px"
        }
    },
    @{
        Selectors = @(".agent-chat__input-btn svg", ".agent-chat__toolbar .btn--ghost svg")
        Properties = @{
            "width" = "14px"
            "height" = "14px"
        }
    },
    @{
        Selectors = @(".log-stream")
        Properties = @{
            "border-radius" = "var(--radius-md)"
            "max-height" = "380px"
        }
    },
    @{
        Selectors = @(".log-row")
        Properties = @{
            "grid-template-columns" = "1fr"
            "gap" = "4px"
            "padding" = "8px"
        }
    },
    @{
        Selectors = @(".log-time")
        Properties = @{
            "font-size" = "10px"
        }
    },
    @{
        Selectors = @(".log-level")
        Properties = @{
            "font-size" = "9px"
        }
    },
    @{
        Selectors = @(".log-subsystem")
        Properties = @{
            "font-size" = "11px"
        }
    },
    @{
        Selectors = @(".log-message")
        Properties = @{
            "font-size" = "12px"
        }
    },
    @{
        Selectors = @(".list-item")
        Properties = @{
            "padding" = "10px"
            "border-radius" = "var(--radius-md)"
        }
    },
    @{
        Selectors = @(".list-title")
        Properties = @{
            "font-size" = "13px"
        }
    },
    @{
        Selectors = @(".list-sub")
        Properties = @{
            "font-size" = "11px"
        }
    },
    @{
        Selectors = @(".code-block")
        Properties = @{
            "padding" = "8px"
            "border-radius" = "var(--radius-md)"
            "font-size" = "11px"
        }
    },
    @{
        Selectors = @(".theme-orb__trigger")
        Properties = @{
            "width" = "26px"
            "height" = "26px"
            "font-size" = "13px"
        }
    }
)
foreach ($rule in $tabletRules) {
    $cssContent += New-CssRule -Selectors $rule.Selectors -Properties $rule.Properties
}

$cssContent += "}"

# Media Query: max-width 400px
$cssContent += "@media (max-width: 400px) {"

$smallMobileRules = @(
    @{
        Selectors = @(":root")
        Properties = @{
            "--shell-pad" = "4px"
        }
    },
    @{
        Selectors = @(".topbar")
        Properties = @{
            "padding" = "8px 10px"
        }
    },
    @{
        Selectors = @(".brand-title")
        Properties = @{
            "font-size" = "13px"
        }
    },
    @{
        Selectors = @(".nav-item")
        Properties = @{
            "padding" = "6px 8px"
            "font-size" = "11px"
        }
    },
    @{
        Selectors = @(".content")
        Properties = @{
            "padding" = "4px 4px 12px"
            "gap" = "10px"
        }
    },
    @{
        Selectors = @(".card")
        Properties = @{
            "padding" = "10px"
        }
    },
    @{
        Selectors = @(".stat")
        Properties = @{
            "padding" = "8px"
        }
    },
    @{
        Selectors = @(".stat-value")
        Properties = @{
            "font-size" = "16px"
        }
    },
    @{
        Selectors = @(".chat-bubble")
        Properties = @{
            "padding" = "8px 10px"
        }
    },
    @{
        Selectors = @(".chat-compose__field textarea")
        Properties = @{
            "min-height" = "52px"
            "padding" = "8px 10px"
            "font-size" = "13px"
        }
    },
    @{
        Selectors = @(".btn")
        Properties = @{
            "padding" = "6px 10px"
            "font-size" = "11px"
        }
    },
    @{
        Selectors = @(".topbar-status .pill")
        Properties = @{
            "padding" = "3px 6px"
            "font-size" = "10px"
        }
    },
    @{
        Selectors = @(".theme-orb__trigger")
        Properties = @{
            "width" = "24px"
            "height" = "24px"
            "font-size" = "12px"
        }
    }
)
foreach ($rule in $smallMobileRules) {
    $cssContent += New-CssRule -Selectors $rule.Selectors -Properties $rule.Properties
}

$cssContent += "}"

# Session Table Responsive Column Hiding
$cssContent += "/* ===========================================`n   Sessions table – responsive column hiding`n   =========================================== */"
$cssContent += "/* nth-child is 1-based and includes the checkbox column (col 1). */"

# Media Query: max-width 1400px
$cssContent += "@media (max-width: 1400px) {"
$cssContent += "  .data-table th:nth-child(9),`n  .data-table td:nth-child(9),`n  .data-table th:nth-child(10),`n  .data-table td:nth-child(10) {`n    display: none;`n  }"
$cssContent += "}"

# Media Query: max-width 1100px
$cssContent += "@media (max-width: 1100px) {"
$cssContent += "  .data-table th:nth-child(4),`n  .data-table td:nth-child(4),`n  .data-table th:nth-child(8),`n  .data-table td:nth-child(8) {`n    display: none;`n  }"
$cssContent += "  .data-table th,`n  .data-table td {`n    padding: 8px 10px;`n  }"
$cssContent += "}"

# Media Query: max-width 900px
$cssContent += "@media (max-width: 900px) {"
$cssContent += "  .data-table th:nth-child(3),`n  .data-table td:nth-child(3),`n  .data-table th:nth-child(7),`n  .data-table td:nth-child(7) {`n    display: none;`n  }"
$cssContent += "}"

# Media Query: max-width 768px
$cssContent += "@media (max-width: 768px) {"
$cssContent += "  .data-table th:nth-child(6),`n  .data-table td:nth-child(6) {`n    display: none;`n  }"
$cssContent += "  .data-table th,`n  .data-table td {`n    padding: 8px 6px;`n    font-size: 12px;`n  }"
$cssContent += "  .data-table-pagination {`n    flex-direction: column;`n    align-items: stretch;`n    gap: 8px;`n    padding: 10px 8px;`n  }"
$cssContent += "  .data-table-pagination__info {`n    text-align: center;`n  }"
$cssContent += "  .data-table-pagination__controls {`n    justify-content: center;`n  }"
$cssContent += "  .data-table-search input {`n    font-size: 14px;`n    padding: 8px 10px;`n  }"
$cssContent += "  .data-table-wrapper {`n    border-radius: var(--radius-sm);`n  }"
$cssContent += "  .session-key-cell {`n    max-width: 200px;`n  }"
$cssContent += "  .session-key-cell .session-link,`n  .session-key-cell .session-key-display-name {`n    overflow: hidden;`n    text-overflow: ellipsis;`n    white-space: nowrap;`n    overflow-wrap: normal;`n    word-break: normal;`n  }"
$cssContent += "  .filters {`n    flex-wrap: wrap;`n    gap: 8px;`n  }"
$cssContent += "}"

# Media Query: max-width 500px
$cssContent += "@media (max-width: 500px) {"
$cssContent += "  .data-table th,`n  .data-table td {`n    padding: 6px 4px;`n    font-size: 11px;`n  }"
$cssContent += "  .session-key-cell {`n    max-width: 140px;`n  }"
$cssContent += "}"

# Write final content to file
$fullContent = $cssContent -join "`n`n"
Set-Content -Path $OutputPath -Value $fullContent -Encoding Utf8

Write-Host "CSS file successfully written to $OutputPath"
