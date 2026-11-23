#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "8056129aef39b8f98729159cfde28ac6232a267d9626097d94b5b9c9b9fdcd7f", "source_sha256": "8ec3d801d0245c44e6cd926baa89388c6e541d4fa4c4caa70ff0c0c94f6369d9", "target_language": "shell"}
# sqlite-vec-smoke.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/sqlite-vec-smoke.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# This script is a bash translation of the original JavaScript code.
# It tests sqlite-vec functionality using bash and sqlite3 CLI.

# Function to convert array of floats to binary representation
# Mimics the JavaScript 'vec' function behavior
vec() {
    local values=("$@")
    local hex_output=""
    
    # Convert each float to little-endian IEEE 754 hex representation
    for val in "${values[@]}"; do
        # Use Perl to convert float to hex (as bash doesn't have native float conversion)
        local hex_part=$(perl -e "printf '%08x', unpack 'L', pack 'f', $val" | sed 's/\(..\)/\1 /g' | tr ' ' '\n' | tac | tr -d '\n')
        hex_output+="$hex_part"
    done
    
    # Output the hex string without spaces
    echo -n "$hex_output" | tr -d ' '
}

# Create temporary database file
DB_FILE=$(mktemp)
trap 'rm -f "$DB_FILE"' EXIT

# Load sqlite-vec extension
# Note: This assumes sqlite-vec is available as a loadable extension
if ! sqlite3 "$DB_FILE" ".load $(dirname "$(which sqlite3)")/libsqlite_vec.so" "SELECT 1;" >/dev/null 2>&1; then
    echo "sqlite-vec load failed:" >&2
    echo "Cannot load sqlite-vec extension" >&2
    echo "expected extension path: $(dirname "$(which sqlite3)")/libsqlite_vec.so" >&2
    exit 1
fi

# Create virtual table
sqlite3 "$DB_FILE" <<EOF
.load $(dirname "$(which sqlite3)")/libsqlite_vec.so
CREATE VIRTUAL TABLE v USING vec0(
  id TEXT PRIMARY KEY,
  embedding FLOAT[4]
);
EOF

# Insert data
# We need to convert our float arrays to hex representations
sqlite3 "$DB_FILE" <<EOF
.load $(dirname "$(which sqlite3)")/libsqlite_vec.so
INSERT INTO v (id, embedding) VALUES ('a', X'$(vec 1 0 0 0)');
INSERT INTO v (id, embedding) VALUES ('b', X'$(vec 0 1 0 0)');
INSERT INTO v (id, embedding) VALUES ('c', X'$(vec 0.2 0.2 0 0)');
EOF

# Query and display results
echo "sqlite-vec ok"
sqlite3 -separator "|" -header "$DB_FILE" <<EOF
.load $(dirname "$(which sqlite3)")/libsqlite_vec.so
SELECT id, vec_distance_cosine(embedding, X'$(vec 1 0 0 0)') AS dist FROM v ORDER BY dist ASC;
EOF
