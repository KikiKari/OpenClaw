// abstraction-provenance: {"artifact_sha256": "541a315b52192a4af7c01db5e02109179c4cc7994d45b363c1729bea38c0f410", "source_sha256": "25e94789e3af346018b091c7c4d6d65632394c19fcf9eaaeac876efbe534149a", "target_language": "java"}
// bundle-a2ui.sh — portiert nach java
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

public class BundleA2UI {
    public static void main(String[] args) {
        try {
            // Bestimme das Wurzelverzeichnis (übergeordnetes Verzeichnis des Skriptverzeichnisses)
            Path scriptPath = Paths.get(BundleA2UI.class.getProtectionDomain().getCodeSource().getLocation().toURI());
            Path rootDir = scriptPath.getParent().getParent();

            // Pfad zur Node.js-Datei
            Path nodeScript = rootDir.resolve("scripts").resolve("bundle-a2ui.mjs");

            // Prüfe, ob die Datei existiert
            if (!Files.exists(nodeScript)) {
                System.err.println("Fehler: Die Datei " + nodeScript + " wurde nicht gefunden.");
                System.exit(1);
            }

            // Baue den Befehl zum Ausführen der Node.js-Datei
            List<String> command = new ArrayList<>();
            command.add("node");
            command.add(nodeScript.toString());

            // Füge alle übergebenen Argumente hinzu
            for (String arg : args) {
                command.add(arg);
            }

            // Führe den Befehl aus
            ProcessBuilder processBuilder = new ProcessBuilder(command);
            processBuilder.inheritIO(); // Leite Ein-/Ausgabe weiter
            Process process = processBuilder.start();
            int exitCode = process.waitFor();
            System.exit(exitCode);

        } catch (Exception e) {
            e.printStackTrace();
            System.exit(1);
        }
    }
}
