#!/usr/bin/perl
# gateway-dashboard.html — portiert nach perl5
# Quelle: html, OpenClaw@main:examples/gateway-dashboard.html
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

# Parameter für die Ausgabedatei
my $output_file = $ARGV[0] // 'gateway-dashboard.html';

# HTML-Struktur erzeugen
my $html = create_html();

# In Datei schreiben
open my $fh, '>', $output_file or die "Kann Datei '$output_file' nicht öffnen: $!";
print $fh $html;
close $fh;

print "HTML wurde in '$output_file' geschrieben.\n";

# Funktion zur Erzeugung der HTML-Struktur
sub create_html {
    my $html = '';

    # DOCTYPE und HTML-Tag
    $html .= '<!DOCTYPE html>' . "\n";
    $html .= '<html lang="en">' . "\n";

    # Head-Bereich
    $html .= '<head>' . "\n";
    $html .= '  <meta charset="UTF-8">' . "\n";
    $html .= '  <meta name="viewport" content="width=device-width, initial-scale=1.0">' . "\n";
    $html .= '  <title>OpenClaw — Gateway Dashboard</title>' . "\n";
    $html .= '  <link rel="stylesheet" href="gateway-styles.css">' . "\n";
    $html .= '</head>' . "\n";

    # Body-Bereich
    $html .= '<body>' . "\n";

    # Header
    $html .= '  <header>' . "\n";
    $html .= '    <h1>OpenClaw Cluster</h1>' . "\n";
    $html .= '    <span id="cluster-status" class="badge">Checking...</span>' . "\n";
    $html .= '  </header>' . "\n";

    # Main-Bereich
    $html .= '  <main>' . "\n";

    # Grid-Section
    $html .= '    <section class="grid">' . "\n";

    # Gateway 1
    $html .= '      <div class="card" id="gw1">' . "\n";
    $html .= '        <h2>Gateway 1</h2>' . "\n";
    $html .= '        <p class="endpoint">gateway1.openclaw.internal</p>' . "\n";
    $html .= '        <div class="status-dot"></div>' . "\n";
    $html .= '      </div>' . "\n";

    # Gateway 2
    $html .= '      <div class="card" id="gw2">' . "\n";
    $html .= '        <h2>Gateway 2</h2>' . "\n";
    $html .= '        <p class="endpoint">gateway2.openclaw.internal</p>' . "\n";
    $html .= '        <div class="status-dot"></div>' . "\n";
    $html .= '      </div>' . "\n";

    $html .= '    </section>' . "\n";

    # Metrics-Section
    $html .= '    <section class="metrics">' . "\n";
    $html .= '      <h2>Node Metrics</h2>' . "\n";
    $html .= '      <table>' . "\n";
    $html .= '        <thead>' . "\n";
    $html .= '          <tr><th>Node</th><th>Latency</th><th>Requests</th><th>Status</th></tr>' . "\n";
    $html .= '        </thead>' . "\n";
    $html .= '        <tbody id="metrics-body">' . "\n";
    $html .= '          <tr><td colspan="4">Loading...</td></tr>' . "\n";
    $html .= '        </tbody>' . "\n";
    $html .= '      </table>' . "\n";
    $html .= '    </section>' . "\n";

    $html .= '  </main>' . "\n";

    # Script-Bereich
    $html .= '  <script>' . "\n";
    $html .= '    const GATEWAY_URL = window.OPENCLAW_URL || "http://localhost:8080";' . "\n";
    $html .= "\n";
    $html .= '    async function pollStatus() {' . "\n";
    $html .= '      try {' . "\n";
    $html .= '        const res = await fetch(`${GATEWAY_URL}/health`);' . "\n";
    $html .= '        const ok = res.ok;' . "\n";
    $html .= '        document.getElementById("cluster-status").textContent = ok ? "Online" : "Degraded";' . "\n";
    $html .= '        document.getElementById("cluster-status").className = `badge ${ok ? "ok" : "warn"}`;' . "\n";
    $html .= '        document.querySelectorAll(".status-dot").forEach(d => d.className = `status-dot ${ok ? "green" : "red"}`);' . "\n";
    $html .= '      } catch {' . "\n";
    $html .= '        document.getElementById("cluster-status").textContent = "Offline";' . "\n";
    $html .= '        document.getElementById("cluster-status").className = "badge error";' . "\n";
    $html .= '      }' . "\n";
    $html .= '    }' . "\n";
    $html .= "\n";
    $html .= '    pollStatus();' . "\n";
    $html .= '    setInterval(pollStatus, 5000);' . "\n";
    $html .= '  </script>' . "\n";

    # Abschluss
    $html .= '</body>' . "\n";
    $html .= '</html>' . "\n";

    return $html;
}
