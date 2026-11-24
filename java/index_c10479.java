// abstraction-provenance: {"artifact_sha256": "5f13e99a8625dcabb7b4f420be30914d4dedec4e24b0cc027644c6b1d4b8d229", "source_sha256": "c10479f79ca5554fe399cf2f5d70fb5b32e837c1c7a846eb7dd7c9e9e5319c66", "target_language": "java"}
// index.html — portiert nach java
// Quelle: html, Projects@TikTok-Live-Companion:site/index.html
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:site/index.html
// auch in: Projects@vercel/install-and-configure-vercel-w-98sxlo:site/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

import java.io.FileWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

public class IndexGenerator {
    
    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.println("Usage: java IndexGenerator <output-file>");
            System.exit(1);
        }
        
        String outputFile = args[0];
        generateIndexHtml(outputFile);
    }
    
    /**
     * Erzeugt das HTML-Dokument und schreibt es in die angegebene Datei
     */
    public static void generateIndexHtml(String outputFile) {
        try (FileWriter writer = new FileWriter(outputFile, StandardCharsets.UTF_8)) {
            // Schreibe doctype
            writer.write("<!doctype html>\n");
            writer.write("<html lang=\"de\">\n");
            writer.write("  <head>\n");
            writer.write("    <meta charset=\"UTF-8\" />\n");
            writer.write("    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />\n");
            writer.write("    <meta name=\"description\" content=\"Dokumentation für TikTok LIVE Companion 0.8.2 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser.\" />\n");
            writer.write("    <meta name=\"theme-color\" content=\"#ffffff\" />\n");
            writer.write("    <link rel=\"icon\" type=\"image/png\" href=\"/branding/staenderglobus-ios.png\" />\n");
            writer.write("    <link rel=\"apple-touch-icon\" href=\"/branding/staenderglobus-ios.png\" />\n");
            writer.write("    <title>TikTok LIVE Companion – Dokumentation</title>\n");
            writer.write("  </head>\n");
            writer.write("  <body>\n");
            writer.write("    <div id=\"root\"></div>\n");
            writer.write("    <script type=\"module\" src=\"/src/main.tsx\"></script>\n");
            writer.write("  </body>\n");
            writer.write("</html>\n");
            
        } catch (IOException e) {
            System.err.println("Fehler beim Schreiben der Datei: " + e.getMessage());
            System.exit(1);
        }
    }
}
