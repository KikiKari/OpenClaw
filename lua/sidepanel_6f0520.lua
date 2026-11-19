#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "41d7f7d7c4dfa70036d0277be0a42d02aaaa4f8fa87d6462b9871044e464341a", "source_sha256": "6f0520ae03891dc25c6d08a38907c3c9c1c5f8bb7d8a33172bd65cf6a1d074d9", "target_language": "lua"}
-- sidepanel.html — portiert nach lua
-- Quelle: html, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/browser-extension/sidepanel.html
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local function create_element(tag, attrs, children)
  local element = {tag = tag, attrs = {}, children = children or {}}
  if attrs then
    for k, v in pairs(attrs) do
      element.attrs[k] = v
    end
  end
  return element
end

local function add_child(parent, child)
  table.insert(parent.children, child)
  return child
end

local function text(content)
  return {tag = "text", content = content}
end

local function render_element(element)
  if element.tag == "text" then
    return element.content
  end
  
  local attr_str = ""
  for k, v in pairs(element.attrs) do
    attr_str = attr_str .. " " .. k .. "=\"" .. v .. "\""
  end
  
  if #element.children == 0 then
    return "<" .. element.tag .. attr_str .. "></" .. element.tag .. ">"
  end
  
  local children_str = ""
  for _, child in ipairs(element.children) do
    children_str = children_str .. render_element(child)
  end
  
  return "<" .. element.tag .. attr_str .. ">" .. children_str .. "</" .. element.tag .. ">"
end

local function save_to_file(element, filename)
  local file = io.open(filename, "w")
  if not file then
    error("Could not open file for writing: " .. filename)
  end
  file:write("<!DOCTYPE html>\n")
  file:write(render_element(element))
  file:close()
end

-- Create the document structure
local html_doc = create_element("html", {lang = "de"})
local head = add_child(html_doc, create_element("head"))
add_child(head, create_element("meta", {charset = "utf-8"}))
add_child(head, create_element("meta", {name = "viewport", content = "width=device-width, initial-scale=1"}))
add_child(head, create_element("title", {}, {text("TikTok LIVE Companion")}))
add_child(head, create_element("link", {rel = "stylesheet", href = "sidepanel.css"}))

local body = add_child(html_doc, create_element("body"))

-- Header
local header = add_child(body, create_element("header"))
add_child(header, create_element("p", {id = "page-title", ["class"] = "muted"}, {text("Kein TikTok-Tab ausgewählt")}))

local main = add_child(body, create_element("main"))

-- Chat section
local chat_section = add_child(main, create_element("section", {["aria-labelledby"] = "chat-heading"}))

local chat_title_div = add_child(chat_section, create_element("div", {["class"] = "section-title"}))
add_child(chat_title_div, create_element("h2", {id = "chat-heading"}, {text("Chat")}))

local title_actions = add_child(chat_title_div, create_element("div", {["class"] = "title-actions"}))
add_child(title_actions, create_element("span", {
  id = "chat-led",
  ["class"] = "status-led off",
  role = "status",
  ["aria-label"] = "Chat inaktiv",
  title = "Chat inaktiv"
}))
add_child(title_actions, create_element("button", {
  id = "chat-count",
  ["class"] = "count count-button",
  type = "button",
  ["aria-haspopup"] = "dialog",
  title = "Gesammelte Chatzeilen öffnen"
}, {text("0")}))
add_child(title_actions, create_element("button", {
  id = "refresh-chat",
  ["class"] = "secondary compact",
  title = "Chatanzeige leeren"
}, {text("Refresh")}))
add_child(title_actions, create_element("button", {
  id = "toggle-speech",
  ["class"] = "secondary compact",
  ["aria-pressed"] = "false",
  ["aria-label"] = "Vorlesen"
}, {text("On")}))
add_child(title_actions, create_element("span", {
  id = "speech-led",
  ["class"] = "status-led off",
  role = "status",
  ["aria-label"] = "Vorlesen inaktiv",
  title = "Vorlesen inaktiv"
}))

add_child(chat_section, create_element("div", {
  id = "chat-list",
  ["class"] = "chat-list empty",
  role = "log",
  ["aria-live"] = "polite",
  ["aria-relevant"] = "additions",
  ["aria-label"] = "Die letzten fünf bereinigten Chatnachrichten"
}, {text("Noch keine Chatnachrichten erkannt.")}))

add_child(chat_section, create_element("p", {
  id = "speech-status",
  role = "status",
  ["class"] = "inline-status"
}, {text("Vorlesen ist ausgeschaltet.")}))

local control_label = add_child(chat_section, create_element("div", {["class"] = "control-label"}))
add_child(control_label, create_element("label", {["for"] = "speech-volume"}, {text("Vorleselautstärke")}))
add_child(control_label, create_element("output", {id = "speech-volume-output", ["for"] = "speech-volume"}, {text("100%")}))

add_child(chat_section, create_element("input", {
  id = "speech-volume",
  type = "range",
  min = "0",
  max = "100",
  step = "5",
  value = "50"
}))

local button_row = add_child(chat_section, create_element("div", {["class"] = "button-row"}))
add_child(button_row, create_element("button", {id = "service-action", ["class"] = "secondary"}, {text("Sprachdienst")}))
add_child(button_row, create_element("button", {id = "sherpa-action", ["class"] = "secondary"}, {text("Sherpa")}))
add_child(button_row, create_element("button", {
  id = "open-speech-settings",
  ["class"] = "secondary compact settings-button",
  type = "button",
  ["aria-label"] = "Erweiterte Einstellungen öffnen",
  ["aria-haspopup"] = "dialog",
  title = "Einstellungen"
}, {text("⚙")}))

add_child(chat_section, create_element("p", {id = "service-status", ["class"] = "inline-status"}, {text("Lokaler Sprachdienst noch nicht geprüft.")}))
add_child(chat_section, create_element("div", {id = "service-setup", ["class"] = "inline-status", hidden = ""}))
add_child(chat_section, create_element("label", {["class"] = "option-row"}, {
  create_element("input", {id = "keep-speech-active", type = "checkbox"}),
  text(" Permanent aktiv")
}))

-- Top chatters section
local top_chatters_section = add_child(main, create_element("section", {["aria-labelledby"] = "top-chatters-heading"}))

local top_chatters_title = add_child(top_chatters_section, create_element("div", {["class"] = "section-title"}))
add_child(top_chatters_title, create_element("h2", {id = "top-chatters-heading"}, {text("Top-Chatter")}))
add_child(top_chatters_title, create_element("button", {
  id = "open-audience",
  ["class"] = "secondary compact"
}, {text("Zuschauer*innen")}))

add_child(top_chatters_section, create_element("p", {id = "team-tag-status", ["class"] = "inline-status"}, {text("Teamkürzel: noch nicht erkannt.")}))
add_child(top_chatters_section, create_element("div", {id = "top-chatters", ["class"] = "top-chatters empty"}, {text("Noch keine Personen im Chat beobachtet.")}))
add_child(top_chatters_section, create_element("div", {id = "top-chatters-actions", ["class"] = "top-chatters-actions", hidden = ""}, {
  create_element("button", {id = "top-chatters-reset", ["class"] = "top-chatter-link", type = "button", hidden = ""}, {text("Reset")}),
  create_element("button", {id = "top-chatters-more", ["class"] = "top-chatter-link", type = "button"}, {text("mehr…")})
}))

-- Page info section
local page_info_section = add_child(main, create_element("section", {id = "page-info-section", ["aria-labelledby"] = "page-info-heading"}))

local page_info_title = add_child(page_info_section, create_element("div", {["class"] = "section-title"}))
add_child(page_info_title, create_element("h2", {id = "page-info-heading"}, {text("PROFIL-Information")}))
local page_info_actions = add_child(page_info_title, create_element("div", {["class"] = "title-actions"}))
add_child(page_info_actions, create_element("span", {id = "page-info-source", ["class"] = "live-indicator"}, {text("Metadaten")}))
add_child(page_info_actions, create_element("button", {id = "refresh-page-info", ["class"] = "secondary compact"}, {text("Refresh")}))
add_child(page_info_actions, create_element("button", {id = "force-page-info", ["class"] = "secondary compact danger-outline"}, {text("Force")}))

add_child(page_info_section, create_element("div", {id = "profile-info", ["class"] = "profile-info", hidden = ""}))
add_child(page_info_section, create_element("div", {id = "summary-info", ["class"] = "summary-info"}))

-- Stats section
local stats_section = add_child(main, create_element("section", {["aria-labelledby"] = "stats-heading"}))

local stats_title = add_child(stats_section, create_element("div", {["class"] = "section-title"}))
add_child(stats_title, create_element("h2", {id = "stats-heading"}, {text("LIVE-Information")}))
add_child(stats_title, create_element("span", {id = "stats-live", ["class"] = "live-indicator"}, {text("warte")}))

add_child(stats_section, create_element("div", {id = "live-stats", ["class"] = "status-grid stats-grid"}))
add_child(stats_section, create_element("p", {id = "stats-status", ["class"] = "inline-status"}))

-- Hook section
local hook_section = add_child(main, create_element("section", {["aria-labelledby"] = "hook-heading"}))

local hook_title = add_child(hook_section, create_element("div", {["class"] = "section-title"}))
add_child(hook_title, create_element("h2", {id = "hook-heading"}, {text("Connection")}))
add_child(hook_title, create_element("span", {
  id = "hook-led",
  ["class"] = "status-led off",
  role = "status",
  ["aria-label"] = "Hook inaktiv",
  title = "Hook inaktiv"
}))

local hook_buttons = add_child(hook_section, create_element("div", {["class"] = "button-row"}))
add_child(hook_buttons, create_element("button", {
  id = "toggle-hook",
  ["class"] = "primary",
  ["aria-label"] = "Connection",
  ["aria-pressed"] = "false"
}, {text("On")}))
add_child(hook_buttons, create_element("button", {id = "reset-tab", ["class"] = "secondary danger-outline"}, {text("Refresh")}))
add_child(hook_buttons, create_element("button", {id = "open-embed-live", ["class"] = "secondary"}, {text("Embed")}))
add_child(hook_buttons, create_element("button", {id = "open-normal-live", ["class"] = "secondary"}, {text("Browser")}))
add_child(hook_buttons, create_element("button", {id = "player-vlc-frame", ["class"] = "secondary compact"}, {text("Player")}))
add_child(hook_buttons, create_element("button", {
  id = "open-connection-settings",
  ["class"] = "secondary compact settings-button",
  type = "button",
  ["aria-label"] = "Connection-Einstellungen öffnen",
  ["aria-haspopup"] = "dialog"
}, {text("⚙")}))

add_child(hook_section, create_element("p", {id = "hook-status", ["class"] = "inline-status"}))
add_child(hook_section, create_element("p", {id = "embed-startup-status", ["class"] = "inline-status", role = "status", ["aria-live"] = "polite", hidden = ""}))
add_child(hook_section, create_element("button", {id = "cancel-embed-startup", ["class"] = "secondary", hidden = ""}, {text("Embed-Start abbrechen")}))
add_child(hook_section, create_element("label", {["class"] = "option-row"}, {
  create_element("input", {id = "hook-autostart", type = "checkbox"}),
  text(" Permanent Hook")
}))
add_child(hook_section, create_element("p", {id = "hook-reconnect-status", ["class"] = "inline-status", role = "status"}, {text("Hook-Reconnect: aus")}))
add_child(hook_section, create_element("p", {id = "player-recovery-status", ["class"] = "inline-status", role = "status"}, {text("Player-Recovery: aus")}))

-- Recommendations section
local recommendations_section = add_child(main, create_element("section", {id = "recommendations-section", ["aria-labelledby"] = "recommendations-heading"}))

local rec_title = add_child(recommendations_section, create_element("div", {["class"] = "section-title"}))
add_child(rec_title, create_element("h2", {id = "recommendations-heading"}, {text("LIVE-Empfehlungen")}))
add_child(rec_title, create_element("span", {id = "recommendation-status", ["class"] = "live-indicator"}, {text("bereit")}))

local rec_controls = add_child(recommendations_section, create_element("div", {["class"] = "recommendation-controls"}))
add_child(rec_controls, create_element("label", {}, {
  create_element("span", {}, {text("Anzahl")}),
  create_element("input", {
    id = "recommendation-limit",
    type = "number",
    min = "1",
    max = "50",
    step = "1",
    value = "20",
    inputmode = "numeric"
  })
}))
add_child(rec_controls, create_element("label", {}, {
  create_element("span", {}, {text("Sortierung")}),
  create_element("select", {id = "recommendation-sort"}, {
    create_element("option", {value = "tiktok"}, {text("TikTok-Reihenfolge")}),
    create_element("option", {value = "viewers"}, {text("Zuschauer*innen")})
  })
}))

local rec_button_row = add_child(recommendations_section, create_element("div", {["class"] = "button-row"}))
add_child(rec_button_row, create_element("button", {id = "scan-recommendations", ["class"] = "primary"}, {text("Empfehlungen scannen")}))
add_child(rec_button_row, create_element("button", {id = "cancel-recommendations", ["class"] = "secondary", hidden = ""}, {text("Abbrechen")}))

add_child(recommendations_section, create_element("p", {id = "recommendation-progress", ["class"] = "inline-status", ["aria-live"] = "polite"}, {text("Noch kein Scan gestartet.")}))
add_child(recommendations_section, create_element("div", {id = "recommendation-list", ["class"] = "recommendation-list empty"}, {text("Noch keine Empfehlungen erfasst.")}))
add_child(recommendations_section, create_element("div", {id = "recommendation-actions", ["class"] = "top-chatters-actions", hidden = ""}, {
  create_element("button", {id = "recommendation-more", ["class"] = "top-chatter-link", type = "button"}, {text("mehr…")})
}))

-- Caption section
local caption_section = add_child(main, create_element("section", {["aria-labelledby"] = "caption-heading"}))

local caption_title = add_child(caption_section, create_element("div", {["class"] = "section-title"}))
add_child(caption_title, create_element("h2", {id = "caption-heading"}, {text("Titel")}))
add_child(caption_title, create_element("button", {id = "scan", ["class"] = "secondary"}, {text("Seite prüfen")}))

add_child(caption_section, create_element("div", {id = "caption-status", ["class"] = "status-grid"}))
add_child(caption_section, create_element("button", {id = "enable-captions", ["class"] = "primary"}, {text("Untertitel aktivieren")}))
add_child(caption_section, create_element("p", {id = "caption-action-status", role = "status", ["class"] = "inline-status action-status"}))

-- Player section
local player_section = add_child(main, create_element("section", {["aria-labelledby"] = "player-heading"}))

local player_title = add_child(player_section, create_element("div", {["class"] = "section-title"}))
add_child(player_title, create_element("h2", {id = "player-heading"}, {text("Player")}))
add_child(player_title, create_element("span", {id = "player-time", ["class"] = "player-time"}, {text("–")}))

local player_controls = add_child(player_section, create_element("div", {["class"] = "player-controls", role = "group", ["aria-label"] = "TikTok-Player steuern"}))
add_child(player_controls, create_element("button", {id = "player-play", ["class"] = "secondary compact"}, {text("Pause")}))
add_child(player_controls, create_element("button", {id = "player-replay", ["class"] = "secondary compact"}, {text("Neu laden")}))
add_child(player_controls, create_element("button", {id = "player-mute", ["class"] = "secondary compact"}, {text("Stumm")}))
add_child(player_controls, create_element("button", {id = "player-pip", ["class"] = "secondary compact"}, {text("Bild-in-Bild")}))
add_child(player_controls, create_element("button", {id = "player-fullscreen", ["class"] = "secondary compact"}, {text("Vollbild")}))
add_child(player_controls, create_element("button", {id = "player-report", ["class"] = "secondary compact danger-outline"}, {text("Melden öffnen")}))
