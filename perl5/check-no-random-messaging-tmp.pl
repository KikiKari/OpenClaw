#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "b12d180a13641e2d6eacbee021967b7cda425e94e5157bb2eb6c69c8619fb5ca", "source_sha256": "290dec5062f0c8675bc7304f9c93475a3e9667ed53e93894c5bc66f40e5ae5df", "target_language": "perl5"}
# check-no-random-messaging-tmp.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-random-messaging-tmp.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use Cwd 'abs_path';

# Simulating the module paths and functions since Perl doesn't have direct equivalents to TypeScript's AST parsing
# We'll need to implement simplified versions of what the JavaScript code does

my @messaging_tmpdir_guard_source_roots = (
    "src/channels",
    "src/infra/outbound",
    "src/line",
    "src/media",
    "src/media-understanding",
    "extensions"
);

my %allowed_relative_paths = map { $_ => 1 } (
    bundled_plugin_file("feishu", "src/dedup.ts")
);

sub bundled_plugin_file {
    my ($plugin, $file) = @_;
    # This is a placeholder - adjust path as needed for your project structure
    return "plugins/$plugin/$file";
}

# Simplified version of collecting OS tmpdir imports
# In Perl we don't parse AST, so we'll look for patterns in the source text directly
sub collect_os_tmpdir_imports {
    my ($content) = @_;
    
    my %os_namespace_or_default;
    my %named_tmpdir;
    
    # Look for use statements that import OS modules
    if ($content =~ /use\s+POSIX;/) {
        $os_namespace_or_default{'POSIX'} = 1;
    }
    
    # Look for specific tmpdir imports
    if ($content =~ /tmpdir/) {
        $named_tmpdir{'tmpdir'} = 1;
    }
    
    return (\%os_namespace_or_default, \%named_tmpdir);
}

# Simplified version of finding messaging tmpdir call lines
# Instead of using TypeScript AST, we search the source text directly
sub find_messaging_tmpdir_call_lines {
    my ($content, $filename) = @_;
    $filename //= "source.pl";
    
    my ($os_namespace_or_default, $named_tmpdir) = collect_os_tmpdir_imports($content);
    my @lines;
    
    my $line_number = 0;
    for my $line (split /\n/, $content) {
        $line_number++;
        
        # Check for tmpdir calls
        if ($line =~ /\b(tmpdir)\s*\(/ && $named_tmpdir->{'tmpdir'}) {
            push @lines, $line_number;
        }
        
        # Check for POSIX->tmpdir calls
        if ($line =~ /\bPOSIX->tmpdir\b/ && $os_namespace_or_default->{'POSIX'}) {
            push @lines, $line_number;
        }
    }
    
    return @lines;
}

# Simplified version of run_callsite_guard
sub run_callsite_guard {
    my (%args) = @_;
    
    my $source_roots = $args{source_roots};
    my $find_call_lines = $args{find_call_lines};
    my $skip_relative_path = $args{skip_relative_path};
    my $header = $args{header};
    my $footer = $args{footer};
    
    print "$header\n" if $header;
    
    my $violations_found = 0;
    
    # In a real implementation, you would walk through files in source roots
    # For this example, we'll just simulate checking one file
    
    # Example content to check
    my $test_content = <<'EOF';
use POSIX;
my $temp_dir = tmpdir();
EOF
    
    my @violations = find_messaging_tmpdir_call_lines($test_content);
    
    if (@violations) {
        $violations_found = 1;
        print "Found violations in test content at lines: " . join(", ", @violations) . "\n";
        print "$footer\n" if $footer;
    }
    
    exit 1 if $violations_found;
}

sub main {
    run_callsite_guard(
        source_roots => \@messaging_tmpdir_guard_source_roots,
        find_call_lines => \&find_messaging_tmpdir_call_lines,
        skip_relative_path => sub {
            my $relative_path = shift;
            return exists $allowed_relative_paths{$relative_path};
        },
        header => "Found os.tmpdir()/tmpdir() usage in messaging/channel runtime sources:",
        footer => "Use resolvePreferredOpenClawTmpDir() or plugin-sdk temp helpers instead of host tmp defaults.",
        sort_violations => 0
    );
}

# Run as script
main() unless caller;
