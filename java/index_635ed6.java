// abstraction-provenance: {"artifact_sha256": "f5257a52a12f5517054b14b315db13f3a33fcafe4f0707c81cc15f66327b537b", "source_sha256": "635ed6e934aa27ffc7ad156af00126e0797ae1d1c065daddb996e2bddc8cbeb3", "target_language": "java"}
// index.html — portiert nach java
// Quelle: html, workspace@local:skills/github-clones/openclaw/extensions/qa-lab/web/index.html
// auch in: openclaw-css@local:workspace/skills/github-clones/openclaw/extensions/qa-lab/web/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

import java.io.FileWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

public class IndexGenerator {
    
    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.println("Usage: java IndexGenerator <output-file>");
            System.exit(1);
        }
        
        String outputFile = args[0];
        
        try {
            generateIndexHtml(outputFile);
            System.out.println("HTML file generated successfully: " + outputFile);
        } catch (IOException e) {
            System.err.println("Error generating HTML file: " + e.getMessage());
            System.exit(1);
        }
    }
    
    /**
     * Generates an HTML document and writes it to the specified file path.
     * 
     * @param outputPath The path where the HTML file should be written
     * @throws IOException If there is an error writing the file
     */
    public static void generateIndexHtml(String outputPath) throws IOException {
        Path path = Paths.get(outputPath);
        Files.createDirectories(path.getParent());
        
        try (FileWriter writer = new FileWriter(outputPath, StandardCharsets.UTF_8)) {
            // Write doctype
            writer.write("<!doctype html>\n");
            writer.write("<html lang=\"en\">\n");
            writer.write("  <head>\n");
            writer.write("    <meta charset=\"utf-8\" />\n");
            writer.write("    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n");
            writer.write("    <meta name=\"color-scheme\" content=\"light dark\" />\n");
            writer.write("    <title>QA Lab</title>\n");
            writer.write("  </head>\n");
            writer.write("  <body>\n");
            writer.write("    <div id=\"app\"></div>\n");
            writer.write("    <script type=\"module\" src=\"/src/main.ts\"></script>\n");
            writer.write("  </body>\n");
            writer.write("</html>\n");
        }
    }
}
