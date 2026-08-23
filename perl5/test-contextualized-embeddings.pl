#!/usr/bin/env perl
# test-contextualized-embeddings.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
# auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use HTTP::Request::Common;
use File::Temp;

die "PERPLEXITY_API_KEY is required\n" unless $ENV{PERPLEXITY_API_KEY};

my $tmpdir = $ENV{TMPDIR} || "/tmp";
my $out = "$tmpdir/perplexity-contextualized-embeddings-test.json";

my $payload = {
    input => [
        [
            "OpenClaw can route web search through Perplexity.",
            "The Perplexity MCP server exposes search and reasoning tools.",
            "Contextualized embeddings improve document chunk retrieval."
        ]
    ],
    model => "pplx-embed-context-v1-4b"
};

my $json_payload = encode_json($payload);

my $ua = LWP::UserAgent->new;
$ua->timeout(30);

my $req = POST "https://api.perplexity.ai/v1/contextualizedembeddings",
    Content_Type => "application/json",
    Authorization => "Bearer $ENV{PERPLEXITY_API_KEY}",
    Content => $json_payload;

my $response = $ua->request($req);

open my $fh, ">", $out or die "Cannot open $out: $!";
print $fh $response->decoded_content;
close $fh;

my $code = $response->code;
print "contextualized_embeddings_http=$code\n";

# Parse and process the JSON response
my $json_text = $response->decoded_content;
my $data = decode_json($json_text);

my $result = {
    keys => [keys %$data],
    model => exists $data->{model} ? $data->{model} : undef,
    document_count => exists $data->{data} ? scalar(@{$data->{data}}) : 0,
    first_chunk_count => (exists $data->{data} && @{$data->{data}} > 0 && exists $data->{data}[0]{data}) 
        ? scalar(@{$data->{data}[0]{data}}) 
        : 0,
    error => exists $data->{error} ? $data->{error} : undef
};

print encode_json($result) . "\n";
