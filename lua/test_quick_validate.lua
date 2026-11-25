#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "54177fa67dcbbb0bede185deaea4294a1963a1fbd2eb4237527141dd28597c33", "source_sha256": "2be00c164cb61020637d0364dc8387a8085522b6bfff7606f734a5274046be44", "target_language": "lua"}
-- test_quick_validate.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_quick_validate.py
-- auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_quick_validate.py
-- auch in: workspace@local:git/skills/skill-creator/scripts/test_quick_validate.py
-- auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/test_quick_validate.py
-- auch in: 1 weiteren Fundstellen
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

--[[
Regression tests for quick skill validation.
]]

local uv = require("luv")
local quick_validate = require("quick_validate")

-- Simple test framework
local TestCase = {}
TestCase.__index = TestCase

function TestCase:new()
  local obj = {}
  setmetatable(obj, self)
  return obj
end

function TestCase:setUp()
  -- Create temporary directory
  local temp_dir_name = os.tmpname()
  os.remove(temp_dir_name) -- Remove the file created by tmpname
  self.temp_dir = temp_dir_name .. "_test_quick_validate"
  uv.fs_mkdir(self.temp_dir, 511) -- 0777 in octal
end

function TestCase:tearDown()
  if self.temp_dir and uv.fs_stat(self.temp_dir) then
    -- Simple recursive remove function
    local function remove_dir(dir)
      local req = uv.fs_scandir(dir)
      if req then
        local name, type_var = uv.fs_scandir_next(req)
        while name do
          local path = dir .. "/" .. name
          if type_var == "directory" then
            remove_dir(path)
          else
            uv.fs_unlink(path)
          end
          name, type_var = uv.fs_scandir_next(req)
        end
      end
      uv.fs_rmdir(dir)
    end
    remove_dir(self.temp_dir)
  end
end

function TestCase:assertTrue(condition, message)
  if not condition then
    error("Assertion failed: " .. (message or "Expected true"))
  end
end

function TestCase:assertFalse(condition)
  if condition then
    error("Assertion failed: Expected false")
  end
end

function TestCase:assertEqual(a, b)
  if a ~= b then
    error("Assertion failed: " .. tostring(a) .. " ~= " .. tostring(b))
  end
end

-- Test functions
function TestCase:test_accepts_crlf_frontmatter()
  local skill_dir = self.temp_dir .. "/crlf-skill"
  uv.fs_mkdir(skill_dir, 511)
  
  local content = "---\r\nname: crlf-skill\r\ndescription: ok\r\n---\r\n# Skill\r\n"
  local fd = uv.fs_open(skill_dir .. "/SKILL.md", "w", 420) -- 0644 in octal
  uv.fs_write(fd, content)
  uv.fs_close(fd)
  
  local valid, message = quick_validate.validate_skill(skill_dir)
  
  self:assertTrue(valid, message)
end

function TestCase:test_rejects_missing_frontmatter_closing_fence()
  local skill_dir = self.temp_dir .. "/bad-skill"
  uv.fs_mkdir(skill_dir, 511)
  
  local content = "---\nname: bad-skill\ndescription: missing end\n# no closing fence\n"
  local fd = uv.fs_open(skill_dir .. "/SKILL.md", "w", 420)
  uv.fs_write(fd, content)
  uv.fs_close(fd)
  
  local valid, message = quick_validate.validate_skill(skill_dir)
  
  self:assertFalse(valid)
  self:assertEqual(message, "Invalid frontmatter format")
end

function TestCase:test_fallback_parser_handles_multiline_frontmatter_without_pyyaml()
  local skill_dir = self.temp_dir .. "/multiline-skill"
  uv.fs_mkdir(skill_dir, 511)
  
  local content = [[---
name: multiline-skill
description: Works without pyyaml
allowed-tools:
  - gh
metadata: |
  {
    "owners": ["team-openclaw"]
  }
---
# Skill
]]
  local fd = uv.fs_open(skill_dir .. "/SKILL.md", "w", 420)
  uv.fs_write(fd, content)
  uv.fs_close(fd)
  
  -- Temporarily disable yaml
  local previous_yaml = quick_validate.yaml
  quick_validate.yaml = nil
  
  local success, valid, message = pcall(function()
    return quick_validate.validate_skill(skill_dir)
  end)
  
  -- Restore yaml
  quick_validate.yaml = previous_yaml
  
  if not success then
    error("Test failed with error: " .. valid) -- valid contains the error message here
  end
  
  self:assertTrue(valid, message)
end

-- Run tests
local function run_test(name, test_func)
  print("Running " .. name .. "...")
  local test_case = TestCase:new()
  test_case:setUp()
  local status, err = pcall(test_func, test_case)
  test_case:tearDown()
  if not status then
    print("FAILED: " .. err)
    return false
  else
    print("PASSED")
    return true
  end
end

-- Main execution
local tests = {
  {"test_accepts_crlf_frontmatter", TestCase.test_accepts_crlf_frontmatter},
  {"test_rejects_missing_frontmatter_closing_fence", TestCase.test_rejects_missing_frontmatter_closing_fence},
  {"test_fallback_parser_handles_multiline_frontmatter_without_pyyaml", TestCase.test_fallback_parser_handles_multiline_frontmatter_without_pyyaml}
}

local passed = 0
local failed = 0

for _, test in ipairs(tests) do
  local name, func = test[1], test[2]
  if run_test(name, func) then
    passed = passed + 1
  else
    failed = failed + 1
  end
end

print("\nTests completed: " .. passed .. " passed, " .. failed .. " failed")
if failed > 0 then
  os.exit(1)
end
