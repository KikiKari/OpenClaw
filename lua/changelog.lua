#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "b80cc38eb984046b2025de9751d05f5433ed2f02cbb3c368d133392fa8bba750", "source_sha256": "646ce6bf1521c1200f2204aa19a05521f8f53d734ec8c000b61f4290f2a05074", "target_language": "lua"}
-- changelog.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/changelog.sh
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local function normalize_pr_changelog_entries(pr)
  local changelog_path = "CHANGELOG.md"
  
  local file = io.open(changelog_path, "r")
  if not file then return 0 end
  local content = file:read("*a")
  file:close()
  
  local lines = {}
  for line in content:gmatch("[^\r\n]*") do
    table.insert(lines, line)
  end
  
  local pr_pattern = string.format("(%%(#%s)%%|openclaw#%s)", pr, pr)
  
  local function findActiveSectionIndex(arr)
    for i, line in ipairs(arr) do
      if line:match("^## Unreleased$") then
        return i
      end
    end
    return nil
  end
  
  local function findSectionEnd(arr, start)
    for i = start + 1, #arr do
      if arr[i]:match("^## ") then
        return i
      end
    end
    return #arr + 1
  end
  
  local function ensureActiveSection(arr)
    local activeIndex = findActiveSectionIndex(arr)
    if activeIndex then
      return activeIndex
    end
    
    local insertAt = 1
    for i, line in ipairs(arr) do
      if i > 1 and line:match("^## ") then
        insertAt = i
        break
      end
    end
    
    local block = {"## Unreleased", "", "### Changes", ""}
    if insertAt > 1 and arr[insertAt - 1] ~= "" then
      table.insert(block, 1, "")
    end
    
    for i = #block, 1, -1 do
      table.insert(arr, insertAt, block[i])
    end
    
    return findActiveSectionIndex(arr)
  end
  
  local function contextFor(arr, index)
    local major = ""
    local minor = ""
    for i = index, 1, -1 do
      local line = arr[i]
      if minor == "" and line:match("^### ") then
        minor = line
      end
      if line:match("^## ") then
        major = line
        break
      end
    end
    return {major = major, minor = minor}
  end
  
  local function ensureSubsection(arr, subsection)
    local activeIndex = ensureActiveSection(arr)
    local activeEnd = findSectionEnd(arr, activeIndex)
    local desired = (subsection and subsection:match("^### ")) and subsection or "### Changes"
    
    for i = activeIndex + 1, activeEnd - 1 do
      if arr[i]:match("^%s*$") and arr[i]:trim() == desired:trim() then
        return i
      end
    end
    
    local insertAt = activeEnd
    while insertAt > activeIndex + 1 and arr[insertAt - 1] == "" do
      insertAt = insertAt - 1
    end
    
    table.insert(arr, insertAt, "")
    table.insert(arr, insertAt + 1, desired)
    table.insert(arr, insertAt + 2, "")
    return insertAt + 1
  end
  
  local function sectionTailInsertIndex(arr, subsectionIndex)
    local nextHeading = #arr + 1
    for i = subsectionIndex + 1, #arr do
      if arr[i]:match("^### ") or arr[i]:match("^## ") then
        nextHeading = i
        break
      end
    end
    
    local insertAt = nextHeading
    while insertAt > subsectionIndex + 1 and arr[insertAt - 1] == "" do
      insertAt = insertAt - 1
    end
    return insertAt
  end
  
  ensureActiveSection(lines)
  
  local moved = {}
  for i, line in ipairs(lines) do
    if line:match(pr_pattern) then
      local ctx = contextFor(lines, i)
      if ctx.major ~= "## Unreleased" then
        table.insert(moved, {
          line = line,
          subsection = ctx.minor ~= "" and ctx.minor or "### Changes",
          index = i
        })
      end
    end
  end
  
  if #moved == 0 then
    return
  end
  
  local removeIndexes = {}
  for _, entry in ipairs(moved) do
    removeIndexes[entry.index] = true
  end
  
  local nextLines = {}
  for i, line in ipairs(lines) do
    if not removeIndexes[i] then
      table.insert(nextLines, line)
    end
  end
  
  for _, entry in ipairs(moved) do
    local subsectionIndex = ensureSubsection(nextLines, entry.subsection)
    local insertAt = sectionTailInsertIndex(nextLines, subsectionIndex)
    
    local nextHeading = #nextLines + 1
    for i = subsectionIndex + 1, #nextLines do
      if nextLines[i]:match("^### ") or nextLines[i]:match("^## ") then
        nextHeading = i
        break
      end
    end
    
    local alreadyPresent = false
    for i = subsectionIndex + 1, nextHeading - 1 do
      if nextLines[i] == entry.line then
        alreadyPresent = true
        break
      end
    end
    
    if not alreadyPresent then
      table.insert(nextLines, insertAt, entry.line)
    end
  end
  
  local updated = table.concat(nextLines, "\n")
  if updated ~= content then
    local file = io.open(changelog_path, "w")
    file:write(updated)
    file:close()
  end
end

local function validate_changelog_entry_for_pr(pr, contrib)
  local handle = io.popen('git diff --unified=0 origin/main...HEAD -- CHANGELOG.md')
  local diff_output = handle:read("*a")
  handle:close()
  
  local added_lines = {}
  for line in diff_output:gmatch("[^\r\n]+") do
    if not line:match("^%+%+%+") and line:match("^%+") then
      table.insert(added_lines, line:sub(2))
    end
  end
  
  if #added_lines == 0 then
    print("CHANGELOG.md is in diff but no added lines were detected.")
    os.exit(1)
  end
  
  local pr_pattern = string.format("%%(#%s|openclaw#%s%%)", pr, pr)
  
  local with_pr = {}
  for _, line in ipairs(added_lines) do
    if line:lower():match(pr_pattern:lower()) then
      table.insert(with_pr, line)
    end
  end
  
  if #with_pr == 0 then
    print(string.format("CHANGELOG.md update must reference PR #%s (for example, (#%s)).", pr, pr))
    os.exit(1)
  end
  
  local temp_file = os.tmpname()
  local file = io.open(temp_file, "w")
  file:write(diff_output)
  file:close()
  
  local function validate_diff_placement()
    local diff_handle = io.open(temp_file, "r")
    local diff_content = diff_handle:read("*a")
    diff_handle:close()
    
    local added = {}
    local pr_added_lines = {}
    local pr_added_text = {}
    local changelog = {}
    
    local line_no = 0
    local file_line_count = 0
    local issue_count = 0
    
    for line in diff_content:gmatch("[^\r\n]*") do
      if line:match("^@@ ") then
        local match = line:match("%+([0-9]+)")
        if match then
          line_no = tonumber(match) or 0
        else
          line_no = 0
        end
      elseif line:match("^%+%+%+") then
        -- skip
      elseif line:match("^%+") then
        if line_no > 0 then
          added[line_no] = true
          local added_text = line:sub(2)
          if added_text:lower():match(pr_pattern:lower()) then
            table.insert(pr_added_lines, line_no)
            pr_added_text[line_no] = added_text
          end
          line_no = line_no + 1
        end
      elseif line:match("^%-") then
        -- skip
      elseif line_no > 0 then
        line_no = line_no + 1
      end
    end
    
    local changelog_handle = io.open("CHANGELOG.md", "r")
    local changelog_content = changelog_handle:read("*a")
    changelog_handle:close()
    
    local line_num = 1
    for line in changelog_content:gmatch("[^\r\n]*") do
      changelog[line_num] = line
      file_line_count = line_num
      line_num = line_num + 1
    end
    
    for _, entry_line in ipairs(pr_added_lines) do
      local release_line = 0
      local section_line = 0
      
      for i = entry_line, 1, -1 do
        if section_line == 0 and changelog[i] and changelog[i]:match("^### ") then
          section_line = i
        elseif changelog[i] and changelog[i]:match("^## ") then
          release_line = i
          break
        end
      end
      
      if release_line == 0 or changelog[release_line] ~= "## Unreleased" then
        print(string.format("CHANGELOG.md PR-linked entry must be in ## Unreleased: line %d: %s", entry_line, pr_added_text[entry_line]))
        issue_count = issue_count + 1
      elseif section_line == 0 then
        print(string.format("CHANGELOG.md entry must be inside a subsection (### ...): line %d: %s", entry_line, pr_added_text[entry_line]))
        issue_count = issue_count + 1
      else
        local section_name = changelog[section_line]
        local next_heading = file_line_count + 1
        
        for i = entry_line + 1, file_line_count do
          if changelog[i] and (changelog[i]:match("^### ") or changelog[i]:match("^## ")) then
            next_heading = i
            break
          end
        end
        
        for i = entry_line + 1, next_heading - 1 do
          local line_text = changelog[i] or ""
          if not line_text:match("^%s*$") and not added[i] then
            print(string.format("CHANGELOG.md PR-linked entry must be appended at the end of section %s: line %d: %s", section_name, entry_line, pr_added_text[entry_line]))
            print(string.format("Found existing non-added line below it at line %d: %s", i, line_text))
            issue_count = issue_count + 1
            break
          end
        end
      end
    end
    
    if issue_count > 0 then
      print("Move this PR changelog entry to the end of its section (just before the next heading).")
      return false
    end
    
    return true
  end
  
  if not validate_diff_placement() then
    os.remove(temp_file)
    os.exit(1)
  end
  
  os.remove(temp_file)
  print("changelog placement validated: PR-linked entries are appended at section tail")
  
  if contrib and contrib ~= "null" then
    local with_pr_and_thanks = {}
    for _, line in ipairs(with_pr) do
      if line:lower():match("thanks @" .. contrib:lower()) then
        table.insert(with_pr_and_thanks, line)
      end
    end
    
    if #with_pr_and_thanks == 0 then
      print(string.format("CHANGELOG.md update must include both PR #%s and thanks @%s on the changelog entry line.", pr, contrib))
      os.exit(1)
    end
    
    print(string.format("changelog validated: found PR #%s + thanks @%s", pr, contrib))
    return
  end
  
  print(string.format("changelog validated: found PR #%s (contributor handle unavailable, skipping thanks check)", pr))
end

local function validate_changelog_merge_hygiene()
  local handle = io.popen('git diff --unified=0 origin/main...HEAD -- CHANGELOG.md')
  local diff = handle:read("*a")
  handle:close()
  
  local removed_lines = {}
  for line in diff:gmatch("[^\r\n]+") do
    if not line:match("^---") and line:match("^%-") then
      table.insert(removed_lines, line:sub(2))
    end
  end
  
  if #removed_lines == 0 then
    return
  end
  
  local removed_refs = {}
  for _, line in ipairs(removed_lines) do
    for ref in line:gmatch("#[0-9]+") do
      removed_refs[ref] = true
    end
  end
  
  local refs_list = {}
  for ref, _ in pairs(removed_refs) do
    table.insert(refs_list, ref)
  end
  
  if #refs_list == 0 then
    return
  end
  
  local added_lines = {}
  for line in diff:gmatch("[^\r\n]+") do
    if not line:match("^%+%+%+") and line:match("^%+") then
      table.insert(added_lines, line:sub(2))
    end
  end
  
  for _, ref in ipairs(refs_list) do
    local found = false
    for _, line in ipairs(added_lines) do
      if line:find(ref, 1, true) then
        found = true
        break
      end
    end
    
    if not found then
      print(string.format("CHANGELOG.md drops existing entry reference %s without re-adding it.", ref))
      print("Likely merge conflict loss; restore the dropped entry (or keep the same PR ref in rewritten text).")
      os.exit(1)
    end
  end
  
  print("changelog merge hygiene validated: no dropped PR references")
end

-- Main execution based on arguments
if arg[1] == "normalize" then
  normalize_pr_changelog_entries(arg[2])
elseif arg[1] == "validate_entry" then
  validate_changelog_entry_for_pr(arg[2], arg[3])
elseif arg[1] == "validate_merge" then
  validate_changelog_merge_hygiene()
end
