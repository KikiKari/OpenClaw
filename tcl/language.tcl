#!/usr/bin/env tclsh
# language.html — portiert nach tcl
# Quelle: html, OpenClaw@gateway1:skills/scripting-utils/references/raku/language.html
# auch in: OpenClaw@gateway2:skills/scripting-utils/references/raku/language.html
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Function to generate the 404 HTML page
proc generate_404_page {} {
    set html {}

    # Add DOCTYPE and html tag
    append html {<!DOCTYPE html>}
    append html "\n" {<html lang="en" class="fontawesome-i2svg-active fontawesome-i2svg-complete" style="scroll-padding-top:60px">}

    # Head section
    append html "\n" {<head>}
    append html "\n" {    <title>404 | Raku Documentation</title>}
    append html "\n" {    <meta charset="UTF-8" />}
    append html "\n" {    }
    append html "\n" {<link href="/assets/images/Camelia.ico" rel="icon" type="image/x-icon"/>}
    append html "\n" {    }
    append html "\n" {    }
    append html "\n" {<link rel="stylesheet" href="/assets/css/Website.css"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/css/filtered-toc-dark.css" title="dark"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/css/filtered-toc-light.css" title="light"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/css/rainbow-dark.css" title="dark"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/css/rainbow-light.css" title="light"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/tm-styling.css"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/tm-light.css" title="light"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/tm-dark.css" title="dark"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/all.min.css"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/listf-styling-light.css" title="light"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/listf-styling-dark.css" title="dark"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/typegraph-styling.css"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/typegraph-dark.css" title="dark"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/typegraph-light.css" title="light"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/css/page-styling-main.css"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/css/page-styling-dark.css" title="dark"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/css/page-styling-light.css" title="light"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/css/chyronToggle-dark.css" title="dark"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/css/chyronToggle-light.css" title="light"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/css/centreToggle-dark.css" title="dark"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/css/centreToggle-light.css" title="light"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/css/options-search-light.css" title="light"/>}
    append html "\n" {<link rel="stylesheet" href="/assets/css/css/options-search-dark.css" title="dark"/>}
    append html "\n" {<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-light.min.css" title="light" />}
    append html "\n" {<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-dark.min.css" title="dark" />}
    append html "\n" {<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tarekraafat/autocomplete.js@10.2.7/dist/css/autoComplete.min.css" />}
    append html "\n" {    }
    append html "\n" {    <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>}
    append html "\n" {    <script src="/assets/scripts/all.min.js"></script><script src="/assets/scripts/tableManager.js"></script><script src="/assets/scripts/filter-script.js"></script><script src="https://cdn.jsdelivr.net/npm/fuzzysort@2.0.4/fuzzysort.min.js"></script><script src="https://cdn.jsdelivr.net/npm/@tarekraafat/autocomplete.js@10.2.7/dist/autoComplete.min.js"></script><script src="/assets/scripts/filtered-toc.js"></script><script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script><script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/haskell.min.js"></script><script src="/assets/scripts/options-search.js"></script><script src="/assets/scripts/page-styling.js"></script><script src="/assets/scripts/rainbow.js"></script>}
    append html "\n" {</head>}
    append html "\n" {}
    append html "\n" {<body class="has-navbar-fixed-top">}
    append html "\n" {<div id="404" class="top-of-page"></div>}
    append html "\n" {<nav class="navbar is-fixed-top is-flex-touch" role="navigation" aria-label="main navigation">}
    append html "\n" {        <div class="navbar-item" style="margin-left: auto;">}
    append html "\n" {          <div class="left-bar-toggle" title="Toggle Table of Contents & Index">}
    append html "\n" {      <label class="chyronToggle left">}
    append html "\n" {          <input id="navbar-left-toggle" type="checkbox">}
    append html "\n" {          <span class="text">Contents</span>}
    append html "\n" {      </label>}
    append html "\n" {  </div>}
    append html "\n" {}
    append html "\n" {    </div>}
    append html "\n" {}
    append html "\n" {    <div class="container is-justify-content-space-around">}
    append html "\n" {        <div class="navbar-brand">}
    append html "\n" {  <div class="navbar-logo">}
    append html "\n" {    <a class="navbar-item" href="/">}
    append html "\n" {      <img src="/assets/images/camelia-recoloured.png" alt="Raku" width="52.83" height="38">}
    append html "\n" {    </a>}
    append html "\n" {    <span class="navbar-logo-tm">tm</span>}
    append html "\n" {  </div>}
    append html "\n" {  <a role="button" class="navbar-burger burger" aria-label="menu" aria-expanded="false" data-target="navMenu">}
    append html "\n" {    <span aria-hidden="true"></span>}
    append html "\n" {    <span aria-hidden="true"></span>}
    append html "\n" {    <span aria-hidden="true"></span>}
    append html "\n" {  </a>}
    append html "\n" {</div>}
    append html "\n" {}
    append html "\n" {          <div id="navMenu" class="navbar-menu">}
    append html "\n" {    <div class="navbar-start">}
    append html "\n" {        <a class="navbar-item" href="/introduction" title="Getting started, Tutorials, Migration guides">}
    append html "\n" {            Introduction}
    append html "\n" {        </a>}
    append html "\n" {        <a class="navbar-item" href="/reference" title="Fundamentals, General reference">}
    append html "\n" {            Reference}
    append html "\n" {        </a>}
    append html "\n" {        <a class="navbar-item" href="/miscellaneous" title="Programs, Experimental">}
    append html "\n" {            Miscellaneous}
    append html "\n" {        </a>}
    append html "\n" {        <a class="navbar-item" href="/types" title="The core types (classes) available">}
    append html "\n" {            Types}
    append html "\n" {        </a>}
    append html "\n" {        <a class="navbar-item" href="/routines" title="Searchable table of routines">}
    append html "\n" {            Routines}
    append html "\n" {        </a>}
    append html "\n" {        <a class="navbar-item" href="https://raku.org" title="Home page for community">}
    append html "\n" {            Raku<sup>®</sup>}
    append html "\n" {        </a>}
    append html "\n" {        <a class="navbar-item" href="https://web.libera.chat/#raku" title="IRC live chat">}
    append html "\n" {            Chat}
    append html "\n" {        </a>}
    append html "\n" {        <div class="navbar-item has-dropdown is-hoverable">}
    append html "\n" {          <a class="navbar-link">}
    append html "\n" {            More}
    append html "\n" {          </a>}
    append html "\n" {          <div class="navbar-dropdown is-right is-rounded">}
    append html "\n" {            }
    append html "\n" {            <hr class="navbar-divider">}
    append html "\n" {            <a class="navbar-item js-modal-trigger" data-target="download-ebook">}
    append html "\n" {              Download E-Book (epub)}
    append html "\n" {            </a>}
    append html "\n" {        }
    append html "\n" {            <hr class="navbar-divider">}
    append html "\n" {            <a class="navbar-item" href="/about">}
    append html "\n" {              About}
    append html "\n" {            </a>}
    append html "\n" {            <hr class="navbar-divider">}
    append html "\n" {            <a class="navbar-item has-text-red" href="https://github.com/raku/doc-website/issues">}
    append html "\n" {              Report an issue with this site}
    append html "\n" {            </a>}
    append html "\n" {            <hr class="navbar-divider">}
    append html "\n" {            <a class="navbar-item" href="https://github.com/raku/doc/issues">}
    append html "\n" {              Report an issue with the documentation content}
    append html "\n" {            </a>}
    append html "\n" {            }
    append html "\n" {          </div>}
    append html "\n" {        </div>}
    append html "\n" {    </div>}
    append html "\n" {        <div class="navbar-end navbar-search-wrapper">}
    append html "\n" {        <div class="navbar-item">}
    append html "\n" {            <div class="field has-addons">}
    append html "\n" {                <div class="autoComplete_options">}
    append html "\n" {                    <input class="control input" id="autoComplete" type="search" dir="ltr" spellcheck=false autocorrect="off" autocomplete="off" autocapitalize="off" placeholder="🔍 Type f to search for ...">}
    append html "\n" {                </div>}
    append html "\n" {                <div class="control" title="Search options">}
    append html "\n" {                    <a class="button is-primary js-modal-trigger" data-target="options-search-info">}
    append html "\n" {                        <span class="icon">}
    append html "\n" {                            <i class="fas fa-cogs"></i>}
    append html "\n" {                        </span>}
    append html "\n" {                    </a>}
    append html "\n" {                </div>}
    append html "\n" {            </div>}
    append html "\n" {        </div>}
    append html "\n" {    </div>}
    append html "\n" {    <div id="options-search-info" class="modal">}
    append html "\n" {        <div class="modal-background"></div>}
    append html "\n" {        <div class="modal-content">}
    append html "\n" {            <div class="box">}
    append html "\n" {                <p>The last search was: <span id="selected-candidate" class="ss-selected"></span></p>}
    append html "\n" {                <div class="control is-grouped is-grouped-centered options-search-controls">}
    append html "\n" {                    <label class="centreToggle" title="Include extra information (Alt-E)" style="--switch-width: 10.5">}
    append html "\n" {                       <input id="options-search-extra" type="checkbox">}
    append html "\n" {                       <span class="text">Extra info</span>}
    append html "\n" {                       <span class="on">yes</span>}
    append html "\n" {                       <span class="off">no</span>}
    append html "\n" {                    </label>}
    append html "\n" {                <p>The search response can be shortened by excluding the extra information line (Alt-E)</p>}
    append html "\n" {                    <label class="centreToggle" title="Search engine type Strict/Loose (Alt-L)" style="--switch-width: 10.5">}
    append html "\n" {                       <input id="options-search-loose" type="checkbox">}
    append html "\n" {                       <span class="text">Search type</span>}
    append html "\n" {                       <span class="on">loose</span>}
    append html "\n" {                       <span class="off">strict</span>}
    append html "\n" {                    </label>}
    append html "\n" {                <p> The search engine can perform a strict search (only the characters in the search}
    append html "\n" {                box) or a loose search (Alt-L)</p>}
    append html "\n" {                    <label class="centreToggle" title="Search in headings (Alt-H)" style="--switch-width: 10.5">}
    append html "\n" {                       <input id="options-search-headings" type="checkbox">}
    append html "\n" {                       <span class="text">Headings</span>}
    append html "\n" {                       <span class="on">yes</span>}
    append html "\n" {                       <span class="off">no</span>}
    append html "\n" {                    </label>}
    append html "\n" {                    <p>Search through headings in all web-pages (Alt-H)</p>}
    append html "\n" {                    <label class="centreToggle" title="Search indexed items (Alt-I)" style="--switch-width: 10.5">}
    append html "\n" {                       <input id="options-search-indexed" type="checkbox">}
    append html "\n" {                       <span class="text">Indexed</span>}
    append html "\n" {                       <span class="on">yes</span>}
    append html "\n" {                       <span class="off">no</span>}
    append html "\n" {                    </label>}
    append html "\n" {                    <p>Search through all indexed items (Alt-I)</p>}
    append html "\n" {                    <label class="centreToggle" title="Search composite pages (Alt-C)" style="--switch-width: 10.5">}
    append html "\n" {                       <input id="options-search-composite" type="checkbox">}
    append html "\n" {                       <span class="text">Composite</span>}
    append html "\n" {                       <span class="on">yes</span>}
    append html "\n" {                       <span class="off">no</span>}
    append html "\n" {                    </label>}
    append html "\n" {                    <p>Search in the names of composite pages, which combine similar information from}
    append html "\n" {                    the main web pages (Alt-C)</p>}
    append html "\n" {                    <label class="centreToggle" title="Search primary sources (Alt-P)" style="--switch-width: 10.5">}
    append html "\n" {                       <input id="options-search-primary" type="checkbox">}
    append html "\n" {                       <span class="text">Primary</span>}
    append html "\n" {                       <span class="on">yes</span>}
    append html "\n" {                       <span class="off">no</span>}
    append html "\n" {                    </label>}
    append html "\n" {                    <p>Search through the names of the main web pages (Alt-P)</p>}
    append html "\n" {                    <label class="centreToggle" title="Open in new tab (Alt-Q)" style="--switch-width: 10.5">}
    append html "\n" {                       <input id="options-search-newtab" type="checkbox">}
    append html "\n" {                       <span class="text">New tab</span>}
    append html "\n" {                       <span class="on">yes</span>}
    append html "\n" {                       <span class="off">no</span>}
    append html "\n" {                    </label>}
    append html "\n" {                    <p>Once a search candidate has been chosen, it can be opened in a new tab or in the current}
    append html "\n" {                    tab (Alt-Q)</p>}
    append html "\n" {                    <p>If all else fails, an item is added to use the Google search engine on the whole site</p>}
    append html "\n" {                    <button class="button is-warning" id="options-search-reset-defaults">Clear options, reset to defaults</button>}
    append html "\n" {                    <p>Exit this page by pressing &lt;Escape&gt;, or clicking on X or on the background.</p>}
    append html "\n" {                </div>}
    append html "\n" {            </div>}
    append html "\n" {        </div>}
    append html "\n" {        <button class="modal-close is-large" aria-label="close"></button>}
    append html "\n" {    </div>}
    append html "\n" {}
    append html "\n" {  </div>}
    append html "\n" {         <div id="download-ebook" class="modal">}
    append html "\n" {                    <div class="modal-background"></div>}
    append html "\n" {                    <div class="modal-content">}
    append html "\n" {                        <div class="box">}
    append html "\n" {                            <p><a href="/RakuDocumentation.epub" download>RakuDocumentation.epub</a> is a work in}
    append html "\n" {                            progress e-book. It targets the <a href="https://www.w3.org/publishing/epub3/">EPUB v3 specification</a>.}
    append html "\n" {                            It needs testing on a variety of ereaders (some of which may still implicitly expect}
    append html "\n" {                            compliance with EPUB v2). The CSS definitely needs enhancing (especially for code snippets).}
    append html "\n" {                            The Ebook opens in a Calibre reader, which is available on all operating systems.</p>}
    append html "\n" {                            <p>Suggestions are welcome and should be addressed by opening an issue on}
    append html "\n" {                            the Raku/doc-website repository</p>}
    append html "\n" {                            <p>Exit this popup by pressing &lt;Escape&gt;, or clicking on X or on the background.</p>}
    append html "\n" {                        </div>}
    append html "\n" {                    </div>}
    append html "\n" {                    <button class="modal-close is-large" aria-label="close"></button>}
    append html "\n" {                </div>}
    append html "\n" {        }
    append html "\n" {  }
    append html "\n" {}
    append html "\n" {    </div>}
    append html "\n" {</nav>}
    append html "\n" {}
    append html "\n" {<div class="tile is-ancestor section">}
    append html "\n" {    <div class="page-edit">}
    append html "\n" {    <a class="button page-edit-button" href="https://github.com/Raku/doc-website/edit/main/Website/structure-sources/404.rakudoc" title="Edit this page.&#13;Commit: 0ead45c 2026-04-04">}
    append html "\n" {      <span class="icon is-right">}
    append html "\n" {        <i class="fas fa-pen-alt is-medium"></i>}
    append html "\n" {      </span>}
    append html "\n" {    </a>}
    append html "\n" {  </div>}
    append html "\n" {}
    append html "\n" {    <div id="left-column" class="tile is-parent is-2 is-hidden">}
    append html "\n" {        <div id="left-col-inner">}
    append html "\n" {                <input type="checkbox" id="No-TOC" checked="checked" style="visibility: collapse;">}
    append html "\n" {    </input>}
    append html "\n" {    <div class="content">No Table of Contents or Index available</div>}
    append html "\n" {}
    append html "\n" {        </div>}
    append html "\n" {    </div>}
    append html "\n" {    <div id="main-column" class="tile is-parent" style="overflow-x: hidden;">}
    append html "\n" {        <div id="main-col-inner">}
    append html "\n" {            <section class="raku page-header">}
    append html "\n" {    <div class="container px-4">}
    append html "\n" {        <div class="raku page-title has-text-centered">}
    append html "\n" {        404}
    append html "\n" {        </div>}
    append html "\n" {        <div class="raku page-subtitle has-text-centered">}
    append html "\n" {        }
    append html "\n" {        </div>}
    append html "\n" {    </div>}
    append html "\n" {</section>}
    append html "\n" {<section class="raku page-content"><div class="container px-4"><div class="columns one-col"><img src="/assets/images/Camelia-404.png" class="camelia">}
    append html "\n" {}
    append html "\n" {<h2 id="404:_Page_Not_Found" class="raku-h2"><a href="#404" title="go to top of document">404: Page Not Found<a class="raku-anchor" title="direct link" href="#404:_Page_Not_Found">§</a></a></h2>}
    append html "\n" {<p>We're sorry, but the content you tried to reach wasn't found.</p><p>While we do review server logs to catch these issues, we recently deployed a new version of the site, so please feel free to <a href="https://github.com/Raku/doc-website/issues/">report any issues</a>.</p><p>Thanks!</p>}
    append html "\n" {}
    append html "\n" {</div></div></section>}
    append html "\n" {}
    append html "\n" {        </div>}
    append html "\n" {    </div>}
    append html "\n" {</div>}
    append html "\n" {}
    append html "\n" {<footer class="footer main-footer">}
    append html "\n" {  <div class="container px-4">}
    append html "\n" {    <nav class="level">}
    append html "\n" {    <div class="level-left">}
    append html "\n" {    <div class="level-item">}
    append html "\n" {      <a href="/about">About</a>}
    append html "\n" {    </div>}
    append html "\n" {    <div class="level-item">}
    append html "\n" {      <a id="toggle-theme">Toggle theme</a>}
    append html "\n" {    </div>}
    append html "\n" {        <div class="level-item" title="0ead45c 2026-04-04">}
    append html "\n" {      <a>Commit</a>}
    append html "\n" {    </div>}
    append html "\n" {}
    append html "\n" {</div>}
    append html "\n" {}
    append html "\n" {    <div class="level-right">}
    append html "\n" {    <div class="level-item">}
    append html "\n" {      <a href="/license">License</a>}
    append html "\n" {    </div>}
    append html "\n" {</div>}
    append html "\n" {}
    append html "\n" {    </nav>}
    append html "\n" {  </div>}
    append html "\n" {</footer>}
    append html "\n" {}
    append html "\n" {}
    append html "\n" {</body>}
    append html "\n" {</html>}

    return $html
}

# Main execution
if {$argc != 1} {
    puts stderr "Usage: $argv0 <output-file>"
    exit 1
}

set output_file [lindex $argv 0]

# Generate the HTML content
set html_content [generate_404_page]

# Write to file
if {[catch {open $output_file w} file_handle]} {
    puts stderr "Error: Could not open file '$output_file' for writing"
    exit 1
}

puts $file_handle $html_content
close $file_handle

puts "404 page generated successfully: $output_file"
