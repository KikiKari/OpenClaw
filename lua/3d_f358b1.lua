#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "e090f612620ec0e40d64614d4b692d7db9073e150d89e6d4ea1999fa980d10ca", "source_sha256": "f358b11a77df0b448606016b4bebe36f1bbeb63039d30369ebe5c1689f0faff9", "target_language": "lua"}
-- 3d.html — portiert nach lua
-- Quelle: html, Projects@Telegram-Monitor:public/3d.html
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

-- 3d.lua: Telegram Monitor — Interaktive Architektur
-- Portiert von HTML/JS nach Lua mit Love2D für 3D-Darstellung

local spec = {
  schichten = {
    {
      name = "Plattformen",
      farbe = {0.37, 0.40, 0.45}, -- #5f6773
      blocks = {
        {id = "t-me", name = "t.me", untertitel = "ohne Zugangsdaten"},
        {id = "bot-api", name = "Bot-API", untertitel = "Bot-Token"},
        {id = "mtproto", name = "MTProto", untertitel = "api_id + hash"},
        {id = "discord", name = "Discord", untertitel = "Invite-Lookup"},
        {id = "tiktok", name = "TikTok", untertitel = "oeffentliche Quellen"}
      }
    },
    {
      name = "Adapter",
      farbe = {0.14, 0.51, 0.80}, -- #2481cc
      blocks = {
        {id = "telegram-web", name = "telegram_web", untertitel = "immer aktiv"},
        {id = "telegram-bot", name = "telegram_bot", untertitel = "Metadaten"},
        {id = "mtproto", name = "mtproto", untertitel = "globale Suche"},
        {id = "tiktok-live", name = "tiktok_live", untertitel = "Livegang"}
      }
    },
    {
      name = "Kern",
      farbe = {0.43, 0.36, 0.82}, -- #6d5bd0
      blocks = {
        {id = "registry", name = "registry", untertitel = "zusammenfuehren"},
        {id = "store", name = "store", untertitel = "Zustand halten"},
        {id = "live", name = "live", untertitel = "Wechsel erkennen"},
        {id = "models", name = "models", untertitel = "Datenformen"}
      }
    },
    {
      name = "Ausgabe",
      farbe = {1.00, 0.17, 0.33}, -- #fe2c55
      blocks = {
        {id = "notify", name = "notify", untertitel = "melden"},
        {id = "cli-py", name = "cli.py", untertitel = "Kommandozeile"},
        {id = "server-py", name = "server.py", untertitel = "127.0.0.1"},
        {id = "web-pwa", name = "web/ PWA", untertitel = "installierbar"}
      }
    }
  },
  kanten = {
    {von = "t-me", nach = "telegram-web", art = "fluss"},
    {von = "bot-api", nach = "telegram-bot", art = "fluss"},
    {von = "mtproto", nach = "mtproto", art = "fluss"},
    {von = "discord", nach = "tiktok-live", art = "fluss"},
    {von = "tiktok", nach = "telegram-web", art = "fluss"},
    {von = "telegram-web", nach = "registry", art = "fluss"},
    {von = "telegram-bot", nach = "store", art = "fluss"},
    {von = "mtproto", nach = "live", art = "fluss"},
    {von = "tiktok-live", nach = "models", art = "fluss"},
    {von = "registry", nach = "notify", art = "fluss"},
    {von = "store", nach = "cli-py", art = "fluss"},
    {von = "live", nach = "server-py", art = "fluss"},
    {von = "models", nach = "web-pwa", art = "fluss"}
  },
  kantenarten = {
    {art = "fluss", farbe = {0.14, 0.51, 0.80}, stil = "voll", text = "Fluss von unten nach oben"} -- #2481cc
  }
}

function love.load()
  love.window.setTitle("Telegram Monitor — Interaktive Architektur")
  love.window.setMode(1200, 800)
  
  -- Globale Variablen
  D = 26
  radius = 82
  aspekt = 1
  azimut = math.pi/4
  elevation = 0.62
  rotiert = true
  zieht = false
  gezogen = false
  lx = 0
  ly = 0
  aktiv = -1
  
  -- Kamera Setup
  kameraIso = {
    left = -D,
    right = D,
    top = D,
    bottom = -D,
    near = 0.1,
    far = 600
  }
  
  kameraPersp = {
    fov = 42,
    aspect = 1,
    near = 0.1,
    far = 600
  }
  
  kamera = kameraIso
  iso = true
  
  -- Szene Setup
  szene = {}
  knoten = {}
  nachId = {}
  klickbar = {}
  
  -- Lichter
  ambientLight = {color = {1, 1, 1}, intensity = 0.66}
  directionalLight = {color = {1, 1, 1}, intensity = 0.8, position = {30, 46, 26}}
  gegenLight = {color = {0.56, 0.64, 1}, intensity = 0.3, position = {-32, 16, -28}}
  
  -- Grid
  raster = {size = 110, divisions = 34, color1 = {0.15, 0.20, 0.29}, color2 = {0.10, 0.14, 0.20}}
  
  -- Aufbau
  local BW = 7.4
  local BD = 4.2
  local BH = 1.7
  local LUFT = 1.3
  local ABSTAND = 11.4
  local START = -17
  
  for si, sch in ipairs(spec.schichten) do
    local y = START + si * ABSTAND
    local bl = {}
    
    for _, b in ipairs(sch.blocks) do
      table.insert(bl, type(b) == "string" and {id = nil, name = b, untertitel = ""} or b)
    end
    
    local spalten = math.max(1, math.ceil(#bl / 2))
    local reihen = #bl <= 1 and 1 or 2
    local gx = spalten*BW + (spalten-1)*LUFT
    local gz = reihen*BD + (reihen-1)*LUFT
    
    -- Plattform
    local platte = {
      type = "platte",
      position = {0, y-1.7, 0},
      size = {gx+3, 0.6, gz+3},
      color = {sch.farbe[1]*0.4, sch.farbe[2]*0.4, sch.farbe[3]*0.4}
    }
    table.insert(szene, platte)
    
    for i, b in ipairs(bl) do
      local sp = (i-1) % spalten
      local re = math.floor((i-1) / spalten)
      local x = -gx/2 + BW/2 + sp*(BW+LUFT)
      local z = -gz/2 + BD/2 + re*(BD+LUFT)
      
      local block = {
        type = "block",
        position = {x, y, z},
        size = {BW, BH, BD},
        color = sch.farbe,
        userData = {index = #knoten}
      }
      table.insert(szene, block)
      table.insert(klickbar, block)
      
      -- Kanten
      local kante = {
        type = "kante",
        points = {{x, y + 0.9, z}, {x, y - 0.9, z}},
        color = {0.05, 0.08, 0.13} -- #0e1420
      }
      table.insert(szene, kante)
      
      -- Text
      local textObj = {
        type = "text",
        text = b.name,
        untertitel = b.untertitel,
        position = {x, y + BH/2 + (b.untertitel and 2.1 or 1.6), z}
      }
      table.insert(szene, textObj)
      
      local id = b.id or string.gsub(string.lower(b.name), "[^a-z0-9]+", "-"):gsub("^%-+%-*$", "")
      local eintrag = {
        id = id,
        name = b.name,
        untertitel = b.untertitel or "",
        schicht = sch.name,
        block = block,
        color = sch.farbe,
        position = {x, y, z}
      }
      table.insert(knoten, eintrag)
      nachId[id] = eintrag
    end
  end
  
  -- Kanten zeichnen
  for _, k in ipairs(spec.kanten) do
    local a = nachId[k.von]
    local b = nachId[k.nach]
    if a and b then
      local art = nil
      for _, ka in ipairs(spec.kantenarten) do
        if ka.art == k.art then
          art = ka
          break
        end
      end
      
      if not art then
        art = {farbe = {0.56, 0.64, 1}, stil = "voll"} -- #8ea2ff
      end
      
      local linie = {
        type = "linie",
        points = {{a.position[1], a.position[2] + 0.9, a.position[3]}, {b.position[1], b.position[2] - 0.9, b.position[3]}},
        color = art.farbe,
        stil = art.stil
      }
      table.insert(szene, linie)
    end
  end
  
  -- Initiale Auswahl
  waehle(0)
end

function waehle(i)
  if aktiv >= 0 then
    knoten[aktiv+1].block.color = knoten[aktiv+1].color
  end
  
  aktiv = ((i % #knoten) + #knoten) % #knoten
  local k = knoten[aktiv+1]
  k.block.color = {k.color[1]*1.2, k.color[2]*1.2, k.color[3]*1.2}
end

function stelle()
  local x = radius*math.cos(elevation)*math.sin(azimut)
  local y = radius*math.sin(elevation)
  local z = radius*math.cos(elevation)*math.cos(azimut)
  kamera.position = {x, y, z}
  kamera.target = {0, 0, 0}
end

function zoom(f)
  if iso then
    D = math.max(11, math.min(54, D * f))
  else
    radius = math.max(32, math.min(160, radius * f))
  end
end

function love.mousepressed(x, y, button)
  if button == 1 then
    zieht = true
    gezogen = false
    lx = x
    ly = y
  end
end

function love.mousereleased(x, y, button)
  if button == 1 then
    zieht = false
    gezogen = false
  end
end

function love.mousemoved(x, y, dx, dy)
  if zieht then
    if math.abs(x-lx) + math.abs(y-ly) > 3 then
      gezogen = true
      rotiert = false
    end
    azimut = azimut - dx * 0.006
    elevation = math.max(0.08, math.min(1.45, elevation + dy * 0.005))
    lx = x
    ly = y
  end
end

function love.wheelmoved(x, y)
  zoom(y > 0 and 0.85 or 1.18)
end

function love.keypressed(key)
  if key == "r" then
    azimut = math.pi/4
    elevation = 0.62
    D = 26
    radius = 82
    rotiert = true
    iso = true
    kamera = kameraIso
  elseif key == "i" then
    iso = not iso
    kamera = iso and kameraIso or kameraPersp
  elseif key == "+" then
    zoom(0.85)
  elseif key == "-" then
    zoom(1.18)
  elseif key == "left" then
    waehle(aktiv - 1)
  elseif key == "right" then
    waehle(aktiv + 1)
  end
end

function love.update(dt)
  if rotiert then
    azimut = azimut + 0.003
  end
  stelle()
end

function love.draw()
  -- Hintergrund
  love.graphics.setBackgroundColor(0.05, 0.08, 0.13) -- #0e1420
  
  -- 3D Szene rendern (vereinfacht)
  for _, obj in ipairs(szene) do
    if obj.type == "block" then
      love.graphics.setColor(obj.color[1], obj.color[2], obj.color[3])
      love.graphics.rectangle("fill", 
        400 + obj.position[1]*10, 
        300 + obj.position[2]*10, 
        obj.size[1]*10, 
        obj.size[2]*10)
    end
  end
  
  -- UI Elemente
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Telegram Monitor", 20, 20)
  love.graphics.print("Verwende Pfeiltasten zum Navigieren, +/- zum Zoomen", 20, 40)
  love.graphics.print("R: Zurücksetzen, I: Iso/Persp wechseln", 20, 60)
  
  if aktiv >= 0 then
    local k = knoten[aktiv+1]
    love.graphics.print("Ausgewählt: " .. k.name, 20, 100)
    love.graphics.print("Schicht: " .. k.schicht, 20, 120)
    love.graphics.print("ID: " .. k.id, 20, 140)
  end
end
