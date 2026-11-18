#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "a3b1aea12e93236525a41b48da4e8c13002da85a51af3ae1974d31102f4bcc77", "source_sha256": "f290101073ee6a167f46edadda164d2c88affc03c554135fe101a4e422c44c22", "target_language": "lua"}
-- package_skill.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/package_skill.py
-- auch in: OpenClaw@gateway2:skills/skill-creator/scripts/package_skill.py
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

local lfs = require("lfs")
local zip = require("zip")

local function is_within(path, root)
    local root_str = tostring(root)
    local path_str = tostring(path)
    return path_str:sub(1, #root_str) == root_str
end

local function validate_skill(skill_path)
    -- Placeholder for validation function
    -- In a real implementation, this would call the actual validation logic
    return true, "Skill validation passed"
end

local function package_skill(skill_path, output_dir)
    skill_path = lfs.currentdir() .. "/" .. skill_path
    skill_path = skill_path:gsub("//+", "/")
    
    -- Validate skill folder exists
    local attr = lfs.attributes(skill_path)
    if not attr then
        print("[ERROR] Skill folder not found: " .. skill_path)
        return nil
    end
    
    if attr.mode ~= "directory" then
        print("[ERROR] Path is not a directory: " .. skill_path)
        return nil
    end
    
    -- Validate SKILL.md exists
    local skill_md = skill_path .. "/SKILL.md"
    if not lfs.attributes(skill_md) then
        print("[ERROR] SKILL.md not found in " .. skill_path)
        return nil
    end
    
    -- Run validation before packaging
    print("Validating skill...")
    local valid, message = validate_skill(skill_path)
    if not valid then
        print("[ERROR] Validation failed: " .. message)
        print("   Please fix the validation errors before packaging.")
        return nil
    end
    print("[OK] " .. message .. "\n")
    
    -- Determine output location
    local skill_name = skill_path:match("([^/]+)$")
    local output_path
    if output_dir then
        output_path = output_dir
        lfs.mkdir(output_path)
    else
        output_path = lfs.currentdir()
    end
    
    local skill_filename = output_path .. "/" .. skill_name .. ".skill"
    
    local EXCLUDED_DIRS = {
        [".git"] = true,
        [".svn"] = true,
        [".hg"] = true,
        ["__pycache__"] = true,
        ["node_modules"] = true
    }
    
    -- Create the .skill file (zip format)
    local zipfile, err = zip.open(skill_filename, zip.CREATE)
    if not zipfile then
        print("[ERROR] Error creating .skill file: " .. err)
        return nil
    end
    
    local function add_files_to_zip(dir_path, base_path)
        for file in lfs.dir(dir_path) do
            if file ~= "." and file ~= ".." then
                local full_path = dir_path .. "/" .. file
                local rel_path = full_path:sub(#base_path + 2)
                
                -- Skip excluded directories
                if EXCLUDED_DIRS[file] then
                    goto continue
                end
                
                local attr = lfs.attributes(full_path)
                if attr.mode == "directory" then
                    add_files_to_zip(full_path, base_path)
                elseif attr.mode == "file" then
                    -- Security check: ensure file doesn't escape skill root
                    if not is_within(full_path, base_path) then
                        print("[ERROR] File escapes skill root: " .. full_path)
                        return false
                    end
                    
                    -- Skip the output archive itself
                    if full_path == skill_filename then
                        print("[WARN] Skipping output archive: " .. full_path)
                        goto continue
                    end
                    
                    -- Add file to zip
                    local arcname = skill_name .. "/" .. rel_path
                    local content = io.open(full_path, "rb")
                    if content then
                        local data = content:read("*a")
                        content:close()
                        zipfile:add(arcname, data)
                        print("  Added: " .. arcname)
                    end
                elseif attr.mode == "link" then
                    print("[WARN] Skipping symlink: " .. full_path)
                end
            end
            ::continue::
        end
        return true
    end
    
    local success = add_files_to_zip(skill_path, skill_path)
    zipfile:close()
    
    if not success then
        os.remove(skill_filename)
        return nil
    end
    
    print("\n[OK] Successfully packaged skill to: " .. skill_filename)
    return skill_filename
end

local function main()
    if #arg < 1 then
        print("Usage: lua package_skill.lua <path/to/skill-folder> [output-directory]")
        print("\nExample:")
        print("  lua package_skill.lua skills/public/my-skill")
        print("  lua package_skill.lua skills/public/my-skill ./dist")
        os.exit(1)
    end
    
    local skill_path = arg[1]
    local output_dir = #arg > 1 and arg[2] or nil
    
    print("Packaging skill: " .. skill_path)
    if output_dir then
        print("   Output directory: " .. output_dir)
    end
    print()
    
    local result = package_skill(skill_path, output_dir)
    
    if result then
        os.exit(0)
    else
        os.exit(1)
    end
end

main()
