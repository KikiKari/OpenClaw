#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "a1b6d6a9d398c3add3764c28c91bfdf85548a1cd1335df2607283563675e0ba5", "source_sha256": "8ec3d801d0245c44e6cd926baa89388c6e541d4fa4c4caa70ff0c0c94f6369d9", "target_language": "python"}
# sqlite-vec-smoke.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/sqlite-vec-smoke.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import sys
import struct
import sqlite3

def vec(values):
    """Convert a list of floats to a binary representation compatible with sqlite-vec"""
    return struct.pack(f'{len(values)}f', *values)

# Create an in-memory database
db = sqlite3.connect(":memory:")

# Load the sqlite-vec extension
try:
    db.enable_load_extension(True)
    # Note: You'll need to provide the correct path to the sqlite-vec extension
    # This might be something like 'sqlite-vec.so' or 'vec.dll' depending on your system
    db.load_extension("./vec")  # Adjust this path as needed
except Exception as err:
    print("sqlite-vec load failed:")
    print(str(err))
    print("expected extension path: ./vec (adjust as needed)")
    sys.exit(1)

# Create the virtual table using vec0
db.execute("""
    CREATE VIRTUAL TABLE v USING vec0(
        id TEXT PRIMARY KEY,
        embedding FLOAT[4]
    );
""")

# Prepare and execute insert statements
insert = db.prepare("INSERT INTO v (id, embedding) VALUES (?, ?)")
insert.execute("a", vec([1, 0, 0, 0]))
insert.execute("b", vec([0, 1, 0, 0]))
insert.execute("c", vec([0.2, 0.2, 0, 0]))

# Perform the query
query = vec([1, 0, 0, 0])
rows = db.execute(
    "SELECT id, vec_distance_cosine(embedding, ?) AS dist FROM v ORDER BY dist ASC",
    (query,)
).fetchall()

print("sqlite-vec ok")
for row in rows:
    print(dict(row))
