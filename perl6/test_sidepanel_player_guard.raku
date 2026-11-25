#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "34dae6289d7c4b2e2a51f5f9492519c12cc215e914717c22066d5e057f48defb", "source_sha256": "982245244dd1863414e9d3aaedaf8afbfb270bbbc18cd490fbb288290b7667d3", "target_language": "perl6"}
# test_sidepanel_player_guard.cjs — portiert nach perl6
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_sidepanel_player_guard.cjs
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

use v6;

use MONKEY-SEE-NO-EVAL;

# Emuliere Node.js Module
class VM::Context {
    has $.activeTabId is rw;
    has $.activeIsTikTok is rw;
    has $.playerContextGeneration is rw;
    has &.send;
    has &.renderPlayer;
}

# Globale Variablen für Tests
my $reply;
my $calls = 0;
my @rendered;

sub MAIN() {
    my $source = slurp("../browser-extension/sidepanel.js".IO);
    my $start = $source.index('  async function refreshPlayer()');
    my $end = $source.index('  function setButtonBusy', $start);
    
    die "Start or end marker not found" unless defined $start && defined $end && $end > $start;
    
    # Erstelle Kontext
    my $context = VM::Context.new(
        activeTabId => 1,
        activeIsTikTok => True,
        playerContextGeneration => 0,
        send => sub () {
            $calls++;
            return Promise.start({
                await Promise.at(now + 0.01); # Minimal delay to simulate async
                return -> $resolve { $reply = $resolve };
            });
        },
        renderPlayer => sub ($state) { @rendered.push($state) }
    );
    
    # Extrahiere und führe Code aus
    my $code = $source.substr($start, $end - $start);
    EVAL($code, :$context);
    
    # Test 1: Alte Tab-Antwort wird ignoriert
    my $pending = $context.refreshPlayer();
    $context.activeTabId = 2;
    $reply({response => {playerState => {playing => True}}});
    await $pending;
    die "FAIL: Old tab response must be ignored" unless @rendered.elems == 0;
    
    # Test 2: Nicht-TikTok Tabs werden nicht abgefragt
    $context.activeIsTikTok = False;
    await $context.refreshPlayer();
    die "FAIL: Non-TikTok tabs must not be polled" unless $calls == 1;
    
    # Test 3: Aktuelle Tab-Antwort wird gerendert
    $context.activeIsTikTok = True;
    $pending = $context.refreshPlayer();
    $reply({response => {playerState => {playing => True}}});
    await $pending;
    die "FAIL: Current tab response must render" unless @rendered.elems == 1;
    
    # Test 4: Rückkehr zum gleichen Tab erweckt alte Antwort nicht wieder
    $pending = $context.refreshPlayer();
    $context.activeTabId = 3;
    $context.playerContextGeneration++;
    $context.activeTabId = 2;
    $context.playerContextGeneration++;
    $reply({response => {playerState => {playing => False}}});
    await $pending;
    die "FAIL: Returning to the same tab must not revive an old response" unless @rendered.elems == 1;
    
    # Test 5: Kontextinvalidierung vor asynchroner Tab-Suche
    die "FAIL: Context invalidation must precede asynchronous tab lookup" 
        unless $source ~~ /'async function refresh()' \s* '{' \s* 'playerContextGeneration++;' /;
    
    say 'PASS: stale tab response ignored, non-TikTok polling skipped, current response rendered';
}

MAIN();
