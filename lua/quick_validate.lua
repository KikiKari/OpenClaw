#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "55a786a36345aa8f9eae6469de53d5ef2721aab891f5e9f331ed0e7f8515d016", "source_sha256": "3e3cdceba2daa893e260551c8c5f09937f94be1153307185c7fc7c24c0896750", "target_language": "lua"}
-- quick_validate.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/quick_validate.py
-- auch in: OpenClaw@gateway2:skills/skill-creator/scripts/quick_validate.py
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

--[[
Quick validation script for skills - minimal version
]]

local MAX_SKILL_NAME_LENGTH = 64

-- Helper function to check if a file exists
local function file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- Helper function to read file content
local function read_file(path)
    local file, err = io.open(path, "r")
    if not file then
        return nil, err
    end
    local content = file:read("*a")
    file:close()
    return content
end

-- Extract frontmatter from content
local function extract_frontmatter(content)
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    if #lines == 0 or lines[1]:match("^%s*$") ~= nil or lines[1]:gsub("^%s*(.-)%s*$", "%1") ~= "---" then
        return nil
    end
    
    for i = 2, #lines do
        if lines[i]:gsub("^%s*(.-)%s*$", "%1") == "---" then
            local frontmatter_lines = {}
            for j = 2, i - 1 do
                table.insert(frontmatter_lines, lines[j])
            end
            return table.concat(frontmatter_lines, "\n")
        end
    end
    
    return nil
end

-- Simple YAML-like parser for basic key-value pairs
local function parse_simple_frontmatter(frontmatter_text)
    local parsed = {}
    local current_key = nil
    
    for line in frontmatter_text:gmatch("[^\r\n]+") do
        local stripped = line:match("^%s*(.-)%s*$")
        if stripped ~= "" and not stripped:match("^%s*#") then
            local is_indented = line:match("^%s") ~= nil
            
            if is_indented then
                if current_key == nil then
                    return nil
                end
                local current_value = parsed[current_key]
                if current_value and current_value ~= "" then
                    parsed[current_key] = current_value .. "\n" .. stripped
                else
                    parsed[current_key] = stripped
                end
            else
                local colon_pos = stripped:find(":")
                if not colon_pos then
                    return nil
                end
                
                local key = stripped:sub(1, colon_pos - 1):match("^%s*(.-)%s*$")
                if key == "" then
                    return nil
                end
                
                local value = stripped:sub(colon_pos + 1):match("^%s*(.-)%s*$")
                
                -- Remove quotes if present
                if (value:sub(1,1) == '"' and value:sub(-1,-1) == '"') or 
                   (value:sub(1,1) == "'" and value:sub(-1,-1) == "'") then
                    value = value:sub(2, -2)
                end
                
                parsed[key] = value
                current_key = key
            end
        end
    end
    
    return parsed
end

-- Validate skill directory
local function validate_skill(skill_path)
    -- Normalize path separator
    if not skill_path:match("/$") then
        skill_path = skill_path .. "/"
    end
    
    local skill_md = skill_path .. "SKILL.md"
    
    if not file_exists(skill_md) then
        return false, "SKILL.md not found"
    end
    
    local content, err = read_file(skill_md)
    if not content then
        return false, "Could not read SKILL.md: " .. tostring(err)
    end
    
    local frontmatter_text = extract_frontmatter(content)
    if not frontmatter_text then
        return false, "Invalid frontmatter format"
    end
    
    local frontmatter = parse_simple_frontmatter(frontmatter_text)
    if not frontmatter then
        return false, "Invalid YAML in frontmatter: unsupported syntax without PyYAML installed"
    end
    
    local allowed_properties = {
        name = true,
        description = true,
        license = true,
        ["allowed-tools"] = true,
        metadata = true
    }
    
    -- Check for unexpected keys
    local unexpected_keys = {}
    for key, _ in pairs(frontmatter) do
        if not allowed_properties[key] then
            table.insert(unexpected_keys, key)
        end
    end
    
    if #unexpected_keys > 0 then
        table.sort(unexpected_keys)
        local allowed_list = {}
        for k, _ in pairs(allowed_properties) do
            table.insert(allowed_list, k)
        end
        table.sort(allowed_list)
        
        return false, string.format(
            "Unexpected key(s) in SKILL.md frontmatter: %s. Allowed properties are: %s",
            table.concat(unexpected_keys, ", "),
            table.concat(allowed_list, ", ")
        )
    end
    
    if not frontmatter.name then
        return false, "Missing 'name' in frontmatter"
    end
    
    if not frontmatter.description then
        return false, "Missing 'description' in frontmatter"
    end
    
    local name = frontmatter.name
    if type(name) ~= "string" then
        return false, string.format("Name must be a string, got %s", type(name))
    end
    
    name = name:match("^%s*(.-)%s*$")  -- strip whitespace
    
    if name ~= "" then
        if not name:match("^[a-z0-9%-]+$") then
            return false, string.format(
                "Name '%s' should be hyphen-case (lowercase letters, digits, and hyphens only)",
                name
            )
        end
        
        if name:sub(1,1) == "-" or name:sub(-1,-1) == "-" or name:find("%-%-") then
            return false, string.format(
                "Name '%s' cannot start/end with hyphen or contain consecutive hyphens",
                name
            )
        end
        
        if #name > MAX_SKILL_NAME_LENGTH then
            return false, string.format(
                "Name is too long (%d characters). Maximum is %d characters.",
                #name, MAX_SKILL_NAME_LENGTH
            )
        end
    end
    
    local description = frontmatter.description
    if type(description) ~= "string" then
        return false, string.format("Description must be a string, got %s", type(description))
    end
    
    description = description:match("^%s*(.-)%s*$")  -- strip whitespace
    
    if description ~= "" then
        if description:find("<") or description:find(">") then
            return false, "Description cannot contain angle brackets (< or >)"
        end
        
        if #description > 1024 then
            return false, string.format(
                "Description is too long (%d characters). Maximum is 1024 characters.",
                #description
            )
        end
    end
    
    return true, "Skill is valid!"
end

-- Main execution
if #arg ~= 1 then
    print("Usage: lua quick_validate.lua <skill_directory>")
    os.exit(1)
end

local valid, message = validate_skill(arg[1])
print(message)
os.exit(valid and 0 or 1)
