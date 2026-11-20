#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "dbb614d5f7f9ef8505f4214852ae1bbbc2f620e65aead7ee70963307556404b3", "source_sha256": "13d5446c5e30146c4173cad6e5ecff0482c7febec4cd8586ae04dff1eaf2417b", "target_language": "lua"}
-- extension-source-classifier.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/extension-source-classifier.mjs
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local CODE_FILE_RE = "%.(%a*ts%s-|%a*js%s-|tsx%s-|jsx%s-)$"
local DECLARATION_FILE_RE = "%.d%.ts$"
local RUNTIME_API_BARREL_RE = "([^/]*/?)runtime%-api%.(%a*ts%s-|%a*js%s-|tsx%s-|jsx%s-)$"
local PUBLIC_API_BARREL_RE = "([^/]*/?)api%.(%a*ts%s-|%a*js%s-|tsx%s-|jsx%s-)$"
local TEST_LIKE_SEGMENT_RE = "([^/]*/?)(__tests__%s-|fixtures%s-|test%s-|tests%s-|test%-fixtures%s-|test%-support%s-|test%-utils%s-)(/?%s-)"
local TEST_LIKE_FILENAME_RE = "([^/]*/?)[^/]-test%-(support%s-|helpers%s-|fixtures%s-|harness%s-)%.(%a*ts%s-|%a*js%s-|tsx%s-|jsx%s-)$"
local TEST_SHARED_FILENAME_RE = "([^/]*/?)[^/]-%.test%-%a+%.(%a*ts%s-|%a*js%s-|tsx%s-|jsx%s-)$"
local TEST_CANARY_FILENAME_RE = "([^/]*/?)__rootdir_boundary_canary__%.(%a*ts%s-|%a*js%s-|tsx%s-|jsx%s-)$"
local SNAPSHOT_FILE_RE = "%.snap$"
local SUFFIX_SKIP_RE = "%.(test%s-|spec%s-|fixture%s-)%.%a+$"
local INFRA_DIR_RE = "([^/]*/?)(coverage%s-|dist%s-|node_modules%s-)(/?%s-)"
local INFRA_NAME_RE = "(test%-harness%s-|test%-support%s-|test%-helpers%s-|test%-fixtures%s-)"

function normalizeExtensionSourcePath(filePath)
    --[[ Normalize backslashes to forward slashes ]]
    return string.gsub(filePath, "\\", "/")
end

function classifyBundledExtensionSourcePath(filePath)
    local normalizedPath = normalizeExtensionSourcePath(filePath)
    
    -- Check if the file is a code file (not a declaration file)
    local isCodeFile = string.match(normalizedPath, CODE_FILE_RE) and not string.match(normalizedPath, DECLARATION_FILE_RE)
    
    -- Check for runtime API barrel files
    local isRuntimeApiBarrel = string.match(normalizedPath, RUNTIME_API_BARREL_RE)
    
    -- Check for public API barrel files
    local isPublicApiBarrel = string.match(normalizedPath, PUBLIC_API_BARREL_RE)
    
    -- Determine if path looks like test-related content
    local isTestLike = 
        string.match(normalizedPath, TEST_LIKE_SEGMENT_RE) or
        string.match(normalizedPath, TEST_LIKE_FILENAME_RE) or
        string.match(normalizedPath, TEST_SHARED_FILENAME_RE) or
        string.match(normalizedPath, TEST_CANARY_FILENAME_RE) or
        string.match(normalizedPath, SUFFIX_SKIP_RE) or
        string.match(normalizedPath, SNAPSHOT_FILE_RE) or
        string.match(normalizedPath, INFRA_NAME_RE)
        
    -- Check for infrastructure artifacts
    local isInfraArtifact = string.match(normalizedPath, INFRA_DIR_RE)
    
    -- Determine if it's production source code
    local isProductionSource = isCodeFile and not isRuntimeApiBarrel and not isTestLike and not isInfraArtifact
    
    -- Return classification results as table
    return {
        normalizedPath = normalizedPath,
        isCodeFile = isCodeFile,
        isRuntimeApiBarrel = isRuntimeApiBarrel,
        isPublicApiBarrel = isPublicApiBarrel,
        isTestLike = isTestLike,
        isInfraArtifact = isInfraArtifact,
        isProductionSource = isProductionSource
    }
end

-- Export functions in a module-like table
M = {}
M.normalizeExtensionSourcePath = normalizeExtensionSourcePath
M.classifyBundledExtensionSourcePath = classifyBundledExtensionSourcePath
return M
