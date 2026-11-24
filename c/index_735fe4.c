// abstraction-provenance: {"artifact_sha256": "7d10c00d2697d2f25b5434fd8e5b61a400fc13149250020159c5afbeccb800d9", "source_sha256": "735fe4b2c74b10f265f715cd4e85d574f46a7132d2e592703b5e712888470105", "target_language": "c"}
// index.html — portiert nach c
// Quelle: html, OpenClaw@main:index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>

void write_html_document(FILE* file) {
    fprintf(file, "<!DOCTYPE html>\n");
    fprintf(file, "<html lang=\"de\">\n");
    fprintf(file, "  <head>\n");
    fprintf(file, "    <meta charset=\"utf-8\" />\n");
    fprintf(file, "    <link rel=\"icon\" href=\"/favicon.ico\" />\n");
    fprintf(file, "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n");
    fprintf(file, "    <meta name=\"theme-color\" content=\"#0b1020\" />\n");
    fprintf(file, "    <meta\n");
    fprintf(file, "      name=\"description\"\n");
    fprintf(file, "      content=\"OpenClaw Startseite für Repository, Dokumentation und Frontend-Branch.\"\n");
    fprintf(file, "    />\n");
    fprintf(file, "    <link rel=\"apple-touch-icon\" href=\"/logo192.png\" />\n");
    fprintf(file, "    <!--\n");
    fprintf(file, "      manifest.json provides metadata used when your web app is installed on a\n");
    fprintf(file, "      user's mobile device or desktop. See https://developers.google.com/web/fundamentals/web-app-manifest/\n");
    fprintf(file, "    -->\n");
    fprintf(file, "    <link rel=\"manifest\" href=\"/manifest.json\" />\n");
    fprintf(file, "    <title>OpenClaw</title>\n");
    fprintf(file, "  </head>\n");
    fprintf(file, "  <body>\n");
    fprintf(file, "    <noscript>You need to enable JavaScript to run this app.</noscript>\n");
    fprintf(file, "    <div id=\"root\"></div>\n");
    fprintf(file, "    <!--\n");
    fprintf(file, "      This HTML file is a template.\n");
    fprintf(file, "      If you open it directly in the browser, you will see an empty page.\n");
    fprintf(file, "\n");
    fprintf(file, "      You can add webfonts, meta tags, or analytics to this file.\n");
    fprintf(file, "      The build step will place the bundled scripts into the <body> tag.\n");
    fprintf(file, "\n");
    fprintf(file, "      To begin the development, run `npm start` or `yarn start`.\n");
    fprintf(file, "      To create a production bundle, use `npm run build` or `yarn build`.\n");
    fprintf(file, "    -->\n");
    fprintf(file, "  </body>\n");
    fprintf(file, "  <script type=\"module\" src=\"/src/index.jsx\"></script>\n");
    fprintf(file, "</html>\n");
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <output_file>\n", argv[0]);
        return 1;
    }

    FILE* output_file = fopen(argv[1], "w");
    if (!output_file) {
        perror("Error opening file");
        return 1;
    }

    write_html_document(output_file);
    fclose(output_file);

    return 0;
}
