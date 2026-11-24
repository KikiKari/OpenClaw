// abstraction-provenance: {"artifact_sha256": "b6a070f9c44f8d1a54d52822da1afc0e3d00f0330045e8ab7e3ccbb473d5292c", "source_sha256": "635ed6e934aa27ffc7ad156af00126e0797ae1d1c065daddb996e2bddc8cbeb3", "target_language": "c"}
// index.html — portiert nach c
// Quelle: html, workspace@local:skills/github-clones/openclaw/extensions/qa-lab/web/index.html
// auch in: openclaw-css@local:workspace/skills/github-clones/openclaw/extensions/qa-lab/web/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void write_html_document(FILE* file) {
    fprintf(file, "<!doctype html>\n");
    fprintf(file, "<html lang=\"en\">\n");
    fprintf(file, "  <head>\n");
    fprintf(file, "    <meta charset=\"utf-8\" />\n");
    fprintf(file, "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n");
    fprintf(file, "    <meta name=\"color-scheme\" content=\"light dark\" />\n");
    fprintf(file, "    <title>QA Lab</title>\n");
    fprintf(file, "  </head>\n");
    fprintf(file, "  <body>\n");
    fprintf(file, "    <div id=\"app\"></div>\n");
    fprintf(file, "    <script type=\"module\" src=\"/src/main.ts\"></script>\n");
    fprintf(file, "  </body>\n");
    fprintf(file, "</html>\n");
}

int main(int argc, char* argv[]) {
    FILE* output_file;
    
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <output_file>\n", argv[0]);
        return 1;
    }
    
    output_file = fopen(argv[1], "w");
    if (output_file == NULL) {
        perror("Error opening file");
        return 1;
    }
    
    write_html_document(output_file);
    
    fclose(output_file);
    return 0;
}
