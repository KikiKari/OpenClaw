#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "fc1e2f4c55795bb2fab16a2759943eff7406e531fa66c591b734ddd95910ceaf", "source_sha256": "4683de03d118212741f1ba6fc6f25ee1cfaf247a9d136a0a5b33152bb39ce5a5", "target_language": "shell"}
# ci-node-test-plan.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/ci-node-test-plan.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Definiere ausgeschlossene Shards und Projekt-Konfigurationen
declare -A EXCLUDED_FULL_SUITE_SHARDS
EXCLUDED_FULL_SUITE_SHARDS["test/vitest/vitest.full-core-contracts.config.ts"]=1
EXCLUDED_FULL_SUITE_SHARDS["test/vitest/vitest.full-core-bundled.config.ts"]=1
EXCLUDED_FULL_SUITE_SHARDS["test/vitest/vitest.full-extensions.config.ts"]=1

declare -A EXCLUDED_PROJECT_CONFIGS
EXCLUDED_PROJECT_CONFIGS["test/vitest/vitest.channels.config.ts"]=1

# Funktion zur Formatierung des Check-Namens
formatNodeTestShardCheckName() {
    local shardName="$1"
    local normalizedShardName

    if [[ "$shardName" == core-unit-* ]]; then
        normalizedShardName="core-${shardName#core-unit-}"
    else
        normalizedShardName="$shardName"
    fi

    echo "checks-node-$normalizedShardName"
}

# Funktion zum Erstellen der Node-Test-Shards
createNodeTestShards() {
    # Simuliere fullSuiteVitestShards als assoziatives Array mit Shard-Informationen
    # In einer echten Implementierung würden diese Daten dynamisch geladen
    declare -A shards=(
        ["core-unit-math"]="test/vitest/vitest.core-unit-math.config.ts,test/vitest/vitest.core-unit-helper.config.ts"
        ["full-core"]="test/vitest/vitest.full-core.config.ts"
        ["channels"]="test/vitest/vitest.channels.config.ts"
    )

    for shardName in "${!shards[@]}"; do
        local config="${shards[$shardName]%%,*}"
        local projects_csv="${shards[$shardName]}"
        
        # Überspringe ausgeschlossene Shards
        if [[ -n "${EXCLUDED_FULL_SUITE_SHARDS[$config]+isset}" ]]; then
            continue
        fi

        # Teile die Projekte auf
        IFS=',' read -ra PROJECTS <<< "$projects_csv"
        local valid_configs=()
        
        for project in "${PROJECTS[@]}"; do
            if [[ -z "${EXCLUDED_PROJECT_CONFIGS[$project]+isset}" ]]; then
                valid_configs+=("$project")
            fi
        done

        # Überspringe leere Konfigurationen
        if [ ${#valid_configs[@]} -eq 0 ]; then
            continue
        fi

        # Erstelle den Check-Namen
        local checkName
        checkName=$(formatNodeTestShardCheckName "$shardName")

        # Gebe das Ergebnis im JSON-ähhnlichen Format aus (simuliert)
        echo "checkName: $checkName"
        echo "shardName: $shardName"
        echo "configs:"
        for cfg in "${valid_configs[@]}"; do
            echo "  - $cfg"
        done
        echo "---"
    done
}
