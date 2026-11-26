// abstraction-provenance: {"artifact_sha256": "30e532b6369cf32819067d0255cf0e8b53bd09d253b9be43e644479b91def717", "source_sha256": "d5eb18db536b690023fd61c3dfa4d99f899ec602247f48fb044c53baebb78556", "target_language": "java"}
// serve_compare_transfer.sh — portiert nach java
// Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
// auch in: workspace@local:scripts/serve_compare_transfer.sh
// auch in: workspace@local:vscode/compare/transfer/serve_compare_transfer.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.net.*;
import java.nio.file.*;
import java.util.*;
import java.util.stream.*;

public class ServeCompareTransfer {
    private static final String COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare";
    private static final String TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer";
    private static final String HOST_IP = "152.53.145.65";
    private static final int PORT = 80;
    
    public static void main(String[] args) {
        try {
            Path compareDirPath = Paths.get(COMPARE_DIR);
            if (!Files.exists(compareDirPath)) {
                System.err.println("Verzeichnis " + COMPARE_DIR + " existiert nicht.");
                System.exit(1);
            }
            
            // Eigene Datei ausschließen und Dateien finden
            List<Path> files = Files.list(compareDirPath)
                .filter(Files::isRegularFile)
                .filter(path -> !path.equals(Paths.get(ServeCompareTransfer.class.getProtectionDomain()
                    .getCodeSource().getLocation().toURI()).normalize()))
                .sorted()
                .collect(Collectors.toList());
                
            if (files.isEmpty()) {
                System.out.println("Keine Dateien in " + COMPARE_DIR + " gefunden.");
                System.exit(1);
            }
            
            System.out.println();
            System.out.println("Bereitgestellte Dateien aus " + COMPARE_DIR + ":");
            for (Path src : files) {
                System.out.println("- " + src.getFileName());
            }
            
            System.out.println();
            System.out.println("Copy/Paste auf anderem Gateway (Download nach " + TRANSFER_DIR + "):");
            for (Path src : files) {
                String file = src.getFileName().toString();
                System.out.println("curl -fL --retry 3 --connect-timeout 10 -o " + 
                    TRANSFER_DIR + "/" + file + " http://" + HOST_IP + ":" + PORT + "/" + file);
            }
            
            System.out.println();
            System.out.println("Server auf Port " + PORT + " aktiv. Beenden mit STRG+C.");
            System.out.println();
            
            // HTTP Server starten
            HttpServer server = HttpServer.create(new InetSocketAddress("0.0.0.0", PORT), 0);
            server.createContext("/", new FileHandler(compareDirPath));
            server.setExecutor(null);
            server.start();
            
            System.out.println("Server läuft auf Port " + PORT + ". Beenden mit STRG+C.");
            
            // Warten bis der Server manuell beendet wird
            Thread.currentThread().join();
            
        } catch (Exception e) {
            e.printStackTrace();
            System.exit(1);
        }
    }
    
    static class FileHandler implements com.sun.net.httpserver.HttpHandler {
        private final Path baseDir;
        
        public FileHandler(Path baseDir) {
            this.baseDir = baseDir;
        }
        
        @Override
        public void handle(com.sun.net.httpserver.HttpExchange exchange) throws IOException {
            String requestPath = exchange.getRequestURI().getPath();
            if (requestPath.startsWith("/")) {
                requestPath = requestPath.substring(1);
            }
            
            Path filePath = baseDir.resolve(requestPath).normalize();
            
            // Sicherheitscheck: Stelle sicher, dass der Pfad innerhalb des Basisverzeichnisses bleibt
            if (!filePath.startsWith(baseDir)) {
                exchange.sendResponseHeaders(403, -1); // Forbidden
                return;
            }
            
            if (Files.exists(filePath) && Files.isRegularFile(filePath)) {
                exchange.sendResponseHeaders(200, Files.size(filePath));
                try (OutputStream os = exchange.getResponseBody();
                     InputStream is = Files.newInputStream(filePath)) {
                    is.transferTo(os);
                }
            } else {
                exchange.sendResponseHeaders(404, -1); // Not Found
            }
        }
    }
}
