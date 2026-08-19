#!/bin/bash
# index.css — portiert nach shell
# Quelle: css, OpenClaw@main:src/index.css
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Function to generate the CSS content
generate_css() {
    cat << 'EOF'
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}
EOF
}

# Main function
main() {
    local output_file="${1:-}"

    if [[ -z "$output_file" ]]; then
        echo "Usage: $0 <output_file>" >&2
        exit 1
    fi

    # Generate CSS and write to the specified file
    generate_css > "$output_file"
    
    echo "CSS file generated successfully: $output_file"
}

# Run main function with all arguments
main "$@"
