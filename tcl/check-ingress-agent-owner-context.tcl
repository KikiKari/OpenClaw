#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "ef56735b9d038cfb4bb1499a70ffbf2d2d3336b13ae1de62b33a4abe59457e20", "source_sha256": "cfa6fdcce252a97fa8be4d621d55955657d2f6616d52330d880db2123e1db43b", "target_language": "tcl"}
# check-ingress-agent-owner-context.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-ingress-agent-owner-context.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Tcl does not have native module imports like JavaScript.
# We'll simulate the required functionality directly.

# Simulated constants and variables
set sourceRoots [list "src/gateway" [bundledPluginFile "discord" "src/voice"]]
set enforcedFiles [dict create]
foreach file {
    "src/discord/src/voice/manager.ts"
    "src/gateway/openai-http.ts"
    "src/gateway/openresponses-http.ts"
    "src/gateway/server-methods/agent.ts"
    "src/gateway/server-node-events.ts"
} {
    dict set enforcedFiles $file 1
}

# Dummy implementations for missing functions
proc bundledPluginFile {plugin path} {
    # Simulate path construction
    return "src/$plugin/$path"
}

proc runCallsiteGuard {args} {
    # Placeholder implementation
    puts "Running callsite guard..."
    # In a real scenario, this would process files and check for violations
}

proc collectCallExpressionLines {ts sourceFile predicate} {
    # Placeholder implementation
    return [list]
}

proc unwrapExpression {expression} {
    # Placeholder implementation
    return $expression
}

proc findLegacyAgentCommandCallLines {content {fileName "source.ts"}} {
    # Placeholder implementation
    return [list]
}

proc main {} {
    global sourceRoots enforcedFiles
    runCallsiteGuard \
        -importMetaUrl "" \
        -sourceRoots $sourceRoots \
        -findCallLines findLegacyAgentCommandCallLines \
        -skipRelativePath [list apply {{relPath} {
            global enforcedFiles
            if {[dict exists $enforcedFiles [string map {\\ /} $relPath]]]} {
                return false
            } else {
                return true
            }
        }}] \
        -header "Found ingress callsites using local agentCommand() (must be explicit owner-aware):" \
        -footer "Use agentCommandFromIngress(...) and pass senderIsOwner explicitly at ingress boundaries."
}

# Run as script
if {[info script] eq $argv0} {
    main
}
