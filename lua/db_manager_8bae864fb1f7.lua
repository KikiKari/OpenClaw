#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "fb3548c1b85dea2a8c08d4d7626f9f102712b4aa7682c1b161dd6ee8e018f637", "source_sha256": "62685d1bad45f2dffb79d4424a8a668a222d4008e157a9d6b51a3e2a1d1d204d", "target_language": "lua"}
-- db_manager.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:scripts/db_manager.py
-- auch in: OpenClaw@gateway2:scripts/db_manager.py
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

--[[
Workspace Documentation Database Manager

Erstellt und verwaltet docs.db und tree.db im Workspace-Datenbankverzeichnis.
Beide Datenbanken liegen unter $OPENCLAW_WORKSPACE/db/.

Verwendung:
    lua db_manager.lua

Konfiguration:
    OPENCLAW_WORKSPACE (Umgebungsvariable) — Standard: /home/openclaw/.openclaw/workspace
]]

local sqlite3 = require("lsqlite3")
local json = require("cjson")

-- ---------------------------------------------------------------------------
-- Hilfsfunktionen
-- ---------------------------------------------------------------------------

local function getenv(var, default)
    local value = os.getenv(var)
    return value or default
end

local function split(str, sep)
    local fields = {}
    local pattern = string.format("([^%s]+)", sep or " ")
    str:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

local function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

local function write_file(path, content)
    local file = io.open(path, "w")
    if file then
        file:write(content)
        file:close()
        return true
    else
        return false
    end
end

-- ---------------------------------------------------------------------------
-- Konfiguration
-- ---------------------------------------------------------------------------

local WORKSPACE = getenv("OPENCLAW_WORKSPACE", "/home/openclaw/.openclaw/workspace")
local DB_DIR = WORKSPACE .. "/db"

-- Erlaubte Tabellennamen für Export-Methoden (verhindert SQL-Injection)
local _DOCS_EXPORT_TABLES = {
    documents = true,
    categories = true,
    symlinks = true,
    skills = true
}
local _TREE_EXPORT_TABLES = {
    tree_entries = true,
    tree_scans = true
}

-- ---------------------------------------------------------------------------
-- Logger
-- ---------------------------------------------------------------------------

local logger = {
    info = function(msg, ...)
        print(string.format("%s | %-8s | %s | " .. msg, 
            os.date("%Y-%m-%d %H:%M:%S"), "INFO", "db_manager", ...))
    end,
    error = function(msg, ...)
        print(string.format("%s | %-8s | %s | " .. msg, 
            os.date("%Y-%m-%d %H:%M:%S"), "ERROR", "db_manager", ...))
    end
}

-- ---------------------------------------------------------------------------
-- DocsDatabase
-- ---------------------------------------------------------------------------

local DocsDatabase = {}
DocsDatabase.__index = DocsDatabase

function DocsDatabase:new()
    local obj = {
        db_path = DB_DIR .. "/docs.db"
    }
    setmetatable(obj, DocsDatabase)
    return obj
end

function DocsDatabase:_get_connection()
    local conn = sqlite3.open(self.db_path)
    if not conn then
        error("Could not open database: " .. self.db_path)
    end
    return conn
end

function DocsDatabase:init_schema()
    local conn = self:_get_connection()
    
    conn:exec([[
        CREATE TABLE IF NOT EXISTS documents (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT    NOT NULL,
            path        TEXT    NOT NULL,
            category    TEXT,
            description TEXT,
            type        TEXT    CHECK(type IN ('config', 'doc', 'guide', 'script', 'symlink')),
            has_symlink BOOLEAN DEFAULT 0,
            symlink_path TEXT,
            last_update TEXT,
            created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    
    conn:exec([[
        CREATE TABLE IF NOT EXISTS categories (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT    UNIQUE NOT NULL,
            description TEXT,
            priority    INTEGER DEFAULT 0
        )
    ]])
    
    conn:exec([[
        CREATE TABLE IF NOT EXISTS symlinks (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT    NOT NULL,
            target      TEXT    NOT NULL,
            source_path TEXT    NOT NULL,
            description TEXT,
            created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    
    conn:exec([[
        CREATE TABLE IF NOT EXISTS skills (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT    NOT NULL,
            version     TEXT,
            status      TEXT    CHECK(status IN ('installed', 'local', 'published')),
            description TEXT,
            path        TEXT
        )
    ]])
    
    conn:close()
    logger.info("docs.db Schema initialisiert: %s", self.db_path)
    return self
end

function DocsDatabase:populate_from_workspace()
    local categories = {
        {"main",      "Hauptverzeichnis Dateien",        1},
        {"memory",    "Memory und Protokolle",           2},
        {"reports",   "Berichte und Analysen",           3},
        {"cluster",   "Cluster und Infrastruktur",       4},
        {"skills",    "Installierte Skills",             5},
        {"websearch", "WebSearch Dokumentationen",       6},
        {"mcp",       "MCP Integration",                 7},
        {"links",     "Symbolische Links",               8},
    }

    local docs = {
        {"AGENTS.md",             "/", "main", "Agent-Konfiguration, Memory-Regeln",      "config",  false, nil,                          "2026-04-11"},
        {"SOUL.md",               "/", "main", "Agent-Persönlichkeit und Kernwahrheiten", "config",  false, nil,                          "2026-04-11"},
        {"IDENTITY.md",           "/", "main", "Agent-Name und Eigenschaften",            "config",  false, nil,                          "2026-04-11"},
        {"USER.md",               "/", "main", "Benutzerinformationen",                   "config",  false, nil,                          "2026-04-11"},
        {"TOOLS.md",              "/", "main", "Tool-spezifische Konfigurationen",        "config",  false, nil,                          "2026-04-18"},
        {"MEMORY.md",             "/", "main", "Langzeitspeicher, System-Konfiguration",  "config",  false, nil,                          "2026-04-11"},
        {"DOCUMENTATION-INDEX.md","/", "main", "Übersicht aller Dokumentationen",         "doc",     false, nil,                          "2026-04-18"},
        {"WORKSPACE-INDEX.md",    "/", "main", "Symlink zu DOCUMENTATION-INDEX.md",       "symlink", true,  "DOCUMENTATION-INDEX.md",      "2026-04-18"},
        {"WEBSEARCH_README.md",        "websearch/", "websearch", "Schnellstart Guide",                    "guide",  true, "websearch/WEBSEARCH_README.md",          "2026-04-18"},
        {"WEBSEARCH_MCP_GUIDE.md",     "websearch/", "websearch", "Vollständige technische Dokumentation", "guide",  true, "websearch/WEBSEARCH_MCP_GUIDE.md",       "2026-04-18"},
        {"WEBSEARCH_CONFIG.md",        "websearch/", "websearch", "Konfigurations-Referenz",               "config", true, "websearch/WEBSEARCH_CONFIG.md",          "2026-04-18"},
        {"WEBSEARCH_PRIORITY_CONFIG.md","websearch/","websearch", "Provider-Priorität",                    "config", true, "websearch/WEBSEARCH_PRIORITY_CONFIG.md", "2026-04-18"},
        {"WEBSEARCH_SCRIPTS.md",       "websearch/", "websearch", "Automation & Scripting",                "script", true, "websearch/WEBSEARCH_SCRIPTS.md",         "2026-04-18"},
        {"WEBSEARCH_OPS.md",           "websearch/", "websearch", "IT-Operations",                         "guide",  true, "websearch/WEBSEARCH_OPS.md",             "2026-04-18"},
        {"MCP_GUIDE.md",               "mcp/",       "mcp",       "Symlink zu websearch/WEBSEARCH_MCP_GUIDE.md","symlink",false,"websearch/WEBSEARCH_MCP_GUIDE.md",  "2026-04-18"},
    }

    local skills = {
        {"json-utils",          "1.0.0", "installed", "JSON parsing and validation",      "skills/json-utils/"},
        {"scripting-utils",     "1.0.0", "installed", "Multi-language scripting support", "skills/scripting-utils/"},
        {"tiktok-live-mon",     "1.0.0", "installed", "TikTok stream monitoring",         "skills/tiktok-live-mon/"},
        {"cluster-management",  "1.0.0", "installed", "Cluster topology management",      "skills/cluster-management/"},
        {"worker-node",         "-",     "local",     "Worker node configuration",        "skills/worker-node/"},
        {"resource-manager",    "-",     "local",     "Resource management",              "skills/resource-manager/"},
        {"git-publish-agent",   "1.0.0", "local",     "Git publishing automation",        "skills/git-publish-agent/"},
    }

    local symlinks = {
        {"openclaw.env",               "/home/openclaw/.config/openclaw/env",  "/",             "API-Keys Shortcut"},
        {"openclaw.json",              "/home/openclaw/.openclaw/openclaw.json","/",             "Konfig Shortcut"},
        {"links/config/openclaw-env",  "/home/openclaw/.config/openclaw/env",  "links/config/", "API-Keys"},
        {"links/dotfiles/.tavily",     "/home/openclaw/.tavily/",              "links/dotfiles/","Tavily Config"},
        {"links/dotfiles/.claude",     "/home/openclaw/.claude/",              "links/dotfiles/","Claude Config"},
        {"links/dotfiles/.mcporter",   "/home/openclaw/.mcporter/",            "links/dotfiles/","MCPorter Config"},
        {"links/dotfiles/.ssh",        "/home/openclaw/.ssh/",                 "links/dotfiles/","SSH Keys"},
    }

    local conn = self:_get_connection()
    
    for _, cat in ipairs(categories) do
        conn:exec(string.format(
            "INSERT OR IGNORE INTO categories (name, description, priority) VALUES ('%s','%s',%d)",
            cat[1], cat[2], cat[3]
        ))
    end
    
    for _, doc in ipairs(docs) do
        local has_symlink = doc[6] and 1 or 0
        local symlink_path = doc[7] or "NULL"
        conn:exec(string.format(
            [[INSERT OR REPLACE INTO documents 
              (name, path, category, description, type, has_symlink, symlink_path, last_update)
              VALUES ('%s','%s','%s','%s','%s',%d,%s,'%s')]],
            doc[1], doc[2], doc[3], doc[4], doc[5], has_symlink, 
            symlink_path ~= "NULL" and "'"..symlink_path.."'" or "NULL", doc[8]
        ))
    end
    
    for _, skill in ipairs(skills) do
        conn:exec(string.format(
            [[INSERT OR REPLACE INTO skills 
              (name, version, status, description, path)
              VALUES ('%s','%s','%s','%s','%s')]],
            skill[1], skill[2], skill[3], skill[4], skill[5]
        ))
    end
    
    for _, link in ipairs(symlinks) do
        conn:exec(string.format(
            [[INSERT OR REPLACE INTO symlinks 
              (name, target, source_path, description)
              VALUES ('%s','%s','%s','%s')]],
            link[1], link[2], link[3], link[4]
        ))
    end
    
    conn:close()
    logger.info(
        "docs.db befüllt: %d Dokumente, %d Skills, %d Symlinks",
        #docs, #skills, #symlinks
    )
    return self
end

function DocsDatabase:_validate_table_name(table, allowed)
    if not allowed[table] then
        error(string.format(
            "Ungültiger Tabellename: '%s'. Erlaubt: {%s}",
            table, table.concat({}, ", ")
        ))
    end
end

function DocsDatabase:export_csv(table)
    self:_validate_table_name(table, _DOCS_EXPORT_TABLES)
    
    local conn = self:_get_connection()
    local stmt = conn:prepare(string.format("SELECT * FROM %s", table))
    local rows = {}
    local column_names = {}
    
    for row in stmt:nrows() do
        if #column_names == 0 then
            for k, _ in pairs(row) do
                table.insert(column_names, k)
            end
        end
        table.insert(rows, row)
    end
    
    stmt:finalize()
    conn:close()
    
    if #rows == 0 then
        logger.info("Tabelle '%s' ist leer — kein CSV erzeugt", table)
        return nil
    end
    
    local csv_content = table.concat(column_names, ",") .. "\n"
    for _, row in ipairs(rows) do
        local line = {}
        for _, col in ipairs(column_names) do
            table.insert(line, tostring(row[col] or ""))
        end
        csv_content = csv_content .. table.concat(line, ",") .. "\n"
    end
    
    local csv_path = WORKSPACE .. "/export_" .. table .. ".csv"
    local success = write_file(csv_path, csv_content)
    
    if success then
        logger.info("CSV exportiert: %s (%d Zeilen)", csv_path, #rows)
        return csv_path
    else
        logger.error("Fehler beim Schreiben der CSV-Datei: %s", csv_path)
        return nil
    end
end

function DocsDatabase:export_json(table)
    self:_validate_table_name(table, _DOCS_EXPORT_TABLES)
    
    local conn = self:_get_connection()
    local stmt = conn:prepare(string.format("SELECT * FROM %s", table))
    local rows = {}
    
    for row in stmt:nrows() do
        table.insert(rows, row)
    end
    
    stmt:finalize()
    conn:close()
    
    if #rows == 0 then
        logger.info("Tabelle '%s' ist leer — kein JSON erzeugt", table)
        return nil
    end
    
    local json_path = WORKSPACE .. "/export_" .. table .. ".json"
    local json_content = json.encode(rows, {indent = true})
    
    local success = write_file(json_path, json_content)
    
    if success then
        logger.info("JSON exportiert: %s (%d Einträge)", json_path, #rows)
        return json_path
    else
        logger.error("Fehler beim Schreiben der JSON-Datei: %s", json_path)
        return nil
    end
end

-- ---------------------------------------------------------------------------
-- TreeDatabase
-- ---------------------------------------------------------------------------

local TreeDatabase = {}
TreeDatabase.__index = TreeDatabase

function TreeDatabase:new()
    local obj = {
        db_path = DB_DIR .. "/tree.db"
    }
    setmetatable(obj, TreeDatabase)
    return obj
end

function TreeDatabase:_get_connection()
    local conn = sqlite3.open(self.db_path)
    if not conn then
        error("Could not open database: " .. self.db_path)
    end
    return conn
end

function TreeDatabase:init_schema()
    local conn = self:_get_connection()
    
    conn:exec([[
        CREATE TABLE IF NOT EXISTS tree_entries (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            root_path     TEXT    NOT NULL,
            relative_path TEXT    NOT NULL,
            name          TEXT    NOT NULL,
            type          TEXT    CHECK(type IN ('file', 'directory', 'symlink')),
            depth         INTEGER,
            parent_path   TEXT,
            size          INTEGER,
            created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    
    conn:exec([[
        CREATE TABLE IF NOT EXISTS tree_scans (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            root_path      TEXT    NOT NULL,
            max_depth      INTEGER,
            total_files    INTEGER,
            total_dirs     INTEGER,
            total_symlinks INTEGER,
            scanned_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    
    conn:close()
    logger.info("tree.db Schema initialisiert: %s", self.db_path)
    return self
end

function TreeDatabase:add_entry(root_path, relative_path, name, entry_type, depth, parent_path, size)
    size = size or 0
    
    local conn = self:_get_connection()
    local stmt = conn:prepare([[
        INSERT INTO tree_entries
        (root_path, relative_path, name, type, depth, parent_path, size)
        VALUES (?,?,?,?,?,?,?)
    ]])
    
    stmt:bind_values(root_path, relative_path, name, entry_type, depth, parent_path, size)
    stmt:step()
    stmt:finalize()
    conn:close()
end

function TreeDatabase:export_csv(root_path_filter)
    local conn = self:_get_connection()
    local query
    local params = {}
    
    if root_path_filter then
        query = "SELECT * FROM tree_entries WHERE root_path = ?"
        table.insert(params, root_path_filter)
    else
        query = "SELECT * FROM tree_entries"
    end
    
    local stmt = conn:prepare(query)
    for i, param in ipairs(params) do
        stmt:bind(i, param)
    end
    
    local rows = {}
    local column_names = {}
    
    for row in stmt:nrows() do
        if #column_names == 0 then
            for k, _ in pairs(row) do
                table.insert(column_names, k)
            end
        end
        table.insert(rows, row)
    end
    
    stmt:finalize()
    conn:close()
    
    if #rows == 0 then
        logger.info("Keine Tree-Einträge vorhanden — kein CSV erzeugt")
        return nil
    end
    
    local suffix = root_path_filter and "_" .. string.gsub(root_path_filter, "/", "_") or "_all"
    local csv_path = WORKSPACE .. "/export_tree" .. suffix .. ".csv"
    
    local csv_content = table.concat(column_names, ",") .. "\n"
    for _, row in ipairs(rows) do
        local line = {}
        for _, col in ipairs(column_names) do
            table.insert(line, tostring(row[col] or ""))
        end
        csv_content = csv_content .. table.concat(line, ",") .. "\n"
    end
    
    local success = write_file(csv_path, csv_content)
    
    if success then
        logger.info("Tree-CSV exportiert: %s (%d Einträge)", csv_path, #rows)
        return csv_path
    else
        logger.error("Fehler beim Schreiben der CSV-Datei: %s", csv_path)
        return nil
    end
end

-- ---------------------------------------------------------------------------
-- Einstiegspunkt
-- ---------------------------------------------------------------------------

local function main()
    print("=" .. string.rep("-", 59))
    print("WORKSPACE DATABASE MANAGER")
    print("=" .. string.rep("-", 59))
    
    -- DB-Verzeichnis hier (nicht auf Modulebene) anlegen
    local function mkdir_p(path)
        local cmd = "mkdir -p " .. path
        local result = os.execute(cmd)
        return result == 0 or result == true
    end
    
    if not mkdir_p(DB_DIR) then
        logger.error("DB-Verzeichnis konnte nicht erstellt werden: %s", DB_DIR)
        os.exit(1)
    end
    
    logger.info("DB-Verzeichnis: %s", DB_DIR)
    
    -- docs.db aufbauen
    local docs_db = DocsDatabase:new()
    docs_db:init_schema()
    docs_db:populate_from_workspace()
    
    -- Exporte
    print("\n--- Exporte docs.db ---")
    for _, table in ipairs({"documents", "skills", "symlinks"}) do
        docs_db:export_csv(table)
    end
    docs_db:export_json("documents")
    
    -- tree.db aufbauen (Daten kommen via tree.py)
    print("\n--- tree.db Initialisierung ---")
    local tree_db = TreeDatabase:new()
    tree_db:init_schema()
    logger.info("Tree-Daten werden via tree.py Script befüllt")
    
    print("\n" .. string.rep("=", 60))
    print("DATENBANKEN BEREIT")
    print(string.rep("=", 60))
    print("\nDatenbanken: " .. DB_DIR .. "/")
    print("Exporte:     " .. WORKSPACE .. "/")
end

main()
