// abstraction-provenance: {"artifact_sha256": "33de925a16b9beaca138ed267a06e193342e0bec5c6bebf86bc7c17a361803b7", "source_sha256": "daf22c296c801d3d533083361cc59fbdc22e5bfe528aa4bad1973b54cc5448a4", "target_language": "java"}
// index.css — portiert nach java
// Quelle: css, OpenClaw@main:src/index.css
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Path;

public class IndexCssGenerator {
    
    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.println("Usage: java IndexCssGenerator <output-file>");
            System.exit(1);
        }
        
        String outputFile = args[0];
        generateCssFile(outputFile);
    }
    
    public static void generateCssFile(String outputPath) {
        try (FileWriter writer = new FileWriter(Path.of(outputPath).toFile())) {
            
            // Write body styles
            writer.write("body {\n");
            writer.write("  margin: 0;\n");
            writer.write("  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',\n");
            writer.write("    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',\n");
            writer.write("    sans-serif;\n");
            writer.write("  -webkit-font-smoothing: antialiased;\n");
            writer.write("  -moz-osx-font-smoothing: grayscale;\n");
            writer.write("}\n\n");
            
            // Write code styles
            writer.write("code {\n");
            writer.write("  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',\n");
            writer.write("    monospace;\n");
            writer.write("}\n");
            
        } catch (IOException e) {
            System.err.println("Error writing CSS file: " + e.getMessage());
            System.exit(1);
        }
    }
}
