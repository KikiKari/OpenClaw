#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "0d9515aeacdb5d2ddaaf65b9243f948d73e3554fdbbd5f7435d0e6f4aa1fab83", "source_sha256": "635ed6e934aa27ffc7ad156af00126e0797ae1d1c065daddb996e2bddc8cbeb3", "target_language": "shell"}
# index.html — portiert nach shell
# Quelle: html, workspace@local:skills/github-clones/openclaw/extensions/qa-lab/web/index.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Function to generate HTML document
generate_html() {
    cat << 'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="color-scheme" content="light dark" />
    <title>QA Lab</title>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>
EOF
}

# Main function
main() {
    local output_file="${1:-}"

    if [[ -z "$output_file" ]]; then
        # Output to stdout if no parameter provided
        generate_html
    else
        # Write to file if parameter provided
        generate_html > "$output_file"
    fi
}

# Call main function with all arguments
main "$@"
