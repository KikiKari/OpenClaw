#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "a6ea0b18dc2195ac491e05746b5e87619ba9df571a4a019704d3d3425dc175f1", "source_sha256": "6b261a50fe632846e59e96b1c3e1f6787ffd534f7204d14bd7df8784873ac691", "target_language": "lua"}
-- test_package_skill.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_package_skill.py
-- auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_package_skill.py
-- auch in: workspace@local:git/skills/skill-creator/scripts/test_package_skill.py
-- auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/test_package_skill.py
-- auch in: 1 weiteren Fundstellen
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

--[[
Regression tests for skill packaging security behavior.
]]

local package_skill_module = require("package_skill")
local package_skill = package_skill_module.package_skill
local lfs = require("lfs")
local zip = require("zip")

-- Helper functions to simulate Python's Path operations and temporary directory creation
local function create_temp_dir(prefix)
    local temp_dir = os.tmpname()
    os.remove(temp_dir) -- Remove the file created by tmpname
    local full_path = prefix .. tostring(os.time()) .. "_" .. math.random(1000, 9999)
    lfs.mkdir(full_path)
    return full_path
end

local function write_file(path, content)
    local f = io.open(path, "w")
    f:write(content)
    f:close()
end

local function read_file(path)
    local f = io.open(path, "r")
    local content = f:read("*all")
    f:close()
    return content
end

local function exists(path)
    local attr = lfs.attributes(path)
    return attr ~= nil
end

local function is_symlink(path)
    local attr = lfs.symlinkattributes(path)
    return attr and attr.mode == "link"
end

local function rmtree(path)
    if not exists(path) then return end
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local filepath = path .. "/" .. file
            if lfs.attributes(filepath, "mode") == "directory" then
                rmtree(filepath)
            else
                os.remove(filepath)
            end
        end
    end
    lfs.rmdir(path)
end

-- Mocking quick_validate module
_G.quick_validate = {
    validate_skill = function(_path) return true, "Skill is valid!" end
}

-- Test class simulation using metatables
local TestPackageSkillSecurity = {}
TestPackageSkillSecurity.__index = TestPackageSkillSecurity

function TestPackageSkillSecurity:new()
    local instance = {
        temp_dir = nil
    }
    setmetatable(instance, TestPackageSkillSecurity)
    return instance
end

function TestPackageSkillSecurity:setUp()
    self.temp_dir = create_temp_dir("test_skill_")
end

function TestPackageSkillSecurity:tearDown()
    if exists(self.temp_dir) then
        rmtree(self.temp_dir)
    end
end

function TestPackageSkillSecurity:create_skill(name)
    local skill_dir = self.temp_dir .. "/" .. (name or "test-skill")
    lfs.mkdir(skill_dir)
    write_file(skill_dir .. "/SKILL.md", "---\nname: test-skill\ndescription: test\n---\n")
    write_file(skill_dir .. "/script.py", "print('ok')\n")
    return skill_dir
end

function TestPackageSkillSecurity:test_packages_normal_files()
    local skill_dir = self:create_skill("normal-skill")
    local out_dir = self.temp_dir .. "/out"
    lfs.mkdir(out_dir)

    local result = package_skill(skill_dir, out_dir)

    assert(result ~= nil, "Result should not be nil")
    local skill_file = out_dir .. "/normal-skill.skill"
    assert(exists(skill_file), "Skill file should exist")

    local archive = zip.open(skill_file)
    local names = {}
    for entry in archive:files() do
        names[entry.filename] = true
    end
    archive:close()

    assert(names["normal-skill/SKILL.md"], "Should contain SKILL.md")
    assert(names["normal-skill/script.py"], "Should contain script.py")
end

function TestPackageSkillSecurity:test_skips_symlink_to_external_file()
    local skill_dir = self:create_skill("symlink-file-skill")
    local outside = self.temp_dir .. "/outside-secret.txt"
    write_file(outside, "super-secret\n")
    local link = skill_dir .. "/loot.txt"
    local out_dir = self.temp_dir .. "/out"
    lfs.mkdir(out_dir)

    local success, err = os.execute("ln -s " .. outside .. " " .. link)
    if not success then
        print("Symlink unsupported on this platform - skipping test")
        return
    end

    local result = package_skill(skill_dir, out_dir)
    assert(result ~= nil, "Result should not be nil")
    local skill_file = out_dir .. "/symlink-file-skill.skill"
    assert(exists(skill_file), "Skill file should exist")

    local archive = zip.open(skill_file)
    local names = {}
    for entry in archive:files() do
        names[entry.filename] = true
    end
    archive:close()

    assert(names["symlink-file-skill/SKILL.md"], "Should contain SKILL.md")
    assert(names["symlink-file-skill/script.py"], "Should contain script.py")
    assert(not names["symlink-file-skill/loot.txt"], "Should NOT contain loot.txt")
end

function TestPackageSkillSecurity:test_skips_symlink_directory()
    local skill_dir = self:create_skill("symlink-dir-skill")
    local outside_dir = self.temp_dir .. "/outside"
    lfs.mkdir(outside_dir)
    write_file(outside_dir .. "/secret.txt", "secret\n")
    local link = skill_dir .. "/docs"
    local out_dir = self.temp_dir .. "/out"
    lfs.mkdir(out_dir)

    local success, err = os.execute("ln -s " .. outside_dir .. " " .. link)
    if not success then
        print("Symlink unsupported on this platform - skipping test")
        return
    end

    local result = package_skill(skill_dir, out_dir)
    assert(result ~= nil, "Result should not be nil")
    local skill_file = out_dir .. "/symlink-dir-skill.skill"

    local archive = zip.open(skill_file)
    local names = {}
    for entry in archive:files() do
        names[entry.filename] = true
    end
    archive:close()

    assert(names["symlink-dir-skill/SKILL.md"], "Should contain SKILL.md")
    assert(names["symlink-dir-skill/script.py"], "Should contain script.py")
    assert(not names["symlink-dir-skill/docs/secret.txt"], "Should NOT contain secret.txt")
end

function TestPackageSkillSecurity:test_rejects_resolved_path_outside_skill_root()
    local skill_dir = self:create_skill("escape-skill")
    local out_dir = self.temp_dir .. "/out"
    lfs.mkdir(out_dir)

    -- Save original function
    local original_is_within = package_skill_module._is_within

    -- Create mock function
    package_skill_module._is_within = function(path_obj, root)
        if string.match(path_obj, "script.py") then
            return false
        end
        return original_is_within(path_obj, root)
    end

    local result = package_skill(skill_dir, out_dir)

    -- Restore original function
    package_skill_module._is_within = original_is_within

    assert(result == nil, "Result should be nil when path validation fails")
end

function TestPackageSkillSecurity:test_allows_nested_regular_files()
    local skill_dir = self:create_skill("nested-skill")
    local nested = skill_dir .. "/lib/helpers"
    lfs.mkdir(skill_dir .. "/lib")
    lfs.mkdir(nested)
    write_file(nested .. "/util.py", "def run():\n    return 1\n")
    local out_dir = self.temp_dir .. "/out"
    lfs.mkdir(out_dir)

    local result = package_skill(skill_dir, out_dir)

    assert(result ~= nil, "Result should not be nil")
    local skill_file = out_dir .. "/nested-skill.skill"

    local archive = zip.open(skill_file)
    local names = {}
    for entry in archive:files() do
        names[entry.filename] = true
    end
    archive:close()

    assert(names["nested-skill/lib/helpers/util.py"], "Should contain nested util.py")
end

function TestPackageSkillSecurity:test_skips_output_archive_when_output_dir_is_skill_dir()
    local skill_dir = self:create_skill("self-output-skill")

    local result = package_skill(skill_dir, skill_dir)

    assert(result ~= nil, "Result should not be nil")
    local skill_file = skill_dir .. "/self-output-skill.skill"
    assert(exists(skill_file), "Skill file should exist")

    local archive = zip.open(skill_file)
    local names = {}
    for entry in archive:files() do
        names[entry.filename] = true
    end
    archive:close()

    assert(names["self-output-skill/SKILL.md"], "Should contain SKILL.md")
    assert(names["self-output-skill/script.py"], "Should contain script.py")
    assert(not names["self-output-skill/self-output-skill.skill"], "Should NOT contain itself")
end

-- Run all tests
local function run_tests()
    local test_instance = TestPackageSkillSecurity:new()
    
    print("Running test_packages_normal_files...")
    test_instance:setUp()
    test_instance:test_packages_normal_files()
    test_instance:tearDown()
    
    print("Running test_skips_symlink_to_external_file...")
    test_instance:setUp()
    test_instance:test_skips_symlink_to_external_file()
    test_instance:tearDown()
    
    print("Running test_skips_symlink_directory...")
    test_instance:setUp()
    test_instance:test_skips_symlink_directory()
    test_instance:tearDown()
    
    print("Running test_rejects_resolved_path_outside_skill_root...")
    test_instance:setUp()
    test_instance:test_rejects_resolved_path_outside_skill_root()
    test_instance:tearDown()
    
    print("Running test_allows_nested_regular_files...")
    test_instance:setUp()
    test_instance:test_allows_nested_regular_files()
    test_instance:tearDown()
    
    print("Running test_skips_output_archive_when_output_dir_is_skill_dir...")
    test_instance:setUp()
    test_instance:test_skips_output_archive_when_output_dir_is_skill_dir()
    test_instance:tearDown()
    
    print("All tests passed!")
end

run_tests()
