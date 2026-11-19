#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "089c8059590ce2cac8996165cf0b59db5e61c5536be63930ee3be44870d44250", "source_sha256": "162cbb093559fd1ff9a7f362e753f4d965a73d5e557fce20d9cd95367574146b", "target_language": "lua"}
-- peak-limiter.html — portiert nach lua
-- Quelle: html, Projects@TikTok-Live-Companion:plugin-source/tests/peak-limiter.html
-- auch in: Projects@TikTok-Live-Companion-Android:plugin-source/tests/peak-limiter.html
-- auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/tests/peak-limiter.html
-- auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/tests/peak-limiter.html
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

-- Pegelschutz: synthetischer Web-Audio-Volg Vergleich
-- Offline gerenderte Testsignale. Kein LIVE- oder Hörnachweis.

local json = require("cjson")
local math = require("math")

-- Hilfsfunktionen
local function log10(x)
  return math.log(x) / math.log(10)
end

local function peakDb(values)
  local max_val = 1e-10
  for _, v in ipairs(values) do
    max_val = math.max(max_val, math.abs(v))
  end
  return 20 * log10(max_val)
end

local function limiterStrengthToDbfs(strength)
  return -20 + (strength or 0) / 100 * 20
end

local function limiterMakeupCompensation(threshold, ratio)
  return -threshold * (1 - 1/ratio)
end

-- Simulation eines Audio-Knotens für Peak-Limiter
local function createPeakLimiterNode(context)
  local node = {
    setProtection = function(self, config)
      self.enabled = config.enabled
      self.strength = config.strength
    end,
    process = function(self, inputData)
      if not self.enabled then
        return inputData
      end
      local threshold = limiterStrengthToDbfs(self.strength)
      local limit = 10^(threshold/20)
      local output = {}
      for i, sample in ipairs(inputData) do
        if math.abs(sample) > limit then
          output[i] = sample > 0 and limit or -limit
        else
          output[i] = sample
        end
      end
      return output
    end
  }
  return node
end

-- Rendering-Funktion
local function render(kind, strength, legacy)
  local rate = 48000
  local length = rate
  local data = {}
  
  -- Signal generieren
  for i = 1, length do
    data[i] = 0
    if kind == 'speech-band' then
      data[i] = 0.01 * math.sin(2 * math.pi * 220 * (i-1) / rate)
    elseif kind == 'short-high-tone' and i >= 5000 and i < 5100 then
      data[i] = 0.95 * math.sin(2 * math.pi * 8000 * (i-1) / rate)
    elseif kind == 'level-step' and i >= 5000 and i < 10000 then
      data[i] = 0.95 * math.sin(2 * math.pi * 1000 * (i-1) / rate)
    end
  end
  
  if kind == 'impulse' then
    data[5000] = 0.95
  end
  
  local rendered = {}
  
  if strength == nil then
    -- Kein Limiter
    rendered = data
  elseif legacy then
    -- Legacy Compressor
    local threshold = limiterStrengthToDbfs(strength)
    local makeupGain = limiterMakeupCompensation(threshold, 20)
    local ratio = 20
    local knee = 0.5
    local attack = 0.0015
    local release = 0.08
    
    -- Vereinfachte Kompressor-Simulation
    local envelope = 0
    for i, sample in ipairs(data) do
      local absSample = math.abs(sample)
      if absSample > envelope then
        envelope = envelope + (absSample - envelope) * attack
      else
        envelope = envelope + (absSample - envelope) * release
      end
      
      local gain = 1
      if envelope > 10^(threshold/20) then
        gain = (10^(threshold/20) / envelope)^(1 - 1/ratio)
      end
      
      rendered[i] = sample * gain * 10^(makeupGain/20)
    end
  else
    -- Neuer Peak-Limiter
    local node = createPeakLimiterNode()
    node:setProtection({enabled=true, strength=strength})
    rendered = node:process(data)
  end
  
  local path
  if strength == nil then
    path = 'off'
  elseif legacy then
    path = '0.8.2-compressor'
  else
    path = 'candidate-lookahead'
  end
  
  return {
    kind = kind,
    strength = strength,
    path = path,
    inputDbfs = peakDb(data),
    outputDbfs = peakDb(rendered)
  }
end

-- Hauptfunktion
local function runTest()
  print("Läuft")
  
  local results = {}
  local kinds = {'impulse', 'short-high-tone', 'level-step', 'speech-band'}
  local strengths = {25, 75, 100}
  
  for _, kind in ipairs(kinds) do
    table.insert(results, render(kind, nil, false))
    for _, strength in ipairs(strengths) do
      table.insert(results, render(kind, strength, true))
      table.insert(results, render(kind, strength, false))
    end
  end
  
  -- Fehler prüfen
  local failures = {}
  for _, row in ipairs(results) do
    if row.path == 'candidate-lookahead' then
      local limitExceeded = row.outputDbfs > limiterStrengthToDbfs(row.strength) + 0.05
      local speechBandMismatch = (row.kind == 'speech-band' and math.abs(row.outputDbfs - row.inputDbfs) > 0.05)
      if limitExceeded or speechBandMismatch then
        table.insert(failures, row)
      end
    end
  end
  
  local passed = #failures == 0
  
  return {
    passed = passed,
    failures = failures,
    rows = results
  }
end

-- Ergebnis ausgeben
local result = runTest()
print(json.encode(result, {indent = true}))
