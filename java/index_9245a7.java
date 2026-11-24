// abstraction-provenance: {"artifact_sha256": "fdc79e6bda780c985b5882f3b1a4fc74a3e8bc769b6cd78fadce2b128e06a767", "source_sha256": "9245a78489adb3949ae2a56f5e0987a465142b9a8ee97bddaca453f5011daef8", "target_language": "java"}
// index.html — portiert nach java
// Quelle: html, Projects@Program-Derivation:public/index.html
// auch in: Projects@Vision-Check:public/index.html
// auch in: Projects@Weather-Check:public/index.html
// auch in: Projects@abstractions:public/index.html
// auch in: 5 weiteren Fundstellen
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

import java.io.FileWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

public class IndexHtmlGenerator {
    
    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.println("Verwendung: java IndexHtmlGenerator <ausgabedatei>");
            System.exit(1);
        }
        
        String dateiname = args[0];
        
        try {
            generiereIndexHtml(dateiname);
            System.out.println("Datei " + dateiname + " erfolgreich erstellt.");
        } catch (IOException e) {
            System.err.println("Fehler beim Schreiben der Datei: " + e.getMessage());
            System.exit(1);
        }
    }
    
    /**
     * Erzeugt eine HTML-Datei mit Weiterleitung zur 3D-Ansicht
     * @param dateiname Der Name der zu erstellenden Datei
     * @throws IOException wenn beim Schreiben ein Fehler auftritt
     */
    public static void generiereIndexHtml(String dateiname) throws IOException {
        try (FileWriter writer = new FileWriter(dateiname, StandardCharsets.UTF_8)) {
            // DOCTYPE und HTML-Start
            writer.write("<!DOCTYPE html>\n");
            writer.write("<html lang=\"de\">\n");
            writer.write("<head>\n");
            
            // Metadaten
            writer.write("<meta charset=\"utf-8\">\n");
            writer.write("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n");
            writer.write("<meta http-equiv=\"refresh\" content=\"0; url=3d.html\">\n");
            
            // Titel
            writer.write("<title>Weiterleitung zur 3D-Ansicht</title>\n");
            
            // Canonical Link
            writer.write("<link rel=\"canonical\" href=\"3d.html\">\n");
            
            // JavaScript-Weiterleitung
            writer.write("<script>location.replace('3d.html');</script>\n");
            
            // Head-Abschluss und Body-Start
            writer.write("</head>\n");
            writer.write("<body>\n");
            
            // Inhalt mit Link
            writer.write("<p><a href=\"3d.html\">3D-Ansicht öffnen</a></p>\n");
            
            // Body und HTML-Abschluss
            writer.write("</body>\n");
            writer.write("</html>\n");
        }
    }
}
