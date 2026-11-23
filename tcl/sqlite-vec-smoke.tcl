#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "eec9826be157a3c93378a7cadf3383e02a547d4decb376706df79e20173c946a", "source_sha256": "8ec3d801d0245c44e6cd926baa89388c6e541d4fa4c4caa70ff0c0c94f6369d9", "target_language": "tcl"}
# sqlite-vec-smoke.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/sqlite-vec-smoke.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Tcl does not have native support for SQLite extensions like sqlite-vec,
# and it doesn't have a direct equivalent to node:sqlite's DatabaseSync.
# We'll use the standard 'sqlite3' command-line tool via exec as a workaround.

# This function mimics creating a binary float32 array representation.
# In Tcl, we will pass the raw values as a string to be handled by the SQLite extension.
proc vec {values} {
    # Since Tcl cannot easily create binary Float32Arrays without external libraries,
    # we'll just join the list with spaces or pass it directly where needed.
    # For this example, we assume the SQLite extension can handle list of floats.
    return $values
}

# Create an in-memory database using sqlite3 CLI
# Note: This is a simplified approach assuming sqlite3 CLI is available and supports vec0
set db ":memory:"

# Load the sqlite-vec extension
# This would normally require compiling/loading the extension properly
# Here we simulate loading by attempting to load it through CLI
if {[catch {
    exec sqlite3 $db ".load ./sqlite-vec"
} err]} {
    puts stderr "sqlite-vec load failed:"
    puts stderr $err
    puts stderr "expected extension path: ./sqlite-vec.so or similar"
    exit 1
}

# Execute SQL commands
exec sqlite3 $db "
CREATE VIRTUAL TABLE v USING vec0(
  id TEXT PRIMARY KEY,
  embedding FLOAT[4]
);
" >@stdout 2>@stderr

# Insert data
# Note: Direct parameterized queries are difficult with CLI, so we inline values
# This is insecure but necessary due to limitations of CLI interface
set inserts {
    {"a" {1 0 0 0}}
    {"b" {0 1 0 0}}
    {"c" {0.2 0.2 0 0}}
}

foreach insert_data $inserts {
    lassign $insert_data id embedding_list
    set embedding_str [join $embedding_list ","]
    exec sqlite3 $db "INSERT INTO v (id, embedding) VALUES ('$id', '$embedding_str');"
}

# Query data
set query_embedding [vec {1 0 0 0}]
set query_str [join $query_embedding ","]

# Run the query and capture output
set result [exec sqlite3 $db "
SELECT id, vec_distance_cosine(embedding, '$query_str') AS dist FROM v ORDER BY dist ASC;
.headers on
.mode column
"]

puts "sqlite-vec ok"
puts $result
