#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "8b12c488999c029dba8866fa1449110ce621f517b50d7eb4d0bf9caeb876a1d5", "source_sha256": "4683de03d118212741f1ba6fc6f25ee1cfaf247a9d136a0a5b33152bb39ce5a5", "target_language": "perl6"}
# ci-node-test-plan.mjs — portiert nach perl6
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/ci-node-test-plan.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

use v6;

# Importieren der Shard-Daten (angenommen, diese sind in einem Modul definiert)
# In Raku gibt es kein direktes Equivalent zu JS-Imports, daher mÃ¼ssen wir dies anders handhaben
# FÃ¼r dieses Beispiel definieren wir die Daten direkt oder laden sie aus einer externen Quelle

# Beispielhafte Definition der Shard-Daten (diese wÃ¼rden normalerweise importiert)
my @fullSuiteVitestShards = (
    { name => 'core-unit-example', config => 'test/vitest/vitest.core-unit-example.config.ts', projects => ['project1', 'project2'] },
    { name => 'core-unit-another', config => 'test/vitest/vitest.full-core-contracts.config.ts', projects => ['project3'] },
    { name => 'channels', config => 'test/vitest/vitest.channels.config.ts', projects => ['project4'] },
    # Weitere Shards kÃ¶nnen hier hinzugefÃ¼gt werden
);

my $EXCLUDED_FULL_SUITE_SHARDS = set(
    "test/vitest/vitest.full-core-contracts.config.ts",
    "test/vitest/vitest.full-core-bundled.config.ts",
    "test/vitest/vitest.full-extensions.config.ts"
);

my $EXCLUDED_PROJECT_CONFIGS = set("test/vitest/vitest.channels.config.ts");

sub formatNodeTestShardCheckName($shardName) {
    my $normalizedShardName = $shardName.starts-with("core-unit-")
        ?? "core-" ~ $shardName.substr("core-unit-".chars)
        !! $shardName;
    return "checks-node-" ~ $normalizedShardName;
}

sub createNodeTestShards() {
    my @result;
    for @fullSuiteVitestShards -> $shard {
        next if $EXCLUDED_FULL_SUITE_SHARDS{$shard<config>};

        my @configs = $shard<projects>.grep({ !$EXCLUDED_PROJECT_CONFIGS{$_} });
        next if @configs.elems == 0;

        @result.push({
            checkName => formatNodeTestShardCheckName($shard<name>),
            shardName => $shard<name>,
            configs   => @configs
        });
    }
    return @result;
}

# Beispielaufruf der Funktion (kann entfernt werden, wenn nur als Modul verwendet)
# say createNodeTestShards().gist;
