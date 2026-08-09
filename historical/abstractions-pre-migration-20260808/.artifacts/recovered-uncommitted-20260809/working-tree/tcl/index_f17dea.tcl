#!/usr/bin/env tclsh
# index.html — portiert nach tcl
# Quelle: html, OpenClaw@gateway1:skills/scripting-utils/references/raku/index.html
# auch in: OpenClaw@gateway2:skills/scripting-utils/references/raku/index.html
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

# Tcl script to generate HTML document

proc generate_html {} {
    set html ""
    
    # DOCTYPE and html start
    append html {<!DOCTYPE html>}
    append html {\n<html lang="en"}
    append html { class="fontawesome-i2svg-active fontawesome-i2svg-complete"}
    append html { style="scroll-padding-top:60px">}
    
    # Head section
    append html {\n<head>}
    append html {\n    <title>Raku Documentation | Raku Documentation</title>}
    append html {\n    <meta charset="UTF-8" />}
    append html {\n    }
    
    # Links
    append html {\n<link href="/assets/images/Camelia.ico" rel="icon" type="image/x-icon"/>}
    append html {\n\n    }
    append html {\n<link rel="stylesheet" href="/assets/css/Website.css"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/css/filtered-toc-dark.css" title="dark"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/css/filtered-toc-light.css" title="light"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/css/rainbow-dark.css" title="dark"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/css/rainbow-light.css" title="light"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/tm-styling.css"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/tm-light.css" title="light"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/tm-dark.css" title="dark"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/all.min.css"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/listf-styling-light.css" title="light"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/listf-styling-dark.css" title="dark"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/typegraph-styling.css"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/typegraph-dark.css" title="dark"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/typegraph-light.css" title="light"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/css/page-styling-main.css"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/css/page-styling-dark.css" title="dark"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/css/page-styling-light.css" title="light"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/css/chyronToggle-dark.css" title="dark"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/css/chyronToggle-light.css" title="light"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/css/centreToggle-dark.css" title="dark"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/css/centreToggle-light.css" title="light"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/css/options-search-light.css" title="light"/>}
    append html {\n<link rel="stylesheet" href="/assets/css/css/options-search-dark.css" title="dark"/>}
    append html {\n<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-light.min.css" title="light" />}
    append html {\n<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-dark.min.css" title="dark" />}
    append html {\n<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tarekraafat/autocomplete.js@10.2.7/dist/css/autoComplete.min.css" />}
    append html {\n\n    }
    
    # Scripts
    append html {\n<script src="https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>}
    append html {\n<script src="/assets/scripts/all.min.js"></script>}
    append html {<script src="/assets/scripts/tableManager.js"></script>}
    append html {<script src="/assets/scripts/filter-script.js"></script>}
    append html {<script src="https://cdn.jsdelivr.net/npm/fuzzysort@2.0.4/fuzzysort.min.js"></script>}
    append html {<script src="https://cdn.jsdelivr.net/npm/@tarekraafat/autocomplete.js@10.2.7/dist/autoComplete.min.js"></script>}
    append html {<script src="/assets/scripts/filtered-toc.js"></script>}
    append html {<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>}
    append html {<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/haskell.min.js"></script>}
    append html {<script src="/assets/scripts/options-search.js"></script>}
    append html {<script src="/assets/scripts/page-styling.js"></script>}
    append html {<script src="/assets/scripts/rainbow.js"></script>}
    append html {\n</head>\n\n}
    
    # Body start
    append html {<body class="has-navbar-fixed-top">}
    append html {\n<div id="Raku_Documentation" class="top-of-page"></div>}
    
    # Navigation
    append html {\n<nav class="navbar is-fixed-top is-flex-touch" role="navigation" aria-label="main navigation">}
    append html {\n    }
    append html {\n<div class="container is-justify-content-space-around">}
    append html {\n<div class="navbar-brand">}
    append html {\n<div class="navbar-logo">}
    append html {\n<a class="navbar-item" href="/">}
    append html {\n<img src="/assets/images/camelia-recoloured.png" alt="Raku" width="52.83" height="38">}
    append html {\n</a>}
    append html {\n<span class="navbar-logo-tm">tm</span>}
    append html {\n</div>}
    append html {\n<a role="button" class="navbar-burger burger" aria-label="menu" aria-expanded="false" data-target="navMenu">}
    append html {\n<span aria-hidden="true"></span>}
    append html {\n<span aria-hidden="true"></span>}
    append html {\n<span aria-hidden="true"></span>}
    append html {\n</a>}
    append html {\n</div>\n\n}
    
    # Navbar menu
    append html {\n<div id="navMenu" class="navbar-menu">}
    append html {\n<div class="navbar-start">}
    append html {\n<a class="navbar-item" href="/introduction" title="Getting started, Tutorials, Migration guides">}
    append html {\nIntroduction}
    append html {\n</a>}
    append html {\n<a class="navbar-item" href="/reference" title="Fundamentals, General reference">}
    append html {\nReference}
    append html {\n</a>}
    append html {\n<a class="navbar-item" href="/miscellaneous" title="Programs, Experimental">}
    append html {\nMiscellaneous}
    append html {\n</a>}
    append html {\n<a class="navbar-item" href="/types" title="The core types (classes) available">}
    append html {\nTypes}
    append html {\n</a>}
    append html {\n<a class="navbar-item" href="/routines" title="Searchable table of routines">}
    append html {\nRoutines}
    append html {\n</a>}
    append html {\n<a class="navbar-item" href="https://raku.org" title="Home page for community">}
    append html {\nRaku<sup>®</sup>}
    append html {\n</a>}
    append html {\n<a class="navbar-item" href="https://web.libera.chat/#raku" title="IRC live chat">}
    append html {\nChat}
    append html {\n</a>}
    append html {\n<div class="navbar-item has-dropdown is-hoverable">}
    append html {\n<a class="navbar-link">}
    append html {\nMore}
    append html {\n</a>}
    append html {\n<div class="navbar-dropdown is-right is-rounded">}
    append html {\n}
    append html {\n<hr class="navbar-divider">}
    append html {\n<a class="navbar-item js-modal-trigger" data-target="download-ebook">}
    append html {\nDownload E-Book (epub)}
    append html {\n</a>}
    append html {\n\n<hr class="navbar-divider">}
    append html {\n<a class="navbar-item" href="/about">}
    append html {\nAbout}
    append html {\n</a>}
    append html {\n<hr class="navbar-divider">}
    append html {\n<a class="navbar-item has-text-red" href="https://github.com/raku/doc-website/issues">}
    append html {\nReport an issue with this site}
    append html {\n</a>}
    append html {\n<hr class="navbar-divider">}
    append html {\n<a class="navbar-item" href="https://github.com/raku/doc/issues">}
    append html {\nReport an issue with the documentation content}
    append html {\n</a>}
    append html {\n}
    append html {\n</div>}
    append html {\n</div>}
    append html {\n</div>}
    
    # Search section
    append html {\n<div class="navbar-end navbar-search-wrapper">}
    append html {\n<div class="navbar-item">}
    append html {\n<div class="field has-addons">}
    append html {\n<div class="autoComplete_options">}
    append html {\n<input class="control input" id="autoComplete" type="search" dir="ltr" spellcheck=false autocorrect="off" autocomplete="off" autocapitalize="off" placeholder="🔍 Type f to search for ...">}
    append html {\n</div>}
    append html {\n<div class="control" title="Search options">}
    append html {\n<a class="button is-primary js-modal-trigger"}
    append html {\ndata-target="options-search-info">}
    append html {\n<span class="icon">}
    append html {\n<i class="fas fa-cogs"></i>}
    append html {\n</span>}
    append html {\n</a>}
    append html {\n</div>}
    append html {\n</div>}
    append html {\n</div>}
    append html {\n</div>}
    
    # Options search modal
    append html {\n<div id="options-search-info" class="modal">}
    append html {\n<div class="modal-background"></div>}
    append html {\n<div class="modal-content">}
    append html {\n<div class="box">}
    append html {\n<p>The last search was: <span id="selected-candidate" class="ss-selected"></span></p>}
    append html {\n<div class="control is-grouped is-grouped-centered options-search-controls">}
    append html {\n<label class="centreToggle" title="Include extra information (Alt-E)" style="--switch-width: 10.5">}
    append html {\n<input id="options-search-extra" type="checkbox">}
    append html {\n<span class="text">Extra info</span>}
    append html {\n<span class="on">yes</span>}
    append html {\n<span class="off">no</span>}
    append html {\n</label>}
    append html {\n<p>The search response can be shortened by excluding the extra information line (Alt-E)</p>}
    append html {\n<label class="centreToggle" title="Search engine type Strict/Loose (Alt-L)" style="--switch-width: 10.5">}
    append html {\n<input id="options-search-loose" type="checkbox">}
    append html {\n<span class="text">Search type</span>}
    append html {\n<span class="on">loose</span>}
    append html {\n<span class="off">strict</span>}
    append html {\n</label>}
    append html {\n<p> The search engine can perform a strict search (only the characters in the search}
    append html {\nbox) or a loose search (Alt-L)</p>}
    append html {\n<label class="centreToggle" title="Search in headings (Alt-H)" style="--switch-width: 10.5">}
    append html {\n<input id="options-search-headings" type="checkbox">}
    append html {\n<span class="text">Headings</span>}
    append html {\n<span class="on">yes</span>}
    append html {\n<span class="off">no</span>}
    append html {\n</label>}
    append html {\n<p>Search through headings in all web-pages (Alt-H)</p>}
    append html {\n<label class="centreToggle" title="Search indexed items (Alt-I)" style="--switch-width: 10.5">}
    append html {\n<input id="options-search-indexed" type="checkbox">}
    append html {\n<span class="text">Indexed</span>}
    append html {\n<span class="on">yes</span>}
    append html {\n<span class="off">no</span>}
    append html {\n</label>}
    append html {\n<p>Search through all indexed items (Alt-I)</p>}
    append html {\n<label class="centreToggle" title="Search composite pages (Alt-C)" style="--switch-width: 10.5">}
    append html {\n<input id="options-search-composite" type="checkbox">}
    append html {\n<span class="text">Composite</span>}
    append html {\n<span class="on">yes</span>}
    append html {\n<span class="off">no</span>}
    append html {\n</label>}
    append html {\n<p>Search in the names of composite pages, which combine similar information from}
    append html {\nthe main web pages (Alt-C)</p>}
    append html {\n<label class="centreToggle" title="Search primary sources (Alt-P)" style="--switch-width: 10.5">}
    append html {\n<input id="options-search-primary" type="checkbox">}
    append html {\n<span class="text">Primary</span>}
    append html {\n<span class="on">yes</span>}
    append html {\n<span class="off">no</span>}
    append html {\n</label>}
    append html {\n<p>Search through the names of the main web pages (Alt-P)</p>}
    append html {\n<label class="centreToggle" title="Open in new tab (Alt-Q)" style="--switch-width: 10.5">}
    append html {\n<input id="options-search-newtab" type="checkbox">}
    append html {\n<span class="text">New tab</span>}
    append html {\n<span class="on">yes</span>}
    append html {\n<span class="off">no</span>}
    append html {\n</label>}
    append html {\n<p>Once a search candidate has been chosen, it can be opened in a new tab or in the current}
    append html {\ntab (Alt-Q)</p>}
    append html {\n<p>If all else fails, an item is added to use the Google search engine on the whole site</p>}
    append html {\n<button class="button is-warning" id="options-search-reset-defaults">Clear options, reset to defaults</button>}
    append html {\n<p>Exit this page by pressing &lt;Escape&gt;, or clicking on X or on the background.</p>}
    append html {\n</div>}
    append html {\n</div>}
    append html {\n</div>}
    append html {\n<button class="modal-close is-large" aria-label="close"></button>}
    append html {\n</div>\n\n}
    
    # Download ebook modal
    append html {\n<div id="download-ebook" class="modal">}
    append html {\n<div class="modal-background"></div>}
    append html {\n<div class="modal-content">}
    append html {\n<div class="box">}
    append html {\n<p><a href="/RakuDocumentation.epub" download>RakuDocumentation.epub</a> is a work in}
    append html {\nprogress e-book. It targets the <a href="https://www.w3.org/publishing/epub3/">EPUB v3 specification</a>.}
    append html {\nIt needs testing on a variety of ereaders (some of which may still implicitly expect}
    append html {\ncompliance with EPUB v2). The CSS definitely needs enhancing (especially for code snippets).}
    append html {\nThe Ebook opens in a Calibre reader, which is available on all operating systems.</p>}
    append html {\n<p>Suggestions are welcome and should be addressed by opening an issue on}
    append html {\nthe Raku/doc-website repository</p>}
    append html {\n<p>Exit this popup by pressing &lt;Escape&gt;, or clicking on X or on the background.</p>}
    append html {\n</div>}
    append html {\n</div>}
    append html {\n<button class="modal-close is-large" aria-label="close"></button>}
    append html {\n</div>\n\n}
    
    append html {\n</div>}
    append html {\n</nav>\n\n}
    
    # Main content wrapper
    append html {\n<div id="wrapper">}
    append html { }
    append html {<section class="hero is-medium is-primary">}
    append html { }
    append html {<div class="hero-body">}
    append html { }
    append html {<div class="container">}
    append html { }
    append html {<h1 class="title is-1 is-size-2-mobile has-text-centered">}
    append html { Raku documentation }
    append html {\n</h1>}
    append html { }
    append html {<h2 class="subtitle is-4 has-text-centered mt-3">}
    append html { Welcome to the official documentation of the Raku<sup>®</sup> programming language! }
    append html {\n</h2>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {</section>}
    append html { }
    append html {<section class="section">}
    append html { }
    append html {<div class="container px-4">}
    append html { }
    append html {<div class="columns is-multiline">}
    append html { }
    append html {<!-- Card -->}
    append html { }
    append html {<div class="column is-one-half">}
    append html { }
    append html {<div class="card card-home">}
    append html { }
    append html {<div class="card-content">}
    append html { }
    append html {<div class="has-text-centered">}
    append html { }
    append html {<a href="/introduction">}
    append html { }
    append html {<span class="icon is-large has-text-primary">}
    append html { }
    append html {<i class="fas fa-graduation-cap icon-large"></i>}
    append html { }
    append html {</span>}
    append html { }
    append html {</a>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="content has-text-centered">}
    append html { }
    append html {<p class="title is-5 has-text-primary">}
    append html {<a href="/introduction">}
    append html {Getting started, Migration guides from other languages, &amp; Tutorials}
    append html {</a>}
    append html {</p>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="content has-text-centered">}
    append html { Documents introducing the language for various audiences. }
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="has-text-centered">}
    append html { }
    append html {<a class="button is-primary" href="/introduction">}
    append html { }
    append html {<strong>Learn more</strong>}
    append html { }
    append html {</a>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="column is-one-half">}
    append html { }
    append html {<div class="card card-home">}
    append html { }
    append html {<div class="card-content">}
    append html { }
    append html {<div class="has-text-centered">}
    append html { }
    append html {<a href="/reference">}
    append html { }
    append html {<span class="icon is-large has-text-primary">}
    append html { }
    append html {<i class="fas fa-book icon-large"></i>}
    append html { }
    append html {</span>}
    append html { }
    append html {</a>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="content has-text-centered">}
    append html { }
    append html {<p class="title is-5 has-text-primary">}
    append html {<a href="/reference">}
    append html {Language References}
    append html {</a>}
    append html {</p>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="content has-text-centered">}
    append html { Documents explaining the various conceptual parts of the language. }
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="has-text-centered">}
    append html { }
    append html {<a class="button is-primary" href="/reference">}
    append html { }
    append html {<strong>Learn more</strong>}
    append html { }
    append html {</a>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="column is-one-third">}
    append html { }
    append html {<div class="card card-home">}
    append html { }
    append html {<div class="card-content">}
    append html { }
    append html {<div class="has-text-centered">}
    append html { }
    append html {<a href="/types">}
    append html { }
    append html {<span class="icon is-large has-text-primary">}
    append html { }
    append html {<i class="fas fa-layer-group icon-large"></i>}
    append html { }
    append html {</span>}
    append html { }
    append html {</a>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="content has-text-centered">}
    append html { }
    append html {<p class="title is-5 has-text-primary">}
    append html {<a href="/types">}
    append html {Type Reference}
    append html {</a>}
    append html {</p>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="content has-text-centered">}
    append html { Index of built-in classes, roles and enums. }
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="has-text-centered">}
    append html { }
    append html {<a class="button is-primary" href="/types">}
    append html { }
    append html {<strong>Learn more</strong>}
    append html { }
    append html {</a>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="column is-one-third">}
    append html { }
    append html {<div class="card card-home">}
    append html { }
    append html {<div class="card-content">}
    append html { }
    append html {<div class="has-text-centered">}
    append html { }
    append html {<a href="/routines">}
    append html { }
    append html {<span class="icon is-large has-text-primary">}
    append html { }
    append html {<i class="fas fa-paperclip icon-large"></i>}
    append html { }
    append html {</span>}
    append html { }
    append html {</a>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="content has-text-centered">}
    append html { }
    append html {<p class="title is-5 has-text-primary">}
    append html {<a href="/routines">}
    append html {Routine Reference}
    append html {</a>}
    append html {</p>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="content has-text-centered">}
    append html { Index of built-in subroutines and methods. }
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="has-text-centered">}
    append html { }
    append html {<a class="button is-primary" href="/routines">}
    append html { }
    append html {<strong>Learn more</strong>}
    append html { }
    append html {</a>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="column is-one-third">}
    append html { }
    append html {<div class="card card-home">}
    append html { }
    append html {<div class="card-content">}
    append html { }
    append html {<div class="has-text-centered">}
    append html { }
    append html {<a href="/miscellaneous">}
    append html { }
    append html {<span class="icon is-large has-text-primary">}
    append html { }
    append html {<i class="fas fa-code icon-large"></i>}
    append html { }
    append html {</span>}
    append html { }
    append html {</a>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="content has-text-centered">}
    append html { }
    append html {<p class="title is-5 has-text-primary">}
    append html {<a href="/miscellaneous">}
    append html {Miscellaneous}
    append html {</a>}
    append html {</p>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="content has-text-centered">}
    append html { Documents explaining experimental topics and Raku programs rather than the language itself. }
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="has-text-centered">}
    append html { }
    append html {<a class="button is-primary" href="/miscellaneous">}
    append html { }
    append html {<strong>Learn more</strong>}
    append html { }
    append html {</a>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="column is-one-half">}
    append html { }
    append html {<div class="card card-home">}
    append html { }
    append html {<div class="card-content">}
    append html { }
    append html {<div class="has-text-centered">}
    append html { }
    append html {<a href="/language/faq">}
    append html { }
    append html {<span class="icon is-large has-text-primary">}
    append html { }
    append html {<svg class="svg-inline--fa fa-question-circle fa-w-16 icon-large" aria-hidden="true" data-prefix="fas" data-icon="question-circle" role="img" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" data-fa-i2svg="">}
    append html {<path fill="currentColor" d="M504 256c0 136.997-111.043 248-248 248S8 392.997 8 256C8 119.083 119.043 8 256 8s248 111.083 248 248zM262.655 90c-54.497 0-89.255 22.957-116.549 63.758-3.536 5.286-2.353 12.415 2.715 16.258l34.699 26.31c5.205 3.947 12.621 3.008 16.665-2.122 17.864-22.658 30.113-35.797 57.303-35.797 20.429 0 45.698 13.148 45.698 32.958 0 14.976-12.363 22.667-32.534 33.976C247.128 238.528 216 254.941 216 296v4c0 6.627 5.373 12 12 12h56c6.627 0 12-5.373 12-12v-1.333c0-28.462 83.186-29.647 83.186-106.667 0-58.002-60.165-102-116.531-102zM256 338c-25.365 0-46 20.635-46 46 0 25.364 20.635 46 46 46s46-20.636 46-46c0-25.365-20.635-46-46-46z"></path>}
    append html {</svg>}
    append html {<!-- <i class="fas fa-question-circle icon-large"></i> -->}
    append html { }
    append html {</span>}
    append html { }
    append html {</a>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="content has-text-centered">}
    append html { }
    append html {<p class="title is-5 has-text-primary">}
    append html {<a href="/language/faq">}
    append html {FAQs (Frequently Asked Questions)}
    append html {</a>}
    append html {</p>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="content has-text-centered">}
    append html { A collection of questions that have cropped up often, along with answers. }
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="has-text-centered">}
    append html { }
    append html {<a class="button is-primary" href="/language/faq">}
    append html { }
    append html {<strong>Learn more</strong>}
    append html { }
    append html {</a>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {</div>}
    append html { }
    append html {<div class="column is-one-half">}
    append html { }
    append html {<div class="card card-home">}
    append html { }
    append html {<div class="card-content">}
    append html { }
    append html {<div class="has-text-centered">}
    append html { }
    append html {<a href="/language/community">}
    append html { }
    append html {<span class="icon is-large has-text-primary">}
    append html { }
    append html {<svg class="svg-inline--fa fa-user-friends fa-w-20 icon-large" aria-hidden="true" data-prefix="fas" data-icon="user-friends" role="img" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 512" data-fa-i2svg="">}
    append html {<path fill="currentColor" d="M192 256c61.9 0 112-50.1 112-112S253.9 32 192 32 80 82.1 80 144s50.1 112 112 112zm76.8 32h-8.3c-20.8 10-43.9 16-68.5 16s-47.6-6-68.5-16h-8.3C51.6 288 0 339.6 0 403.2V432c0 26.5 21.5 48 48 48h288c26.5 0 48-21.5 48-48v-28.8c0-63.6-51.6-115.2-115.2-115.2zM480 256c53 0 96-43 96-96s-43-96-96-96-96 43-96 96 43 96 96 96zm48 32h-3.8c-13.9 4.8-28.6 8-44.2 8s-30.3-3.2-44.2-8H432c-20.4 0-39.2 5.9-55.7 15.4 24.4 26.3 39.7 61.2 39
