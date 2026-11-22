#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "8fa16ee641b053df0f99afe84e909123d0f2c9660365b16309a46be2da2add5e", "source_sha256": "7d9c583822b7f56d89ce608cb8d469719c8a0d1dda7229ea2e4bbf717e511afe", "target_language": "perl5"}
# run.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-e2e/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use File::Basename;
use Cwd qw(abs_path);
use POSIX qw(strftime);
use IPC::Open3;
use Symbol qw(gensym);

my $script_dir = dirname(abs_path($0));
my $verify_helper_path = "/usr/local/install-sh-common/version-parse.sh";
unless (-f $verify_helper_path) {
    $verify_helper_path = "$script_dir/../install-sh-common/version-parse.sh";
}
do $verify_helper_path or die "Failed to load version-parse.sh: $!";

my $install_url = $ENV{'OPENCLAW_INSTALL_URL'} // "https://openclaw.bot/install.sh";
my $models_mode = $ENV{'OPENCLAW_E2E_MODELS'} // "both"; # both|openai|anthropic
my $install_tag = $ENV{'OPENCLAW_INSTALL_TAG'} // "latest";
my $e2e_previous_version = $ENV{'OPENCLAW_INSTALL_E2E_PREVIOUS'} // "";
my $skip_previous = $ENV{'OPENCLAW_INSTALL_E2E_SKIP_PREVIOUS'} // "0";
my $openai_api_key = $ENV{'OPENAI_API_KEY'} // "";
my $anthropic_api_key = $ENV{'ANTHROPIC_API_KEY'} // "";
my $anthropic_api_token = $ENV{'ANTHROPIC_API_TOKEN'} // "";

# This image runs as a non-root user, so seed a user-local npm prefix before we
# preinstall an older global version to exercise the upgrade path.
my $npm_config_prefix = $ENV{'NPM_CONFIG_PREFIX'} // "$ENV{HOME}/.npm-global";
mkdir $npm_config_prefix unless -d $npm_config_prefix;
$ENV{'PATH'} = "$npm_config_prefix/bin:$ENV{PATH}";

if ($models_mode ne "both" && $models_mode ne "openai" && $models_mode ne "anthropic") {
    print STDERR "ERROR: OPENCLAW_E2E_MODELS must be one of: both|openai|anthropic\n";
    exit 2;
}

if ($models_mode eq "both") {
    if (!$openai_api_key) {
        print STDERR "ERROR: OPENCLAW_E2E_MODELS=both requires OPENAI_API_KEY.\n";
        exit 2;
    }
    if (!$anthropic_api_token && !$anthropic_api_key) {
        print STDERR "ERROR: OPENCLAW_E2E_MODELS=both requires ANTHROPIC_API_TOKEN or ANTHROPIC_API_KEY.\n";
        exit 2;
    }
} elsif ($models_mode eq "openai" && !$openai_api_key) {
    print STDERR "ERROR: OPENCLAW_E2E_MODELS=openai requires OPENAI_API_KEY.\n";
    exit 2;
} elsif ($models_mode eq "anthropic" && !$anthropic_api_token && !$anthropic_api_key) {
    print STDERR "ERROR: OPENCLAW_E2E_MODELS=anthropic requires ANTHROPIC_API_TOKEN or ANTHROPIC_API_KEY.\n";
    exit 2;
}

print "==> Resolve npm versions\n";
my $expected_version = quiet_npm("view", "openclaw@$install_tag", "version");
if (!$expected_version || $expected_version eq "undefined" || $expected_version eq "null") {
    print STDERR "ERROR: unable to resolve openclaw@$install_tag version\n";
    exit 2;
}
my $previous_version;
if ($e2e_previous_version) {
    $previous_version = $e2e_previous_version;
} else {
    my $versions_json = quiet_npm("view", "openclaw", "versions", "--json");
    my @versions = split /\n/, `$^X -e 'use JSON; my \$v = decode_json(\$ENV{\"VERSIONS_JSON\"}); print join(\"\\n\", ref \$v eq \"ARRAY\" ? @\$v : ())'`;
    if (@versions == 0) {
        print STDERR "ERROR: unable to resolve previous version\n";
        exit 2;
    }
    $previous_version = @versions >= 2 ? $versions[@versions-2] : $versions[0];
}
print "expected=$expected_version previous=$previous_version\n";

if ($skip_previous eq "1") {
    print "==> Skip preinstall previous (OPENCLAW_INSTALL_E2E_SKIP_PREVIOUS=1)\n";
} else {
    print "==> Preinstall previous (forces installer upgrade path; avoids read() prompt)\n";
    quiet_npm("install", "-g", "openclaw@$previous_version");
}

print "==> Run official installer one-liner\n";
if ($install_tag eq "beta") {
    $ENV{'OPENCLAW_BETA'} = 1;
    system("curl -fsSL \"$install_url\" | bash");
    delete $ENV{'OPENCLAW_BETA'};
} elsif ($install_tag ne "latest") {
    $ENV{'OPENCLAW_VERSION'} = $install_tag;
    system("curl -fsSL \"$install_url\" | bash");
    delete $ENV{'OPENCLAW_VERSION'};
} else {
    system("curl -fsSL \"$install_url\" | bash");
}

print "==> Verify installed version\n";
my $installed_version = `openclaw --version 2>/dev/null | head -n 1 | tr -d '\\r'`;
chomp $installed_version;
$installed_version = extract_openclaw_semver($installed_version);
print "installed=$installed_version expected=$expected_version\n";
if ($installed_version ne $expected_version) {
    print STDERR "ERROR: expected openclaw@$expected_version, got openclaw@$installed_version\n";
    exit 1;
}

sub set_image_model {
    my ($profile, @candidates) = @_;
    for my $candidate (@candidates) {
        if (system("openclaw --profile \"$profile\" models set-image \"$candidate\" >/dev/null 2>&1") == 0) {
            return $candidate;
        }
    }
    print STDERR "ERROR: could not set an image model (tried: " . join(", ", @candidates) . ")\n";
    return undef;
}

sub set_agent_model {
    my ($profile, @candidates) = @_;
    for my $candidate (@candidates) {
        if (system("openclaw --profile \"$profile\" models set \"$candidate\" >/dev/null 2>&1") == 0) {
            return $candidate;
        }
    }
    print STDERR "ERROR: could not set agent model (tried: " . join(", ", @candidates) . ")\n";
    return undef;
}

sub write_png_lr_rg {
    my ($out) = @_;
    my $width = 96;
    my $height = 64;
    
    # Generate CRC table
    my @crc_table;
    for my $i (0..255) {
        my $c = $i;
        for my $k (0..7) {
            $c = ($c & 1) ? (0xedb88320 ^ ($c >> 1)) : ($c >> 1);
        }
        push @crc_table, $c & 0xffffffff;
    }
    
    sub crc32 {
        my ($buf) = @_;
        my $c = 0xffffffff;
        for my $byte (unpack("C*", $buf)) {
            $c = $crc_table[($c ^ $byte) & 0xff] ^ ($c >> 8);
        }
        return ($c ^ 0xffffffff) & 0xffffffff;
    }
    
    sub chunk {
        my ($type, $data) = @_;
        my $type_buf = pack("A4", $type);
        my $len = pack("N", length($data));
        my $crc = pack("N", crc32($type_buf . $data));
        return $len . $type_buf . $data . $crc;
    }
    
    my $sig = pack("C8", 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a);
    my $ihdr = pack("NNCCCCC", $width, $height, 8, 2, 0, 0, 0);
    
    my @rows;
    for my $y (0..$height-1) {
        my $row = pack("C", 0); # filter: none
        for my $x (0..$width-1) {
            my $left = $x < $width / 2;
            my ($r, $g, $b) = $left ? (255, 0, 0) : (0, 255, 0);
            $row .= pack("CCC", $r, $g, $b);
        }
        push @rows, $row;
    }
    my $raw = join("", @rows);
    my $idat = `echo '$raw' | gzip -9`;
    
    my $png = $sig . chunk("IHDR", $ihdr) . chunk("IDAT", $idat) . chunk("IEND", "");
    open(my $fh, '>', $out) or die "Cannot write to $out: $!";
    print $fh $png;
    close $fh;
}

sub run_agent_turn {
    my ($profile, $session_id, $prompt, $out_json) = @_;
    # Installer E2E validates install + onboard + embedded agent tooling. It does
    # not need a paired Gateway control-plane hop, which is flaky/non-deterministic
    # in the isolated container and already covered by gateway-specific lanes.
    system("openclaw --profile \"$profile\" agent --local --session-id \"$session_id\" --message \"$prompt\" --thinking off --json >\"$out_json\" 2>&1");
    
    my $raw = `cat "$out_json"`;
    eval {
        my $parsed = extract_trailing_json_object($raw);
        open(my $fh, '>', $out_json) or die "Cannot write to $out_json: $!";
        print $fh encode_json_pretty($parsed) . "\n";
        close $fh;
    };
    if ($@) {
        print STDERR "ERROR: could not extract JSON payload from agent output\n";
        exit 1;
    }
}

sub extract_trailing_json_object {
    my ($input) = @_;
    $input =~ s/^\s+|\s+$//g;
    if (!$input) {
        die "agent output was empty";
    }
    eval {
        return decode_json($input);
    };
    if ($@) {
        # Some local runs emit stderr diagnostics before the final JSON payload.
        # Walk backward and keep the last parseable top-level object.
        my $index = rindex($input, "{");
        while ($index >= 0) {
            my $candidate = substr($input, $index);
            eval {
                return decode_json($candidate);
            };
            $index = rindex($input, "{", $index - 1);
        }
        die "could not extract JSON payload from agent output:\n$input";
    }
}

sub assert_agent_json_has_text {
    my ($path) = @_;
    my $content = `cat "$path"`;
    my $p = decode_json($content);
    my $payloads = 
        (ref($p->{result}->{payloads}) eq "ARRAY") ? $p->{result}->{payloads} :
        (ref($p->{payloads}) eq "ARRAY") ? $p->{payloads} :
        [];
    my @texts = map { $_->{text} // "" } @$payloads;
    @texts = grep { $_ =~ /\S/ } @texts;
    if (@texts == 0) {
        exit 1;
    }
}

sub assert_agent_json_ok {
    my ($json_path, $expect_provider) = @_;
    my $content = `cat "$json_path"`;
    my $p = decode_json($content);
    
    if (defined $p->{status} && $p->{status} ne "ok" && $p->{status} ne "accepted") {
        print STDERR "ERROR: gateway status=$p->{status}\n";
        exit 1;
    }
    
    my $result = $p->{result} // $p;
    my $payloads = (ref($result->{payloads}) eq "ARRAY") ? $result->{payloads} : [];
    my $any_error = grep { $_->{isError} } @$payloads;
    my $combined_text = join("\n", map { $_->{text} // "" } @$payloads);
    $combined_text =~ s/^\s+|\s+$//g;
    
    if ($any_error) {
        print STDERR "ERROR: agent returned error payload: $combined_text\n";
        exit 1;
    }
    if ($combined_text =~ /rate_limit_error/i || $combined_text =~ /^429\b/) {
        print STDERR "ERROR: agent rate limited: $combined_text\n";
        exit 1;
    }
    
    my $meta = $result->{meta};
    my $provider = 
        (defined $meta->{agentMeta}->{provider} && $meta->{agentMeta}->{provider} =~ /\S/) ? $meta->{agentMeta}->{provider} :
        (defined $meta->{provider} && $meta->{provider} =~ /\S/) ? $meta->{provider} :
        "";
    if ($expect_provider && $provider && $provider ne $expect_provider) {
        print STDERR "ERROR: expected provider=$expect_provider, got provider=$provider\n";
        exit 1;
    }
}

sub extract_matching_text {
    my ($path, $expected) = @_;
    my $content = `cat "$path"`;
    my $p = decode_json($content);
    my $payloads = 
        (ref($p->{result}->{payloads}) eq "ARRAY") ? $p->{result}->{payloads} :
        (ref($p->{payloads}) eq "ARRAY") ? $p->{payloads} :
        [];
    my @texts = map { $_->{text} // "" } @$payloads;
    @texts = grep { $_ =~ /\S/ } @texts;
    my ($match) = grep { $_ eq $expected } @texts;
    return $match // $texts[0] // "";
}

sub assert_session_used_tools {
    my ($jsonl, @required) = @_;
    my %required_set = map { $_ => 1 } @required;
    my $content = `cat "$jsonl"`;
    my @lines = grep { /\S/ } map { s/^\s+|\s+$//gr } split(/\n/, $content);
    my %seen;
    
    my %tool_types = map { $_ => 1 } (
        "tool_use", "tool_result", "tool", "tool-call", "tool_call",
        "tooluse", "tool-use", "toolresult", "tool-result"
    );
    
    sub walk {
        my ($node, $parent) = @_;
        return unless defined $node;
        if (ref($node) eq "ARRAY") {
            walk($_, $node) for @$node;
            return;
        }
        return unless ref($node) eq "HASH";
        my $obj = $node;
        my $t = defined $obj->{type} ? $obj->{type} : undef;
        if ($t && ($tool_types{$t} || $t =~ /tool/i)) {
            my $name = 
                (defined $obj->{name} && ref($obj->{name}) eq "") ? $obj->{name} :
                (defined $obj->{toolName} && ref($obj->{toolName}) eq "") ? $obj->{toolName} :
                (defined $obj->{tool_name} && ref($obj->{tool_name}) eq "") ? $obj->{tool_name} :
                (defined $obj->{tool} && ref($obj->{tool}) eq "HASH" && defined $obj->{tool}->{name} && ref($obj->{tool}->{name}) eq "") ? $obj->{tool}->{name} :
                undef;
            $seen{$name} = 1 if defined $name;
        }
        if (defined $obj->{name} && ref($obj->{name}) eq "" && defined $obj->{input} && ref($obj->{input}) eq "HASH") {
            # Many tool-use blocks look like { type: "...", name: "exec", input: {...} }
            # but some transcripts omit/rename type.
            $seen{$obj->{name}} = 1;
        }
        # OpenAI-ish tool call shapes.
        if (ref($obj->{tool_calls}) eq "ARRAY") {
            for my $c (@{$obj->{tool_calls}}) {
                my $fn = $c->{function};
                if ($fn && defined $fn->{name} && ref($fn->{name}) eq "") {
                    $seen{$fn->{name}} = 1;
                }
            }
        }
        if (defined $obj->{function} && defined $obj->{function}->{name} && ref($obj->{function}->{name}) eq "") {
            $seen{$obj->{function}->{name}} = 1;
        }
        walk($_, $obj) for values %$obj;
    }
    
    for my $line (@lines) {
        eval {
            my $entry = decode_json($line);
            walk($entry, undef);
        };
    }
    
    my @missing = grep { !$seen{$_} } keys %required_set;
    if (@missing) {
        print STDERR "Missing tools in transcript: " . join(", ", @missing) . "\n";
        print STDERR "Seen tools: " . join(", ", sort keys %seen) . "\n";
        print STDERR "Transcript head:\n";
        print STDERR join("\n", @lines[0..4]) . "\n";
        exit 1;
    }
}

sub run_profile {
    my ($profile, $port, $workspace, $agent_model_provider) = @_;
    
    print "==> Onboard ($profile)\n";
    if ($agent_model_provider eq "openai") {
        system("openclaw --profile \"$profile\" onboard --non-interactive --accept-risk --flow quickstart --auth-choice openai-api-key --openai-api-key \"$openai_api_key\" --gateway-port \"$port\" --gateway-bind loopback --gateway-auth token --workspace \"$workspace\" --skip-health");
    } elsif ($anthropic_api_key) {
        system("openclaw --profile \"$profile\" onboard --non-interactive --accept-risk --flow quickstart --auth-choice apiKey --anthropic-api-key \"$anthropic_api_key\" --gateway-port \"$port\" --gateway-bind loopback --gateway-auth token --workspace \"$workspace\" --skip-health");
    } elsif ($anthropic_api_token) {
        system("openclaw --profile \"$profile\" onboard --non-interactive --accept-risk --flow quickstart --auth-choice token --token-provider anthropic --token \"$anthropic_api_token\" --gateway-port \"$port\" --gateway-bind loopback --gateway-auth token --workspace \"$workspace\" --skip-health");
    } else {
        system("openclaw --profile \"$profile\" onboard --non-interactive --accept-risk --flow quickstart --auth-choice apiKey --anthropic-api-key \"$anthropic_api_key\" --gateway-port \"$port\" --gateway-bind loopback --gateway-auth token --workspace \"$workspace\" --skip-health");
    }
    
    print "==> Verify workspace identity files ($profile)\n";
    die "Missing AGENTS.md" unless -f "$workspace/AGENTS.md";
    die "Missing IDENTITY.md" unless -f "$workspace/IDENTITY.md";
    die "Missing USER.md" unless -f "$workspace/USER.md";
    die "Missing SOUL.md" unless -f "$workspace/SOUL.md";
    die "Missing TOOLS.md" unless -f "$workspace/TOOLS.md";
    
    print "==> Configure models ($profile)\n";
    my $agent_model;
    my $image_model;
    if ($agent_model_provider eq "openai") {
        $agent_model = set_agent_model($profile, "openai/gpt-5.4", "openai/gpt-4o-mini", "openai/gpt-4o");
        $image_model = set_image_model($profile, "openai/gpt-4o-mini", "openai/gpt-4o");
    } else {
        $agent_model = set_agent_model($profile, "anthropic/claude-opus-4-6", "claude-opus-4-6");
        $image_model = set_image_model($profile, "anthropic/claude-opus-4-6", "claude-opus-4-6");
    }
    print "model=$agent_model\n";
    print "imageModel=$image_model\n";
    
    print "==> Prepare tool fixtures ($profile)\n";
    my $proof_txt = "$workspace/proof.txt";
    my $proof_copy = "$workspace/copy.txt";
    my $hostname_txt = "$workspace/hostname.txt";
    my $image_png = "$workspace/proof.png";
    my $image_txt = "$workspace/image.txt";
    my $session_id = "e2e-tools-${profile}";
    my $session_jsonl = "$ENV{HOME}/.openclaw-${profile}/agents/main/sessions/${session_id}.jsonl";
    
    my $proof_value = `perl -e 'use Digest::MD5 qw(md5_hex); print md5_hex(rand())'`;
    chomp $proof_value;
    open(my $fh, '>', $proof_txt) or die "Cannot write to $proof_txt: $!";
    print $fh $proof_value;
    close $fh;
    write_png_lr_rg($image_png);
    my $expected_hostname = `hostname`;
    chomp $expected_hostname;
    $expected_hostname =~ s/\r|\n//g;
    
    print "==> Start gateway ($profile)\n";
    my $gateway_log = "$workspace/gateway.log";
    my $gateway_pid = fork();
    if ($gateway_pid == 0) {
        open(STDOUT, '>', $gateway_log) or die "Cannot redirect stdout: $!";
        open(STDERR, '>&STDOUT') or die "Cannot redirect stderr: $!";
        exec("openclaw --profile \"$profile\" gateway --port \"$port\" --bind loopback");
    }
    
    sub cleanup_profile {
        if (kill(0, $gateway_pid)) {
            kill('TERM', $gateway_pid);
            waitpid($gateway_pid, 0);
        }
    }
    
    $SIG{INT} = \&cleanup_profile;
    $SIG{TERM} = \&cleanup_profile;
    
    print "==> Wait for health ($profile)\n";
    for my $i (1..240) {
        if (system("openclaw --profile \"$profile\" health --timeout 5000 --json >/dev/null 2>&1") == 0) {
            last;
        }
        select(undef, undef, undef, 0.25);
    }
    system("openclaw --profile \"$profile\" health --timeout 60000 --json >/dev/null");
    
    print "==> Agent turns ($profile)\n";
    my $turn1_json = "/tmp/agent-${profile}-1.json";
    my $turn2_json = "/tmp/agent-${profile}-2.json";
    my $turn2b_json = "/tmp/agent-${profile}-2b.json";
    my $turn3_json = "/tmp/agent-${profile}-3.json";
    my $turn3b_json = "/tmp/agent-${profile}-3b.json";
    my $turn4_json = "/tmp/agent-${profile}-4.json";
    
    run_agent_turn($profile, $session_id, "Use the read tool (not exec) to read ${proof_txt}. Reply with the exact contents only (no extra whitespace).", $turn1_json);
    assert_agent_json_has_text($turn1_json);
    assert_agent_json_ok($turn1_json, $agent_model_provider);
    my $reply1 = extract_matching_text($turn1_json, $proof_value);
    $reply1 =~ s/\r|\n//g;
    if ($reply1 ne $proof_value) {
        print STDERR "ERROR: agent did not read proof.txt correctly ($profile): $reply1\n";
        exit 1;
    }
    
    my $prompt2 = "Use the write tool (not exec) to write exactly this string into ${proof_copy}:\n${reply1}\nReply with exactly: WROTE";
    run_agent_turn($profile, $session_id, $prompt2, $turn2_json);
    assert_agent_json_has_text($turn2_json);
    assert_agent_json_ok($turn2_json, $agent_model_provider);
    my $copy_value = `cat "$proof_copy" 2>/dev/null`;
    chomp $copy_value;
    $copy_value =~ s/\r|\n//g;
    if ($copy_value ne $proof_value) {
        print STDERR "ERROR: copy.txt did not match proof.txt ($profile)\n";
        exit 1;
    }
    run_agent_turn($profile, $session_id, "Use the read tool (not exec) to read ${proof_copy}. Reply with the exact contents only (no extra whitespace).", $turn2b_json);
    assert_agent_json_has_text($turn2b_json);
    assert_agent_json_ok($turn2b_json, $agent_model_provider);
    my $reply2 = extract_matching_text($turn2b_json, $proof_value);
    $reply2 =~ s/\r|\n//g;
    if ($reply2 ne $proof_value) {
        print STDERR "ERROR: agent did not read copy.txt correctly ($profile): $reply2\n";
        exit 1;
    }
    
    run_agent_turn($profile, $session_id, "Use the exec tool to run this command: hostname. Reply with the exact stdout only (trim trailing newline).", $turn3_json);
    assert_agent_json_has_text($turn3_json);
    assert_agent_json_ok($turn3_json, $agent_model_provider);
    my $reply3 = extract_matching_text($turn3_json, $expected_hostname);
    $reply3 =~ s/\r|\n//g;
    if ($reply3 ne $expected_hostname) {
        print STDERR "ERROR: agent did not run hostname correctly ($profile): $reply3\n";
        exit 1;
    }
    my $prompt3b = "Use the write tool to write exactly this string into ${hostname_txt}:\n${reply3}\nReply with exactly: WROTE";
    run_agent_turn($profile, $session_id, $prompt3b, $turn3b_json);
    assert_agent_json_has_text($turn3b_json);
    assert_agent_json_ok($turn3b_json, $agent_model_provider);
    my $hostname_content = `cat "$hostname_txt" 2>/dev/null`;
    chomp $hostname_content;
    $hostname_content =~ s/\r|\n//g;
    if ($hostname_content ne $expected_hostname) {
        print STDERR "ERROR: hostname.txt did not match hostname output ($profile)\n";
        exit 1;
    }
    
    run_agent_turn($profile, $session_id, "Use the image tool on ${image_png}. Determine which color is on the left half and which is on the right half. Then use the write tool to write exactly: LEFT=RED RIGHT=GREEN into ${image_txt}. Reply with exactly: LEFT=RED RIGHT=GREEN", $turn4_json);
    assert_agent_json_has_text($turn4_json);
    assert_agent_json_ok($turn4_json, $agent_model_provider);
    my $image_content = `cat "$image_txt" 2>/dev/null`;
    chomp $image_content;
    $image_content =~ s/\r|\n//g;
    if ($image_content ne "LEFT=RED RIGHT=GREEN") {
        print STDERR "ERROR: image.txt did not contain expected marker ($profile)\n";
        exit 1;
    }
    my $reply4 = extract_matching_text($turn4_json, "LEFT=RED RIGHT=GREEN");
    if ($reply4 ne "LEFT=RED RIGHT=GREEN") {
        print STDERR "ERROR: agent reply did not contain expected marker ($profile): $reply4\n";
        exit 1;
    }
    
    print "==> Verify tool usage via session transcript ($profile)\n";
    # Give the gateway a moment to flush transcripts.
    sleep(1);
    if (!-f $session_jsonl) {
        print STDERR "ERROR: missing session transcript ($profile): $session_jsonl\n";
        system("ls -la \"$ENV{HOME}/.openclaw-${profile}/agents/main/sessions\" >&2");
        exit 1;
    }
    assert_session_used_tools($session_jsonl, "read", "write", "exec", "image");
    
    cleanup_profile();
    $SIG{INT} = "DEFAULT";
    $SIG{TERM} = "DEFAULT";
}

if ($models_mode eq "openai" || $models_mode eq "both") {
    run_profile("e2e-openai", "18789", "/tmp/openclaw-e2e-openai", "openai");
}

if ($models_mode eq "anthropic" || $models_mode eq "both") {
    run_profile("e2e-anthropic", "18799", "/tmp/openclaw-e2e-anthropic", "anthropic");
}

print "OK\n";

sub quiet_npm {
    my @args = @_;
    my $pid = open3(gensym, \*READER, \*WRITER, "npm", @args);
    close WRITER;
    my $output = do { local $/; <READER> };
    close READER;
    waitpid($pid, 0);
    chomp $output;
    return $output;
}

sub decode_json {
    my ($json_str) = @_;
    # Simple JSON parser for basic structures
    $json_str =~ s/^\s+|\s+$//g;
    if ($json_str =~ /^\{/) {
        my %hash;
        $json_str =~ s/^\{\s*//;
        $json_str =~ s/\s*\}$//;
        for my $pair (split /,\s*/, $json_str) {
            if ($pair =~ /^"(.*?)"\s*:\s*(.*)$/) {
                my ($key, $value) = ($1, $2);
                if ($value =~ /^"/) {
                    $value =~ s/^"(.*)"$/$1/;
                } elsif ($value =~ /^\[/) {
                    # Simplified array parsing
                    $value =~ s/^\[(.*)\]$/$1/;
                    my @arr = split /,\s*/, $value;
                    for my $item (@arr) {
                        $item =~ s/^"(.*)"$/$1/ if $item =~ /^"/;
                    }
                    $hash{$key} = \@arr;
                    next;
                } else {
                    $value += 0 if $value =~ /^\d+$/;
                }
                $hash{$key} = $value;
            }
        }
        return \%hash;
    } elsif ($json_str =~ /^\[/) {
        $json_str =~ s/^\[\s*//;
        $json_str =~ s/\s*\]$//;
        my @arr = split /,\s*/, $json_str;
        for my $item (@arr) {
            $item =~ s/^"(.*)"$/$1/ if $item =~ /^"/;
            $item += 0 if $item =~ /^\d+$/;
        }
        return \@arr;
    }
    return $json_str;
}

sub encode_json_pretty {
    my ($data, $indent) = @_;
    $indent //= 0;
    my $spaces = "  " x $indent;
    if (ref($data) eq "HASH") {
        my @pairs;
        for my $key (sort keys %$data) {
            my $value = $data->{$key};
            my $formatted_value = encode_json_pretty($value, $indent + 1);
            push @pairs, "\"$key\": $formatted_value";
        }
        return "{\n" . join(",\n", map { "  $spaces$_" } @pairs) . "\n$spaces}";
    } elsif (ref($data) eq "ARRAY") {
        my @items = map { encode_json_pretty($_, $indent + 1) } @$data;
        return "[\n" . join(",\n", map { "  $spaces$_" } @items) . "\n$spaces]";
    } elsif (ref($data)) {
        return "\"$data\"";
    } elsif ($data =~ /^\d+$/) {
        return $data;
    } else {
        return "\"$data\"";
    }
}
