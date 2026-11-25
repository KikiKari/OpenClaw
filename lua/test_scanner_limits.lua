#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "025ef72933c29fa58a59dac8e995c013fdfc983d7b611853766f845f9921ce6f", "source_sha256": "994fedde2bf4a37dd0a1c17fabe831ffea24f9660e322a06d93e42b0e44a96a7", "target_language": "lua"}
-- test_scanner_limits.cjs — portiert nach lua
-- Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_scanner_limits.cjs
-- auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_scanner_limits.cjs
-- auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_scanner_limits.cjs
-- auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_scanner_limits.cjs
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

local fs = require("fs")
local path = require("path")
local vm = require("vm")

local root = path.resolve(__dirname, "..")
local sources = {
    {"browser-extension/content.js", "  function explicitCardSummary", true},
    {"mobile-shared/webview-bridge.js", "  function primaryVideo", false}
}

local function structuredClone(obj)
    if type(obj) ~= "table" then return obj end
    local res = {}
    for k, v in pairs(obj) do
        res[k] = structuredClone(v)
    end
    return res
end

for _, src in ipairs(sources) do
    local file, ending, browser = src[1], src[2], src[3]
    local source = fs.readFileSync(path.join(root, file), "utf8")
    local startIndex = string.find(source, "  async function scanRecommendations%(run%)")
    local endIndex = string.find(source, ending, startIndex)
    local code = string.sub(source, startIndex, endIndex - 1)
    
    assert(#code > 100, "Code length should be greater than 100")
    
    for _, n in ipairs({1, 50, 51, 299, 300, 301}) do
        local updates = {}
        local cards = {}
        for i = 1, 301 do
            table.insert(cards, {
                handle = "creator" .. (i - 1),
                card = {
                    scrollIntoView = function() end,
                    dispatchEvent = function() end
                }
            })
        end
        
        local run = {
            limit = math.min(n, 300),
            sourceUrl = "https://www.tiktok.com/@creator/live",
            runId = "test",
            cancelled = false
        }
        
        local context = vm.createContext({
            root = {},
            scrollX = 0,
            scrollY = 0,
            innerHeight = 800,
            location = {href = run.sourceUrl},
            Date = os.date,
            MouseEvent = {},
            setTimeout = function(fn)
                fn()
                return 1
            end,
            window = {
                scrollX = 0,
                scrollY = 0,
                innerHeight = 800,
                scrollTo = function() end,
                scrollBy = function() end
            },
            scrollTo = function() end,
            scrollBy = function() end,
            activeRecommendationScan = run,
            RECOMMENDATION_SCAN_MAX_ROUNDS = 12,
            RECOMMENDATION_SCAN_MAX_MS = 45000,
            core = require(path.join(root, "browser-extension/content-core.js")),
            recommendationCards = function()
                return cards
            end,
            recommendationItem = function(e, p)
                return {
                    handle = e.handle,
                    position = p,
                    title = string.rep("x", 300)
                }
            end,
            text = tostring,
            emit = function(type, p)
                table.insert(updates, structuredClone(p))
            end,
            emitRecommendationProgress = function(r, status, items)
                table.insert(updates, structuredClone({status = status, items = items}))
            end
        })
        
        vm.runInContext(code, context)
        context.scanRecommendations(run)
        
        assert(updates[#updates].status == "complete", "Status should be complete")
        assert(#updates[#updates].items == math.min(n, 300), "Items length should match expected value")
        assert(updates[#updates].items[#updates[#updates].items].position == math.min(n, 300), "Last item position should match expected value")
    end
    
    print("PASS synthetic production scan loop: " .. file .. "; 1,50,51,299,300,301")
end
