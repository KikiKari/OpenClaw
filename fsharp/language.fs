// abstraction-provenance: {"artifact_sha256": "b3ddc4c652da0e047b389419b98e923fd44634d7493608d205b2b195c2e4e4a9", "source_sha256": "0f3530ed5a95fa71241e65119ede0362d09d6dbde8fbabfc84d844298613edb6", "target_language": "fsharp"}
// language.html — portiert nach fsharp
// Quelle: html, OpenClaw@gateway1:skills/scripting-utils/references/raku/language.html
// auch in: OpenClaw@gateway2:skills/scripting-utils/references/raku/language.html
// auch in: workspace@local:git/skills/scripting-utils/references/raku/language.html
// auch in: workspace@local:skills/scripting-utils/references/raku/language.html
// auch in: 4 weiteren Fundstellen
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO

type HtmlElement = {
    Tag: string
    Attributes: Map<string, string>
    Children: HtmlNode list
}

and HtmlNode =
    | Element of HtmlElement
    | Text of string

let createElement tag attributes children =
    Element { Tag = tag; Attributes = Map.ofList attributes; Children = children }

let createText text = Text text

let rec renderHtml (node: HtmlNode) : string =
    match node with
    | Text s -> s
    | Element e ->
        let attrs = 
            e.Attributes 
            |> Map.toList
            |> List.map (fun (k, v) -> sprintf "%s=\"%s\"" k v)
            |> String.concat " "
        let attrStr = if attrs = "" then "" else " " + attrs
        let childrenHtml = 
            e.Children 
            |> List.map renderHtml
            |> String.concat ""
        sprintf "<%s%s>%s</%s>" e.Tag attrStr childrenHtml e.Tag

let docType = "<!DOCTYPE html>"
let htmlAttrs = [
    ("lang", "en")
    ("class", "fontawesome-i2svg-active fontawesome-i2svg-complete")
    ("style", "scroll-padding-top:60px")
]

let headChildren = [
    createElement "title" [] [createText "404 | Raku Documentation"]
    createElement "meta" [("charset", "UTF-8")] []
    createElement "link" [("href", "/assets/images/Camelia.ico"); ("rel", "icon"); ("type", "image/x-icon")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/Website.css")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/css/filtered-toc-dark.css"); ("title", "dark")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/css/filtered-toc-light.css"); ("title", "light")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/css/rainbow-dark.css"); ("title", "dark")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/css/rainbow-light.css"); ("title", "light")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/tm-styling.css")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/tm-light.css"); ("title", "light")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/tm-dark.css"); ("title", "dark")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/all.min.css")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/listf-styling-light.css"); ("title", "light")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/listf-styling-dark.css"); ("title", "dark")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/typegraph-styling.css")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/typegraph-dark.css"); ("title", "dark")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/typegraph-light.css"); ("title", "light")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/css/page-styling-main.css")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/css/page-styling-dark.css"); ("title", "dark")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/css/page-styling-light.css"); ("title", "light")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/css/chyronToggle-dark.css"); ("title", "dark")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/css/chyronToggle-light.css"); ("title", "light")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/css/centreToggle-dark.css"); ("title", "dark")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/css/centreToggle-light.css"); ("title", "light")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/css/options-search-light.css"); ("title", "light")] []
    createElement "link" [("rel", "stylesheet"); ("href", "/assets/css/css/options-search-dark.css"); ("title", "dark")] []
    createElement "link" [("rel", "stylesheet"); ("href", "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-light.min.css"); ("title", "light")] []
    createElement "link" [("rel", "stylesheet"); ("href", "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-dark.min.css"); ("title", "dark")] []
    createElement "link" [("rel", "stylesheet"); ("href", "https://cdn.jsdelivr.net/npm/@tarekraafat/autocomplete.js@10.2.7/dist/css/autoComplete.min.css")] []
    createElement "script" [("src", "https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js")] []
    createElement "script" [("src", "/assets/scripts/all.min.js")] []
    createElement "script" [("src", "/assets/scripts/tableManager.js")] []
    createElement "script" [("src", "/assets/scripts/filter-script.js")] []
    createElement "script" [("src", "https://cdn.jsdelivr.net/npm/fuzzysort@2.0.4/fuzzysort.min.js")] []
    createElement "script" [("src", "https://cdn.jsdelivr.net/npm/@tarekraafat/autocomplete.js@10.2.7/dist/autoComplete.min.js")] []
    createElement "script" [("src", "/assets/scripts/filtered-toc.js")] []
    createElement "script" [("src", "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js")] []
    createElement "script" [("src", "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/haskell.min.js")] []
    createElement "script" [("src", "/assets/scripts/options-search.js")] []
    createElement "script" [("src", "/assets/scripts/page-styling.js")] []
    createElement "script" [("src", "/assets/scripts/rainbow.js")] []
]

let navChildren = [
    createElement "div" [("class", "navbar-item"); ("style", "margin-left: auto;")] [
        createElement "div" [("class", "left-bar-toggle"); ("title", "Toggle Table of Contents & Index")] [
            createElement "label" [("class", "chyronToggle left")] [
                createElement "input" [("id", "navbar-left-toggle"); ("type", "checkbox")] []
                createElement "span" [("class", "text")] [createText "Contents"]
            ]
        ]
    ]
    createElement "div" [("class", "container is-justify-content-space-around")] [
        createElement "div" [("class", "navbar-brand")] [
            createElement "div" [("class", "navbar-logo")] [
                createElement "a" [("class", "navbar-item"); ("href", "/")] [
                    createElement "img" [("src", "/assets/images/camelia-recoloured.png"); ("alt", "Raku"); ("width", "52.83"); ("height", "38")] []
                ]
                createElement "span" [("class", "navbar-logo-tm")] [createText "tm"]
            ]
            createElement "a" [("role", "button"); ("class", "navbar-burger burger"); ("aria-label", "menu"); ("aria-expanded", "false"); ("data-target", "navMenu")] [
                createElement "span" [("aria-hidden", "true")] []
                createElement "span" [("aria-hidden", "true")] []
                createElement "span" [("aria-hidden", "true")] []
            ]
        ]
        createElement "div" [("id", "navMenu"); ("class", "navbar-menu")] [
            createElement "div" [("class", "navbar-start")] [
                createElement "a" [("class", "navbar-item"); ("href", "/introduction"); ("title", "Getting started, Tutorials, Migration guides")] [createText "Introduction"]
                createElement "a" [("class", "navbar-item"); ("href", "/reference"); ("title", "Fundamentals, General reference")] [createText "Reference"]
                createElement "a" [("class", "navbar-item"); ("href", "/miscellaneous"); ("title", "Programs, Experimental")] [createText "Miscellaneous"]
                createElement "a" [("class", "navbar-item"); ("href", "/types"); ("title", "The core types (classes) available")] [createText "Types"]
                createElement "a" [("class", "navbar-item"); ("href", "/routines"); ("title", "Searchable table of routines")] [createText "Routines"]
                createElement "a" [("class", "navbar-item"); ("href", "https://raku.org"); ("title", "Home page for community")] [createText "Raku®"]
                createElement "a" [("class", "navbar-item"); ("href", "https://web.libera.chat/#raku"); ("title", "IRC live chat")] [createText "Chat"]
                createElement "div" [("class", "navbar-item has-dropdown is-hoverable")] [
                    createElement "a" [("class", "navbar-link")] [createText "More"]
                    createElement "div" [("class", "navbar-dropdown is-right is-rounded")] [
                        createElement "hr" [("class", "navbar-divider")] []
                        createElement "a" [("class", "navbar-item js-modal-trigger"); ("data-target", "download-ebook")] [createText "Download E-Book (epub)"]
                        createElement "hr" [("class", "navbar-divider")] []
                        createElement "a" [("class", "navbar-item"); ("href", "/about")] [createText "About"]
                        createElement "hr" [("class", "navbar-divider")] []
                        createElement "a" [("class", "navbar-item has-text-red"); ("href", "https://github.com/raku/doc-website/issues")] [createText "Report an issue with this site"]
                        createElement "hr" [("class", "navbar-divider")] []
                        createElement "a" [("class", "navbar-item"); ("href", "https://github.com/raku/doc/issues")] [createText "Report an issue with the documentation content"]
                    ]
                ]
            ]
            createElement "div" [("class", "navbar-end navbar-search-wrapper")] [
                createElement "div" [("class", "navbar-item")] [
                    createElement "div" [("class", "field has-addons")] [
                        createElement "div" [("class", "autoComplete_options")] [
                            createElement "input" [
                                ("class", "control input")
                                ("id", "autoComplete")
                                ("type", "search")
                                ("dir", "ltr")
                                ("spellcheck", "false")
                                ("autocorrect", "off")
                                ("autocomplete", "off")
                                ("autocapitalize", "off")
                                ("placeholder", "🔍 Type f to search for ...")
                            ] []
                        ]
                        createElement "div" [("class", "control"); ("title", "Search options")] [
                            createElement "a" [("class", "button is-primary js-modal-trigger"); ("data-target", "options-search-info")] [
                                createElement "span" [("class", "icon")] [
                                    createElement "i" [("class", "fas fa-cogs")] []
                                ]
                            ]
                        ]
                    ]
                ]
            ]
            createElement "div" [("id", "options-search-info"); ("class", "modal")] [
                createElement "div" [("class", "modal-background")] []
                createElement "div" [("class", "modal-content")] [
                    createElement "div" [("class", "box")] [
                        createElement "p" [] [createText "The last search was: "; createElement "span" [("id", "selected-candidate"); ("class", "ss-selected")] []]
                        createElement "div" [("class", "control is-grouped is-grouped-centered options-search-controls")] [
                            createElement "label" [("class", "centreToggle"); ("title", "Include extra information (Alt-E)"); ("style", "--switch-width: 10.5")] [
                                createElement "input" [("id", "options-search-extra"); ("type", "checkbox")] []
                                createElement "span" [("class", "text")] [createText "Extra info"]
                                createElement "span" [("class", "on")] [createText "yes"]
                                createElement "span" [("class", "off")] [createText "no"]
                            ]
                            createElement "p" [] [createText "The search response can be shortened by excluding the extra information line (Alt-E)"]
                            createElement "label" [("class", "centreToggle"); ("title", "Search engine type Strict/Loose (Alt-L)"); ("style", "--switch-width: 10.5")] [
                                createElement "input" [("id", "options-search-loose"); ("type", "checkbox")] []
                                createElement "span" [("class", "text")] [createText "Search type"]
                                createElement "span" [("class", "on")] [createText "loose"]
                                createElement "span" [("class", "off")] [createText "strict"]
                            ]
                            createElement "p" [] [createText " The search engine can perform a strict search (only the characters in the search box) or a loose search (Alt-L)"]
                            createElement "label" [("class", "centreToggle"); ("title", "Search in headings (Alt-H)"); ("style", "--switch-width: 10.5")] [
                                createElement "input" [("id", "options-search-headings"); ("type", "checkbox")] []
                                createElement "span" [("class", "text")] [createText "Headings"]
                                createElement "span" [("class", "on")] [createText "yes"]
                                createElement "span" [("class", "off")] [createText "no"]
                            ]
                            createElement "p" [] [createText "Search through headings in all web-pages (Alt-H)"]
                            createElement "label" [("class", "centreToggle"); ("title", "Search indexed items (Alt-I)"); ("style", "--switch-width: 10.5")] [
                                createElement "input" [("id", "options-search-indexed"); ("type", "checkbox")] []
                                createElement "span" [("class", "text")] [createText "Indexed"]
                                createElement "span" [("class", "on")] [createText "yes"]
                                createElement "span" [("class", "off")] [createText "no"]
                            ]
                            createElement "p" [] [createText "Search through all indexed items (Alt-I)"]
                            createElement "label" [("class", "centreToggle"); ("title", "Search composite pages (Alt-C)"); ("style", "--switch-width: 10.5")] [
                                createElement "input" [("id", "options-search-composite"); ("type", "checkbox")] []
                                createElement "span" [("class", "text")] [createText "Composite"]
                                createElement "span" [("class", "on")] [createText "yes"]
                                createElement "span" [("class", "off")] [createText "no"]
                            ]
                            createElement "p" [] [createText "Search in the names of composite pages, which combine similar information from the main web pages (Alt-C)"]
                            createElement "label" [("class", "centreToggle"); ("title", "Search primary sources (Alt-P)"); ("style", "--switch-width: 10.5")] [
                                createElement "input" [("id", "options-search-primary"); ("type", "checkbox")] []
                                createElement "span" [("class", "text")] [createText "Primary"]
                                createElement "span" [("class", "on")] [createText "yes"]
                                createElement "span" [("class", "off")] [createText "no"]
                            ]
                            createElement "p" [] [createText "Search through the names of the main web pages (Alt-P)"]
                            createElement "label" [("class", "centreToggle"); ("title", "Open in new tab (Alt-Q)"); ("style", "--switch-width: 10.5")] [
                                createElement "input" [("id", "options-search-newtab"); ("type", "checkbox")] []
                                createElement "span" [("class", "text")] [createText "New tab"]
                                createElement "span" [("class", "on")] [createText "yes"]
                                createElement "span" [("class", "off")] [createText "no"]
                            ]
                            createElement "p" [] [createText "Once a search candidate has been chosen, it can be opened in a new tab or in the current tab (Alt-Q)"]
                            createElement "p" [] [createText "If all else fails, an item is added to use the Google search engine on the whole site"]
                            createElement "button" [("class", "button is-warning"); ("id", "options-search-reset-defaults")] [createText "Clear options, reset to defaults"]
                            createElement "p" [] [createText "Exit this page by pressing <Escape>, or clicking on X or on the background."]
                        ]
                    ]
                ]
                createElement "button" [("class", "modal-close is-large"); ("aria-label", "close")] []
            ]
        ]
        createElement "div" [("id", "download-ebook"); ("class", "modal")] [
            createElement "div" [("class", "modal-background")] []
            createElement "div" [("class", "modal-content")] [
                createElement "div" [("class", "box")] [
                    createElement "p" [] [
                        createElement "a" [("href", "/RakuDocumentation.epub"); ("download", "")] [createText "RakuDocumentation.epub"]
                        createText " is a work in progress e-book. It targets the "
                        createElement "a" [("href", "https://www.w3.org/publishing/epub3/")] [createText "EPUB v3 specification"]
                        createText ". It needs testing on a variety of ereaders (some of which may still implicitly expect compliance with EPUB v2). The CSS definitely needs enhancing (especially for code snippets). The Ebook opens in a Calibre reader, which is available on all operating systems."
                    ]
                    createElement "p" [] [createText "Suggestions are welcome and should be addressed by opening an issue on the Raku/doc-website repository"]
                    createElement "p" [] [createText "Exit this popup by pressing <Escape>, or clicking on X or on the background."]
                ]
            ]
            createElement "button" [("class", "modal-close is-large"); ("aria-label", "close")] []
        ]
    ]
]

let bodyChildren = [
    createElement "div" [("id", "404"); ("class", "top-of-page")] []
    createElement "nav" [("class", "navbar is-fixed-top is-flex-touch"); ("role", "navigation"); ("aria-label", "main navigation")] navChildren
    createElement "div" [("class", "tile is-ancestor section")] [
        createElement "div" [("class", "page-edit")] [
            createElement "a" [
                ("class", "button page-edit-button")
                ("href", "https://github.com/Raku/doc-website/edit/main/Website/structure-sources/404.rakudoc")
                ("title", "Edit this page.\nCommit: 0ead45c 2026-04-04")
            ] [
                createElement "span" [("class", "icon is-right")] [
                    createElement "i" [("class", "fas fa-pen-alt is-medium")] []
                ]
            ]
        ]
        createElement "div" [("id", "left-column"); ("class", "tile is-parent is-2 is-hidden")] [
            createElement "div" [("id", "left-col-inner")] [
                createElement "input" [
                    ("type", "checkbox")
                    ("id", "No-TOC")
                    ("checked", "checked")
                    ("style", "visibility: collapse;")
                ] []
                createElement "div" [("class", "content")] [createText "No Table of Contents or Index available"]
            ]
        ]
        createElement "div" [("id", "main-column"); ("class", "tile is-parent"); ("style", "overflow-x: hidden;")] [
            createElement "div" [("id", "main-col-inner")] [
                createElement "section" [("class", "raku page-header")] [
                    createElement "div" [("class", "container px-4")] [
                        createElement "div" [("class", "raku page-title has-text-centered")] [createText "404"]
                        createElement "div" [("class", "raku page-subtitle has-text-centered")] []
                    ]
                ]
                createElement "section" [("class", "raku page-content")] [
                    createElement "div" [("class", "container px-4")] [
                        createElement "div" [("class", "columns one-col")] [
                            createElement "img" [("src", "/assets/images/Camelia-404.png"); ("class", "camelia")] []
                            createElement "h2" [("id", "404:_Page_Not_Found"); ("class", "raku-h2")] [
                                createElement "a" [("href", "#404"); ("title", "go to top of document")] [
                                    createText "404: Page Not Found"
                                    createElement "a" [("class", "raku-anchor"); ("title", "direct link"); ("href", "#404:_Page_Not_Found")] [createText "§"]
                                ]
                            ]
                            createElement "p" [] [createText "We're sorry, but the content you tried to reach wasn't found."]
                            createElement "p" [] [
                                createText "While we do review server logs to catch these issues, we recently deployed a new version of the site, so please feel free to "
                                createElement "a" [("href", "https://github.com/Raku/doc-website/issues/")] [createText "report any issues"]
                                createText "."
                            ]
                            createElement "p" [] [createText "Thanks!"]
                        ]
                    ]
                ]
            ]
        ]
    ]
    createElement "footer" [("class", "footer main-footer")] [
        createElement "div" [("class", "container px-4")] [
            createElement "nav" [("class", "level")] [
                createElement "div" [("class", "level-left")] [
                    createElement "div" [("class", "level-item")] [
                        createElement "a" [("href", "/about")] [createText "About"]
                    ]
                    createElement "div" [("class", "level-item")] [
                        createElement "a" [("id", "toggle-theme")] [createText "Toggle theme"]
                    ]
                    createElement "div" [("class", "level-item"); ("title", "0ead45c 2026-04-04")] [
                        createElement "a" [] [createText "Commit"]
                    ]
                ]
                createElement "div" [("class", "level-right")] [
                    createElement "div" [("class", "level-item")] [
                        createElement "a" [("href", "/license")] [createText "License"]
                    ]
                ]
            ]
        ]
    ]
]

let htmlDocument = 
    createElement "html" htmlAttrs [
        createElement "head" [] headChildren
        createElement "body" [("class", "has-navbar-fixed-top")] bodyChildren
    ]

let generateHtml () =
    docType + "\n" + renderHtml (Element htmlDocument)

[<EntryPoint>]
let main argv =
    if argv.Length <> 1 then
        printfn "Usage: %s <output-file>" argv.[0]
        1
    else
        try
            let htmlContent = generateHtml()
            File.WriteAllText(argv.[0], htmlContent)
            printfn "HTML file generated successfully: %s" argv.[0]
            0
        with
        | ex ->
            printfn "Error generating HTML file: %s" ex.Message
            1
