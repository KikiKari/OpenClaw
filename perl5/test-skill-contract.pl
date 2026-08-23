#!/usr/bin/perl
# test-skill-contract.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:skills/tiktok-live/scripts/test-skill-contract.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use File::Basename;
use Test::More;

# Regression checks for the documented /tiktok_live normal flow.

my $script_dir = dirname(__FILE__);
my $skill_file = File::Spec->catfile($script_dir, '..', 'SKILL.md');
$skill_file = File::Spec->rel2abs($skill_file);

# Read SKILL.md content
open my $fh, '<:encoding(UTF-8)', $skill_file or die "Cannot read $skill_file: $!";
my $text = do { local $/; <$fh> };
close $fh;

# Normalize whitespace
my $normalized_text = join(' ', split(/\s+/, $text));

my $CANONICAL_COMMAND = '/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @handle --quality auto --json';
my $NODE_COMMAND = $CANONICAL_COMMAND;

subtest 'dispatcher_is_the_documented_first_action' => sub {
    like($text, qr/Make the existing dispatcher the first action/, 'First action mentioned');
    like($normalized_text, qr/first tool call of the request/, 'Tool call mentioned');
    is(($text =~ s/\Q$CANONICAL_COMMAND\E//g), 2, 'Canonical command appears twice');
};

subtest 'slash_command_bypasses_the_model' => sub {
    my @expected = (
        'command-dispatch: tool',
        'command-tool: tiktok_live_command',
        'command-arg-mode: raw'
    );
    for my $exp (@expected) {
        like($text, qr/\Q$exp\E/, "Expected string '$exp'");
    }
};

subtest 'no_preliminary_playwright_or_dependency_probe' => sub {
    my @expected = (
        'Before this dispatcher call, do not invoke or inspect',
        '`tiktok-check-profile.js`',
        'Do not attempt to install or repair browser dependencies',
        'failed preliminary tool call'
    );
    for my $exp (@expected) {
        like($normalized_text, qr/\Q$exp\E/, "Expected normalized string '$exp'");
    }
};

subtest 'direct_exec_without_shell_wrapper' => sub {
    my @expected = (
        'Invoke that executable directly as the exec command',
        'Do not invoke `bash`',
        '`bash -lc`',
        'wrapper must not be attempted in the first place'
    );
    for my $exp (@expected) {
        like($normalized_text, qr/\Q$exp\E/, "Expected normalized string '$exp'");
    }
};

subtest 'success_json_wins_over_trailing_diagnostics' => sub {
    my @expected = (
        'display the final stdout JSON before trailing stderr diagnostics',
        'regardless of its visual position',
        'the tool execution succeeded',
        'Never replace such a result with a generic tool-failure message',
        '`node_available`'
    );
    for my $exp (@expected) {
        like($normalized_text, qr/\Q$exp\E/, "Expected normalized string '$exp'");
    }
};

subtest 'auto_host_and_bounded_node_fallback' => sub {
    my @expected = (
        'tools.exec.host=auto',
        'omit both the `host` and `node` fields',
        'retry exactly once',
        'least-loaded connected paired node',
        'host=node',
        $NODE_COMMAND,
        'Never replace it with'
    );
    for my $exp (@expected) {
        like($text, qr/\Q$exp\E/, "Expected string '$exp'");
    }

    like($normalized_text, qr/`technical_error`, `dependency_missing`, or `overloaded`/, 'Error types mentioned');

    unlike($text, qr/host=gateway/, 'host=gateway should not appear');
    like($text, qr/Never start a second node retry/, 'Second retry forbidden');
    like($text, qr/never\\nchange the global exec host/, 'Host change forbidden');
    like($text, qr/runtime block occurs before the Node allowlist/, 'Runtime block timing mentioned');
    is(($text =~ s/\Q$CANONICAL_COMMAND\E//g), 2, 'Canonical command appears twice');
};

subtest 'public_contract_covers_legacy_and_rich_formats' => sub {
    my $legacy = '@<handle> is currently <OFFLINE|RESTRICTED|OVERLOADED|TECHNICAL_ERROR> on TikTok.
VLC/MPV: not available
Method: <validated method>';
    
    like($text, qr/\Q$legacy\E/, 'Legacy format present');
    like($text, qr/\@<handle> is currently LIVE on TikTok.\nTitel: <room.title>/, 'LIVE format present');

    my @expected = (
        'Stream-URLs:',
        '<label> $$HLS$$:',
        '<label> $$FLV$$:',
        'Live seit: <HH:MM UTC> $$<Xh Ym>$$',
        'exactly one URL and nothing else',
        'degrades to the legacy three lines including the `VLC/MPV:` URL',
        'No raw URL appears in plain text'
    );
    for my $exp (@expected) {
        like($normalized_text, qr/\Q$exp\E/, "Expected normalized string '$exp'");
    }
};

subtest 'existing_capabilities_are_preserved' => sub {
    my @capabilities = (
        'Node', 'browser', 'file', 'directory', 'configuration',
        'dependency', 'diagnostic tools remain available'
    );
    for my $cap (@capabilities) {
        like($text, qr/\Q$cap\E/, "Capability '$cap' preserved");
    }
};

subtest 'no_response_flag_is_documented' => sub {
    unlike($text, qr/--response/, '--response flag should not be documented');
};

subtest 'atomic_output_and_synchronized_audio' => sub {
    my @expected = (
        'send it atomically',
        'Preserve every returned URL byte-for-byte',
        'channel voice output set to `always`',
        'Do not invoke the `tts` tool',
        'do not emit `\[\[tts:text\]\]` wrappers',
        'visible text remains the authoritative source'
    );
    for my $exp (@expected) {
        like($normalized_text, qr/\Q$exp\E/, "Expected normalized string '$exp'");
    }
};

done_testing();
