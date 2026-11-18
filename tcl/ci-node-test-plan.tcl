#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "9e1f5effdc11d67d5c2ed92378a4b674eb097c42a29d6535d965ee148fd00621", "source_sha256": "4683de03d118212741f1ba6fc6f25ee1cfaf247a9d136a0a5b33152bb39ce5a5", "target_language": "tcl"}
# ci-node-test-plan.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/ci-node-test-plan.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Laden der benötigten Module
source "../../test/vitest/vitest.test-shards.mjs"

# Definition der ausgeschlossenen Shards
set EXCLUDED_FULL_SUITE_SHARDS [dict create \
  "test/vitest/vitest.full-core-contracts.config.ts" 1 \
  "test/vitest/vitest.full-core-bundled.config.ts" 1 \
  "test/vitest/vitest.full-extensions.config.ts" 1 \
]

# Definition der ausgeschlossenen Projekt-Konfigurationen
set EXCLUDED_PROJECT_CONFIGS [dict create \
  "test/vitest/vitest.channels.config.ts" 1 \
]

# Funktion zur Formatierung des Check-Namens
proc formatNodeTestShardCheckName {shardName} {
  if {[string match "core-unit-*" $shardName]} {
    set suffix [string range $shardName 9 end]
    set normalizedShardName "core-$suffix"
  } else {
    set normalizedShardName $shardName
  }
  return "checks-node-$normalizedShardName"
}

# Funktion zur Erstellung der Node-Test-Shards
proc createNodeTestShards {} {
  global fullSuiteVitestShards
  global EXCLUDED_FULL_SUITE_SHARDS
  global EXCLUDED_PROJECT_CONFIGS
  
  set result {}
  
  foreach shard $fullSuiteVitestShards {
    set config [dict get $shard "config"]
    
    # Prüfung ob Shard ausgeschlossen ist
    if {[dict exists $EXCLUDED_FULL_SUITE_SHARDS $config]} {
      continue
    }
    
    # Filtern der Projekte
    set filtered_configs {}
    foreach project_config [dict get $shard "projects"] {
      if {![dict exists $EXCLUDED_PROJECT_CONFIGS $project_config]} {
        lappend filtered_configs $project_config
      }
    }
    
    # Wenn keine Konfigurationen übrig bleiben, überspringen
    if {[llength $filtered_configs] == 0} {
      continue
    }
    
    # Hinzufügen des gültigen Shards zum Ergebnis
    dict set shard_dict "checkName" [formatNodeTestShardCheckName [dict get $shard "name"]]
    dict set shard_dict "shardName" [dict get $shard "name"]
    dict set shard_dict "configs" $filtered_configs
    
    lappend result $shard_dict
  }
  
  return $result
}
