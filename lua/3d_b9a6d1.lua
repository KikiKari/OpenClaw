#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "0f5c038871200b3396de526a281c6eeb10a84411919fe9e3b8d2ffcdd081829d", "source_sha256": "b9a6d1d4d9783116bef70521da8501c55e460dc5bd8fb1efea805da22633ddc3", "target_language": "lua"}
-- 3d.html — portiert nach lua
-- Quelle: html, Projects@clawhub:public/3d.html
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

-- 3D-Dokumentation für ClawHub-Git-Sync
-- Portiert von HTML/JS zu Lua mit LOVE2D

local spec = {
  schichten = {
    {
      name = "Seiten",
      farbe = "#5f6773",
      blocks = {
        {id = "workspace-skills", name = "workspace/skills", untertitel = "ClawHub-Seite"},
        {id = "workspace-git-skills", name = "workspace/git/skills", untertitel = "Git-Seite"}
      }
    },
    {
      name = "Vergleich",
      farbe = "#2481cc",
      blocks = {
        {id = "zeitstempel", name = "Zeitstempel", untertitel = "welche Seite neuer"},
        {id = "hash", name = "Hash", untertitel = "ob geaendert"},
        {id = "konfliktfall", name = "Konfliktfall", untertitel = "melden statt raten"}
      }
    },
    {
      name = "Absicherung",
      farbe = "#6d5bd0",
      blocks = {
        {id = "backup", name = "Backup", untertitel = "vor jeder Aenderung"},
        {id = "dry-run", name = "Dry-Run", untertitel = "Plan zeigen"},
        {id = "freigabe", name = "Freigabe", untertitel = "manuell"}
      }
    },
    {
      name = "Uebertragung",
      farbe = "#b45309",
      blocks = {
        {id = "sync-agent-py", name = "sync_agent.py", untertitel = "der Abgleich"},
        {id = "git-commit", name = "git commit", untertitel = "Historie"},
        {id = "clawhub-publish", name = "clawhub publish", untertitel = "Veroeffentlichung"}
      }
    },
    {
      name = "Takt",
      farbe = "#f5654a",
      blocks = {
        {id = "cron-alle-12-h", name = "Cron alle 12 h", untertitel = "unbeaufsichtigt"},
        {id = "gateway-skripte", name = "Gateway-Skripte", untertitel = "mit Sperre"}
      }
    }
  },
  kanten = {
    {von = "workspace-skills", nach = "zeitstempel", art = "fluss"},
    {von = "workspace-git-skills", nach = "hash", art = "fluss"},
    {von = "zeitstempel", nach = "backup", art = "fluss"},
    {von = "hash", nach = "dry-run", art = "fluss"},
    {von = "konfliktfall", nach = "freigabe", art = "fluss"},
    {von = "backup", nach = "sync-agent-py", art = "fluss"},
    {von = "dry-run", nach = "git-commit", art = "fluss"},
    {von = "freigabe", nach = "clawhub-publish", art = "fluss"},
    {von = "sync-agent-py", nach = "cron-alle-12-h", art = "fluss"},
    {von = "git-commit", nach = "gateway-skripte", art = "fluss"},
    {von = "clawhub-publish", nach = "cron-alle-12-h", art = "fluss"}
  },
  kantenarten = {
    {art = "fluss", farbe = "#f5654a", stil = "voll", text = "Fluss von unten nach oben"}
  }
}

function hexToRgb(hex)
  local r, g, b = string.match(hex, "#(%x%x)(%x%x)(%x%x)")
  return {r = tonumber(r, 16)/255, g = tonumber(g, 16)/255, b = tonumber(b, 16)/255}
end

function love.load()
  love.window.setTitle("ClawHub-Git-Sync — Interaktive Architektur")
  love.window.setMode(1240, 768)
  
  -- Globale Variablen
  D = 26
  radius = 82
  azimut = math.pi/4
  elevation = 0.62
  rotiert = true
  gezogen = false
  zieht = false
  lx = 0
  ly = 0
  aktiv = -1
  knoten = {}
  nachId = {}
  klickbar = {}
  
  -- Setup camera
  kameraIso = {type = "orthographic"}
  kameraPersp = {type = "perspective", fov = 42}
  kamera = kameraIso
  iso = true
  
  -- Setup scene
  szene = {
    background = {0.055, 0.078, 0.125},
    objects = {},
    ambientLight = {color = {1, 1, 1}, intensity = 0.66},
    directionalLights = {
      {position = {30, 46, 26}, color = {1, 1, 1}, intensity = 0.8},
      {position = {-32, 16, -28}, color = {0.56, 0.635, 1}, intensity = 0.3}
    }
  }
  
  -- Grid helper
  table.insert(szene.objects, {
    type = "grid",
    size = 110,
    divisions = 34,
    color = {0.145, 0.196, 0.29},
    centerColor = {0.102, 0.137, 0.2}
  })
  
  -- Build scene
  local BW = 7.4
  local BD = 4.2
  local BH = 1.7
  local LUFT = 1.3
  local ABSTAND = 11.4
  local START = -17
  
  local gruppe = {objects = {}}
  
  for si, sch in ipairs(spec.schichten) do
    local y = START + si * ABSTAND
    local bl = sch.blocks
    local spalten = math.max(1, math.ceil(#bl / 2))
    local reihen = #bl <= 1 and 1 or 2
    local gx = spalten*BW + (spalten-1)*LUFT
    local gz = reihen*BD + (reihen-1)*LUFT
    
    -- Platform
    local platte = {
      type = "box",
      position = {0, y-1.7, 0},
      size = {gx+3, 0.6, gz+3},
      color = hexToRgb(sch.farbe)
    }
    for i = 1, 3 do
      platte.color[i] = platte.color[i] * 0.4
    end
    table.insert(gruppe.objects, platte)
    
    for i, b in ipairs(bl) do
      local sp = (i-1) % spalten
      local re = math.floor((i-1) / spalten)
      local x = -gx/2 + BW/2 + sp*(BW+LUFT)
      local z = -gz/2 + BD/2 + re*(BD+LUFT)
      
      local farbe = hexToRgb(sch.farbe)
      local m = {
        type = "box",
        position = {x, y, z},
        size = {BW, BH, BD},
        color = farbe,
        emissive = {0, 0, 0}
      }
      table.insert(gruppe.objects, m)
      table.insert(klickbar, m)
      
      -- Edges
      local kante = {
        type = "edges",
        position = {x, y, z},
        size = {BW, BH, BD},
        color = {0.055, 0.078, 0.125},
        opacity = 0.55
      }
      table.insert(gruppe.objects, kante)
      
      -- Text (simplified)
      local s = {
        type = "text",
        text = b.name,
        subtext = b.untertitel,
        position = {x, y + BH/2 + (b.untertitel and 2.1 or 1.6), z},
        color = {1, 1, 1}
      }
      table.insert(gruppe.objects, s)
      
      local id = b.id or string.gsub(string.lower(b.name), "[^a-z0-9]+", "-"):gsub("^%-", ""):gsub("%-$", "")
      local eintrag = {
        id = id,
        name = b.name,
        untertitel = b.untertitel or "",
        schicht = sch.name,
        mesh = m,
        color = farbe,
        position = m.position
      }
      table.insert(knoten, eintrag)
      nachId[id] = eintrag
    end
  end
  
  -- Edges/Kanten
  local STIL = {}
  for _, a in ipairs(spec.kantenarten or {}) do
    STIL[a.art] = a
  end
  
  for _, k in ipairs(spec.kanten or {}) do
    local a = nachId[k.von]
    local b = nachId[k.nach]
    if a and b then
      local art = STIL[k.art] or {farbe = "#8ea2ff", stil = "voll"}
      local line = {
        type = "line",
        points = {
          {a.position[1], a.position[2] + 0.9, a.position[3]},
          {b.position[1], b.position[2] - 0.9, b.position[3]}
        },
        color = hexToRgb(art.farbe),
        style = art.stil,
        opacity = art.stil == "gestrichelt" and 0.9 or 0.85
      }
      table.insert(gruppe.objects, line)
    end
  end
  
  szene.objects = gruppe.objects
  
  -- Select first node
  if #knoten > 0 then
    waehle(1)
  end
end

function waehle(i)
  if aktiv >= 0 and knoten[aktiv] then
    local k_alt = knoten[aktiv]
    k_alt.mesh.color = k_alt.color
    k_alt.mesh.emissive = {0, 0, 0}
    k_alt.mesh.scale = nil
  end
  
  aktiv = ((i-1) % #knoten) + 1
  local k = knoten[aktiv]
  
  k.mesh.emissive = {0.2, 0.2, 0.2}
  k.mesh.scale = {1.1, 1.5, 1.1}
  
  -- Update UI display (console output for now)
  print("Ausgewählt: " .. k.name)
  print("Schicht: " .. k.schicht)
  print("ID: " .. k.id)
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

function groesse()
  -- In LOVE2D, window size is handled automatically
end

function love.update(dt)
  if rotiert and not gezogen then
    azimut = azimut + 0.003
  end
  stelle()
end

function love.draw()
  -- Draw background
  love.graphics.setBackgroundColor(szene.background)
  
  -- Draw grid
  for _, obj in ipairs(szene.objects) do
    if obj.type == "grid" then
      love.graphics.setColor(obj.color)
      -- Simplified grid drawing
      local size = obj.size
      for i = -size, size, obj.divisions do
        love.graphics.line(-size, 0, i, size, 0, i)
        love.graphics.line(i, 0, -size, i, 0, size)
      end
    elseif obj.type == "box" then
      love.graphics.setColor(obj.color)
      local x, y, z = obj.position[1], obj.position[2], obj.position[3]
      local w, h, d = obj.size[1], obj.size[2], obj.size[3]
      -- Simplified 3D box projection
      love.graphics.rectangle("fill", 400+x*10, 300+z*10, w*10, d*10)
    elseif obj.type == "text" then
      love.graphics.setColor(1, 1, 1)
      love.graphics.print(obj.text, 400+obj.position[1]*10, 300+obj.position[3]*10)
    end
  end
  
  -- Draw UI info
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("ClawHub-Git-Sync", 20, 20)
  love.graphics.print("Zwei Seiten, ein Abgleich: Vergleich, Absicherung, Übertragung", 20, 50)
  
  if aktiv > 0 and knoten[aktiv] then
    local k = knoten[aktiv]
    love.graphics.print("Ausgewählt: " .. k.name, 20, 100)
    love.graphics.print("Schicht: " .. k.schicht, 20, 120)
    love.graphics.print("Untertitel: " .. k.untertitel, 20, 140)
  end
end

function love.mousepressed(x, y, button)
  if button == 1 then -- Left click
    -- Simple selection based on mouse position
    -- In a real implementation, you would do proper 3D picking
    if #knoten > 0 then
      waehle(aktiv + 1)
    end
  elseif button == 2 then -- Right click to zoom in
    zoom(0.85)
  elseif button == 3 then -- Middle click to zoom out
    zoom(1.18)
  end
end

function love.keypressed(key)
  if key == "up" then
    zoom(0.85)
  elseif key == "down" then
    zoom(1.18)
  elseif key == "left" then
    waehle(aktiv - 1)
  elseif key == "right" then
    waehle(aktiv + 1)
  elseif key == "r" then
    -- Reset view
    azimut = math.pi/4
    elevation = 0.62
    D = 26
    radius = 82
    rotiert = true
    iso = true
    kamera = kameraIso
    if #knoten > 0 then
      waehle(1)
    end
  elseif key == "space" then
    -- Toggle perspective/orthographic
    iso = not iso
    kamera = iso and kameraIso or kameraPersp
  end
end

function love.wheelmoved(x, y)
  if y > 0 then
    zoom(0.93)
  else
    zoom(1.08)
  end
end
