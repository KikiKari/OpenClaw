#!/usr/bin/env perl
# test-search.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-search.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-search.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-search.sh
# auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-search.sh
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use HTTP::Request::Common;

die "PERPLEXITY_API_KEY is required\n" unless $ENV{PERPLEXITY_API_KEY};

my $query = $ARGV[0] || 'Perplexity API Platform';
my $max_results = $ENV{PERPLEXITY_MAX_RESULTS} || 3;
my $max_tokens_per_page = $ENV{PERPLEXITY_MAX_TOKENS_PER_PAGE} || 256;
my $out = ($ENV{TMPDIR} || '/tmp') . '/perplexity-search-test.json';

my $ua = LWP::UserAgent->new;
$ua->timeout(30);

my $data = {
    query => $query,
    max_results => $max_results + 0,  # ensure numeric
    max_tokens_per_page => $max_tokens_per_page + 0  # ensure numeric
};

my $req = POST 'https://api.perplexity.ai/search',
    Content_Type => 'application/json',
    Authorization => "Bearer $ENV{PERPLEXITY_API_KEY}",
    Content => encode_json($data);

my $response = $ua->request($req);

# Write response content to file
open my $fh, '>', $out or die "Cannot write to $out: $!";
print $fh $response->content;
close $fh;

my $code = $response->code;
print "search_http=${code}\n";

# Process the JSON response
my $json_content = $response->decoded_content;
my $json_data = decode_json($json_content);

# Extract keys
my @keys = keys %$json_data;

# Get results count (check both 'results' and 'data' fields)
my $results_array = $json_data->{results} // $json_data->{data} // [];
my $result_count = ref($results_array) eq 'ARRAY' ? scalar(@$results_array) : 0;

# Get first result if available
my $first_result = @$results_array > 0 ? $results_array->[0] : undef;

# Create output structure
my $output = {
    keys => \@keys,
    result_count => $result_count,
    first => $first_result
};

print encode_json($output) . "\n";
