
# Node 3: xnetx

**Stand:** 2026-07-12

- **Rolle:** gepaarter OpenClaw-Node
- **Hostname:** `xnetx`
- **Tailscale-IP:** `100.73.154.125`
- **Gateway:** `100.82.198.122:18790` über Tailscale
- **Externe IP:** `185.162.248.90` (Administration, nicht Pairing)
- **OpenClaw-Version:** mindestens `2026.6.11`
- **Capabilities:** browser, system
- **Public-IP-Fallback:** nicht eingerichtet und nicht vorgesehen
- **Administrative SSH-Verbindung:** unabhängig vom OpenClaw-Pairing

Pairing und laufender Node-Traffic verwenden ausschließlich Tailscale. Ein
Root-SSH-Schlüssel berechtigt zu administrativen Arbeiten, stellt aber weder
das Pairing her noch ersetzt er die Tailscale-Verbindung.
