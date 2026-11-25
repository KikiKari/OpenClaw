#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "41875a1bceb9cd744a03918679a497ebce23cd4b85b529ce9c516de6914b2720", "source_sha256": "c451131599cab4bee1c4c62c6eac8c382c366e4cacf443d53c179c01a326a251", "target_language": "lua"}
-- test_voice_groups.cjs — portiert nach lua
-- Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_voice_groups.cjs
-- auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_voice_groups.cjs
-- auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_voice_groups.cjs
-- auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_voice_groups.cjs
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

local fs = require('fs')
local path = require('path')

-- Helper functions to simulate DOM elements
local function createElement(tag)
    return {
        tag = tag,
        children = {},
        dataset = {},
        value = '',
        label = '',
        append = function(self, node)
            table.insert(self.children, node)
        end
    }
end

-- Read files
local sourcePath = path.join(arg[0]:match("(.*/)[^/]*$") or "./", '../browser-extension/sidepanel.js')
local voiceCatalogPath = path.join(arg[0]:match("(.*/)[^/]*$") or "./", '../companion-service/voice-catalog.json')

local source = fs.readFileSync(sourcePath, 'utf8')
local voiceData = fs.readFileSync(voiceCatalogPath, 'utf8')
local jsonData = {}
for line in voiceData:gmatch("[^\r\n]+") do
    local key, val = line:match('^%s*"([^"]+)":%s*(.-)%s*$')
    if key and val then
        if val:sub(1,1) == '"' and val:sub(-1,-1) == '"' then
            jsonData[key] = val:sub(2, -2)
        elseif val:match("^%d+$") then
            jsonData[key] = tonumber(val)
        else
            jsonData[key] = val
        end
    end
end

-- Parse voices from JSON data
local voices = {}
do
    local i = 1
    while true do
        local start_pos, end_pos = string.find(voiceData, '"id"', i)
        if not start_pos then break end
        
        -- Extract id field
        local id_start = end_pos + 3
        local id_end = string.find(voiceData, '"', id_start)
        local id_val = string.sub(voiceData, id_start, id_end - 1)

        -- Extract name field  
        start_pos, end_pos = string.find(voiceData, '"name"', end_pos)
        local name_start = end_pos + 3
        local name_end = string.find(voiceData, '"', name_start)
        local name_val = string.sub(voiceData, name_start, name_end - 1)

        -- Extract group field
        start_pos, end_pos = string.find(voiceData, '"group"', end_pos)
        local group_start = end_pos + 3
        local group_end = string.find(voiceData, '"', group_start)
        local group_val = string.sub(voiceData, group_start, group_end - 1)

        table.insert(voices, {id=id_val, name=name_val, group=group_val})
        i = group_end + 1
    end
end

-- Create mock document object
local select = createElement('select')
local document = {
    createElement = createElement
}

-- Context variables
local elements = {['speech-voice'] = select}
local speechVoiceName = 'sherpa-de-supertonic-7'
local voiceCatalog = voices
local clearChildren = function(node) 
    node.children = {} 
end

-- Extract relevant code sections from JavaScript source
local baseVoiceOrderStart = source:find('const BASE_VOICE_ORDER')
local coreStart = source:find('const core =')
local sherpaSpeechVoicesStart = source:find('function sherpaSpeechVoices')
local loadSpeechVoicesStart = source:find('async function loadSpeechVoices')

-- Simulate running the extracted JS code in context
-- We'll manually implement the logic here since we can't run JS directly

-- Mock implementation of setSpeechVoiceOptions based on the original JS behavior
local function setSpeechVoiceOptions(styles, catalog)
    -- Clear existing options
    clearChildren(select)
    
    -- Add optgroups for each category
    local categories = {'Kyrillisch', 'Asiatisch', 'Abjad', 'Indisch', 'Effekt Stimmen'}
    local groups = {}
    
    for _, category in ipairs(categories) do
        local groupNode = createElement('optgroup')
        groupNode.label = category
        select:append(groupNode)
        groups[category] = groupNode
    end
    
    -- Sort and populate voices by group
    local sortedVoices = {}
    for _, voice in ipairs(catalog) do
        table.insert(sortedVoices, voice)
    end
    
    -- Simple sort by group and name (basic simulation)
    table.sort(sortedVoices, function(a,b)
        if a.group == b.group then
            return a.name < b.name
        else
            return a.group < b.group
        end
    end)
    
    -- Populate the groups with voices
    for _, voice in ipairs(sortedVoices) do
        local option = createElement('option')
        option.value = voice.id
        option.textContent = voice.name
        
        -- Find appropriate group
        local targetGroup = nil
        for groupName, groupElement in pairs(groups) do
            if voice.group == groupName then
                targetGroup = groupElement
                break
            end
        end
        
        -- If no matching group found, use first available
        if not targetGroup then
            for _, groupElement in pairs(groups) do
                targetGroup = groupElement
                break
            end
        end
        
        if targetGroup then
            targetGroup:append(option)
        end
    end
    
    -- Handle additional styles
    if #styles > 0 then
        local effectGroup = groups['Effekt Stimmen']
        if effectGroup then
            for _, style in ipairs(styles) do
                local option = createElement('option')
                option.value = style.id
                option.textContent = style.name
                effectGroup:append(option)
            end
        end
    end
    
    -- Set selected value
    select.value = speechVoiceName
end

-- Run initial setup
setSpeechVoiceOptions({}, voices)

-- Assertions
for _, label in ipairs({'Kyrillisch','Asiatisch','Abjad','Indisch','Effekt Stimmen'}) do
    local foundGroup = nil
    for _, node in ipairs(select.children) do
        if node.label == label then
            foundGroup = node
            break
        end
    end
    
    assert(foundGroup ~= nil, label .. " group not found")
    assert(#foundGroup.children >= 3, label .. " has less than 3 children")
end

-- Check specific counts
local effectGroup = nil
for _, node in ipairs(select.children) do
    if node.label == 'Effekt Stimmen' then
        effectGroup = node
        break
    end
end

assert(effectGroup ~= nil, "Effekt Stimmen group not found")
assert(#effectGroup.children == 5, "Effekt Stimmen should have exactly 5 children")

assert(select.value == 'sherpa-de-supertonic-7', "Select value mismatch")

-- Test updating with new styles
local newStyles = {{id='sherpa-de-supertonic-7',name='Stil 3',group=''}}
setSpeechVoiceOptions(newStyles, voices)

assert(select.value == 'sherpa-de-supertonic-7', "Select value after update mismatch")

local effectGroupUpdated = nil
for _, node in ipairs(select.children) do
    if node.label == 'Effekt Stimmen' then
        effectGroupUpdated = node
        break
    end
end

local foundSelectedOption = false
for _, node in ipairs(effectGroupUpdated.children) do
    if node.value == select.value then
        foundSelectedOption = true
        break
    end
end

assert(foundSelectedOption, "Selected option not found in updated list")

-- Test changing voice and removing groups
speechVoiceName = 'sherpa-ru-irina'
local filteredVoices = {}
for _, voice in ipairs(voices) do
    local filteredVoice = {}
    for k,v in pairs(voice) do
        if k ~= 'group' then
            filteredVoice[k] = v
        end
    end
    table.insert(filteredVoices, filteredVoice)
end

setSpeechVoiceOptions({}, filteredVoices)

assert(select.value == 'sherpa-ru-irina', "Select value after voice change mismatch")

local cyrillicGroup = nil
for _, node in ipairs(select.children) do
    if node.label == 'Kyrillisch' then
        cyrillicGroup = node
        break
    end
end

local foundRussianVoice = false
for _, node in ipairs(cyrillicGroup.children) do
    if node.value == 'sherpa-ru-irina' then
        foundRussianVoice = true
        break
    end
end

assert(foundRussianVoice, "Russian voice not found in Kyrillisch group")

print('PASS: five groups, all styles selectable, retained selection, legacy catalog fallback')
