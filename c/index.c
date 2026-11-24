// abstraction-provenance: {"artifact_sha256": "1ddfb8d6ff24ff4d60c5aa27ae4a5490f80ca2138112d4a8b6c7ed06d46e669d", "source_sha256": "daf22c296c801d3d533083361cc59fbdc22e5bfe528aa4bad1973b54cc5448a4", "target_language": "c"}
// index.css — portiert nach c
// Quelle: css, OpenClaw@main:src/index.css
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>

void write_css_to_file(const char* filename) {
    FILE* file = fopen(filename, "w");
    if (file == NULL) {
        perror("Fehler beim Öffnen der Datei");
        exit(EXIT_FAILURE);
    }

    /* body styles */
    fprintf(file, "body {\n");
    fprintf(file, "  margin: 0;\n");
    fprintf(file, "  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',\n");
    fprintf(file, "    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',\n");
    fprintf(file, "    sans-serif;\n");
    fprintf(file, "  -webkit-font-smoothing: antialiased;\n");
    fprintf(file, "  -moz-osx-font-smoothing: grayscale;\n");
    fprintf(file, "}\n\n");

    /* code styles */
    fprintf(file, "code {\n");
    fprintf(file, "  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',\n");
    fprintf(file, "    monospace;\n");
    fprintf(file, "}\n");

    fclose(file);
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Verwendung: %s <dateiname>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    write_css_to_file(argv[1]);
    
    return EXIT_SUCCESS;
}
