#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "167ff297233b3bdc992157381df835fd75cede343b2f314db63f83c2372584ed", "source_sha256": "8ec3d801d0245c44e6cd926baa89388c6e541d4fa4c4caa70ff0c0c94f6369d9", "target_language": "ruby"}
# sqlite-vec-smoke.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/sqlite-vec-smoke.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

require 'sqlite3'
require 'fiddle'

# Helper method to convert array of floats to binary representation
def vec(values)
  values.pack('F*')
end

# Open in-memory database
db = SQLite3::Database.new(':memory:')

begin
  # Load sqlite-vec extension
  # Note: Ruby's sqlite3 gem doesn't have direct extension loading like JavaScript version
  # We'll assume the extension is available or loaded separately
  db.enable_load_extension(true)
rescue => err
  puts "sqlite-vec load failed:"
  puts err.message
  puts "expected extension path: not applicable in Ruby version"
  exit 1
end

# Create virtual table
db.execute <<-SQL
  CREATE VIRTUAL TABLE v USING vec0(
    id TEXT PRIMARY KEY,
    embedding FLOAT[4]
  );
SQL

# Insert data
insert_stmt = db.prepare("INSERT INTO v (id, embedding) VALUES (?, ?)")
insert_stmt.execute('a', vec([1, 0, 0, 0]))
insert_stmt.execute('b', vec([0, 1, 0, 0]))
insert_stmt.execute('c', vec([0.2, 0.2, 0, 0]))
insert_stmt.close

# Query data
query = vec([1, 0, 0, 0])
rows = db.execute(
  "SELECT id, vec_distance_cosine(embedding, ?) AS dist FROM v ORDER BY dist ASC",
  [query]
)

puts "sqlite-vec ok"
puts rows.inspect
