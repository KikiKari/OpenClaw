#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "f7ef2ae5aed5f7b88cc306c24c3b90d4ec686398a398f5d3bd27ec9cb89a6a7d", "source_sha256": "f76d25200d74ebc530580d7a7afb24c88ee8981f06c4d1734500f4cc830c4fe9", "target_language": "lua"}
-- scrape_to_markdown.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
-- auch in: OpenClaw@gateway2:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

local http = require("socket.http")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("cjson")
local socket = require("socket")
local url = require("socket.url")
local fs = require("lfs")

-- Helper functions
local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

local function slugify(text, max_len)
  max_len = max_len or 80
  text = text:gsub("[^%w%s%-_]", ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
  text = text:gsub("[%-%s]+", "-")
  return text:sub(1, max_len):gsub("%-+$", ""):gsub("^%-+", "") or "page"
end

local function extract_title(html)
  local title = html:match("<title[^>]*>(.-)</title>")
  if not title then return "" end
  title = title:gsub("<[^>]+>", " ")
  title = title:gsub("%s+", " ")
  return trim(title)
end

local function html_to_markdown(html, preserve_links, body_width)
  -- Simple HTML to Markdown conversion
  local md = html
  md = md:gsub("<br%s*/?>", "\n")
  md = md:gsub("<p[^>]*>", "\n")
  md = md:gsub("</p>", "\n")
  md = md:gsub("<div[^>]*>", "\n")
  md = md:gsub("</div>", "\n")
  md = md:gsub("<[^>]+>", "")
  md = md:gsub("\n%s*\n", "\n\n")
  md = trim(md)
  return md
end

local function load_urls(url_args, url_file)
  local urls = {}
  if url_args then
    for _, u in ipairs(url_args) do
      table.insert(urls, u)
    end
  end
  if url_file and url_file ~= "" then
    local file = io.open(url_file, "r")
    if file then
      for line in file:lines() do
        line = trim(line)
        if line ~= "" and not line:match("^#") then
          table.insert(urls, line)
        end
      end
      file:close()
    end
  end
  local clean = {}
  local seen = {}
  for _, u in ipairs(urls) do
    if not seen[u] then
      table.insert(clean, u)
      seen[u] = true
    end
  end
  return clean
end

local function validate_url(u)
  local parsed = url.parse(u)
  return parsed.scheme and (parsed.scheme == "http" or parsed.scheme == "https") and parsed.host
end

local function fetch_page(u, js, wait_selector, timeout, automatch_domain)
  local body = {}
  local protocol = u:match("^https://") and https or http
  local res, code, headers, status = protocol.request{
    url = u,
    sink = ltn12.sink.table(body),
    timeout = timeout
  }
  local html = table.concat(body)
  return {html = html, status = code}, "socket." .. (u:match("^https://") and "https" or "http")
end

local function pick_main_html(page, preferred_selector)
  local html = page.html or ""
  return html, nil
end

local function write_file(path, content)
  local file = io.open(path, "w")
  if file then
    file:write(content)
    file:close()
    return true
  end
  return false
end

local function mkdir_p(path)
  local sep = package.config:sub(1,1)
  local dirs = {}
  path:gsub("([^"..sep.."]+)", function(dir)
    table.insert(dirs, dir)
  end)
  local current = ""
  for i, dir in ipairs(dirs) do
    current = current .. dir .. sep
    fs.mkdir(current)
  end
end

local function main()
  -- Parse arguments manually
  local args = {
    url = {},
    url_file = "",
    selector = "",
    js = false,
    wait_selector = "",
    preserve_links = false,
    body_width = 0,
    timeout = 30,
    output_dir = "outputs",
    automatch_domain = ""
  }

  local i = 1
  while i <= #arg do
    local a = arg[i]
    if a == "--url" then
      i = i + 1
      table.insert(args.url, arg[i])
    elseif a == "--url-file" then
      i = i + 1
      args.url_file = arg[i]
    elseif a == "--selector" then
      i = i + 1
      args.selector = arg[i]
    elseif a == "--js" then
      args.js = true
    elseif a == "--wait-selector" then
      i = i + 1
      args.wait_selector = arg[i]
    elseif a == "--preserve-links" then
      args.preserve_links = true
    elseif a == "--body-width" then
      i = i + 1
      args.body_width = tonumber(arg[i])
    elseif a == "--timeout" then
      i = i + 1
      args.timeout = tonumber(arg[i])
    elseif a == "--output-dir" then
      i = i + 1
      args.output_dir = arg[i]
    elseif a == "--automatch-domain" then
      i = i + 1
      args.automatch_domain = arg[i]
    end
    i = i + 1
  end

  local urls = load_urls(args.url, args.url_file)
  if #urls == 0 then
    print(json.encode({ok = false, error = "No URLs provided"}))
    os.exit(1)
  end

  for _, u in ipairs(urls) do
    if not validate_url(u) then
      print(json.encode({ok = false, error = "Invalid URL: " .. u}))
      os.exit(1)
    end
  end

  mkdir_p(args.output_dir)

  local results = {}

  for _, u in ipairs(urls) do
    local item = {
      url = u,
      ok = false,
      title = "",
      status = nil,
      selector_used = nil,
      backend = nil,
      markdown = "",
      preview = "",
      output_markdown_file = nil,
      error = nil,
    }
    local success, err_or_page, backend = pcall(fetch_page, u, args.js, args.wait_selector, args.timeout, args.automatch_domain)
    if success then
      local page = err_or_page
      local html, selector_used = pick_main_html(page, args.selector ~= "" and args.selector or nil)
      if not html or html == "" then
        item.error = "No HTML content extracted from page"
      else
        local title = extract_title(html) ~= "" and extract_title(html) or url.parse(u).host
        local markdown = html_to_markdown(html, args.preserve_links, args.body_width)
        local filename = slugify(url.parse(u).host .. "-" .. title) .. ".md"
        local md_path = args.output_dir .. "/" .. filename
        if write_file(md_path, markdown) then
          item.ok = true
          item.title = title
          item.status = page.status
          item.selector_used = selector_used
          item.backend = backend
          item.markdown = markdown
          item.preview = markdown:sub(1, 1200)
          item.output_markdown_file = md_path
        else
          item.error = "Failed to write markdown file"
        end
      end
    else
      item.error = tostring(err_or_page)
    end
    table.insert(results, item)
  end

  local ok = false
  local success_count = 0
  local failure_count = 0
  for _, x in ipairs(results) do
    if x.ok then
      ok = true
      success_count = success_count + 1
    else
      failure_count = failure_count + 1
    end
  end

  local index_path = args.output_dir .. "/index.json"
  local payload = {
    ok = ok,
    count = #results,
    success_count = success_count,
    failure_count = failure_count,
    output_index_file = index_path,
    results = results,
  }

  local file = io.open(index_path, "w")
  if file then
    file:write(json.encode(payload))
    file:close()
  end

  print(json.encode(payload))
end

main()
