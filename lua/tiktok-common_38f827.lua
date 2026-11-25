#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "c5bce9db8baed0207e72a5dbbc4ae27c0d8da07e93bc5ef8a7e99621e8b4666b", "source_sha256": "38f82799f0ca285828fb717a736b87169329e2393ab0778a9019dae9e817c6ec", "target_language": "lua"}
-- tiktok-common.js — portiert nach lua
-- Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-common.js
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

-- Reuse the basic skill's normalization, load, selector, URL, and result
-- contract so both extractors classify identical inputs consistently.
return require('../../tiktok-live/scripts/tiktok-common')
