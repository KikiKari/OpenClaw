<?php
// abstraction-provenance: {"artifact_sha256": "fc3552652e40c8804fa3857c54bf4dfa911062f40b185f6ba066eb05c6b0dc6d", "source_sha256": "e48c1623d8fdce193daf72caa7d76d4da5acf28c8842186c21c07f8cfddb5613", "target_language": "php"}
// index.html — portiert nach php
// Quelle: html, OpenClaw@gateway1:skills/scripting-utils/references/eggdrop/index.html
// auch in: OpenClaw@gateway2:skills/scripting-utils/references/eggdrop/index.html
// auch in: workspace@local:git/skills/scripting-utils/references/eggdrop/index.html
// auch in: workspace@local:skills/scripting-utils/references/eggdrop/index.html
// auch in: 4 weiteren Fundstellen
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py
// Prüfe, ob ein Ausgabedateiname als Kommandozeilenparameter übergeben wurde.
if ($argc < 2 || empty($argv[1])) {
    fwrite(STDERR, "Verwendung: php {$argv[0]} <ausgabedatei>\n");
    exit(1);
}
$outputFile = $argv[1];

// Starte die Ausgabepufferung, um den gesamten HTML-Inhalt in einer Variable zu sammeln.
ob_start();

// --- Datenstrukturen für wiederkehrende Elemente ---

// Daten für die Seitenleiste (Table of Contents)
$tocSections = [
    'Installing Eggdrop' => [
        ['href' => 'install/readme.html', 'text' => 'README'],
        ['href' => 'install/install.html', 'text' => 'Installing Eggdrop'],
        ['href' => 'install/upgrading.html', 'text' => 'Upgrading Eggdrop'],
    ],
    'Using Eggdrop' => [
        ['href' => 'using/features.html', 'text' => 'Eggdrop Features'],
        ['href' => 'using/core.html', 'text' => 'Eggdrop Core Settings'],
        ['href' => 'using/partyline.html', 'text' => 'The Party Line'],
        ['href' => 'using/autoscripts.html', 'text' => 'Eggdrop Autoscripts'],
        ['href' => 'using/users.html', 'text' => 'Users and Flags'],
        ['href' => 'using/bans.html', 'text' => 'Bans, Invites, and Exempts'],
        ['href' => 'using/botnet.html', 'text' => 'Botnet Sharing and Linking'],
        ['href' => 'using/ipv6.html', 'text' => 'IPv6 support'],
        ['href' => 'using/tls.html', 'text' => 'TLS support'],
        ['href' => 'using/ircv3.html', 'text' => 'IRCv3 support'],
        ['href' => 'using/accounts.html', 'text' => 'Account tracking in Eggdrop'],
        ['href' => 'using/pbkdf2info.html', 'text' => 'Encryption/Hashing'],
        ['href' => 'using/python.html', 'text' => 'Using the Python Module'],
        ['href' => 'using/twitchinfo.html', 'text' => 'Twitch'],
        ['href' => 'using/tricks.html', 'text' => 'Advanced Tips'],
        ['href' => 'using/text-sub.html', 'text' => 'Textfile Substitutions'],
        ['href' => 'using/tcl-commands.html', 'text' => 'Eggdrop Tcl Commands'],
        ['href' => 'using/twitch-tcl-commands.html', 'text' => 'Eggdrop Twitch Tcl Commands'],
        ['href' => 'using/patch.html', 'text' => 'Patching Eggdrop'],
    ],
    'Tutorials' => [
        ['href' => 'tutorials/setup.html', 'text' => 'Setting Up Eggdrop'],
        ['href' => 'tutorials/firststeps.html', 'text' => 'Common First Steps'],
        ['href' => 'tutorials/tlssetup.html', 'text' => 'Enabling TLS Security on Eggdrop'],
        ['href' => 'tutorials/userfilesharing.html', 'text' => 'Sharing Userfiles'],
        ['href' => 'tutorials/firstscript.html', 'text' => 'Writing an Eggdrop Tcl Script'],
        ['href' => 'tutorials/module.html', 'text' => 'Writing a Basic Eggdrop Module'],
    ],
    'Eggdrop Modules' => [
        ['href' => 'modules/index.html', 'text' => 'Eggdrop Module Information'],
        ['href' => 'modules/included.html', 'text' => 'Modules included with Eggdrop'],
        ['href' => 'modules/writing.html', 'text' => 'How to Write an Eggdrop Module'],
        ['href' => 'modules/internals.html', 'text' => 'Eggdrop Bind Internals'],
    ],
    'About Eggdrop' => [
        ['href' => 'about/about.html', 'text' => 'About Eggdrop'],
        ['href' => 'about/legal.html', 'text' => 'Boring legal stuff'],
    ],
];

// --- Hilfsfunktionen zur Erzeugung von HTML-Strukturen ---

function render_toc_list(array $sections) {
    foreach ($sections as $caption => $links) {
        echo '<p class="caption" role="heading"><span class="caption-text">' . htmlspecialchars($caption) . '</span></p>';
        echo '<ul>';
        foreach ($links as $link) {
            echo '<li class="toctree-l1"><a class="reference internal" href="' . htmlspecialchars($link['href']) . '">' . htmlspecialchars($link['text']) . '</a></li>';
        }
        echo '</ul>';
    }
}

function render_head() {
    echo '<head>' . "\n";
    echo '    <meta charset="utf-8" />' . "\n";
    echo '    <meta name="viewport" content="width=device-width, initial-scale=1.0" /><meta name="viewport" content="width=device-width, initial-scale=1" />' . "\n";
    echo "\n";
    echo '    <title>Eggdrop, an open source IRC bot &#8212; Eggdrop 1.10.1 documentation</title>' . "\n";
    echo '    <link rel="stylesheet" type="text/css" href="_static/pygments.css?v=03e43079" />' . "\n";
    echo '    <link rel="stylesheet" type="text/css" href="_static/eggdrop.css?v=ab48a1b6" />' . "\n";
    echo '    <script src="_static/documentation_options.js?v=290de6c6"></script>' . "\n";
    echo '    <script src="_static/doctools.js?v=9bcbadda"></script>' . "\n";
    echo '    <script src="_static/sphinx_highlight.js?v=dc90522c"></script>' . "\n";
    echo '    <link rel="search" title="Search" href="search.html" />' . "\n";
    echo '    <link rel="next" title="README" href="install/readme.html" />' . "\n";
    echo '  </head>';
}

function render_header() {
    echo '<div class="header-wrapper" role="banner">' . "\n";
    echo '  <div class="header">' . "\n";
    echo '    <div class="headertitle"><a href="#">Eggdrop 1.10.1 documentation</a></div>' . "\n";
    echo '    <div class="rel" role="navigation" aria-label="related navigation">' . "\n";
    echo '      <a href="install/readme.html" title="README" accesskey="N">next</a>' . "\n";
    echo '    </div>' . "\n";
    echo '   </div>' . "\n";
    echo '</div>' . "\n";
}

function render_sidebar(array $tocSections) {
    echo '<div class="sidebar">' . "\n";
    echo '          ' . "\n";
    echo '          <h3>Table of Contents</h3>' . "\n";
    render_toc_list($tocSections);
    echo '          <div role="search">' . "\n";
    echo '            <h3 style="margin-top: 1.5em;">Search</h3>' . "\n";
    echo '            <form class="search" action="search.html" method="get">' . "\n";
    echo '                <input type="text" name="q" />' . "\n";
    echo '                <input type="submit" value="Go" />' . "\n";
    echo '            </form>' . "\n";
    echo '          </div>' . "\n";
    echo '        </div>' . "\n";
}

function render_document_content(array $tocSections) {
    echo '<div class="document">' . "\n";
    echo '            ' . "\n";
    echo '      <div class="documentwrapper">' . "\n";
    echo '        <div class="bodywrapper">' . "\n";
    echo '          <div class="body" role="main">' . "\n";
    echo '            ' . "\n";
    echo '  <section id="eggdrop-an-open-source-irc-bot">' . "\n";
    echo '<h1>Eggdrop, an open source IRC bot<a class="headerlink" href="#eggdrop-an-open-source-irc-bot" title="Link to this heading">¶</a></h1>' . "\n";
    echo '<p>Eggdrop is a free, open source software program built to assist in managing an IRC channel. It is the world’s oldest actively-maintained IRC bot and was designed to be easily used and expanded on via it’s ability to run Tcl scripts. Eggdrop can join IRC channels and perorm automated tasks such as protecting the channel from abuse, assisting users obtain their op/voice status, provide information and greetings, host games, etc.</p>' . "\n";
    echo '<section id="some-things-you-can-do-with-eggdrop">' . "\n";
    echo '<h2>Some things you can do with Eggdrop<a class="headerlink" href="#some-things-you-can-do-with-eggdrop" title="Link to this heading">¶</a></h2>' . "\n";
    echo '<p>Eggdrop has a large number of features, such as:</p>' . "\n";
    echo '<ul class="simple">' . "\n";
    echo '<li><p><a class="reference external" href="using/users.html">Channel Management</a></p></li>' . "\n";
    echo '<li><p>Running Tcl Scripts</p></li>' . "\n";
    echo '<li><p><a class="reference external" href="using/ircv3.html">Integration of the most current IRCv3 capabilities</a></p></li>' . "\n";
    echo '<li><p><a class="reference external" href="using/botnet.html">The ability to link multiple Eggdrops together and share userfiles</a></p></li>' . "\n";
    echo '<li><p><a class="reference external" href="using/tls.html">TLS Support</a></p></li>' . "\n";
    echo '<li><p><a class="reference external" href="using/ipv6.html">IPv6 Support</a></p></li>' . "\n";
    echo '<li><p><a class="reference external" href="using/twitchinfo.html">Twitch Support</a></p></li>' . "\n";
    echo '<li><p>… and much much more!</p></li>' . "\n";
    echo '</ul>' . "\n";
    echo '</section>' . "\n";
    echo '<section id="how-to-get-eggdrop">' . "\n";
    echo '<h2>How to get Eggdrop<a class="headerlink" href="#how-to-get-eggdrop" title="Link to this heading">¶</a></h2>' . "\n";
    echo '<p>The Eggdrop project source code is hosted at <a class="reference external" href="https://github.com/eggheads/eggdrop">https://github.com/eggheads/eggdrop</a>. You can clone it via git, or alternatively a copy of the current stable snapshot is located at <a class="reference external" href="https://geteggdrop.com">https://geteggdrop.com</a>. Additional information can be found on the official Eggdrop webpage at <a class="reference external" href="https://www.eggheads.org">https://www.eggheads.org</a>. For more information, see <a class="reference external" href="install/install.html">Installing Eggdrop</a></p>' . "\n";
    echo '</section>' . "\n";
    echo '<section id="how-to-install-eggdrop">' . "\n";
    echo '<h2>How to install Eggdrop<a class="headerlink" href="#how-to-install-eggdrop" title="Link to this heading">¶</a></h2>' . "\n";
    echo '<section id="installation-pre-requisites">' . "\n";
    echo '<h3>Installation Pre-requisites<a class="headerlink" href="#installation-pre-requisites" title="Link to this heading">¶</a></h3>' . "\n";
    echo '<p>Eggdrop requires Tcl (and its development header files) to be present on the system it is compiled on. It is also strongly encouraged to install openssl (and its development header files) to enable TLS-protected network communication.</p>' . "\n";
    echo '</section>' . "\n";
    echo '<section id="installation">' . "\n";
    echo '<h3>Installation<a class="headerlink" href="#installation" title="Link to this heading">¶</a></h3>' . "\n";
    echo '<p>A guide to quickly installing Eggdrop can be found here.</p>' . "\n";
    echo '</section>' . "\n";
    echo '</section>' . "\n";
    echo '<section id="where-to-find-more-help">' . "\n";
    echo '<h2>Where to find more help<a class="headerlink" href="#where-to-find-more-help" title="Link to this heading">¶</a></h2>' . "\n";
    echo '<p>The Eggheads development team can be found lurking on #eggdrop on the Libera network (irc.libera.chat).</p>' . "\n";
    
    // Erzeuge die toctree-wrapper-Blöcke im Dokument
    foreach ($tocSections as $caption => $links) {
        echo '<div class="toctree-wrapper compound">' . "\n";
        render_toc_list([$caption => $links]);
        echo '</div>' . "\n";
    }

    echo '</section>' . "\n";
    echo '</section>' . "\n";
    echo '            ' . "\n";
    echo '            <div class="clearer"></div>' . "\n";
    echo '          </div>' . "\n";
    echo '        </div>' . "\n";
    echo '      </div>' . "\n";
    echo '        </div>' . "\n";
}

function render_footer() {
    echo '<div class="footer-wrapper">' . "\n";
    echo '  <div class="footer">' . "\n";
    echo '    <div class="left">' . "\n";
    echo '      <div role="navigation" aria-label="related navigaton">' . "\n";
    echo '        <a href="install/readme.html" title="README">next</a>' . "\n";
    echo '      </div>' . "\n";
    echo '      <div role="note" aria-label="source link">' . "\n";
    echo '      </div>' . "\n";
    echo '    </div>' . "\n";
    echo "\n";
    echo '    <div class="right">' . "\n";
    echo '          ' . "\n";
    echo '    <div class="footer" role="contentinfo">' . "\n";
    echo '    &#169; Copyright 2025, Eggheads.' . "\n";
    echo '      Last updated on Aug 15, 2025.' . "\n";
    echo '      Created using <a href="https://www.sphinx-doc.org/">Sphinx</a> 8.2.3.' . "\n";
    echo '    </div>' . "\n";
    echo '        </div>' . "\n";
    echo '        <div class="clearer"></div>' . "\n";
    echo '      </div>' . "\n";
    echo '</div>' . "\n";
}

function render_body(array $tocSections) {
    echo '<body>' . "\n";
    render_header();
    echo '<div class="content-wrapper">' . "\n";
    echo '  <div class="content">' . "\n";
    render_sidebar($tocSections);
    render_document_content($tocSections);
    echo '        <div class="clearer"></div>' . "\n";
    echo '      </div>' . "\n";
    echo '</div>' . "\n";
    render_footer();
    echo '</body>' . "\n";
}

// --- Hauptausgabe ---

echo '<!DOCTYPE html>' . "\n\n";
echo '<html lang="en" data-content_root="./">' . "\n";
render_head();
render_body($tocSections);
echo '</html>' . "\n";

// Beende die Ausgabepufferung und erhalte den generierten Inhalt.
$htmlContent = ob_get_clean();

// Schreibe den Inhalt in die angegebene Datei.
if (file_put_contents($outputFile, $htmlContent) === false) {
    fwrite(STDERR, "Fehler: Konnte nicht in Datei '{$outputFile}' schreiben.\n");
    exit(1);
}

echo "Datei '{$outputFile}' erfolgreich erstellt.\n";

?>
