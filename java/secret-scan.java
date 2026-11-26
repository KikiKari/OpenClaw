// abstraction-provenance: {"artifact_sha256": "e75e1918c9ef36e1d71698d49768e87363c839467589d9372b4a12c10dd13945", "source_sha256": "5ea1a8c9a13631404f27bfdb1410099cd81f89038616abac4b49bd62666db56a", "target_language": "java"}
// secret-scan.mjs — portiert nach java
// Quelle: javascript, Onboarding@main:scripts/secret-scan.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.IOException;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.*;
import java.util.regex.Pattern;

public class SecretScan {
    private static final Set<String> SKIPPED = new HashSet<>(Arrays.asList(
        "node_modules",
        ".next",
        ".git",
        ".pytest_cache",
        "__pycache__",
        "media-production/raw",
        "media-production/private"
    ));

    private static final Pattern[] PATTERNS = {
        Pattern.compile("sk-(?:proj|svcacct|ant|or-v1|admin)-[A-Za-z0-9_-]{20,}"),
        Pattern.compile("(?:nvapi|lin_api|ntn|vcp)_[A-Za-z0-9_-]{20,}"),
        Pattern.compile("ELEVENLABS_API_KEY\\s*=\\s*[\"']?[A-Za-z0-9]{20,}"),
        Pattern.compile("WAVESPEED_API_KEY\\s*=\\s*[\"']?[A-Za-z0-9]{20,}")
    };

    private static final List<String> findings = new ArrayList<>();

    public static void main(String[] args) throws IOException {
        Path root = Paths.get("").toAbsolutePath();
        
        Files.walkFileTree(root, new SimpleFileVisitor<Path>() {
            @Override
            public FileVisitResult preVisitDirectory(Path dir, BasicFileAttributes attrs) throws IOException {
                String relativePath = root.relativize(dir).toString();
                
                // Prüfe ob das Verzeichnis übersprungen werden soll
                if (shouldSkip(relativePath, dir.getFileName().toString())) {
                    return FileVisitResult.SKIP_SUBTREE;
                }
                
                return FileVisitResult.CONTINUE;
            }

            @Override
            public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
                String fileName = file.getFileName().toString();
                String relativePath = root.relativize(file).toString();

                // Überspringe .env Dateien außer .env.example
                if (fileName.equals(".env") || 
                    (fileName.startsWith(".env.") && !fileName.equals(".env.example"))) {
                    return FileVisitResult.CONTINUE;
                }

                // Überspringe Dateien größer als 2MB
                if (attrs.size() >= 2_000_000) {
                    return FileVisitResult.CONTINUE;
                }

                // Prüfe den Dateiinhalt auf geheime Schlüssel
                try {
                    String content = Files.readString(file);
                    for (Pattern pattern : PATTERNS) {
                        if (pattern.matcher(content).find()) {
                            findings.add(relativePath);
                            break;
                        }
                    }
                } catch (Exception e) {
                    // Ignoriere Fehler beim Lesen der Datei
                }

                return FileVisitResult.CONTINUE;
            }
        });

        // Entferne Duplikate
        Set<String> uniqueFindings = new LinkedHashSet<>(findings);
        
        if (!uniqueFindings.isEmpty()) {
            System.err.println("Secret-Scan fehlgeschlagen: " + String.join(", ", uniqueFindings));
            System.exit(1);
        }
        
        System.out.println("Secret-Scan bestanden.");
    }

    private static boolean shouldSkip(String relativePath, String currentDir) {
        // Prüfe ob das aktuelle Verzeichnis direkt übersprungen werden soll
        if (SKIPPED.contains(currentDir)) {
            return true;
        }

        // Prüfe jeden Teil des Pfades
        String[] pathParts = relativePath.split("[\\\\/]");
        for (String part : pathParts) {
            if (SKIPPED.contains(part)) {
                return true;
            }
        }

        // Prüfe ob der komplette Pfad übersprungen werden soll
        for (String skippedPath : SKIPPED) {
            if (relativePath.equals(skippedPath) || 
                relativePath.startsWith(skippedPath + System.getProperty("file.separator"))) {
                return true;
            }
        }

        return false;
    }
}
