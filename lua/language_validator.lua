#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "3ca3ec63bc33a60531e47e26462ac574427e03ce90872184c6d51980839d0fcb", "source_sha256": "eb21431dabeaafc82a1e3ccf24278616e46ed082eca1de4d328c758ee82ee2c7", "target_language": "lua"}
-- language_validator.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/language_validator.py
-- auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/language_validator.py
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

local subprocess = require("subprocess")
local argparse = require("argparse")

local ValidationResult = {}
ValidationResult.__index = ValidationResult

function ValidationResult.new(language, valid, errors, warnings, doc_url)
    local self = setmetatable({}, ValidationResult)
    self.language = language
    self.valid = valid
    self.errors = errors or {}
    self.warnings = warnings or {}
    self.doc_url = doc_url
    return self
end

local LanguageValidator = {}
LanguageValidator.__index = LanguageValidator

LanguageValidator.LANGUAGES = {
    bash = {cmd = "bash", args = {"-n"}, linter = "shellcheck"},
    sh = {cmd = "sh", args = {"-n"}, linter = "shellcheck"},
    python = {cmd = "python3", args = {"-m", "py_compile"}, linter = "pylint"},
    perl = {cmd = "perl", args = {"-c"}, linter = "perlcritic"},
    raku = {cmd = "raku", args = {"-c"}, linter = nil},
    powershell = {cmd = "pwsh", args = {"-Command", "Get-Command"}, linter = nil},
    javascript = {cmd = "node", args = {"--check"}, linter = "eslint"},
    tcl = {cmd = "tclsh", args = {}, linter = nil},
}

function LanguageValidator.new(language, use_websearch)
    use_websearch = use_websearch == nil and true or use_websearch
    language = language:lower()
    local self = setmetatable({}, LanguageValidator)
    self.language = language
    self.use_websearch = use_websearch
    self.config = LanguageValidator.LANGUAGES[language]
    if not self.config then
        error("Unsupported language: " .. language)
    end
    return self
end

function LanguageValidator:validate(script_path)
    local errors = {}
    local warnings = {}
    
    -- Syntax check
    local cmd_args = {self.config.cmd}
    for _, arg in ipairs(self.config.args) do
        table.insert(cmd_args, arg)
    end
    table.insert(cmd_args, script_path)
    
    local result = subprocess.run(cmd_args, {
        capture_output = true,
        text = true,
        timeout = 30
    })
    
    if result.returncode ~= 0 then
        table.insert(errors, result.stderr)
    end
    
    if result.error and result.error:find("not found") then
        table.insert(errors, "Command not found: " .. self.config.cmd)
        if self.use_websearch then
            local doc_url = self:_fetch_docs()
            return ValidationResult.new(self.language, false, errors, warnings, doc_url)
        end
    end
    
    -- Linter check if available
    if self.config.linter then
        local linter_warnings = self:_run_linter(script_path)
        for _, warn in ipairs(linter_warnings) do
            table.insert(warnings, warn)
        end
    end
    
    return ValidationResult.new(
        self.language,
        #errors == 0,
        errors,
        warnings
    )
end

function LanguageValidator:_run_linter(script_path)
    local linter = self.config.linter
    local warnings = {}
    
    if linter == "shellcheck" then
        local result = subprocess.run({"shellcheck", "-f", "gcc", script_path}, {
            capture_output = true,
            text = true
        })
        if result.stdout and result.stdout ~= "" then
            for line in result.stdout:gmatch("[^\r\n]+") do
                table.insert(warnings, line)
            end
        end
    elseif linter == "pylint" then
        local result = subprocess.run({"pylint", "--output-format=parseable", script_path}, {
            capture_output = true,
            text = true
        })
        if result.stdout and result.stdout ~= "" then
            for line in result.stdout:gmatch("[^\r\n]+") do
                table.insert(warnings, line)
            end
        end
    end
    
    if #warnings == 0 and (result.error and result.error:find("not found")) then
        table.insert(warnings, "Linter not installed: " .. linter)
    end
    
    return warnings
end

function LanguageValidator:_fetch_docs()
    if not self.use_websearch then
        return nil
    end
    
    local docs = {
        powershell = "https://docs.microsoft.com/powershell/",
        raku = "https://docs.raku.org/",
        tcl = "https://www.tcl.tk/",
    }
    return docs[self.language]
end

local function main()
    local parser = argparse("language_validator", "Validate scripts in multiple languages")
    parser:argument("script", "Path to script file")
    parser:option("--lang", "Language (bash/python/perl/etc.)"):args(1)
    parser:flag("--no-websearch", "Disable WebSearch")
    
    local args = parser:parse()
    
    local validator = LanguageValidator.new(args.lang, not args.no_websearch)
    local result = validator.validate(args.script)
    
    print("Language: " .. result.language)
    print("Valid: " .. tostring(result.valid))
    if #result.errors > 0 then
        print("Errors: " .. #result.errors)
        for i = 1, math.min(5, #result.errors) do
            print("  - " .. result.errors[i])
        end
    end
    if #result.warnings > 0 then
        print("Warnings: " .. #result.warnings)
        for i = 1, math.min(5, #result.warnings) do
            print("  - " .. result.warnings[i])
        end
    end
    if result.doc_url then
        print("Docs: " .. result.doc_url)
    end
    
    os.exit(result.valid and 0 or 1)
end

if arg and #arg > 0 then
    main()
end
