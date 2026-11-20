#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "72624df430ccadd434c1a9c064281ccd692d7cead22ac25b22c98665f65d86b2", "source_sha256": "d38a1b483644fdcb8d1b3d4826eb7c89f54ac769bf87debab3ab554e0544844f", "target_language": "lua"}
-- heapsnapshot-delta.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/.agents/skills/openclaw-test-heap-leaks/scripts/heapsnapshot-delta.mjs
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local fs = require("fs")
local path = require("path")

function printUsage()
  io.stderr:write("Usage: lua heapsnapshot-delta.lua <before.heapsnapshot> <after.heapsnapshot> [--top N] [--min-kb N]\n")
  io.stderr:write("   or: lua heapsnapshot-delta.lua --lane-dir <dir> [--pid PID] [--top N] [--min-kb N]\n")
end

function fail(message)
  io.stderr:write(message .. "\n")
  os.exit(1)
end

function parseArgs(argv)
  local options = {
    top = 30,
    minKb = 64,
    laneDir = nil,
    pid = nil,
    files = {},
  }

  local index = 1
  while index <= #argv do
    local arg = argv[index]
    if arg == "--top" then
      options.top = tonumber(argv[index + 1])
      index = index + 2
    elseif arg == "--min-kb" then
      options.minKb = tonumber(argv[index + 1])
      index = index + 2
    elseif arg == "--lane-dir" then
      options.laneDir = argv[index + 1]
      index = index + 2
    elseif arg == "--pid" then
      options.pid = tonumber(argv[index + 1])
      index = index + 2
    else
      table.insert(options.files, arg)
      index = index + 1
    end
  end

  if not options.top or options.top <= 0 then
    fail("--top must be a positive integer")
  end
  if not options.minKb or options.minKb < 0 then
    fail("--min-kb must be a non-negative integer")
  end
  if options.pid ~= nil and (not math.tointeger(options.pid) or options.pid <= 0) then
    fail("--pid must be a positive integer")
  end

  return options
end

local JsonStreamScanner = {}
JsonStreamScanner.__index = JsonStreamScanner

function JsonStreamScanner:new(filePath)
  local stream = fs.createReadStream(filePath, {
    encoding = "utf8",
    highWaterMark = 1024 * 1024,
  })
  
  local scanner = {
    stream = stream,
    buffer = "",
    offset = 0,
    done = false,
  }
  
  setmetatable(scanner, JsonStreamScanner)
  scanner.iterator = stream[Symbol.asyncIterator](stream)
  return scanner
end

function JsonStreamScanner:compactBuffer()
  if self.offset > 65536 then
    self.buffer = string.sub(self.buffer, self.offset + 1)
    self.offset = 0
  end
end

function JsonStreamScanner:ensureAvailable(count)
  count = count or 1
  while not self.done and #self.buffer - self.offset < count do
    local success, nextChunk = pcall(function() return coroutine.wrap(function()
      local result = self.iterator:next()
      if result.done then
        self.done = true
        coroutine.yield(nil)
      else
        coroutine.yield(result.value)
      end
    end)() end)
    
    if not success then
      self.done = true
      break
    end
    
    if nextChunk == nil then
      self.done = true
      break
    end
    
    self.buffer = self.buffer .. nextChunk
  end
end

function JsonStreamScanner:peek()
  self:ensureAvailable(1)
  if self.offset >= #self.buffer then
    return nil
  end
  return string.sub(self.buffer, self.offset + 1, self.offset + 1)
end

function JsonStreamScanner:next()
  self:ensureAvailable(1)
  if self.offset >= #self.buffer then
    return nil
  end
  local char = string.sub(self.buffer, self.offset + 1, self.offset + 1)
  self.offset = self.offset + 1
  self:compactBuffer()
  return char
end

function JsonStreamScanner:skipWhitespace()
  while true do
    local char = self:peek()
    if char == nil or not string.match(char, "%s") then
      return
    end
    self:next()
  end
end

function JsonStreamScanner:expectChar(expected)
  local char = self:next()
  if char ~= expected then
    fail("Expected " .. expected .. " but found " .. (char or "<eof>"))
  end
end

function JsonStreamScanner:find(sequence)
  local matched = 0
  while true do
    local char = self:next()
    if char == nil then
      fail("Could not find " .. sequence)
    end
    if char == string.sub(sequence, matched + 1, matched + 1) then
      matched = matched + 1
      if matched == #sequence then
        return
      end
    else
      matched = (char == string.sub(sequence, 1, 1)) and 1 or 0
      if matched == #sequence then
        return
      end
    end
  end
end

function JsonStreamScanner:readBalancedObject()
  local start = self:next()
  if start ~= "{" then
    fail("Expected { but found " .. (start or "<eof>"))
  end
  local text = "{"
  local depth = 1
  local inString = false
  local escaped = false
  while depth > 0 do
    local char = self:next()
    if char == nil then
      fail("Unexpected EOF while reading JSON object")
    end
    text = text .. char
    if inString then
      if escaped then
        escaped = false
      elseif char == "\\" then
        escaped = true
      elseif char == '"' then
        inString = false
      end
    elseif char == '"' then
      inString = true
    elseif char == "{" then
      depth = depth + 1
    elseif char == "}" then
      depth = depth - 1
    end
  end
  return text
end

function JsonStreamScanner:parseNumberArray(onValue)
  self:skipWhitespace()
  self:expectChar("[")
  self:skipWhitespace()
  if self:peek() == "]" then
    self:next()
    return
  end

  local token = ""
  local index = 0
  local function flush()
    if #token == 0 then
      fail("Unexpected empty number token")
    end
    local value = tonumber(token)
    if not value or value ~= math.floor(value) then
      fail("Invalid numeric token: " .. token)
    end
    onValue(value, index)
    index = index + 1
    token = ""
  end

  while true do
    local char = self:next()
    if char == nil then
      fail("Unexpected EOF while reading number array")
    end
    if char == "]" then
      flush()
      return
    end
    if char == "," then
      flush()
    elseif not string.match(char, "%s") then
      token = token .. char
    end
  end
end

function JsonStreamScanner:readJsonString()
  self:expectChar('"')
  local value = ""
  while true do
    local char = self:next()
    if char == nil then
      fail("Unexpected EOF while reading JSON string")
    end
    if char == '"' then
      return value
    end
    if char ~= "\\" then
      value = value .. char
    else
      local escaped = self:next()
      if escaped == nil then
        fail("Unexpected EOF while reading JSON string escape")
      end
      if escaped == "u" then
        local hex = ""
        for i = 1, 4 do
          local hexChar = self:next()
          if hexChar == nil then
            fail("Unexpected EOF while reading JSON unicode escape")
          end
          hex = hex .. hexChar
        end
        value = value .. string.char(tonumber(hex, 16))
      else
        local escapes = {
          b = "\b",
          f = "\f",
          n = "\n",
          r = "\r",
          t = "\t"
        }
        value = value .. (escapes[escaped] or escaped)
      end
    end
  end
end

function JsonStreamScanner:parseStringArray(onValue)
  self:skipWhitespace()
  self:expectChar("[")
  self:skipWhitespace()
  if self:peek() == "]" then
    self:next()
    return
  end

  local index = 0
  while true do
    local value = self:readJsonString()
    onValue(value, index)
    index = index + 1
    self:skipWhitespace()
    local separator = self:next()
    if separator == "]" then
      return
    end
    if separator ~= "," then
      fail("Expected , or ] but found " .. (separator or "<eof>"))
    end
    self:skipWhitespace()
  end
end

function parseHeapFilename(filePath)
  local base = path.basename(filePath)
  local pattern = "^Heap%.(%d+%.%d+)%.(%d+)%.0%.(%d+)%.heapsnapshot$"
  local stamp, pid, seq = string.match(base, pattern)
  if not stamp or not pid or not seq then
    return nil
  end
  return {
    filePath = filePath,
    pid = tonumber(pid),
    stamp = stamp,
    sequence = tonumber(seq),
  }
end

function resolvePair(options)
  if options.laneDir then
    local entries = {}
    local files = fs.readdirSync(options.laneDir)
    for _, name in ipairs(files) do
      local entry = parseHeapFilename(path.join(options.laneDir, name))
      if entry ~= nil then
        if options.pid == nil or entry.pid == options.pid then
          table.insert(entries, entry)
        end
      end
    end
    
    table.sort(entries, function(left, right)
      if left.pid ~= right.pid then
        return left.pid < right.pid
      end
      if left.stamp ~= right.stamp then
        return left.stamp < right.stamp
      end
      return left.sequence < right.sequence
    end)
    
    if #entries == 0 then
      fail("No matching heap snapshots found in " .. options.laneDir)
    end
    
    local groups = {}
    for _, entry in ipairs(entries) do
      if not groups[entry.pid] then
        groups[entry.pid] = {}
      end
      table.insert(groups[entry.pid], entry)
    end
    
    local candidates = {}
    for pid, group in pairs(groups) do
      table.insert(candidates, {
        pid = pid,
        before = group[1],
        after = group[#group],
        count = #group,
      })
    end
    
    local filtered_candidates = {}
    for _, entry in ipairs(candidates) do
      if entry.count >= 2 then
        table.insert(filtered_candidates, entry)
      end
    end
    
    if #filtered_candidates == 0 then
      fail("Need at least two snapshots for one PID in " .. options.laneDir)
    end
    
    local chosen = nil
    if options.pid ~= nil then
      for _, entry in ipairs(filtered_candidates) do
        if entry.pid == options.pid then
          chosen = entry
          break
        end
      end
    else
      table.sort(filtered_candidates, function(left, right)
        if left.count ~= right.count then
          return left.count > right.count
        end
        return left.pid < right.pid
      end)
      chosen = filtered_candidates[1]
    end
    
    if not chosen then
      fail("No PID with at least two snapshots matched in " .. options.laneDir)
    end
    
    return {
      before = chosen.before.filePath,
      after = chosen.after.filePath,
      pid = chosen.pid,
      snapshotCount = chosen.count,
    }
  end
  
  if #options.files ~= 2 then
    printUsage()
    os.exit(1)
  end
  
  return {
    before = options.files[1],
    after = options.files[2],
    pid = nil,
    snapshotCount = 2,
  }
end

function parseSnapshotMeta(scanner)
  scanner:find('"snapshot":')
  scanner:skipWhitespace()
  local metaObjectText = scanner:readBalancedObject()
  local parsed = {}
  local success, result = pcall(function()
    -- Simple JSON parsing for our specific use case
    local func = load("return " .. metaObjectText)
    if func then
      return func()
    end
    return nil
  end)
  
  if success and result then
    return result.meta
  end
  return nil
end

function buildSummary(filePath)
  local scanner = JsonStreamScanner:new(filePath)
  local meta = parseSnapshotMeta(scanner)
  if not meta then
    fail("Invalid heap snapshot: " .. filePath)
  end
  
  local nodeFieldCount = #meta.node_fields
  local typeNames = meta.node_types[1]
  local typeIndex = nil
  local nameIndex = nil
  local selfSizeIndex = nil
  
  for i, field in ipairs(meta.node_fields) do
    if field == "type" then
      typeIndex = i
    elseif field == "name" then
      nameIndex = i
    elseif field == "self_size" then
      selfSizeIndex = i
    end
  end
  
  if not typeIndex or not nameIndex or not selfSizeIndex then
    fail("Unsupported heap snapshot schema: " .. filePath)
  end
  
  local summaryByIndex = {}
  local nodeCount = 0
  local currentTypeId = 0
  local currentNameId = 0
  local currentSelfSize = 0
  scanner:find('"nodes":')
  scanner:parseNumberArray(function(value, idx)
    local fieldIndex = (idx % nodeFieldCount) + 1
    if fieldIndex == typeIndex then
      currentTypeId = value
      return
    end
    if fieldIndex == nameIndex then
      currentNameId = value
      return
    end
    if fieldIndex == selfSizeIndex then
      currentSelfSize = value
    end
    if fieldIndex ~= nodeFieldCount then
      return
    end
    local key = currentTypeId .. "\t" .. currentNameId
    if not summaryByIndex[key] then
      summaryByIndex[key] = {
        typeId = currentTypeId,
        nameId = currentNameId,
        selfSize = 0,
        count = 0,
      }
    end
    summaryByIndex[key].selfSize = summaryByIndex[key].selfSize + currentSelfSize
    summaryByIndex[key].count = summaryByIndex[key].count + 1
    nodeCount = nodeCount + 1
  end)
  
  local requiredNameIds = {}
  for _, entry in pairs(summaryByIndex) do
    if entry.nameId >= 0 then
      requiredNameIds[entry.nameId] = true
    end
  end
  
  local nameStrings = {}
  scanner:find('"strings":')
  scanner:parseStringArray(function(value, idx)
    if requiredNameIds[idx] then
      nameStrings[idx] = value
    end
  end)
  
  local summary = {}
  for _, entry in pairs(summaryByIndex) do
    local typeName = typeNames[entry.typeId + 1] or "unknown"
    local nameStr = nameStrings[entry.nameId] or ""
    local key = typeName .. "\t" .. nameStr
    summary[key] = {
      type = typeName,
      name = nameStr,
      selfSize = entry.selfSize,
      count = entry.count,
    }
  end
  
  return {
    nodeCount = nodeCount,
    summary = summary,
  }
end

function formatBytes(bytes)
  bytes = math.abs(bytes)
  if bytes >= 1024 * 1024 then
    return string.format("%.2f MiB", bytes / (1024 * 1024))
  end
  if bytes >= 1024 then
    return string.format("%.1f KiB", bytes / 1024)
  end
  return tostring(bytes) .. " B"
end

function formatDelta(bytes)
  local sign = (bytes >= 0) and "+" or "-"
  return sign .. formatBytes(math.abs(bytes))
end

function truncate(text, maxLength)
  if #text <= maxLength then
    return text
  end
  return string.sub(text, 1, maxLength - 1) .. "…"
end

function main()
  local options = parseArgs(arg)
  local pair = resolvePair(options)
  local before = buildSummary(pair.before)
  local after = buildSummary(pair.after)
  local minBytes = options.minKb * 1024
  
  local rows = {}
  for key, nextEntry in pairs(after.summary) do
    local previous = before.summary[key] or { selfSize = 0, count = 0 }
    local sizeDelta = nextEntry.selfSize - previous.selfSize
    local countDelta = nextEntry.count - previous.count
    if sizeDelta >= minBytes then
      table.insert(rows, {
        type = nextEntry.type,
        name = nextEntry.name,
        sizeDelta = sizeDelta,
        countDelta = countDelta,
        afterSize = nextEntry.selfSize,
        afterCount = nextEntry.count,
      })
    end
  end
  
  table.sort(rows, function(left, right)
    if left.sizeDelta ~= right.sizeDelta then
      return left.sizeDelta > right.sizeDelta
    end
    return left.countDelta > right.countDelta
  end)
  
  print("before: " .. pair.before)
  print("after:  " .. pair.after)
  if pair.pid ~= nil then
    print("pid:    " .. pair.pid .. " (" .. pair.snapshotCount .. " snapshots found)")
  end
  print(string.format("nodes:   %d -> %d (%s%d)", 
    before.nodeCount, 
    after.nodeCount, 
    (after.nodeCount - before.nodeCount >= 0) and "+" or "", 
    after.nodeCount - before.nodeCount))
  print("filter:  top=" .. options.top .. " min=" .. options.minKb .. " KiB")
  print("")
  
  if #rows == 0 then
    print("No entries exceeded the minimum delta.")
    return
  end
  
  local displayRows = {}
  for i = 1, math.min(options.top, #rows) do
    table.insert(displayRows, rows[i])
  end
  
  for _, row in ipairs(displayRows) do
    print(string.format("%11s  %10s  %-16s  %s",
      formatDelta(row.sizeDelta),
      "count " .. ((row.countDelta >= 0) and "+" or "") .. row.countDelta,
      row.type,
      truncate(row.name ~= "" and row.name or "(empty)", 96)
    ))
  end
end

main()
