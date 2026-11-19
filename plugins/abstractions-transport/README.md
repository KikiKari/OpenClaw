# Abstractions Transport

Das Plugin überträgt vollständige Übersetzungsaufträge über den authentifizierten Gateway und den Duplexkanal an gepaarte Nodes. Der Manager bleibt der Workflow-Einstieg. Geräte-IDs ordnen die Knoten zu; die Zugangsdaten verbleiben in der Umgebung des ausführenden Systems. Aufträge und Ergebnisse bleiben auf Nodes nur im Arbeitsspeicher. Nach Verlust des Node-Prozesses bleibt ein nicht übernommener Auftrag ungeklärt und wird nicht automatisch erneut gesendet.

Jeder ausführende Host benötigt das Plugin, Python und den mitgelieferten Worker. `ABSTRACTIONS_NODE`, `ABSTRACTIONS_PYTHON` und `ABSTRACTIONS_WORKER` konfigurieren den lokalen Worker. Im Gateway ordnet `nodes` die Node-Namen den gepaarten Geräte-IDs zu. Der Manager verwendet `gateway_transport.py` und die Gateway-authentifizierte Route `/plugins/abstractions-transport`.

## Gateway-Stand 19.11.2026

Die installierte Node-1-Version gibt einen Ausführungsplatz frei, nachdem ein Worker mit `unknown` beendet wurde. Der Versuch bleibt im Prozessspeicher abfragbar und wird nicht automatisch neu gesendet. Die Tests und Grenzen des Nachweises sind in `/home/openclaw/.openclaw/workspace/docs/abstractions/OPERATIONS.md` dokumentiert.
