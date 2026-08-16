---
name: "runtime-event"
description: "Typ‑sicheres Event‑Dispatcher‑Framework für OpenClaw (Enum, Payload‑Klassen, Dispatcher‑Singleton, Manager‑Header)."
---

# Runtime Event System Skill

Dieses Skill‑Paket liefert das komplette OpenClaw‑Runtime‑Event‑System:

* **src/common/runtime_event.hpp** – Enum `Event`, Payload‑Basisklassen, konkrete Payload‑Strukturen (Gateway, Node, Cron, Task, Heartbeat) und Fabrik‑Hilfsfunktionen.
* **src/common/runtime_event.cpp** – Thread‑sichere `EventDispatcher`‑Implementierung (Listener‑Registrierung, Queue‑Enqueue, `dispatchAll`).
* **src/common/runtime_event_manager.hpp** – Singleton‑Zugriff (`openclaw::getDispatcher()`).
* **docs/runtime_event.md** – Vollständige Dokumentation der Events, Payloads und Beispiel‑Listener.

**Integration‑Hinweise**
1. Header `runtime_event_manager.hpp` via Pull‑Request hinzufügen, sobald Schreibrechte wieder verfügbar sind.
2. Build‑Pipeline (CMake) um `src/common/runtime_event.cpp` erweitern.
3. Unit‑Tests (`tests/runtime_event_test.cpp`) einbinden und `ctest` laufen lassen.
4. Komponenten‑Code anpassen (`gateway.cpp`, `node_manager.cpp`, `cron.cpp`, `heartbeat.cpp`) – `#include "runtime_event_manager.hpp"` und Helper‑Funktionen nutzen (`makeGatewayStartedEvent`, `makeNodeConnectedEvent`, …).
5. Listener im System‑Init registrieren (z. B. `main.cpp`).
6. Am Ende jeder Haupt‑Loop‑Iteration `openclaw::getDispatcher().dispatchAll();` aufrufen.

**Weiterführende Events** – Zusätzlich zu den im Enum definierten Events können weitere Payload‑Klassen für `EVENT_TASK_COMPLETED`, `EVENT_CRON_RUN_COMPLETED`, etc. ergänzt werden (z. B. von Abstraction‑Manager, Cluster‑Nodes, Github, Clawhub, TikTok).

---
*Dieses Skill‑Proposal enthält Referenzen zu den Quell‑Dateien im Haupt‑Repository. Die eigentlichen Implementierungen bleiben dort erhalten; das Skill‑Package dient nur zur Wiederverwendung und Dokumentation.*
