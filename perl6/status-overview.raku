#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "463efd79d23cf568ada48a6f8ef0dc5c76e5acbd18bd88971407959c942b994e", "source_sha256": "f95cba00197f4650dddde02431fe14a0ca1baea932052e66b16f5778582e944f", "target_language": "perl6"}
# status-overview.css — portiert nach perl6
# Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview.css
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use v6;

sub MAIN($output-file) {
    my $css = generate-css();
    spurt($output-file, $css);
}

sub generate-css() {
    my @rules;

    # Universal selector and html/body styles
    @rules.push: '*{box-sizing:border-box}';
    @rules.push: 'html,body{margin:0;min-height:100%;background:#101015;color:#fff;font:14px system-ui,sans-serif}';
    @rules.push: 'body{display:flex;flex-direction:column;height:100vh}';

    # Header styles
    @rules.push: 'header{display:flex;gap:1em;align-items:baseline;padding:0 12px}';
    @rules.push: 'h1{font-size:17px;margin:8px 0}';
    @rules.push: 'header p{font-size:12px;color:#bbb;margin:0}';

    # Main grid layout
    @rules.push: 'main{flex:1;min-height:0;display:grid;grid-template-columns:repeat(3,minmax(0,1fr));grid-template-rows:repeat(3,minmax(0,1fr));gap:4px;padding:0}';

    # Tile styles
    @rules.push: '.tile{min-width:0;min-height:0;display:flex;flex-direction:column;background:#202026;border:1px solid #393940}';
    @rules.push: '.tile h2{font-size:13px;margin:3px 8px}';
    @rules.push: '.tile video{min-height:0;width:100%;flex:1;object-fit:contain;background:#000}';
    @rules.push: '.tile p{font-size:11px;margin:3px 8px;color:#ddd}';

    # Alternative grid layout
    @rules.push: 'main.grid2{grid-template-columns:repeat(2,minmax(0,1fr));grid-template-rows:repeat(2,minmax(0,1fr))}';

    # Hidden tiles
    @rules.push: '.tile[hidden]{display:none}';

    return @rules.join("\n");
}
