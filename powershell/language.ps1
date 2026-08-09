#!/usr/bin/env pwsh
# language.html — portiert nach powershell
# Quelle: html, OpenClaw@gateway1:skills/scripting-utils/references/raku/language.html
# auch in: OpenClaw@gateway2:skills/scripting-utils/references/raku/language.html
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Generates the 404 error page for the Raku documentation website.

.DESCRIPTION
This script generates an HTML document representing the 404 error page
for the Raku documentation website. It constructs the HTML structure
programmatically and writes it to a specified output file.

.PARAMETER OutputFile
The path to the output HTML file. If not provided, defaults to 'language.html'.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "language.html"
)

# Create the HTML document structure
$docType = "<!DOCTYPE html>"
$html = New-Object System.Xml.XmlDocument
$html.CreateXmlDeclaration("1.0", "UTF-8", $null) | Out-Null

# Create root html element with attributes
$htmlElement = $html.CreateElement("html")
$htmlElement.SetAttribute("lang", "en")
$htmlElement.SetAttribute("class", "fontawesome-i2svg-active fontawesome-i2svg-complete")
$htmlElement.SetAttribute("style", "scroll-padding-top:60px")
[void]$html.AppendChild($htmlElement)

# --- Head Section ---
$head = $html.CreateElement("head")
[void]$htmlElement.AppendChild($head)

# Title
$title = $html.CreateElement("title")
$title.InnerText = "404 | Raku Documentation"
[void]$head.AppendChild($title)

# Meta charset
$metaCharset = $html.CreateElement("meta")
$metaCharset.SetAttribute("charset", "UTF-8")
[void]$head.AppendChild($metaCharset)

# Links
$links = @(
    @{href="/assets/images/Camelia.ico"; rel="icon"; type="image/x-icon"},
    @{href="/assets/css/Website.css"; rel="stylesheet"},
    @{href="/assets/css/css/filtered-toc-dark.css"; rel="stylesheet"; title="dark"},
    @{href="/assets/css/css/filtered-toc-light.css"; rel="stylesheet"; title="light"},
    @{href="/assets/css/css/rainbow-dark.css"; rel="stylesheet"; title="dark"},
    @{href="/assets/css/css/rainbow-light.css"; rel="stylesheet"; title="light"},
    @{href="/assets/css/tm-styling.css"; rel="stylesheet"},
    @{href="/assets/css/tm-light.css"; rel="stylesheet"; title="light"},
    @{href="/assets/css/tm-dark.css"; rel="stylesheet"; title="dark"},
    @{href="/assets/css/all.min.css"; rel="stylesheet"},
    @{href="/assets/css/listf-styling-light.css"; rel="stylesheet"; title="light"},
    @{href="/assets/css/listf-styling-dark.css"; rel="stylesheet"; title="dark"},
    @{href="/assets/css/typegraph-styling.css"; rel="stylesheet"},
    @{href="/assets/css/typegraph-dark.css"; rel="stylesheet"; title="dark"},
    @{href="/assets/css/typegraph-light.css"; rel="stylesheet"; title="light"},
    @{href="/assets/css/css/page-styling-main.css"; rel="stylesheet"},
    @{href="/assets/css/css/page-styling-dark.css"; rel="stylesheet"; title="dark"},
    @{href="/assets/css/css/page-styling-light.css"; rel="stylesheet"; title="light"},
    @{href="/assets/css/css/chyronToggle-dark.css"; rel="stylesheet"; title="dark"},
    @{href="/assets/css/css/chyronToggle-light.css"; rel="stylesheet"; title="light"},
    @{href="/assets/css/css/centreToggle-dark.css"; rel="stylesheet"; title="dark"},
    @{href="/assets/css/css/centreToggle-light.css"; rel="stylesheet"; title="light"},
    @{href="/assets/css/css/options-search-light.css"; rel="stylesheet"; title="light"},
    @{href="/assets/css/css/options-search-dark.css"; rel="stylesheet"; title="dark"},
    @{href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-light.min.css"; rel="stylesheet"; title="light"},
    @{href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-dark.min.css"; rel="stylesheet"; title="dark"},
    @{href="https://cdn.jsdelivr.net/npm/@tarekraafat/autocomplete.js@10.2.7/dist/css/autoComplete.min.css"; rel="stylesheet"}
)

foreach ($linkData in $links) {
    $link = $html.CreateElement("link")
    foreach ($attr in $linkData.Keys) {
        $link.SetAttribute($attr, $linkData[$attr])
    }
    [void]$head.AppendChild($link)
}

# Scripts
$scripts = @(
    "https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js",
    "/assets/scripts/all.min.js",
    "/assets/scripts/tableManager.js",
    "/assets/scripts/filter-script.js",
    "https://cdn.jsdelivr.net/npm/fuzzysort@2.0.4/fuzzysort.min.js",
    "https://cdn.jsdelivr.net/npm/@tarekraafat/autocomplete.js@10.2.7/dist/autoComplete.min.js",
    "/assets/scripts/filtered-toc.js",
    "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js",
    "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/haskell.min.js",
    "/assets/scripts/options-search.js",
    "/assets/scripts/page-styling.js",
    "/assets/scripts/rainbow.js"
)

foreach ($src in $scripts) {
    $script = $html.CreateElement("script")
    $script.SetAttribute("src", $src)
    [void]$head.AppendChild($script)
}

# --- Body Section ---
$body = $html.CreateElement("body")
$body.SetAttribute("class", "has-navbar-fixed-top")
[void]$htmlElement.AppendChild($body)

# Top anchor
$topDiv = $html.CreateElement("div")
$topDiv.SetAttribute("id", "404")
$topDiv.SetAttribute("class", "top-of-page")
[void]$body.AppendChild($topDiv)

# Navbar
$nav = $html.CreateElement("nav")
$nav.SetAttribute("class", "navbar is-fixed-top is-flex-touch")
$nav.SetAttribute("role", "navigation")
$nav.SetAttribute("aria-label", "main navigation")
[void]$body.AppendChild($nav)

# Navbar item (left toggle)
$navItem = $html.CreateElement("div")
$navItem.SetAttribute("class", "navbar-item")
$navItem.SetAttribute("style", "margin-left: auto;")
[void]$nav.AppendChild($navItem)

$leftBarToggle = $html.CreateElement("div")
$leftBarToggle.SetAttribute("class", "left-bar-toggle")
$leftBarToggle.SetAttribute("title", "Toggle Table of Contents & Index")
[void]$navItem.AppendChild($leftBarToggle)

$chyronToggle = $html.CreateElement("label")
$chyronToggle.SetAttribute("class", "chyronToggle left")
[void]$leftBarToggle.AppendChild($chyronToggle)

$navInput = $html.CreateElement("input")
$navInput.SetAttribute("id", "navbar-left-toggle")
$navInput.SetAttribute("type", "checkbox")
[void]$chyronToggle.AppendChild($navInput)

$navSpan = $html.CreateElement("span")
$navSpan.SetAttribute("class", "text")
$navSpan.InnerText = "Contents"
[void]$chyronToggle.AppendChild($navSpan)

# Container
$container = $html.CreateElement("div")
$container.SetAttribute("class", "container is-justify-content-space-around")
[void]$nav.AppendChild($container)

# Navbar brand
$navbarBrand = $html.CreateElement("div")
$navbarBrand.SetAttribute("class", "navbar-brand")
[void]$container.AppendChild($navbarBrand)

$navbarLogo = $html.CreateElement("div")
$navbarLogo.SetAttribute("class", "navbar-logo")
[void]$navbarBrand.AppendChild($navbarLogo)

$logoLink = $html.CreateElement("a")
$logoLink.SetAttribute("class", "navbar-item")
$logoLink.SetAttribute("href", "/")
[void]$navbarLogo.AppendChild($logoLink)

$logoImg = $html.CreateElement("img")
$logoImg.SetAttribute("src", "/assets/images/camelia-recoloured.png")
$logoImg.SetAttribute("alt", "Raku")
$logoImg.SetAttribute("width", "52.83")
$logoImg.SetAttribute("height", "38")
[void]$logoLink.AppendChild($logoImg)

$logoSpan = $html.CreateElement("span")
$logoSpan.SetAttribute("class", "navbar-logo-tm")
$logoSpan.InnerText = "tm"
[void]$navbarLogo.AppendChild($logoSpan)

$burger = $html.CreateElement("a")
$burger.SetAttribute("role", "button")
$burger.SetAttribute("class", "navbar-burger burger")
$burger.SetAttribute("aria-label", "menu")
$burger.SetAttribute("aria-expanded", "false")
$burger.SetAttribute("data-target", "navMenu")
[void]$navbarBrand.AppendChild($burger)

$burgerSpans = 1..3 | ForEach-Object {
    $span = $html.CreateElement("span")
    $span.SetAttribute("aria-hidden", "true")
    [void]$burger.AppendChild($span)
}

# Navbar menu
$navMenu = $html.CreateElement("div")
$navMenu.SetAttribute("id", "navMenu")
$navMenu.SetAttribute("class", "navbar-menu")
[void]$container.AppendChild($navMenu)

# Navbar start
$navbarStart = $html.CreateElement("div")
$navbarStart.SetAttribute("class", "navbar-start")
[void]$navMenu.AppendChild($navbarStart)

$navItems = @(
    @{href="/introduction"; title="Getting started, Tutorials, Migration guides"; text="Introduction"},
    @{href="/reference"; title="Fundamentals, General reference"; text="Reference"},
    @{href="/miscellaneous"; title="Programs, Experimental"; text="Miscellaneous"},
    @{href="/types"; title="The core types (classes) available"; text="Types"},
    @{href="/routines"; title="Searchable table of routines"; text="Routines"},
    @{href="https://raku.org"; title="Home page for community"; text="Raku®"},
    @{href="https://web.libera.chat/#raku"; title="IRC live chat"; text="Chat"}
)

foreach ($item in $navItems) {
    $a = $html.CreateElement("a")
    $a.SetAttribute("class", "navbar-item")
    $a.SetAttribute("href", $item.href)
    $a.SetAttribute("title", $item.title)
    $a.InnerText = $item.text
    [void]$navbarStart.AppendChild($a)
}

# More dropdown
$dropdownDiv = $html.CreateElement("div")
$dropdownDiv.SetAttribute("class", "navbar-item has-dropdown is-hoverable")
[void]$navbarStart.AppendChild($dropdownDiv)

$dropdownLink = $html.CreateElement("a")
$dropdownLink.SetAttribute("class", "navbar-link")
$dropdownLink.InnerText = "More"
[void]$dropdownDiv.AppendChild($dropdownLink)

$dropdownMenu = $html.CreateElement("div")
$dropdownMenu.SetAttribute("class", "navbar-dropdown is-right is-rounded")
[void]$dropdownDiv.AppendChild($dropdownMenu)

$hr1 = $html.CreateElement("hr")
$hr1.SetAttribute("class", "navbar-divider")
[void]$dropdownMenu.AppendChild($hr1)

$downloadLink = $html.CreateElement("a")
$downloadLink.SetAttribute("class", "navbar-item js-modal-trigger")
$downloadLink.SetAttribute("data-target", "download-ebook")
$downloadLink.InnerText = "Download E-Book (epub)"
[void]$dropdownMenu.AppendChild($downloadLink)

$hr2 = $html.CreateElement("hr")
$hr2.SetAttribute("class", "navbar-divider")
[void]$dropdownMenu.AppendChild($hr2)

$aboutLink = $html.CreateElement("a")
$aboutLink.SetAttribute("class", "navbar-item")
$aboutLink.SetAttribute("href", "/about")
$aboutLink.InnerText = "About"
[void]$dropdownMenu.AppendChild($aboutLink)

$hr3 = $html.CreateElement("hr")
$hr3.SetAttribute("class", "navbar-divider")
[void]$dropdownMenu.AppendChild($hr3)

$reportSiteLink = $html.CreateElement("a")
$reportSiteLink.SetAttribute("class", "navbar-item has-text-red")
$reportSiteLink.SetAttribute("href", "https://github.com/raku/doc-website/issues")
$reportSiteLink.InnerText = "Report an issue with this site"
[void]$dropdownMenu.AppendChild($reportSiteLink)

$hr4 = $html.CreateElement("hr")
$hr4.SetAttribute("class", "navbar-divider")
[void]$dropdownMenu.AppendChild($hr4)

$reportDocLink = $html.CreateElement("a")
$reportDocLink.SetAttribute("class", "navbar-item")
$reportDocLink.SetAttribute("href", "https://github.com/raku/doc/issues")
$reportDocLink.InnerText = "Report an issue with the documentation content"
[void]$dropdownMenu.AppendChild($reportDocLink)

# Navbar end (search)
$navbarEnd = $html.CreateElement("div")
$navbarEnd.SetAttribute("class", "navbar-end navbar-search-wrapper")
[void]$navMenu.AppendChild($navbarEnd)

$searchItem = $html.CreateElement("div")
$searchItem.SetAttribute("class", "navbar-item")
[void]$navbarEnd.AppendChild($searchItem)

$searchField = $html.CreateElement("div")
$searchField.SetAttribute("class", "field has-addons")
[void]$searchItem.AppendChild($searchField)

$autoCompleteDiv = $html.CreateElement("div")
$autoCompleteDiv.SetAttribute("class", "autoComplete_options")
[void]$searchField.AppendChild($autoCompleteDiv)

$searchInput = $html.CreateElement("input")
$searchInput.SetAttribute("class", "control input")
$searchInput.SetAttribute("id", "autoComplete")
$searchInput.SetAttribute("type", "search")
$searchInput.SetAttribute("dir", "ltr")
$searchInput.SetAttribute("spellcheck", "false")
$searchInput.SetAttribute("autocorrect", "off")
$searchInput.SetAttribute("autocomplete", "off")
$searchInput.SetAttribute("autocapitalize", "off")
$searchInput.SetAttribute("placeholder", "🔍 Type f to search for ...")
[void]$autoCompleteDiv.AppendChild($searchInput)

$controlDiv = $html.CreateElement("div")
$controlDiv.SetAttribute("class", "control")
$controlDiv.SetAttribute("title", "Search options")
[void]$searchField.AppendChild($controlDiv)

$searchButton = $html.CreateElement("a")
$searchButton.SetAttribute("class", "button is-primary js-modal-trigger")
$searchButton.SetAttribute("data-target", "options-search-info")
[void]$controlDiv.AppendChild($searchButton)

$searchIconSpan = $html.CreateElement("span")
$searchIconSpan.SetAttribute("class", "icon")
[void]$searchButton.AppendChild($searchIconSpan)

$searchIcon = $html.CreateElement("i")
$searchIcon.SetAttribute("class", "fas fa-cogs")
[void]$searchIconSpan.AppendChild($searchIcon)

# Modals
# Options search info modal
$optionsModal = $html.CreateElement("div")
$optionsModal.SetAttribute("id", "options-search-info")
$optionsModal.SetAttribute("class", "modal")
[void]$navMenu.AppendChild($optionsModal)

$modalBg = $html.CreateElement("div")
$modalBg.SetAttribute("class", "modal-background")
[void]$optionsModal.AppendChild($modalBg)

$modalContent = $html.CreateElement("div")
$modalContent.SetAttribute("class", "modal-content")
[void]$optionsModal.AppendChild($modalContent)

$modalBox = $html.CreateElement("div")
$modalBox.SetAttribute("class", "box")
[void]$modalContent.AppendChild($modalBox)

$modalP1 = $html.CreateElement("p")
$modalP1.InnerText = "The last search was: "
[void]$modalBox.AppendChild($modalP1)

$selectedSpan = $html.CreateElement("span")
$selectedSpan.SetAttribute("id", "selected-candidate")
$selectedSpan.SetAttribute("class", "ss-selected")
[void]$modalP1.AppendChild($selectedSpan)

$optionsDiv = $html.CreateElement("div")
$optionsDiv.SetAttribute("class", "control is-grouped is-grouped-centered options-search-controls")
[void]$modalBox.AppendChild($optionsDiv)

# Extra info toggle
$extraLabel = $html.CreateElement("label")
$extraLabel.SetAttribute("class", "centreToggle")
$extraLabel.SetAttribute("title", "Include extra information (Alt-E)")
$extraLabel.SetAttribute("style", "--switch-width: 10.5")
[void]$optionsDiv.AppendChild($extraLabel)

$extraInput = $html.CreateElement("input")
$extraInput.SetAttribute("id", "options-search-extra")
$extraInput.SetAttribute("type", "checkbox")
[void]$extraLabel.AppendChild($extraInput)

$extraText = $html.CreateElement("span")
$extraText.SetAttribute("class", "text")
$extraText.InnerText = "Extra info"
[void]$extraLabel.AppendChild($extraText)

$extraOn = $html.CreateElement("span")
$extraOn.SetAttribute("class", "on")
$extraOn.InnerText = "yes"
[void]$extraLabel.AppendChild($extraOn)

$extraOff = $html.CreateElement("span")
$extraOff.SetAttribute("class", "off")
$extraOff.InnerText = "no"
[void]$extraLabel.AppendChild($extraOff)

$modalP2 = $html.CreateElement("p")
$modalP2.InnerText = "The search response can be shortened by excluding the extra information line (Alt-E)"
[void]$optionsDiv.AppendChild($modalP2)

# Search type toggle
$looseLabel = $html.CreateElement("label")
$looseLabel.SetAttribute("class", "centreToggle")
$looseLabel.SetAttribute("title", "Search engine type Strict/Loose (Alt-L)")
$looseLabel.SetAttribute("style", "--switch-width: 10.5")
[void]$optionsDiv.AppendChild($looseLabel)

$looseInput = $html.CreateElement("input")
$looseInput.SetAttribute("id", "options-search-loose")
$looseInput.SetAttribute("type", "checkbox")
[void]$looseLabel.AppendChild($looseInput)

$looseText = $html.CreateElement("span")
$looseText.SetAttribute("class", "text")
$looseText.InnerText = "Search type"
[void]$looseLabel.AppendChild($looseText)

$looseOn = $html.CreateElement("span")
$looseOn.SetAttribute("class", "on")
$looseOn.InnerText = "loose"
[void]$looseLabel.AppendChild($looseOn)

$looseOff = $html.CreateElement("span")
$looseOff.SetAttribute("class", "off")
$looseOff.InnerText = "strict"
[void]$looseLabel.AppendChild($looseOff)

$modalP3 = $html.CreateElement("p")
$modalP3.InnerText = " The search engine can perform a strict search (only the characters in the search box) or a loose search (Alt-L)"
[void]$optionsDiv.AppendChild($modalP3)

# Headings toggle
$headingsLabel = $html.CreateElement("label")
$headingsLabel.SetAttribute("class", "centreToggle")
$headingsLabel.SetAttribute("title", "Search in headings (Alt-H)")
$headingsLabel.SetAttribute("style", "--switch-width: 10.5")
[void]$optionsDiv.AppendChild($headingsLabel)

$headingsInput = $html.CreateElement("input")
$headingsInput.SetAttribute("id", "options-search-headings")
$headingsInput.SetAttribute("type", "checkbox")
[void]$headingsLabel.AppendChild($headingsInput)

$headingsText = $html.CreateElement("span")
$headingsText.SetAttribute("class", "text")
$headingsText.InnerText = "Headings"
[void]$headingsLabel.AppendChild($headingsText)

$headingsOn = $html.CreateElement("span")
$headingsOn.SetAttribute("class", "on")
$headingsOn.InnerText = "yes"
[void]$headingsLabel.AppendChild($headingsOn)

$headingsOff = $html.CreateElement("span")
$headingsOff.SetAttribute("class", "off")
$headingsOff.InnerText = "no"
[void]$headingsLabel.AppendChild($headingsOff)

$modalP4 = $html.CreateElement("p")
$modalP4.InnerText = "Search through headings in all web-pages (Alt-H)"
[void]$optionsDiv.AppendChild($modalP4)

# Indexed toggle
$indexedLabel = $html.CreateElement("label")
$indexedLabel.SetAttribute("class", "centreToggle")
$indexedLabel.SetAttribute("title", "Search indexed items (Alt-I)")
$indexedLabel.SetAttribute("style", "--switch-width: 10.5")
[void]$optionsDiv.AppendChild($indexedLabel)

$indexedInput = $html.CreateElement("input")
$indexedInput.SetAttribute("id", "options-search-indexed")
$indexedInput.SetAttribute("type", "checkbox")
[void]$indexedLabel.AppendChild($indexedInput)

$indexedText = $html.CreateElement("span")
$indexedText.SetAttribute("class", "text")
$indexedText.InnerText = "Indexed"
[void]$indexedLabel.AppendChild($indexedText)

$indexedOn = $html.CreateElement("span")
$indexedOn.SetAttribute("class", "on")
$indexedOn.InnerText = "yes"
[void]$indexedLabel.AppendChild($indexedOn)

$indexedOff = $html.CreateElement("span")
$indexedOff.SetAttribute("class", "off")
$indexedOff.InnerText = "no"
[void]$indexedLabel.AppendChild($indexedOff)

$modalP5 = $html.CreateElement("p")
$modalP5.InnerText = "Search through all indexed items (Alt-I)"
[void]$optionsDiv.AppendChild($modalP5)

# Composite toggle
$compositeLabel = $html.CreateElement("label")
$compositeLabel.SetAttribute("class", "centreToggle")
$compositeLabel.SetAttribute("title", "Search composite pages (Alt-C)")
$compositeLabel.SetAttribute("style", "--switch-width: 10.5")
[void]$optionsDiv.AppendChild($compositeLabel)

$compositeInput = $html.CreateElement("input")
$compositeInput.SetAttribute("id", "options-search-composite")
$compositeInput.SetAttribute("type", "checkbox")
[void]$compositeLabel.AppendChild($compositeInput)

$compositeText = $html.CreateElement("span")
$compositeText.SetAttribute("class", "text")
$compositeText.InnerText = "Composite"
[void]$compositeLabel.AppendChild($compositeText)

$compositeOn = $html.CreateElement("span")
$compositeOn.SetAttribute("class", "on")
$compositeOn.InnerText = "yes"
[void]$compositeLabel.AppendChild($compositeOn)

$compositeOff = $html.CreateElement("span")
$compositeOff.SetAttribute("class", "off")
$compositeOff.InnerText = "no"
[void]$compositeLabel.AppendChild($compositeOff)

$modalP6 = $html.CreateElement("p")
$modalP6.InnerText = "Search in the names of composite pages, which combine similar information from the main web pages (Alt-C)"
[void]$optionsDiv.AppendChild($modalP6)

# Primary toggle
$primaryLabel = $html.CreateElement("label")
$primaryLabel.SetAttribute("class", "centreToggle")
$primaryLabel.SetAttribute("title", "Search primary sources (Alt-P)")
$primaryLabel.SetAttribute("style", "--switch-width: 10.5")
[void]$optionsDiv.AppendChild($primaryLabel)

$primaryInput = $html.CreateElement("input")
$primaryInput.SetAttribute("id", "options-search-primary")
$primaryInput.SetAttribute("type", "checkbox")
[void]$primaryLabel.AppendChild($primaryInput)

$primaryText = $html.CreateElement("span")
$primaryText.SetAttribute("class", "text")
$primaryText.InnerText = "Primary"
[void]$primaryLabel.AppendChild($primaryText)

$primaryOn = $html.CreateElement("span")
$primaryOn.SetAttribute("class", "on")
$primaryOn.InnerText = "yes"
[void]$primaryLabel.AppendChild($primaryOn)

$primaryOff = $html.CreateElement("span")
$primaryOff.SetAttribute("class", "off")
$primaryOff.InnerText = "no"
[void]$primaryLabel.AppendChild($primaryOff)

$modalP7 = $html.CreateElement("p")
$modalP7.InnerText = "Search through the names of the main web pages (Alt-P)"
[void]$optionsDiv.AppendChild($modalP7)

# New tab toggle
$newTabLabel = $html.CreateElement("label")
$newTabLabel.SetAttribute("class", "centreToggle")
$newTabLabel.SetAttribute("title", "Open in new tab (Alt-Q)")
$newTabLabel.SetAttribute("style", "--switch-width: 10.5")
[void]$optionsDiv.AppendChild($newTabLabel)

$newTabInput = $html.CreateElement("input")
$newTabInput.SetAttribute("id", "options-search-newtab")
$newTabInput.SetAttribute("type", "checkbox")
[void]$newTabLabel.AppendChild($newTabInput)

$newTabText = $html.CreateElement("span")
$newTabText.SetAttribute("class", "text")
$newTabText.InnerText = "New tab"
[void]$newTabLabel.AppendChild($newTabText)

$newTabOn = $html.CreateElement("span")
$newTabOn.SetAttribute("class", "on")
$newTabOn.InnerText = "yes"
[void]$newTabLabel.AppendChild($newTabOn)

$newTabOff = $html.CreateElement("span")
$newTabOff.SetAttribute("class", "off")
$newTabOff.InnerText = "no"
[void]$newTabLabel.AppendChild($newTabOff)

$modalP8 = $html.CreateElement("p")
$modalP8.InnerText = "Once a search candidate has been chosen, it can be opened in a new tab or in the current tab (Alt-Q)"
[void]$optionsDiv.AppendChild($modalP8)

$modalP9 = $html.CreateElement("p")
$modalP9.InnerText = "If all else fails, an item is added to use the Google search engine on the whole site"
[void]$optionsDiv.AppendChild($modalP9)

$resetButton = $html.CreateElement("button")
$resetButton.SetAttribute("class", "button is-warning")
$resetButton.SetAttribute("id", "options-search-reset-defaults")
$resetButton.InnerText = "Clear options, reset to defaults"
[void]$optionsDiv.AppendChild($resetButton)

$modalP10 = $html.CreateElement("p")
$modalP10.InnerText = "Exit this page by pressing <Escape>, or clicking on X or on the background."
[void]$optionsDiv.AppendChild($modalP10)

$modalClose1 = $html.CreateElement("button")
$modalClose1.SetAttribute("class", "modal-close is-large")
$modalClose1.SetAttribute("aria-label", "close")
[void]$optionsModal.AppendChild($modalClose1)

# Download ebook modal
$ebookModal = $html.CreateElement("div")
$ebookModal.SetAttribute("id", "download-ebook")
$ebookModal.SetAttribute("class", "modal")
[void]$navMenu.AppendChild($ebookModal)

$modalBg2 = $html.CreateElement("div")
$modalBg2.SetAttribute("class", "modal-background")
[void]$ebookModal.AppendChild($modalBg2)

$modalContent2 = $html.CreateElement("div")
$modalContent2.SetAttribute("class", "modal-content")
[void]$ebookModal.AppendChild($modalContent2)

$modalBox2 = $html.CreateElement("div")
$modalBox2.SetAttribute("class", "box")
[void]$modalContent2.AppendChild($modalBox2)

$modalP11 = $html.CreateElement("p")
$modalP11.InnerXml = '<a href="/RakuDocumentation.epub" download>RakuDocumentation.epub</a> is a work in progress e-book. It targets the <a href="https://www.w3.org/publishing/epub3/">EPUB v3 specification</a>. It needs testing on a variety of ereaders (some of which may still implicitly expect compliance with EPUB v2). The CSS definitely needs enhancing (especially for code snippets). The Ebook opens in a Calibre reader, which is available on all operating systems.'
[void]$modalBox2.AppendChild($modalP11)

$modalP12 = $html.CreateElement("p")
$modalP12.InnerText = "Suggestions are welcome and should be addressed by opening an issue on the Raku/doc-website repository"
[void]$modalBox2.AppendChild($modalP12)

$modalP13 = $html.CreateElement("p")
$modalP13.InnerText = "Exit this popup by pressing <Escape>, or clicking on X or on the background."
[void]$modalBox2.AppendChild($modalP13)

$modalClose2 = $html.CreateElement("button")
$modalClose2.SetAttribute("class", "modal-close is-large")
$modalClose2.SetAttribute("aria-label", "close")
[void]$ebookModal.AppendChild($modalClose2)

# Main content area
$tileAncestor = $html.CreateElement("div")
$tileAncestor.SetAttribute("class", "tile is-ancestor section")
[void]$body.AppendChild($tileAncestor)

# Page edit button
$pageEdit = $html.CreateElement("div")
$pageEdit.SetAttribute("class", "page-edit")
[void]$tileAncestor.AppendChild($pageEdit)

$pageEditButton = $html.CreateElement("a")
$pageEditButton.SetAttribute("class", "button page-edit-button")
$pageEditButton.SetAttribute("href", "https://github.com/Raku/doc-website/edit/main/Website/structure-sources/404.rakudoc")
$pageEditButton.SetAttribute("title", "Edit this page.`nCommit: 0ead45c 2026-04-04")
[void]$pageEdit.AppendChild($pageEditButton)

$pageEditIconSpan = $html.CreateElement("span")
$pageEditIconSpan.SetAttribute("class", "icon is-right")
[void]$pageEditButton.AppendChild($pageEditIconSpan)

$pageEditIcon = $html.CreateElement("i")
$pageEditIcon.SetAttribute("class", "fas fa-pen-alt is-medium")
[void]$pageEditIconSpan.AppendChild($pageEditIcon)

# Left column
$leftColumn = $html.CreateElement("div")
$leftColumn.SetAttribute("id", "left-column")
$leftColumn.SetAttribute("class", "tile is-parent is-2 is-hidden")
[void]$tileAncestor.AppendChild($leftColumn)

$leftColInner = $html.CreateElement("div")
$leftColInner.SetAttribute("id", "left-col-inner")
[void]$leftColumn.AppendChild($leftColInner)

$tocInput = $html.CreateElement("input")
$tocInput.SetAttribute("type", "checkbox")
$tocInput.SetAttribute("id", "No-TOC")
$tocInput.SetAttribute("checked", "checked")
$tocInput.SetAttribute("style", "visibility: collapse;")
[void]$leftColInner.AppendChild($tocInput)

$tocDiv = $html.CreateElement("div")
$tocDiv.SetAttribute("class", "content")
$tocDiv.InnerText = "No Table of Contents or Index available"
[void]$leftColInner.AppendChild($tocDiv)

# Main column
$mainColumn = $html.CreateElement("div")
$mainColumn.SetAttribute("id", "main-column")
$mainColumn.SetAttribute("class", "tile is-parent")
$mainColumn.SetAttribute("style", "overflow-x: hidden;")
[void]$tileAncestor.AppendChild($mainColumn)

$mainColInner = $html.CreateElement("div")
$mainColInner.SetAttribute("id", "main-col-inner")
[void]$mainColumn.AppendChild($mainColInner)

# Page header section
$pageHeader = $html.CreateElement("section")
$pageHeader.SetAttribute("class", "raku page-header")
[void]$mainColInner.AppendChild($pageHeader)

$pageHeaderContainer = $html.CreateElement("div")
$pageHeaderContainer.SetAttribute("class", "container px-4")
[void]$pageHeader.AppendChild($pageHeaderContainer)

$pageTitleDiv = $html.CreateElement("div")
$pageTitleDiv.SetAttribute("class", "raku page-title has-text-centered")
$pageTitleDiv.InnerText = "404"
[void]$pageHeaderContainer.AppendChild($pageTitleDiv)

$pageSubtitleDiv = $html.CreateElement("div")
$pageSubtitleDiv.SetAttribute("class", "raku page-subtitle has-text-centered")
[void]$pageHeaderContainer.AppendChild($pageSubtitleDiv)

# Page content section
$pageContent = $html.CreateElement("section")
$pageContent.SetAttribute("class", "raku page-content")
[void]$mainColInner.AppendChild($pageContent)

$contentContainer = $html.CreateElement("div")
$contentContainer.SetAttribute("class", "container px-4")
[void]$pageContent.AppendChild($contentContainer)

$columnsDiv = $html.CreateElement("div")
$columnsDiv.SetAttribute("class", "columns one-col")
[void]$contentContainer.AppendChild($columnsDiv)

$contentImg = $html.CreateElement("img")
$contentImg.SetAttribute("src", "/assets/images/Camelia-404.png")
$contentImg.SetAttribute("class", "camelia")
[void]$columnsDiv.AppendChild($contentImg)

$contentH2 = $html.CreateElement("h2")
$contentH2.SetAttribute("id", "404:_Page_Not_Found")
$contentH2.SetAttribute("class", "raku-h2")
[void]$columnsDiv.AppendChild($contentH2)

$h2AnchorLink = $html.CreateElement("a")
$h2AnchorLink.SetAttribute("href", "#404")
$h2AnchorLink.SetAttribute("title", "go to top of document")
$h2AnchorLink.InnerText = "404: Page Not Found"
[void]$contentH2.AppendChild($h2AnchorLink)

$h2Anchor = $html.CreateElement("a")
$h2Anchor.SetAttribute("class", "raku-anchor")
$h2Anchor.SetAttribute("title", "direct link")
$h2Anchor.SetAttribute("href", "#404:_Page_Not_Found")
$h2Anchor.InnerText = "§"
[void]$h2AnchorLink.AppendChild($h2Anchor)

$contentP1 = $html.CreateElement("p")
$contentP1.InnerText = "We're sorry, but the content you tried to reach wasn't found."
[void]$columnsDiv.AppendChild($contentP1)

$contentP2 = $html.CreateElement("p")
$contentP2.InnerXml = 'While we do review server logs to catch these issues, we recently deployed a new version of the site, so please feel free to <a href="https://github.com/Raku/doc-website/issues/">report any issues</a>.'
[void]$columnsDiv.AppendChild($contentP2)

$contentP3 = $html.CreateElement("p")
$contentP3.InnerText = "Thanks!"
[void]$columnsDiv.AppendChild($contentP3)

# Footer
$footer = $html.CreateElement("footer")
$footer.SetAttribute("class", "footer main-footer")
[void]$body.AppendChild($footer)

$footerContainer = $html.CreateElement("div")
$footerContainer.SetAttribute("class", "container px-4")
[void]$footer.AppendChild($footerContainer)

$footerNav = $html.CreateElement("nav")
$footerNav.SetAttribute("class", "level")
[void]$footerContainer.AppendChild($footerNav)

$levelLeft = $html.CreateElement("div")
$levelLeft.SetAttribute("class", "level-left")
[void]$footerNav.AppendChild($levelLeft)

$aboutLevelItem = $html.CreateElement("div")
$aboutLevelItem.SetAttribute("class", "level-item")
[void]$levelLeft.AppendChild($aboutLevelItem)

$aboutLinkFooter = $html.CreateElement("a")
$aboutLinkFooter.SetAttribute("href", "/about")
$aboutLinkFooter.InnerText = "About"
[void]$aboutLevelItem.AppendChild($aboutLinkFooter)

$themeLevelItem = $html.CreateElement("div")
$themeLevelItem.SetAttribute("class", "level-item")
[void]$levelLeft.AppendChild($themeLevelItem)

$themeLink = $html.CreateElement("a")
$themeLink.SetAttribute("id", "toggle-theme")
$themeLink.InnerText = "Toggle theme"
[void]$themeLevelItem.AppendChild($themeLink)

$commitLevelItem = $html.CreateElement("div")
$commitLevelItem.SetAttribute("class", "level-item")
$commitLevelItem.SetAttribute("title", "0ead45c 2026-04-04")
[void]$levelLeft.AppendChild($commitLevelItem)

$commit
