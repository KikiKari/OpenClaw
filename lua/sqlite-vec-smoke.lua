#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "2adfd9c9d4b08b14d9a70b0caaf531c15d5348ce422b67e5df278478c7c24b59", "source_sha256": "8ec3d801d0245c44e6cd926baa89388c6e541d4fa4c4caa70ff0c0c94f6369d9", "target_language": "lua"}
-- sqlite-vec-smoke.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/sqlite-vec-smoke.mjs
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

local sqlite3 = require("lsqlite3")
local vec = require("sqlite-vec")

local function formatErrorMessage(err)
  -- Simplified error formatting, adapt as needed
  return tostring(err)
end

local function vec_buffer(values)
  local buffer = {}
  for i, v in ipairs(values) do
    -- Convert float to binary representation (simplified)
    -- This is a placeholder - proper implementation would need bit operations
    buffer[i] = string.pack("f", v)
  end
  return table.concat(buffer)
end

local db = sqlite3.open_memory()
if not db then
  print("Failed to create in-memory database")
  os.exit(1)
end

-- Enable extension loading
db:enable_load_extension(true)

local success, err = pcall(function()
  vec.load(db)
end)

if not success then
  local message = formatErrorMessage(err)
  print("sqlite-vec load failed:")
  print(message)
  print("expected extension path: " .. (vec.getLoadablePath and vec.getLoadablePath() or "unknown"))
  os.exit(1)
end

db:exec([[
  CREATE VIRTUAL TABLE v USING vec0(
    id TEXT PRIMARY KEY,
    embedding FLOAT[4]
  );
]])

local insert_stmt = db:prepare("INSERT INTO v (id, embedding) VALUES (?, ?)")
insert_stmt:bind_values("a", vec_buffer({1, 0, 0, 0}))
insert_stmt:step()
insert_stmt:reset()

insert_stmt:bind_values("b", vec_buffer({0, 1, 0, 0}))
insert_stmt:step()
insert_stmt:reset()

insert_stmt:bind_values("c", vec_buffer({0.2, 0.2, 0, 0}))
insert_stmt:step()
insert_stmt:finalize()

local query = vec_buffer({1, 0, 0, 0})
local select_stmt = db:prepare("SELECT id, vec_distance_cosine(embedding, ?) AS dist FROM v ORDER BY dist ASC")
select_stmt:bind_values(1, query)

local rows = {}
while select_stmt:step() == sqlite3.ROW do
  table.insert(rows, {
    id = select_stmt:get_value(0),
    dist = select_stmt:get_value(1)
  })
end

select_stmt:finalize()

print("sqlite-vec ok")
for i, row in ipairs(rows) do
  print("Row " .. i .. ": id=" .. row.id .. ", dist=" .. row.dist)
end

db:close()
