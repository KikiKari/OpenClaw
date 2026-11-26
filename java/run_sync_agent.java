// abstraction-provenance: {"artifact_sha256": "c4ca47697bb1dc33e94eb99ca10c43f7e27158546147dbc4a213c9b0cbecbf10", "source_sha256": "c372bc97113533b0ca2400d318d3cd0e8cd55cea37f0cc563ab714990cc9efb6", "target_language": "java"}
// run_sync_agent.py — portiert nach java
// Quelle: python, OpenClaw@gateway2:scripts/run_sync_agent.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.nio.file.Path;
import java.nio.file.Paths;
import java.lang.reflect.Field;

public class RunSyncAgent {
    /** Sandbox-Wrapper für sync_agent.py: mappt hartcodierte Host-Pfade auf /workspace. */

    private static final Path WS = Paths.get("/workspace");

    public static void main(String[] args) throws Exception {
        // Setze die Pfade in der SyncAgent-Klasse
        setPathField("CLAWHUB_DIR", WS.resolve("skills"));
        setPathField("GIT_DIR", WS.resolve("git").resolve("skills"));
        setPathField("STATE_FILE", WS.resolve("db").resolve("sync_state.json"));

        // Führe die Hauptmethode aus
        SyncAgent.main(args);
    }

    private static void setPathField(String fieldName, Path value) throws Exception {
        Field field = SyncAgent.class.getField(fieldName);
        field.set(null, value);
    }
}
