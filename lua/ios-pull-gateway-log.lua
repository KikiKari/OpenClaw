#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "2848c2f199668567a753b3e1999d193f6712b11d88ac78949b8a8a37e3ef47a9", "source_sha256": "994170e8e95ae7e8bd7564512b31b67821e81c5b77b3b9fd41bad3d0fc2ee46c", "target_language": "lua"}
-- ios-pull-gateway-log.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/dev/ios-pull-gateway-log.sh
-- Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

local function main()
    local DEVICE_UDID = arg[1] or "00008130-000630CE0146001C"
    local BUNDLE_ID = arg[2] or "ai.openclaw.ios.dev.mariano.test"
    local DEST = arg[3] or "/tmp/openclaw-gateway.log"

    local command = string.format(
        'xcrun devicectl device copy from ' ..
        '--device "%s" ' ..
        '--domain-type appDataContainer ' ..
        '--domain-identifier "%s" ' ..
        '--source Documents/openclaw-gateway.log ' ..
        '--destination "%s" >/dev/null',
        DEVICE_UDID, BUNDLE_ID, DEST
    )

    local success = os.execute(command)
    if not success then
        error("Failed to execute xcrun command")
    end

    print("Pulled to: " .. DEST)

    -- Tail last 200 lines
    local tail_command = string.format('tail -n 200 "%s"', DEST)
    os.execute(tail_command)
end

main()
