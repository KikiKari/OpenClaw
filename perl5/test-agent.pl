#!/usr/bin/env perl
# test-agent.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-agent.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-agent.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-agent.sh
# auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-agent.sh
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use HTTP::Request::Common;

die "PERPLEXITY_API_KEY is required\n" unless defined $ENV{PERPLEXITY_API_KEY};

my $prompt = $ARGV[0] // "Compare recent open-source LLMs in terms of performance, licensing, and practical use.";
my $tmpdir = $ENV{TMPDIR} // "/tmp";
my $out = "$tmpdir/perplexity-agent-test.json";

my $ua = LWP::UserAgent->new;
$ua->timeout(30);

my $data = {
    preset => "fast-search",
    input => $prompt
};

my $req = POST 'https://api.perplexity.ai/v1/agent',
    Content_Type => 'application/json',
    Authorization => "Bearer $ENV{PERPLEXITY_API_KEY}",
    Content => encode_json($data);

my $response = $ua->request($req);

open my $fh, '>', $out or die "Cannot write to $out: $!\n";
print $fh $response->decoded_content;
close $fh;

my $code = $response->code;
print "agent_http=${code}\n";

my $json_text = $response->decoded_content;
my $json_data = decode_json($json_text);

my $result = {
    keys => [keys %$json_data],
    id => exists $json_data->{id} ? $json_data->{id} : undef,
    status => exists $json_data->{status} ? $json_data->{status} : undef,
    output_count => exists $json_data->{output} ? scalar(@{$json_data->{output}}) : 0,
    error => exists $json_data->{error} ? $json_data->{error} : undef
};

print encode_json($result) . "\n";
