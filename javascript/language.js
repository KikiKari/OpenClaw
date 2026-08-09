#!/usr/bin/env node
// language.html — portiert nach javascript
// Quelle: html, OpenClaw@gateway1:skills/scripting-utils/references/raku/language.html
// auch in: OpenClaw@gateway2:skills/scripting-utils/references/raku/language.html
// Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');

function generate404Page() {
    const docType = '<!DOCTYPE html>';
    
    const html = {
        tag: 'html',
        attrs: {
            lang: 'en',
            class: 'fontawesome-i2svg-active fontawesome-i2svg-complete',
            style: 'scroll-padding-top:60px'
        },
        children: []
    };

    // Head section
    const head = {
        tag: 'head',
        children: [
            { tag: 'title', children: ['404 | Raku Documentation'] },
            { tag: 'meta', attrs: { charset: 'UTF-8' } },
            { tag: 'link', attrs: { href: '/assets/images/Camelia.ico', rel: 'icon', type: 'image/x-icon' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/Website.css' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/css/filtered-toc-dark.css', title: 'dark' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/css/filtered-toc-light.css', title: 'light' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/css/rainbow-dark.css', title: 'dark' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/css/rainbow-light.css', title: 'light' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/tm-styling.css' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/tm-light.css', title: 'light' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/tm-dark.css', title: 'dark' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/all.min.css' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/listf-styling-light.css', title: 'light' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/listf-styling-dark.css', title: 'dark' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/typegraph-styling.css' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/typegraph-dark.css', title: 'dark' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/typegraph-light.css', title: 'light' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/css/page-styling-main.css' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/css/page-styling-dark.css', title: 'dark' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/css/page-styling-light.css', title: 'light' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/css/chyronToggle-dark.css', title: 'dark' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/css/chyronToggle-light.css', title: 'light' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/css/centreToggle-dark.css', title: 'dark' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/css/centreToggle-light.css', title: 'light' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/css/options-search-light.css', title: 'light' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: '/assets/css/css/options-search-dark.css', title: 'dark' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-light.min.css', title: 'light' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-dark.min.css', title: 'dark' } },
            { tag: 'link', attrs: { rel: 'stylesheet', href: 'https://cdn.jsdelivr.net/npm/@tarekraafat/autocomplete.js@10.2.7/dist/css/autoComplete.min.css' } },
            { tag: 'script', attrs: { src: 'https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js' } },
            { tag: 'script', attrs: { src: '/assets/scripts/all.min.js' } },
            { tag: 'script', attrs: { src: '/assets/scripts/tableManager.js' } },
            { tag: 'script', attrs: { src: '/assets/scripts/filter-script.js' } },
            { tag: 'script', attrs: { src: 'https://cdn.jsdelivr.net/npm/fuzzysort@2.0.4/fuzzysort.min.js' } },
            { tag: 'script', attrs: { src: 'https://cdn.jsdelivr.net/npm/@tarekraafat/autocomplete.js@10.2.7/dist/autoComplete.min.js' } },
            { tag: 'script', attrs: { src: '/assets/scripts/filtered-toc.js' } },
            { tag: 'script', attrs: { src: 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js' } },
            { tag: 'script', attrs: { src: 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/haskell.min.js' } },
            { tag: 'script', attrs: { src: '/assets/scripts/options-search.js' } },
            { tag: 'script', attrs: { src: '/assets/scripts/page-styling.js' } },
            { tag: 'script', attrs: { src: '/assets/scripts/rainbow.js' } }
        ]
    };

    // Body section
    const body = {
        tag: 'body',
        attrs: { class: 'has-navbar-fixed-top' },
        children: [
            { tag: 'div', attrs: { id: '404', class: 'top-of-page' } },
            {
                tag: 'nav',
                attrs: { class: 'navbar is-fixed-top is-flex-touch', role: 'navigation', 'aria-label': 'main navigation' },
                children: [
                    {
                        tag: 'div',
                        attrs: { class: 'navbar-item', style: 'margin-left: auto;' },
                        children: [
                            {
                                tag: 'div',
                                attrs: { class: 'left-bar-toggle', title: 'Toggle Table of Contents & Index' },
                                children: [
                                    {
                                        tag: 'label',
                                        attrs: { class: 'chyronToggle left' },
                                        children: [
                                            { tag: 'input', attrs: { id: 'navbar-left-toggle', type: 'checkbox' } },
                                            { tag: 'span', attrs: { class: 'text' }, children: ['Contents'] }
                                        ]
                                    }
                                ]
                            }
                        ]
                    },
                    {
                        tag: 'div',
                        attrs: { class: 'container is-justify-content-space-around' },
                        children: [
                            {
                                tag: 'div',
                                attrs: { class: 'navbar-brand' },
                                children: [
                                    {
                                        tag: 'div',
                                        attrs: { class: 'navbar-logo' },
                                        children: [
                                            {
                                                tag: 'a',
                                                attrs: { class: 'navbar-item', href: '/' },
                                                children: [
                                                    {
                                                        tag: 'img',
                                                        attrs: {
                                                            src: '/assets/images/camelia-recoloured.png',
                                                            alt: 'Raku',
                                                            width: '52.83',
                                                            height: '38'
                                                        }
                                                    }
                                                ]
                                            },
                                            { tag: 'span', attrs: { class: 'navbar-logo-tm' }, children: ['tm'] }
                                        ]
                                    },
                                    {
                                        tag: 'a',
                                        attrs: {
                                            role: 'button',
                                            class: 'navbar-burger burger',
                                            'aria-label': 'menu',
                                            'aria-expanded': 'false',
                                            'data-target': 'navMenu'
                                        },
                                        children: [
                                            { tag: 'span', attrs: { 'aria-hidden': 'true' } },
                                            { tag: 'span', attrs: { 'aria-hidden': 'true' } },
                                            { tag: 'span', attrs: { 'aria-hidden': 'true' } }
                                        ]
                                    }
                                ]
                            },
                            {
                                tag: 'div',
                                attrs: { id: 'navMenu', class: 'navbar-menu' },
                                children: [
                                    {
                                        tag: 'div',
                                        attrs: { class: 'navbar-start' },
                                        children: [
                                            {
                                                tag: 'a',
                                                attrs: { class: 'navbar-item', href: '/introduction', title: 'Getting started, Tutorials, Migration guides' },
                                                children: ['Introduction']
                                            },
                                            {
                                                tag: 'a',
                                                attrs: { class: 'navbar-item', href: '/reference', title: 'Fundamentals, General reference' },
                                                children: ['Reference']
                                            },
                                            {
                                                tag: 'a',
                                                attrs: { class: 'navbar-item', href: '/miscellaneous', title: 'Programs, Experimental' },
                                                children: ['Miscellaneous']
                                            },
                                            {
                                                tag: 'a',
                                                attrs: { class: 'navbar-item', href: '/types', title: 'The core types (classes) available' },
                                                children: ['Types']
                                            },
                                            {
                                                tag: 'a',
                                                attrs: { class: 'navbar-item', href: '/routines', title: 'Searchable table of routines' },
                                                children: ['Routines']
                                            },
                                            {
                                                tag: 'a',
                                                attrs: { class: 'navbar-item', href: 'https://raku.org', title: 'Home page for community' },
                                                children: ['Raku', { tag: 'sup', attrs: { class: 'raku' }, children: ['®'] }]
                                            },
                                            {
                                                tag: 'a',
                                                attrs: { class: 'navbar-item', href: 'https://web.libera.chat/#raku', title: 'IRC live chat' },
                                                children: ['Chat']
                                            },
                                            {
                                                tag: 'div',
                                                attrs: { class: 'navbar-item has-dropdown is-hoverable' },
                                                children: [
                                                    { tag: 'a', attrs: { class: 'navbar-link' }, children: ['More'] },
                                                    {
                                                        tag: 'div',
                                                        attrs: { class: 'navbar-dropdown is-right is-rounded' },
                                                        children: [
                                                            { tag: 'hr', attrs: { class: 'navbar-divider' } },
                                                            {
                                                                tag: 'a',
                                                                attrs: { class: 'navbar-item js-modal-trigger', 'data-target': 'download-ebook' },
                                                                children: ['Download E-Book (epub)']
                                                            },
                                                            { tag: 'hr', attrs: { class: 'navbar-divider' } },
                                                            {
                                                                tag: 'a',
                                                                attrs: { class: 'navbar-item', href: '/about' },
                                                                children: ['About']
                                                            },
                                                            { tag: 'hr', attrs: { class: 'navbar-divider' } },
                                                            {
                                                                tag: 'a',
                                                                attrs: { class: 'navbar-item has-text-red', href: 'https://github.com/raku/doc-website/issues' },
                                                                children: ['Report an issue with this site']
                                                            },
                                                            { tag: 'hr', attrs: { class: 'navbar-divider' } },
                                                            {
                                                                tag: 'a',
                                                                attrs: { class: 'navbar-item', href: 'https://github.com/raku/doc/issues' },
                                                                children: ['Report an issue with the documentation content']
                                                            }
                                                        ]
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        tag: 'div',
                                        attrs: { class: 'navbar-end navbar-search-wrapper' },
                                        children: [
                                            {
                                                tag: 'div',
                                                attrs: { class: 'navbar-item' },
                                                children: [
                                                    {
                                                        tag: 'div',
                                                        attrs: { class: 'field has-addons' },
                                                        children: [
                                                            {
                                                                tag: 'div',
                                                                attrs: { class: 'autoComplete_options' },
                                                                children: [
                                                                    {
                                                                        tag: 'input',
                                                                        attrs: {
                                                                            class: 'control input',
                                                                            id: 'autoComplete',
                                                                            type: 'search',
                                                                            dir: 'ltr',
                                                                            spellcheck: 'false',
                                                                            autocorrect: 'off',
                                                                            autocomplete: 'off',
                                                                            autocapitalize: 'off',
                                                                            placeholder: '🔍 Type f to search for ...'
                                                                        }
                                                                    }
                                                                ]
                                                            },
                                                            {
                                                                tag: 'div',
                                                                attrs: { class: 'control', title: 'Search options' },
                                                                children: [
                                                                    {
                                                                        tag: 'a',
                                                                        attrs: {
                                                                            class: 'button is-primary js-modal-trigger',
                                                                            'data-target': 'options-search-info'
                                                                        },
                                                                        children: [
                                                                            {
                                                                                tag: 'span',
                                                                                attrs: { class: 'icon' },
                                                                                children: [
                                                                                    { tag: 'i', attrs: { class: 'fas fa-cogs' } }
                                                                                ]
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
                                        tag: 'div',
                                        attrs: { id: 'options-search-info', class: 'modal' },
                                        children: [
                                            { tag: 'div', attrs: { class: 'modal-background' } },
                                            {
                                                tag: 'div',
                                                attrs: { class: 'modal-content' },
                                                children: [
                                                    {
                                                        tag: 'div',
                                                        attrs: { class: 'box' },
                                                        children: [
                                                            {
                                                                tag: 'p',
                                                                children: ['The last search was: ', { tag: 'span', attrs: { id: 'selected-candidate', class: 'ss-selected' } }]
                                                            },
                                                            {
                                                                tag: 'div',
                                                                attrs: { class: 'control is-grouped is-grouped-centered options-search-controls' },
                                                                children: [
                                                                    {
                                                                        tag: 'label',
                                                                        attrs: {
                                                                            class: 'centreToggle',
                                                                            title: 'Include extra information (Alt-E)',
                                                                            style: '--switch-width: 10.5'
                                                                        },
                                                                        children: [
                                                                            { tag: 'input', attrs: { id: 'options-search-extra', type: 'checkbox' } },
                                                                            { tag: 'span', attrs: { class: 'text' }, children: ['Extra info'] },
                                                                            { tag: 'span', attrs: { class: 'on' }, children: ['yes'] },
                                                                            { tag: 'span', attrs: { class: 'off' }, children: ['no'] }
                                                                        ]
                                                                    },
                                                                    {
                                                                        tag: 'p',
                                                                        children: ['The search response can be shortened by excluding the extra information line (Alt-E)']
                                                                    },
                                                                    {
                                                                        tag: 'label',
                                                                        attrs: {
                                                                            class: 'centreToggle',
                                                                            title: 'Search engine type Strict/Loose (Alt-L)',
                                                                            style: '--switch-width: 10.5'
                                                                        },
                                                                        children: [
                                                                            { tag: 'input', attrs: { id: 'options-search-loose', type: 'checkbox' } },
                                                                            { tag: 'span', attrs: { class: 'text' }, children: ['Search type'] },
                                                                            { tag: 'span', attrs: { class: 'on' }, children: ['loose'] },
                                                                            { tag: 'span', attrs: { class: 'off' }, children: ['strict'] }
                                                                        ]
                                                                    },
                                                                    {
                                                                        tag: 'p',
                                                                        children: [' The search engine can perform a strict search (only the characters in the search box) or a loose search (Alt-L)']
                                                                    },
                                                                    {
                                                                        tag: 'label',
                                                                        attrs: {
                                                                            class: 'centreToggle',
                                                                            title: 'Search in headings (Alt-H)',
                                                                            style: '--switch-width: 10.5'
                                                                        },
                                                                        children: [
                                                                            { tag: 'input', attrs: { id: 'options-search-headings', type: 'checkbox' } },
                                                                            { tag: 'span', attrs: { class: 'text' }, children: ['Headings'] },
                                                                            { tag: 'span', attrs: { class: 'on' }, children: ['yes'] },
                                                                            { tag: 'span', attrs: { class: 'off' }, children: ['no'] }
                                                                        ]
                                                                    },
                                                                    { tag: 'p', children: ['Search through headings in all web-pages (Alt-H)'] },
                                                                    {
                                                                        tag: 'label',
                                                                        attrs: {
                                                                            class: 'centreToggle',
                                                                            title: 'Search indexed items (Alt-I)',
                                                                            style: '--switch-width: 10.5'
                                                                        },
                                                                        children: [
                                                                            { tag: 'input', attrs: { id: 'options-search-indexed', type: 'checkbox' } },
                                                                            { tag: 'span', attrs: { class: 'text' }, children: ['Indexed'] },
                                                                            { tag: 'span', attrs: { class: 'on' }, children: ['yes'] },
                                                                            { tag: 'span', attrs: { class: 'off' }, children: ['no'] }
                                                                        ]
                                                                    },
                                                                    { tag: 'p', children: ['Search through all indexed items (Alt-I)'] },
                                                                    {
                                                                        tag: 'label',
                                                                        attrs: {
                                                                            class: 'centreToggle',
                                                                            title: 'Search composite pages (Alt-C)',
                                                                            style: '--switch-width: 10.5'
                                                                        },
                                                                        children: [
                                                                            { tag: 'input', attrs: { id: 'options-search-composite', type: 'checkbox' } },
                                                                            { tag: 'span', attrs: { class: 'text' }, children: ['Composite'] },
                                                                            { tag: 'span', attrs: { class: 'on' }, children: ['yes'] },
                                                                            { tag: 'span', attrs: { class: 'off' }, children: ['no'] }
                                                                        ]
                                                                    },
                                                                    {
                                                                        tag: 'p',
                                                                        children: ['Search in the names of composite pages, which combine similar information from the main web pages (Alt-C)']
                                                                    },
                                                                    {
                                                                        tag: 'label',
                                                                        attrs: {
                                                                            class: 'centreToggle',
                                                                            title: 'Search primary sources (Alt-P)',
                                                                            style: '--switch-width: 10.5'
                                                                        },
                                                                        children: [
                                                                            { tag: 'input', attrs: { id: 'options-search-primary', type: 'checkbox' } },
                                                                            { tag: 'span', attrs: { class: 'text' }, children: ['Primary'] },
                                                                            { tag: 'span', attrs: { class: 'on' }, children: ['yes'] },
                                                                            { tag: 'span', attrs: { class: 'off' }, children: ['no'] }
                                                                        ]
                                                                    },
                                                                    { tag: 'p', children: ['Search through the names of the main web pages (Alt-P)'] },
                                                                    {
                                                                        tag: 'label',
                                                                        attrs: {
                                                                            class: 'centreToggle',
                                                                            title: 'Open in new tab (Alt-Q)',
                                                                            style: '--switch-width: 10.5'
                                                                        },
                                                                        children: [
                                                                            { tag: 'input', attrs: { id: 'options-search-newtab', type: 'checkbox' } },
                                                                            { tag: 'span', attrs: { class: 'text' }, children: ['New tab'] },
                                                                            { tag: 'span', attrs: { class: 'on' }, children: ['yes'] },
                                                                            { tag: 'span', attrs: { class: 'off' }, children: ['no'] }
                                                                        ]
                                                                    },
                                                                    {
                                                                        tag: 'p',
                                                                        children: ['Once a search candidate has been chosen, it can be opened in a new tab or in the current tab (Alt-Q)']
                                                                    },
                                                                    { tag: 'p', children: ['If all else fails, an item is added to use the Google search engine on the whole site'] },
                                                                    {
                                                                        tag: 'button',
                                                                        attrs: { class: 'button is-warning', id: 'options-search-reset-defaults' },
                                                                        children: ['Clear options, reset to defaults']
                                                                    },
                                                                    { tag: 'p', children: ['Exit this page by pressing <Escape>, or clicking on X or on the background.'] }
                                                                ]
                                                            }
                                                        ]
                                                    }
                                                ]
                                            },
                                            { tag: 'button', attrs: { class: 'modal-close is-large', 'aria-label': 'close' } }
                                        ]
                                    }
                                ]
                            },
                            {
                                tag: 'div',
                                attrs: { id: 'download-ebook', class: 'modal' },
                                children: [
                                    { tag: 'div', attrs: { class: 'modal-background' } },
                                    {
                                        tag: 'div',
                                        attrs: { class: 'modal-content' },
                                        children: [
                                            {
                                                tag: 'div',
                                                attrs: { class: 'box' },
                                                children: [
                                                    {
                                                        tag: 'p',
                                                        children: [
                                                            { tag: 'a', attrs: { href: '/RakuDocumentation.epub', download: '' }, children: ['RakuDocumentation.epub'] },
                                                            ' is a work in progress e-book. It targets the ',
                                                            { tag: 'a', attrs: { href: 'https://www.w3.org/publishing/epub3/' }, children: ['EPUB v3 specification'] },
                                                            '. It needs testing on a variety of ereaders (some of which may still implicitly expect compliance with EPUB v2). The CSS definitely needs enhancing (especially for code snippets). The Ebook opens in a Calibre reader, which is available on all operating systems.'
                                                        ]
                                                    },
                                                    {
                                                        tag: 'p',
                                                        children: ['Suggestions are welcome and should be addressed by opening an issue on the Raku/doc-website repository']
                                                    },
                                                    { tag: 'p', children: ['Exit this popup by pressing <Escape>, or clicking on X or on the background.'] }
                                                ]
                                            }
                                        ]
                                    },
                                    { tag: 'button', attrs: { class: 'modal-close is-large', 'aria-label': 'close' } }
                                ]
                            }
                        ]
                    }
                ]
            },
            {
                tag: 'div',
                attrs: { class: 'tile is-ancestor section' },
                children: [
                    {
                        tag: 'div',
                        attrs: { class: 'page-edit' },
                        children: [
                            {
                                tag: 'a',
                                attrs: {
                                    class: 'button page-edit-button',
                                    href: 'https://github.com/Raku/doc-website/edit/main/Website/structure-sources/404.rakudoc',
                                    title: 'Edit this page.\nCommit: 0ead45c 2026-04-04'
                                },
                                children: [
                                    {
                                        tag: 'span',
                                        attrs: { class: 'icon is-right' },
                                        children: [
                                            { tag: 'i', attrs: { class: 'fas fa-pen-alt is-medium' } }
                                        ]
                                    }
                                ]
                            }
                        ]
                    },
                    {
                        tag: 'div',
                        attrs: { id: 'left-column', class: 'tile is-parent is-2 is-hidden' },
                        children: [
                            {
                                tag: 'div',
                                attrs: { id: 'left-col-inner' },
                                children: [
                                    {
                                        tag: 'input',
                                        attrs: {
                                            type: 'checkbox',
                                            id: 'No-TOC',
                                            checked: 'checked',
                                            style: 'visibility: collapse;'
                                        }
                                    },
                                    { tag: 'div', attrs: { class: 'content' }, children: ['No Table of Contents or Index available'] }
                                ]
                            }
                        ]
                    },
                    {
                        tag: 'div',
                        attrs: { id: 'main-column', class: 'tile is-parent', style: 'overflow-x: hidden;' },
                        children: [
                            {
                                tag: 'div',
                                attrs: { id: 'main-col-inner' },
                                children: [
                                    {
                                        tag: 'section',
                                        attrs: { class: 'raku page-header' },
                                        children: [
                                            {
                                                tag: 'div',
                                                attrs: { class: 'container px-4' },
                                                children: [
                                                    {
                                                        tag: 'div',
                                                        attrs: { class: 'raku page-title has-text-centered' },
                                                        children: ['404']
                                                    },
                                                    {
                                                        tag: 'div',
                                                        attrs: { class: 'raku page-subtitle has-text-centered' },
                                                        children: []
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        tag: 'section',
                                        attrs: { class: 'raku page-content' },
                                        children: [
                                            {
                                                tag: 'div',
                                                attrs: { class: 'container px-4' },
                                                children: [
                                                    {
                                                        tag: 'div',
                                                        attrs: { class: 'columns one-col' },
                                                        children: [
                                                            { tag: 'img', attrs: { src: '/assets/images/Camelia-404.png', class: 'camelia' } },
                                                            {
                                                                tag: 'h2',
                                                                attrs: { id: '404:_Page_Not_Found', class: 'raku-h2' },
                                                                children: [
                                                                    {
                                                                        tag: 'a',
                                                                        attrs: { href: '#404', title: 'go to top of document' },
                                                                        children: [
                                                                            '404: Page Not Found',
                                                                            {
                                                                                tag: 'a',
                                                                                attrs: { class: 'raku-anchor', title: 'direct link', href: '#404:_Page_Not_Found' },
                                                                                children: ['§']
                                                                            }
                                                                        ]
                                                                    }
                                                                ]
                                                            },
                                                            { tag: 'p', children: ["We're sorry, but the content you tried to reach wasn't found."] },
                                                            {
                                                                tag: 'p',
                                                                children: [
                                                                    'While we do review server logs to catch these issues, we recently deployed a new version of the site, so please feel free to ',
                                                                    { tag: 'a', attrs: { href: 'https://github.com/Raku/doc-website/issues/' }, children: ['report any issues'] },
                                                                    '.'
                                                                ]
                                                            },
                                                            { tag: 'p', children: ['Thanks!'] }
                                                        ]
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
                tag: 'footer',
                attrs: { class: 'footer main-footer' },
                children: [
                    {
                        tag: 'div',
                        attrs: { class: 'container px-4' },
                        children: [
                            {
                                tag: 'nav',
                                attrs: { class: 'level' },
                                children: [
                                    {
                                        tag: 'div',
                                        attrs: { class: 'level-left' },
                                        children: [
                                            { tag: 'div', attrs: { class: 'level-item' }, children: [{ tag: 'a', attrs: { href: '/about' }, children: ['About'] }] },
                                            { tag: 'div', attrs: { class: 'level-item' }, children: [{ tag: 'a', attrs: { id: 'toggle-theme' }, children: ['Toggle theme'] }] },
                                            {
                                                tag: 'div',
                                                attrs: { class: 'level-item', title: '0ead45c 2026-04-04' },
                                                children: [{ tag: 'a', children: ['Commit'] }]
                                            }
                                        ]
                                    },
                                    {
                                        tag: 'div',
                                        attrs: { class: 'level-right' },
                                        children: [
                                            { tag: 'div', attrs: { class: 'level-item' }, children: [{ tag: 'a', attrs: { href: '/license' }, children: ['License'] }] }
                                        ]
                                    }
                                ]
                            }
                        ]
                    }
                ]
            }
        ]
    };

    html.children.push(head);
    html.children.push(body);

    return { docType, html };
}

function renderElement(element) {
    if (typeof element === 'string') {
        return element;
    }

    if (element.children === undefined) {
        const attrs = element.attrs ? Object.entries(element.attrs).map(([k, v]) => `${k}="${v}"`).join(' ') : '';
        return `<${element.tag}${attrs ? ' ' + attrs : ''}>`;
    }

    const attrs = element.attrs ? Object.entries(element.attrs).map(([k, v]) => `${k}="${v}"`).join(' ') : '';
    const children = element.children.map(renderElement).join('');
    return `<${element.tag}${attrs ? ' ' + attrs : ''}>${children}</${element.tag}>`;
}

function generateHTMLString(structure) {
    const htmlString = renderElement(structure.html);
    return `${structure.docType}\n${htmlString}`;
}

// Main execution
if (process.argv.length < 3) {
    console.error('Usage: node script.js <output-file>');
    process.exit(1);
}

const outputFile = process.argv[2];
const pageStructure = generate404Page();
const htmlString = generateHTMLString(pageStructure);

fs.writeFileSync(outputFile, htmlString, 'utf8');
console.log(`404 page generated successfully: ${outputFile}`);
