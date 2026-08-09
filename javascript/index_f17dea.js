#!/usr/bin/env node
// index.html — portiert nach javascript
// Quelle: html, OpenClaw@gateway1:skills/scripting-utils/references/raku/index.html
// auch in: OpenClaw@gateway2:skills/scripting-utils/references/raku/index.html
// Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

function createHTMLDocument() {
    const doc = {
        doctype: '<!DOCTYPE html>',
        html: {
            attrs: {
                lang: "en",
                class: "fontawesome-i2svg-active fontawesome-i2svg-complete",
                style: "scroll-padding-top:60px"
            },
            head: {
                title: "Raku Documentation | Raku Documentation",
                meta: [{ charset: "UTF-8" }],
                links: [
                    { href: "/assets/images/Camelia.ico", rel: "icon", type: "image/x-icon" },
                    { href: "/assets/css/Website.css", rel: "stylesheet" },
                    { href: "/assets/css/css/filtered-toc-dark.css", rel: "stylesheet", title: "dark" },
                    { href: "/assets/css/css/filtered-toc-light.css", rel: "stylesheet", title: "light" },
                    { href: "/assets/css/css/rainbow-dark.css", rel: "stylesheet", title: "dark" },
                    { href: "/assets/css/css/rainbow-light.css", rel: "stylesheet", title: "light" },
                    { href: "/assets/css/tm-styling.css", rel: "stylesheet" },
                    { href: "/assets/css/tm-light.css", rel: "stylesheet", title: "light" },
                    { href: "/assets/css/tm-dark.css", rel: "stylesheet", title: "dark" },
                    { href: "/assets/css/all.min.css", rel: "stylesheet" },
                    { href: "/assets/css/listf-styling-light.css", rel: "stylesheet", title: "light" },
                    { href: "/assets/css/listf-styling-dark.css", rel: "stylesheet", title: "dark" },
                    { href: "/assets/css/typegraph-styling.css", rel: "stylesheet" },
                    { href: "/assets/css/typegraph-dark.css", rel: "stylesheet", title: "dark" },
                    { href: "/assets/css/typegraph-light.css", rel: "stylesheet", title: "light" },
                    { href: "/assets/css/css/page-styling-main.css", rel: "stylesheet" },
                    { href: "/assets/css/css/page-styling-dark.css", rel: "stylesheet", title: "dark" },
                    { href: "/assets/css/css/page-styling-light.css", rel: "stylesheet", title: "light" },
                    { href: "/assets/css/css/chyronToggle-dark.css", rel: "stylesheet", title: "dark" },
                    { href: "/assets/css/css/chyronToggle-light.css", rel: "stylesheet", title: "light" },
                    { href: "/assets/css/css/centreToggle-dark.css", rel: "stylesheet", title: "dark" },
                    { href: "/assets/css/css/centreToggle-light.css", rel: "stylesheet", title: "light" },
                    { href: "/assets/css/css/options-search-light.css", rel: "stylesheet", title: "light" },
                    { href: "/assets/css/css/options-search-dark.css", rel: "stylesheet", title: "dark" },
                    { href: "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-light.min.css", rel: "stylesheet", title: "light" },
                    { href: "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-dark.min.css", rel: "stylesheet", title: "dark" },
                    { href: "https://cdn.jsdelivr.net/npm/@tarekraafat/autocomplete.js@10.2.7/dist/css/autoComplete.min.css", rel: "stylesheet" }
                ],
                scripts: [
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
                ]
            },
            body: {
                attrs: { class: "has-navbar-fixed-top" },
                content: [
                    { tag: "div", attrs: { id: "Raku_Documentation", class: "top-of-page" } },
                    {
                        tag: "nav",
                        attrs: { class: "navbar is-fixed-top is-flex-touch", role: "navigation", "aria-label": "main navigation" },
                        content: [
                            {
                                tag: "div",
                                attrs: { class: "container is-justify-content-space-around" },
                                content: [
                                    {
                                        tag: "div",
                                        attrs: { class: "navbar-brand" },
                                        content: [
                                            {
                                                tag: "div",
                                                attrs: { class: "navbar-logo" },
                                                content: [
                                                    {
                                                        tag: "a",
                                                        attrs: { class: "navbar-item", href: "/" },
                                                        content: [
                                                            {
                                                                tag: "img",
                                                                attrs: {
                                                                    src: "/assets/images/camelia-recoloured.png",
                                                                    alt: "Raku",
                                                                    width: "52.83",
                                                                    height: "38"
                                                                }
                                                            }
                                                        ]
                                                    },
                                                    { tag: "span", attrs: { class: "navbar-logo-tm" }, content: "tm" }
                                                ]
                                            },
                                            {
                                                tag: "a",
                                                attrs: {
                                                    role: "button",
                                                    class: "navbar-burger burger",
                                                    "aria-label": "menu",
                                                    "aria-expanded": "false",
                                                    "data-target": "navMenu"
                                                },
                                                content: [
                                                    { tag: "span", attrs: { "aria-hidden": "true" } },
                                                    { tag: "span", attrs: { "aria-hidden": "true" } },
                                                    { tag: "span", attrs: { "aria-hidden": "true" } }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        tag: "div",
                                        attrs: { id: "navMenu", class: "navbar-menu" },
                                        content: [
                                            {
                                                tag: "div",
                                                attrs: { class: "navbar-start" },
                                                content: [
                                                    { tag: "a", attrs: { class: "navbar-item", href: "/introduction", title: "Getting started, Tutorials, Migration guides" }, content: "Introduction" },
                                                    { tag: "a", attrs: { class: "navbar-item", href: "/reference", title: "Fundamentals, General reference" }, content: "Reference" },
                                                    { tag: "a", attrs: { class: "navbar-item", href: "/miscellaneous", title: "Programs, Experimental" }, content: "Miscellaneous" },
                                                    { tag: "a", attrs: { class: "navbar-item", href: "/types", title: "The core types (classes) available" }, content: "Types" },
                                                    { tag: "a", attrs: { class: "navbar-item", href: "/routines", title: "Searchable table of routines" }, content: "Routines" },
                                                    { tag: "a", attrs: { class: "navbar-item", href: "https://raku.org", title: "Home page for community" }, content: ["Raku", { tag: "sup", content: "®" }] },
                                                    { tag: "a", attrs: { class: "navbar-item", href: "https://web.libera.chat/#raku", title: "IRC live chat" }, content: "Chat" },
                                                    {
                                                        tag: "div",
                                                        attrs: { class: "navbar-item has-dropdown is-hoverable" },
                                                        content: [
                                                            { tag: "a", attrs: { class: "navbar-link" }, content: "More" },
                                                            {
                                                                tag: "div",
                                                                attrs: { class: "navbar-dropdown is-right is-rounded" },
                                                                content: [
                                                                    { tag: "hr", attrs: { class: "navbar-divider" } },
                                                                    { tag: "a", attrs: { class: "navbar-item js-modal-trigger", "data-target": "download-ebook" }, content: "Download E-Book (epub)" },
                                                                    { tag: "hr", attrs: { class: "navbar-divider" } },
                                                                    { tag: "a", attrs: { class: "navbar-item", href: "/about" }, content: "About" },
                                                                    { tag: "hr", attrs: { class: "navbar-divider" } },
                                                                    { tag: "a", attrs: { class: "navbar-item has-text-red", href: "https://github.com/raku/doc-website/issues" }, content: "Report an issue with this site" },
                                                                    { tag: "hr", attrs: { class: "navbar-divider" } },
                                                                    { tag: "a", attrs: { class: "navbar-item", href: "https://github.com/raku/doc/issues" }, content: "Report an issue with the documentation content" }
                                                                ]
                                                            }
                                                        ]
                                                    }
                                                ]
                                            },
                                            {
                                                tag: "div",
                                                attrs: { class: "navbar-end navbar-search-wrapper" },
                                                content: [
                                                    {
                                                        tag: "div",
                                                        attrs: { class: "navbar-item" },
                                                        content: [
                                                            {
                                                                tag: "div",
                                                                attrs: { class: "field has-addons" },
                                                                content: [
                                                                    {
                                                                        tag: "div",
                                                                        attrs: { class: "autoComplete_options" },
                                                                        content: [
                                                                            {
                                                                                tag: "input",
                                                                                attrs: {
                                                                                    class: "control input",
                                                                                    id: "autoComplete",
                                                                                    type: "search",
                                                                                    dir: "ltr",
                                                                                    spellcheck: "false",
                                                                                    autocorrect: "off",
                                                                                    autocomplete: "off",
                                                                                    autocapitalize: "off",
                                                                                    placeholder: "🔍 Type f to search for ..."
                                                                                }
                                                                            }
                                                                        ]
                                                                    },
                                                                    {
                                                                        tag: "div",
                                                                        attrs: { class: "control", title: "Search options" },
                                                                        content: [
                                                                            {
                                                                                tag: "a",
                                                                                attrs: {
                                                                                    class: "button is-primary js-modal-trigger",
                                                                                    "data-target": "options-search-info"
                                                                                },
                                                                                content: [
                                                                                    {
                                                                                        tag: "span",
                                                                                        attrs: { class: "icon" },
                                                                                        content: [{ tag: "i", attrs: { class: "fas fa-cogs" } }]
                                                                                    }
                                                                                ]
                                                                            }
                                                                        ]
                                                                    }
                                                                ]
                                                            }
                                                        ]
                                                    }
                                                ]
                                            },
                                            {
                                                tag: "div",
                                                attrs: { id: "options-search-info", class: "modal" },
                                                content: [
                                                    { tag: "div", attrs: { class: "modal-background" } },
                                                    {
                                                        tag: "div",
                                                        attrs: { class: "modal-content" },
                                                        content: [
                                                            {
                                                                tag: "div",
                                                                attrs: { class: "box" },
                                                                content: [
                                                                    { tag: "p", content: ["The last search was: ", { tag: "span", attrs: { id: "selected-candidate", class: "ss-selected" } }] },
                                                                    {
                                                                        tag: "div",
                                                                        attrs: { class: "control is-grouped is-grouped-centered options-search-controls" },
                                                                        content: [
                                                                            {
                                                                                tag: "label",
                                                                                attrs: { class: "centreToggle", title: "Include extra information (Alt-E)", style: "--switch-width: 10.5" },
                                                                                content: [
                                                                                    { tag: "input", attrs: { id: "options-search-extra", type: "checkbox" } },
                                                                                    { tag: "span", attrs: { class: "text" }, content: "Extra info" },
                                                                                    { tag: "span", attrs: { class: "on" }, content: "yes" },
                                                                                    { tag: "span", attrs: { class: "off" }, content: "no" }
                                                                                ]
                                                                            },
                                                                            { tag: "p", content: "The search response can be shortened by excluding the extra information line (Alt-E)" },
                                                                            {
                                                                                tag: "label",
                                                                                attrs: { class: "centreToggle", title: "Search engine type Strict/Loose (Alt-L)", style: "--switch-width: 10.5" },
                                                                                content: [
                                                                                    { tag: "input", attrs: { id: "options-search-loose", type: "checkbox" } },
                                                                                    { tag: "span", attrs: { class: "text" }, content: "Search type" },
                                                                                    { tag: "span", attrs: { class: "on" }, content: "loose" },
                                                                                    { tag: "span", attrs: { class: "off" }, content: "strict" }
                                                                                ]
                                                                            },
                                                                            { tag: "p", content: " The search engine can perform a strict search (only the characters in the search box) or a loose search (Alt-L)" },
                                                                            {
                                                                                tag: "label",
                                                                                attrs: { class: "centreToggle", title: "Search in headings (Alt-H)", style: "--switch-width: 10.5" },
                                                                                content: [
                                                                                    { tag: "input", attrs: { id: "options-search-headings", type: "checkbox" } },
                                                                                    { tag: "span", attrs: { class: "text" }, content: "Headings" },
                                                                                    { tag: "span", attrs: { class: "on" }, content: "yes" },
                                                                                    { tag: "span", attrs: { class: "off" }, content: "no" }
                                                                                ]
                                                                            },
                                                                            { tag: "p", content: "Search through headings in all web-pages (Alt-H)" },
                                                                            {
                                                                                tag: "label",
                                                                                attrs: { class: "centreToggle", title: "Search indexed items (Alt-I)", style: "--switch-width: 10.5" },
                                                                                content: [
                                                                                    { tag: "input", attrs: { id: "options-search-indexed", type: "checkbox" } },
                                                                                    { tag: "span", attrs: { class: "text" }, content: "Indexed" },
                                                                                    { tag: "span", attrs: { class: "on" }, content: "yes" },
                                                                                    { tag: "span", attrs: { class: "off" }, content: "no" }
                                                                                ]
                                                                            },
                                                                            { tag: "p", content: "Search through all indexed items (Alt-I)" },
                                                                            {
                                                                                tag: "label",
                                                                                attrs: { class: "centreToggle", title: "Search composite pages (Alt-C)", style: "--switch-width: 10.5" },
                                                                                content: [
                                                                                    { tag: "input", attrs: { id: "options-search-composite", type: "checkbox" } },
                                                                                    { tag: "span", attrs: { class: "text" }, content: "Composite" },
                                                                                    { tag: "span", attrs: { class: "on" }, content: "yes" },
                                                                                    { tag: "span", attrs: { class: "off" }, content: "no" }
                                                                                ]
                                                                            },
                                                                            { tag: "p", content: "Search in the names of composite pages, which combine similar information from the main web pages (Alt-C)" },
                                                                            {
                                                                                tag: "label",
                                                                                attrs: { class: "centreToggle", title: "Search primary sources (Alt-P)", style: "--switch-width: 10.5" },
                                                                                content: [
                                                                                    { tag: "input", attrs: { id: "options-search-primary", type: "checkbox" } },
                                                                                    { tag: "span", attrs: { class: "text" }, content: "Primary" },
                                                                                    { tag: "span", attrs: { class: "on" }, content: "yes" },
                                                                                    { tag: "span", attrs: { class: "off" }, content: "no" }
                                                                                ]
                                                                            },
                                                                            { tag: "p", content: "Search through the names of the main web pages (Alt-P)" },
                                                                            {
                                                                                tag: "label",
                                                                                attrs: { class: "centreToggle", title: "Open in new tab (Alt-Q)", style: "--switch-width: 10.5" },
                                                                                content: [
                                                                                    { tag: "input", attrs: { id: "options-search-newtab", type: "checkbox" } },
                                                                                    { tag: "span", attrs: { class: "text" }, content: "New tab" },
                                                                                    { tag: "span", attrs: { class: "on" }, content: "yes" },
                                                                                    { tag: "span", attrs: { class: "off" }, content: "no" }
                                                                                ]
                                                                            },
                                                                            { tag: "p", content: "Once a search candidate has been chosen, it can be opened in a new tab or in the current tab (Alt-Q)" },
                                                                            { tag: "p", content: "If all else fails, an item is added to use the Google search engine on the whole site" },
                                                                            { tag: "button", attrs: { class: "button is-warning", id: "options-search-reset-defaults" }, content: "Clear options, reset to defaults" },
                                                                            { tag: "p", content: "Exit this page by pressing <Escape>, or clicking on X or on the background." }
                                                                        ]
                                                                    }
                                                                ]
                                                            }
                                                        ]
                                                    },
                                                    { tag: "button", attrs: { class: "modal-close is-large", "aria-label": "close" } }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        tag: "div",
                                        attrs: { id: "download-ebook", class: "modal" },
                                        content: [
                                            { tag: "div", attrs: { class: "modal-background" } },
                                            {
                                                tag: "div",
                                                attrs: { class: "modal-content" },
                                                content: [
                                                    {
                                                        tag: "div",
                                                        attrs: { class: "box" },
                                                        content: [
                                                            { tag: "p", content: [{ tag: "a", attrs: { href: "/RakuDocumentation.epub", download: "" }, content: "RakuDocumentation.epub" }, " is a work in progress e-book. It targets the ", { tag: "a", attrs: { href: "https://www.w3.org/publishing/epub3/" }, content: "EPUB v3 specification" }, ". It needs testing on a variety of ereaders (some of which may still implicitly expect compliance with EPUB v2). The CSS definitely needs enhancing (especially for code snippets). The Ebook opens in a Calibre reader, which is available on all operating systems." ] },
                                                            { tag: "p", content: "Suggestions are welcome and should be addressed by opening an issue on the Raku/doc-website repository" },
                                                            { tag: "p", content: "Exit this popup by pressing <Escape>, or clicking on X or on the background." }
                                                        ]
                                                    }
                                                ]
                                            },
                                            { tag: "button", attrs: { class: "modal-close is-large", "aria-label": "close" } }
                                        ]
                                    }
                                ]
                            }
                        ]
                    },
                    {
                        tag: "div",
                        attrs: { id: "wrapper" },
                        content: [
                            {
                                tag: "section",
                                attrs: { class: "hero is-medium is-primary" },
                                content: [
                                    {
                                        tag: "div",
                                        attrs: { class: "hero-body" },
                                        content: [
                                            {
                                                tag: "div",
                                                attrs: { class: "container" },
                                                content: [
                                                    { tag: "h1", attrs: { class: "title is-1 is-size-2-mobile has-text-centered" }, content: "Raku documentation" },
                                                    { tag: "h2", attrs: { class: "subtitle is-4 has-text-centered mt-3" }, content: ["Welcome to the official documentation of the Raku", { tag: "sup", content: "®" }, " programming language!"] }
                                                ]
                                            }
                                        ]
                                    }
                                ]
                            },
                            {
                                tag: "section",
                                attrs: { class: "section" },
                                content: [
                                    {
                                        tag: "div",
                                        attrs: { class: "container px-4" },
                                        content: [
                                            {
                                                tag: "div",
                                                attrs: { class: "columns is-multiline" },
                                                content: [
                                                    // Card 1
                                                    {
                                                        tag: "div",
                                                        attrs: { class: "column is-one-half" },
                                                        content: [
                                                            {
                                                                tag: "div",
                                                                attrs: { class: "card card-home" },
                                                                content: [
                                                                    {
                                                                        tag: "div",
                                                                        attrs: { class: "card-content" },
                                                                        content: [
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "a",
                                                                                        attrs: { href: "/introduction" },
                                                                                        content: [
                                                                                            {
                                                                                                tag: "span",
                                                                                                attrs: { class: "icon is-large has-text-primary" },
                                                                                                content: [{ tag: "i", attrs: { class: "fas fa-graduation-cap icon-large" } }]
                                                                                            }
                                                                                        ]
                                                                                    }
                                                                                ]
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "content has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "p",
                                                                                        attrs: { class: "title is-5 has-text-primary" },
                                                                                        content: [{ tag: "a", attrs: { href: "/introduction" }, content: "Getting started, Migration guides from other languages, & Tutorials" }]
                                                                                    }
                                                                                ]
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "content has-text-centered" },
                                                                                content: "Documents introducing the language for various audiences."
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "a",
                                                                                        attrs: { class: "button is-primary", href: "/introduction" },
                                                                                        content: [{ tag: "strong", content: "Learn more" }]
                                                                                    }
                                                                                ]
                                                                            }
                                                                        ]
                                                                    }
                                                                ]
                                                            }
                                                        ]
                                                    },
                                                    // Card 2
                                                    {
                                                        tag: "div",
                                                        attrs: { class: "column is-one-half" },
                                                        content: [
                                                            {
                                                                tag: "div",
                                                                attrs: { class: "card card-home" },
                                                                content: [
                                                                    {
                                                                        tag: "div",
                                                                        attrs: { class: "card-content" },
                                                                        content: [
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "a",
                                                                                        attrs: { href: "/reference" },
                                                                                        content: [
                                                                                            {
                                                                                                tag: "span",
                                                                                                attrs: { class: "icon is-large has-text-primary" },
                                                                                                content: [{ tag: "i", attrs: { class: "fas fa-book icon-large" } }]
                                                                                            }
                                                                                        ]
                                                                                    }
                                                                                ]
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "content has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "p",
                                                                                        attrs: { class: "title is-5 has-text-primary" },
                                                                                        content: [{ tag: "a", attrs: { href: "/reference" }, content: "Language References" }]
                                                                                    }
                                                                                ]
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "content has-text-centered" },
                                                                                content: "Documents explaining the various conceptual parts of the language."
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "a",
                                                                                        attrs: { class: "button is-primary", href: "/reference" },
                                                                                        content: [{ tag: "strong", content: "Learn more" }]
                                                                                    }
                                                                                ]
                                                                            }
                                                                        ]
                                                                    }
                                                                ]
                                                            }
                                                        ]
                                                    },
                                                    // Card 3
                                                    {
                                                        tag: "div",
                                                        attrs: { class: "column is-one-third" },
                                                        content: [
                                                            {
                                                                tag: "div",
                                                                attrs: { class: "card card-home" },
                                                                content: [
                                                                    {
                                                                        tag: "div",
                                                                        attrs: { class: "card-content" },
                                                                        content: [
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "a",
                                                                                        attrs: { href: "/types" },
                                                                                        content: [
                                                                                            {
                                                                                                tag: "span",
                                                                                                attrs: { class: "icon is-large has-text-primary" },
                                                                                                content: [{ tag: "i", attrs: { class: "fas fa-layer-group icon-large" } }]
                                                                                            }
                                                                                        ]
                                                                                    }
                                                                                ]
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "content has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "p",
                                                                                        attrs: { class: "title is-5 has-text-primary" },
                                                                                        content: [{ tag: "a", attrs: { href: "/types" }, content: "Type Reference" }]
                                                                                    }
                                                                                ]
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "content has-text-centered" },
                                                                                content: "Index of built-in classes, roles and enums."
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "a",
                                                                                        attrs: { class: "button is-primary", href: "/types" },
                                                                                        content: [{ tag: "strong", content: "Learn more" }]
                                                                                    }
                                                                                ]
                                                                            }
                                                                        ]
                                                                    }
                                                                ]
                                                            }
                                                        ]
                                                    },
                                                    // Card 4
                                                    {
                                                        tag: "div",
                                                        attrs: { class: "column is-one-third" },
                                                        content: [
                                                            {
                                                                tag: "div",
                                                                attrs: { class: "card card-home" },
                                                                content: [
                                                                    {
                                                                        tag: "div",
                                                                        attrs: { class: "card-content" },
                                                                        content: [
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "a",
                                                                                        attrs: { href: "/routines" },
                                                                                        content: [
                                                                                            {
                                                                                                tag: "span",
                                                                                                attrs: { class: "icon is-large has-text-primary" },
                                                                                                content: [{ tag: "i", attrs: { class: "fas fa-paperclip icon-large" } }]
                                                                                            }
                                                                                        ]
                                                                                    }
                                                                                ]
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "content has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "p",
                                                                                        attrs: { class: "title is-5 has-text-primary" },
                                                                                        content: [{ tag: "a", attrs: { href: "/routines" }, content: "Routine Reference" }]
                                                                                    }
                                                                                ]
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "content has-text-centered" },
                                                                                content: "Index of built-in subroutines and methods."
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "a",
                                                                                        attrs: { class: "button is-primary", href: "/routines" },
                                                                                        content: [{ tag: "strong", content: "Learn more" }]
                                                                                    }
                                                                                ]
                                                                            }
                                                                        ]
                                                                    }
                                                                ]
                                                            }
                                                        ]
                                                    },
                                                    // Card 5
                                                    {
                                                        tag: "div",
                                                        attrs: { class: "column is-one-third" },
                                                        content: [
                                                            {
                                                                tag: "div",
                                                                attrs: { class: "card card-home" },
                                                                content: [
                                                                    {
                                                                        tag: "div",
                                                                        attrs: { class: "card-content" },
                                                                        content: [
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "a",
                                                                                        attrs: { href: "/miscellaneous" },
                                                                                        content: [
                                                                                            {
                                                                                                tag: "span",
                                                                                                attrs: { class: "icon is-large has-text-primary" },
                                                                                                content: [{ tag: "i", attrs: { class: "fas fa-code icon-large" } }]
                                                                                            }
                                                                                        ]
                                                                                    }
                                                                                ]
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "content has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "p",
                                                                                        attrs: { class: "title is-5 has-text-primary" },
                                                                                        content: [{ tag: "a", attrs: { href: "/miscellaneous" }, content: "Miscellaneous" }]
                                                                                    }
                                                                                ]
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "content has-text-centered" },
                                                                                content: "Documents explaining experimental topics and Raku programs rather than the language itself."
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "a",
                                                                                        attrs: { class: "button is-primary", href: "/miscellaneous" },
                                                                                        content: [{ tag: "strong", content: "Learn more" }]
                                                                                    }
                                                                                ]
                                                                            }
                                                                        ]
                                                                    }
                                                                ]
                                                            }
                                                        ]
                                                    },
                                                    // Card 6
                                                    {
                                                        tag: "div",
                                                        attrs: { class: "column is-one-half" },
                                                        content: [
                                                            {
                                                                tag: "div",
                                                                attrs: { class: "card card-home" },
                                                                content: [
                                                                    {
                                                                        tag: "div",
                                                                        attrs: { class: "card-content" },
                                                                        content: [
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "a",
                                                                                        attrs: { href: "/language/faq" },
                                                                                        content: [
                                                                                            {
                                                                                                tag: "span",
                                                                                                attrs: { class: "icon is-large has-text-primary" },
                                                                                                content: [
                                                                                                    {
                                                                                                        tag: "svg",
                                                                                                        attrs: {
                                                                                                            class: "svg-inline--fa fa-question-circle fa-w-16 icon-large",
                                                                                                            "aria-hidden": "true",
                                                                                                            "data-prefix": "fas",
                                                                                                            "data-icon": "question-circle",
                                                                                                            role: "img",
                                                                                                            xmlns: "http://www.w3.org/2000/svg",
                                                                                                            viewBox: "0 0 512 512",
                                                                                                            "data-fa-i2svg": ""
                                                                                                        },
                                                                                                        content: [
                                                                                                            {
                                                                                                                tag: "path",
                                                                                                                attrs: {
                                                                                                                    fill: "currentColor",
                                                                                                                    d: "M504 256c0 136.997-111.043 248-248 248S8 392.997 8 256C8 119.083 119.043 8 256 8s248 111.083 248 248zM262.655 90c-54.497 0-89.255 22.957-116.549 63.758-3.536 5.286-2.353 12.415 2.715 16.258l34.699 26.31c5.205 3.947 12.621 3.008 16.665-2.122 17.864-22.658 30.113-35.797 57.303-35.797 20.429 0 45.698 13.148 45.698 32.958 0 14.976-12.363 22.667-32.534 33.976C247.128 238.528 216 254.941 216 296v4c0 6.627 5.373 12 12 12h56c6.627 0 12-5.373 12-12v-1.333c0-28.462 83.186-29.647 83.186-106.667 0-58.002-60.165-102-116.531-102zM256 338c-25.365 0-46 20.635-46 46 0 25.364 20.635 46 46 46s46-20.636 46-46c0-25.365-20.635-46-46-46z"
                                                                                                                }
                                                                                                            }
                                                                                                        ]
                                                                                                    }
                                                                                                ]
                                                                                            }
                                                                                        ]
                                                                                    }
                                                                                ]
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "content has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "p",
                                                                                        attrs: { class: "title is-5 has-text-primary" },
                                                                                        content: [{ tag: "a", attrs: { href: "/language/faq" }, content: "FAQs (Frequently Asked Questions)" }]
                                                                                    }
                                                                                ]
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "content has-text-centered" },
                                                                                content: "A collection of questions that have cropped up often, along with answers."
                                                                            },
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "a",
                                                                                        attrs: { class: "button is-primary", href: "/language/faq" },
                                                                                        content: [{ tag: "strong", content: "Learn more" }]
                                                                                    }
                                                                                ]
                                                                            }
                                                                        ]
                                                                    }
                                                                ]
                                                            }
                                                        ]
                                                    },
                                                    // Card 7
                                                    {
                                                        tag: "div",
                                                        attrs: { class: "column is-one-half" },
                                                        content: [
                                                            {
                                                                tag: "div",
                                                                attrs: { class: "card card-home" },
                                                                content: [
                                                                    {
                                                                        tag: "div",
                                                                        attrs: { class: "card-content" },
                                                                        content: [
                                                                            {
                                                                                tag: "div",
                                                                                attrs: { class: "has-text-centered" },
                                                                                content: [
                                                                                    {
                                                                                        tag: "a",
                                                                                        attrs: { href: "/language/community" },
                                                                                        content: [
                                                                                            {
                                                                                                tag: "span",
                                                                                                attrs: { class: "icon is-large has-text-primary" },
                                                                                                content: [
                                                                                                    {
                                                                                                        tag: "svg",
                                                                                                        attrs: {
                                                                                                            class: "svg-inline--fa fa-user-friends fa-w-20 icon-large",
                                                                                                            "aria-hidden": "true",
                                                                                                            "data-prefix": "fas",
                                                                                                            "data-icon": "user-friends",
                                                                                                            role: "img",
                                                                                                            xmlns: "http://www.w3.org/2000/svg",
                                                                                                            viewBox: "0 0 640 512",
                                                                                                            "data-fa-i2svg": ""
                                                                                                        },
                                                                                                        content: [
                                                                                                            {
                                                                                                                tag: "path",
                                                                                                                attrs: {
                                                                                                                    fill: "currentColor",
                                                                                                                    d: "M192 256c61.9 0 112-50.1 112-112S253.9 32 192 32 80 82.1 80 144s50.1 112 112 112zm76.8 32h-8.3c-20
