#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "77396fa659221030bcf7661885d74420f114cd3f71565ccf4e17258c286d6d4e", "source_sha256": "fde0925c6da9f2674781482e5d06631c48818efbac6d63d45e764a139fc3bdf4", "target_language": "lua"}
-- 3d.html — portiert nach lua
-- Quelle: html, Projects@secret-vault-public:public/3d.html
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

-- 3d.lua: Secret-Vault Public — Interaktive Architektur
-- Portiert von HTML/JavaScript zu Lua mit LÖVE2D

local spec = {
  schichten = {
    {
      name = "Eingaben",
      farbe = {0.37, 0.40, 0.45}, -- #5f6773
      blocks = {
        {id = "passphrase", name = "Passphrase", untertitel = "nie gespeichert"},
        {id = "vault-datei", name = "Vault-Datei", untertitel = "Ciphertext"},
        {id = "neue-felder", name = "neue Felder", untertitel = "Formular"}
      }
    },
    {
      name = "Schluesselableitung",
      farbe = {0.14, 0.51, 0.80}, -- #2481cc
      blocks = {
        {id = "pbkdf2-210k", name = "PBKDF2 210k", untertitel = "Iterationen"},
        {id = "salt-16-b", name = "Salt 16 B", untertitel = "zufaellig"},
        {id = "sha-256", name = "SHA-256", untertitel = "HMAC"}
      }
    },
    {
      name = "Verschluesselung",
      farbe = {0.36, 0.36, 0.84}, -- #5b5bd6
      blocks = {
        {id = "aes-256-gcm", name = "AES-256-GCM", untertitel = "authentisiert"},
        {id = "iv-12-b", name = "IV 12 B", untertitel = "nie doppelt"},
        {id = "crypto-subtle", name = "crypto.subtle", untertitel = "WebCrypto"}
      }
    },
    {
      name = "Verwaltung",
      farbe = {0.71, 0.32, 0.04}, -- #b45309
      blocks = {
        {id = "anbieter", name = "Anbieter", untertitel = "Gruppen"},
        {id = "felder", name = "Felder", untertitel = "Schluessel/Wert"},
        {id = "rotation", name = "Rotation", untertitel = "neuer Wert"}
      }
    },
    {
      name = "Ausgabe",
      farbe = {0.13, 0.63, 0.42}, -- #22a06b
      blocks = {
        {id = "download", name = "Download", untertitel = "Blob-URL"},
        {id = "export", name = "Export", untertitel = "JSON"},
        {id = "zwischenablage", name = "Zwischenablage", untertitel = "nur auf Klick"}
      }
    }
  },
  kanten = {
    {von = "passphrase", nach = "pbkdf2-210k", art = "fluss"},
    {von = "vault-datei", nach = "salt-16-b", art = "fluss"},
    {von = "neue-felder", nach = "sha-256", art = "fluss"},
    {von = "pbkdf2-210k", nach = "aes-256-gcm", art = "fluss"},
    {von = "salt-16-b", nach = "iv-12-b", art = "fluss"},
    {von = "sha-256", nach = "crypto-subtle", art = "fluss"},
    {von = "aes-256-gcm", nach = "anbieter", art = "fluss"},
    {von = "iv-12-b", nach = "felder", art = "fluss"},
    {von = "crypto-subtle", nach = "rotation", art = "fluss"},
    {von = "anbieter", nach = "download", art = "fluss"},
    {von = "felder", nach = "export", art = "fluss"},
    {von = "rotation", nach = "zwischenablage", art = "fluss"}
  },
  kantenarten = {
    {art = "fluss", farbe = {0.36, 0.36, 0.84}, stil = "voll", text = "Fluss von unten nach oben"} -- #5b5bd6
  }
}

local scene = {}
local camera = {}
local renderer = {}
local nodes = {}
local nodeIdMap = {}
local clickableMeshes = {}
local activeNodeIndex = -1
local raycaster = {}
local mousePosition = {x = 0, y = 0}
local dragging = false
local dragged = false
local lastX, lastY = 0, 0
local azimuth = math.pi / 4
local elevation = 0.62
local rotating = true
local orthographic = true
local D = 26
local radius = 82
local width, height = 800, 600

function love.load()
  love.window.setTitle("Secret-Vault Public")
  love.window.setMode(width, height)
  
  -- Initialisiere Szene
  scene.background = {0.05, 0.08, 0.13} -- #0e1420
  
  -- Initialisiere Kamera
  camera.position = {x = 0, y = 0, z = 0}
  camera.target = {x = 0, y = 0, z = 0}
  
  -- Erstelle Grid
  scene.grid = createGrid(110, 34, {0.15, 0.20, 0.29}, {0.10, 0.14, 0.20}) -- #25324a, #1a2333
  scene.grid.position = {x = 0, y = -24, z = 0}
  
  -- Erstelle Lichtquellen
  scene.lights = {
    ambient = {color = {1, 1, 1}, intensity = 0.66},
    directional = {
      {color = {1, 1, 1}, intensity = 0.8, position = {30, 46, 26}},
      {color = {0.56, 0.64, 1}, intensity = 0.3, position = {-32, 16, -28}} -- #8ea2ff
    }
  }
  
  -- Erstelle Knoten und Kanten
  buildScene()
  
  -- Wähle ersten Knoten
  selectNode(0)
end

function createGrid(size, divisions, color1, color2)
  local grid = {}
  local step = size / divisions
  local halfSize = size / 2
  
  -- Hauptlinien (dicker)
  grid.mainLines = {}
  for i = 0, divisions do
    local pos = -halfSize + i * step
    table.insert(grid.mainLines, {start = {-halfSize, 0, pos}, finish = {halfSize, 0, pos}})
    table.insert(grid.mainLines, {start = {pos, 0, -halfSize}, finish = {pos, 0, halfSize}})
  end
  
  -- Nebenlinien (dünner)
  grid.subLines = {}
  
  return grid
end

function buildScene()
  local BW, BD, BH = 7.4, 4.2, 1.7
  local LUFT = 1.3
  local ABSTAND = 11.4
  local START = -17
  
  scene.group = {}
  scene.group.children = {}
  
  for si, sch in ipairs(spec.schichten) do
    local y = START + (si - 1) * ABSTAND
    local bl = sch.blocks
    
    -- Berechne Layout
    local spalten = math.max(1, math.ceil(#bl / 2))
    local reihen = (#bl <= 1) and 1 or 2
    local gx = spalten * BW + (spalten - 1) * LUFT
    local gz = reihen * BD + (reihen - 1) * LUFT
    
    -- Erstelle Plattform
    local platform = {
      type = "platform",
      geometry = {width = gx + 3, height = 0.6, depth = gz + 3},
      material = {color = multiplyColor(sch.farbe, 0.4)},
      position = {x = 0, y = y - 1.7, z = 0}
    }
    table.insert(scene.group.children, platform)
    
    -- Erstelle Blöcke
    for i, b in ipairs(bl) do
      local sp = (i - 1) % spalten
      local re = math.floor((i - 1) / spalten)
      local x = -gx/2 + BW/2 + sp * (BW + LUFT)
      local z = -gz/2 + BD/2 + re * (BD + LUFT)
      
      -- Erstelle Würfel
      local cube = {
        type = "cube",
        geometry = {width = BW, height = BH, depth = BD},
        material = {color = sch.farbe},
        position = {x = x, y = y, z = z},
        userData = {index = #nodes}
      }
      table.insert(scene.group.children, cube)
      table.insert(clickableMeshes, cube)
      
      -- Erstelle Kanten
      local edges = {
        type = "edges",
        parent = cube,
        material = {color = {0.05, 0.08, 0.13}, opacity = 0.55} -- #0e1420
      }
      table.insert(scene.group.children, edges)
      
      -- Erstelle Beschriftung
      local label = {
        type = "label",
        text = b.name,
        subtitle = b.untertitel or "",
        position = {x = x, y = y + BH/2 + ((b.untertitel and #b.untertitel > 0) and 2.1 or 1.6), z = z}
      }
      table.insert(scene.group.children, label)
      
      -- Speichere Knoten
      local id = b.id or string.gsub(string.lower(b.name), "[^a-z0-9]+", "-"):gsub("^%-+%-*$", "")
      local entry = {
        id = id,
        name = b.name,
        untertitel = b.untertitel or "",
        schicht = sch.name,
        mesh = cube,
        material = cube.material,
        farbe = sch.farbe,
        position = cube.position
      }
      table.insert(nodes, entry)
      nodeIdMap[id] = entry
    end
  end
  
  -- Erstelle Kanten
  scene.edges = {}
  for _, k in ipairs(spec.kanten) do
    local a = nodeIdMap[k.von]
    local b = nodeIdMap[k.nach]
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
      
      local edge = {
        start = {x = a.position.x, y = a.position.y + 0.9, z = a.position.z},
        finish = {x = b.position.x, y = b.position.y - 0.9, z = b.position.z},
        color = art.farbe,
        dashed = (art.stil == "gestrichelt")
      }
      table.insert(scene.edges, edge)
    end
  end
end

function multiplyColor(color, factor)
  return {
    math.min(1, math.max(0, color[1] * factor)),
    math.min(1, math.max(0, color[2] * factor)),
    math.min(1, math.max(0, color[3] * factor))
  }
end

function selectNode(index)
  -- Zurücksetzen vorheriger Auswahl
  if activeNodeIndex >= 0 and nodes[activeNodeIndex + 1] then
    local prevNode = nodes[activeNodeIndex + 1]
    prevNode.material.color = prevNode.farbe
    prevNode.mesh.scale = {x = 1, y = 1, z = 1}
  end
  
  -- Setze neue Auswahl
  activeNodeIndex = ((index % #nodes) + #nodes) % #nodes
  local node = nodes[activeNodeIndex + 1]
  node.material.emissive = {0.2, 0.2, 0.2}
  node.mesh.scale = {x = 1.1, y = 1.5, z = 1.1}
  
  -- Aktualisiere UI (in echter Anwendung würde dies die GUI aktualisieren)
  print("Selected:", node.name)
  print("Subtitle:", node.untertitel)
  print("Layer:", node.schicht)
  print("ID:", node.id)
end

function updateCamera()
  local x = radius * math.cos(elevation) * math.sin(azimuth)
  local y = radius * math.sin(elevation)
  local z = radius * math.cos(elevation) * math.cos(azimuth)
  camera.position.x, camera.position.y, camera.position.z = x, y, z
  camera.target.x, camera.target.y, camera.target.z = 0, 0, 0
end

function zoom(factor)
  if orthographic then
    D = math.max(11, math.min(54, D * factor))
  else
    radius = math.max(32, math.min(160, radius * factor))
  end
end

function love.update(dt)
  -- Automatische Rotation
  if rotating then
    azimuth = azimuth + 0.003
  end
  
  -- Aktualisiere Kamera
  updateCamera()
end

function love.draw()
  -- Zeichne Hintergrund
  love.graphics.clear(scene.background)
  
  -- Zeichne Grid
  love.graphics.setColor(scene.grid.mainLines[1].material and scene.grid.mainLines[1].material.color or {0.2, 0.2, 0.2})
  for _, line in ipairs(scene.grid.mainLines) do
    love.graphics.line(
      line.start[1] + width/2, 
      line.start[3] + height/2,
      line.finish[1] + width/2, 
      line.finish[3] + height/2
    )
  end
  
  -- Zeichne Knoten
  for _, node in ipairs(nodes) do
    love.graphics.setColor(node.material.color)
    love.graphics.rectangle("fill", 
      node.position.x - 20, 
      node.position.z - 10, 
      40, 20)
  end
  
  -- Zeichne Kanten
  for _, edge in ipairs(scene.edges) do
    love.graphics.setColor(edge.color)
    if edge.dashed then
      -- Zeichne gestrichelte Linie
      local dx = edge.finish.x - edge.start.x
      local dy = edge.finish.z - edge.start.z
      local length = math.sqrt(dx*dx + dy*dy)
      local steps = length / 10
      for i = 0, steps, 2 do
        local t1 = i / steps
        local t2 = math.min(1, (i + 1) / steps)
        love.graphics.line(
          edge.start.x + dx * t1, edge.start.z,
          edge.start.x + dx * t2, edge.start.z
        )
      end
    else
      -- Zeichne volle Linie
      love.graphics.line(
        edge.start.x, edge.start.z,
        edge.finish.x, edge.finish.z
      )
    end
  end
end

function love.mousepressed(x, y, button)
  if button == 1 then -- Linke Maustaste
    dragging = true
    dragged = false
    lastX, lastY = x, y
  end
end

function love.mousereleased(x, y, button)
  if button == 1 then
    dragging = false
    if not dragged then
      -- Klick-Ereignis verarbeiten
      -- In einer echten Implementierung würden wir hier Raycasting durchführen
      -- und prüfen, ob ein Knoten getroffen wurde
    end
    dragged = false
  end
end

function love.mousemoved(x, y, dx, dy)
  if dragging then
    if math.abs(dx) + math.abs(dy) > 3 then
      dragged = true
      rotating = false
    end
    azimuth = azimuth - dx * 0.006
    elevation = math.max(0.08, math.min(1.45, elevation + dy * 0.005))
    lastX, lastY = x, y
  end
end

function love.wheelmoved(x, y)
  local factor = (y > 0) and 0.93 or 1.08
  zoom(factor)
end

function love.keypressed(key)
  if key == "r" then
    -- Reset-Kamera
    azimuth = math.pi / 4
    elevation = 0.62
    D = 26
    radius = 82
    rotating = true
    orthographic = true
  elseif key == "o" then
    -- Wechsel zwischen Orthographisch/Perspektivisch
    orthographic = not orthographic
  elseif key == "left" then
    selectNode(activeNodeIndex - 1)
  elseif key == "right" then
    selectNode(activeNodeIndex + 1)
  end
end
