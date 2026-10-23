#!/usr/bin/perl
# test_scanner_limits.cjs — portiert nach perl5
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_scanner_limits.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_scanner_limits.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_scanner_limits.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_scanner_limits.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use JSON::PP;
use lib File::Spec->catdir(File::Spec->updir(), 'browser-extension');
require 'content-core.pl';

# Emulate Node.js path.resolve behavior
my $root = File::Spec->rel2abs(File::Spec->updir());

# Sources to test with their end markers and browser flags (not used in Perl version)
my @sources = (
    ['browser-extension/content.js', '  function explicitCardSummary', 1],
    ['mobile-shared/webview-bridge.js', '  function primaryVideo', 0]
);

# Mock classes and functions needed for the test environment
package MockContext;
sub new {
    my ($class, %args) = @_;
    return bless { %args }, $class;
}

sub scrollTo {}
sub scrollBy {}

package main;

# Structured clone emulation using JSON (simplified)
sub structured_clone {
    my ($data) = @_;
    my $json = JSON::PP->new->allow_blessed->convert_blessed;
    return $json->decode($json->encode($data));
}

# Run tests for each source file
foreach my $source_data (@sources) {
    my ($file, $end_marker, $browser_flag) = @$source_data;
    my $full_path = File::Spec->catfile($root, $file);
    
    open my $fh, '<:encoding(UTF-8)', $full_path or die "Cannot read $full_path: $!";
    my $source = do { local $/; <$fh> };
    close $fh;

    # Extract relevant code segment
    my $start_pos = index($source, '  async function scanRecommendations(run)');
    my $end_pos = index($source, $end_marker, $start_pos);
    die "Could not find code boundaries in $file" if $start_pos == -1 || $end_pos == -1;
    
    my $code = substr($source, $start_pos, $end_pos - $start_pos);
    die "Code segment too short in $file" unless length($code) > 100;

    # Test different limits
    foreach my $n (1, 50, 51, 299, 300, 301) {
        my @updates;
        my @cards = map { { handle => "creator$_", card => { scrollIntoView => sub {}, dispatchEvent => sub {} } } } 0..300;
        
        my $run = {
            limit => ($n < 300 ? $n : 300),
            sourceUrl => "https://www.tiktok.com/\@creator/live",
            runId => "test",
            cancelled => 0
        };

        # Create mock context similar to VM context in JS
        my $context = MockContext->new(
            root => {},
            scrollX => 0,
            scrollY => 0,
            innerHeight => 800,
            location => { href => $run->{sourceUrl} },
            Date => 'Date', # Simplified placeholder
            MouseEvent => sub {},
            setTimeout => sub {
                my ($fn) = @_;
                $fn->();
                return 1;
            },
            window => {
                scrollX => 0,
                scrollY => 0,
                innerHeight => 800,
                scrollTo => sub {},
                scrollBy => sub {}
            },
            activeRecommendationScan => $run,
            RECOMMENDATION_SCAN_MAX_ROUNDS => 12,
            RECOMMENDATION_SCAN_MAX_MS => 45000,
            core => ContentCore->new(), # Assuming content-core.js was converted to ContentCore.pm
            recommendationCards => sub { return \@cards },
            recommendationItem => sub {
                my ($e, $p) = @_;
                return { handle => $e->{handle}, position => $p, title => "x" x 300 };
            },
            text => sub { return $_[0]; },
            emit => sub {
                my ($type, $p) = @_;
                push @updates, structured_clone($p);
            },
            emitRecommendationProgress => sub {
                my ($r, $status, $items) = @_;
                push @updates, structured_clone({ status => $status, items => $items });
            }
        );

        # Execute the code in the context (this is a simplified approach)
        # In reality, you'd need to properly evaluate the JavaScript code here
        # Since we're in Perl, this would require a JS engine like JavaScript::V8 or similar
        
        # For now, simulate that the scanRecommendations function ran successfully
        # This part needs actual implementation based on how content.js works
        eval $code; # This won't work directly - just illustrative
        
        # Assertions (simulated)
        die "Update status not complete" unless $updates[-1]->{status} eq 'complete';
        die "Item count mismatch" unless scalar(@{$updates[-1]->{items}}) == ($n < 300 ? $n : 300);
        die "Last item position incorrect" unless $updates[-1]->{items}->[-1]->{position} == ($n < 300 ? $n : 300);
    }
    
    print "PASS synthetic production scan loop: $file; 1,50,51,299,300,301\n";
}
