#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "3919286f18b2b35952a2b84d741fd218bf3d470f3a6521e94a4c7ba97691e3a1", "source_sha256": "d8cfbb58894cc82e4e8ba7def8f5bcc6b6c011986e853dba0f1c96ca81a4b49e", "target_language": "perl5"}
# docs-list.js — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-list.js
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Find;
use File::Spec;
use Cwd 'getcwd';

# Handle broken pipe gracefully like in Node.js version
$SIG{PIPE} = sub { exit 0 };

my $DOCS_DIR = File::Spec->catdir(getcwd(), 'docs');

unless (-d $DOCS_DIR) {
    if (!-e $DOCS_DIR) {
        print STDERR "docs:list: missing docs directory. Run from repo root.\n";
    } else {
        print STDERR "docs:list: docs path is not a directory.\n";
    }
    exit 1;
}

my %EXCLUDED_DIRS = map { $_ => 1 } qw(archive research);

# Function to filter out empty/undefined values and trim strings
sub compact_strings {
    my @values = @_;
    my @result;
    for my $value (@values) {
        next unless defined $value;
        my $normalized;
        if (ref($value) eq '') {  # string
            $normalized = $value;
            $normalized =~ s/^\s+|\s+$//g;
        } elsif (ref($value) eq 'SCALAR' || ref($value) eq 'REF') {
            # Handle scalar refs if needed, but typically not used here
            $normalized = "$value";
            $normalized =~ s/^\s+|\s+$//g;
        } else {
            $normalized = "$value";
            $normalized =~ s/^\s+|\s+$//g;
        }
        push @result, $normalized if length($normalized) > 0;
    }
    return @result;
}

# Walk through directories recursively to find markdown files
sub walk_markdown_files {
    my ($dir, $base) = @_;
    $base //= $dir;
    my @files;
    
    find(sub {
        return if /^\./;  # skip hidden files/dirs
        
        my $full_path = $File::Find::name;
        my $rel_path = File::Spec->abs2rel($full_path, $base);
        
        if (-d $_) {
            if ($EXCLUDED_DIRS{$_}) {
                $File::Find::prune = 1;  # don't recurse into this dir
                return;
            }
        } elsif (-f $_ && /\.md$/) {
            push @files, $rel_path;
        }
    }, $dir);
    
    @files = sort @files;
    return @files;
}

# Extract metadata from markdown file's front matter
sub extract_metadata {
    my ($full_path) = @_;
    open my $fh, '<:encoding(UTF-8)', $full_path or die "Cannot open $full_path: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    
    unless ($content =~ /^---/) {
        return { summary => undef, read_when => [], error => 'missing front matter' };
    }
    
    my ($front_matter) = $content =~ /^---\n(.*?)\n---/s;
    unless (defined $front_matter) {
        return { summary => undef, read_when => [], error => 'unterminated front matter' };
    }
    
    my @lines = split /\n/, $front_matter;
    my $summary_line;
    my @read_when;
    my $collecting_field;
    
    for my $raw_line (@lines) {
        my $line = $raw_line;
        $line =~ s/^\s+|\s+$//g;
        
        if ($line =~ /^summary:/) {
            $summary_line = $line;
            $collecting_field = undef;
            next;
        }
        
        if ($line =~ /^read_when:/) {
            $collecting_field = 'read_when';
            my $inline = $line;
            $inline =~ s/^read_when:\s*//;
            
            if ($inline =~ /^\[.*\]$/) {
                # Try to parse inline array
                $inline =~ s/'/"/g;
                eval {
                    # Simple parsing attempt - in real case might need JSON module
                    if ($inline =~ /^\["(.+)"\]$/) {
                        my @items = split /",\s*"/, $1;
                        push @read_when, compact_strings(@items);
                    } elsif ($inline eq '[]') {
                        # Empty array
                    } else {
                        warn "Could not parse inline array: $inline\n";
                    }
                };
            }
            next;
        }
        
        if ($collecting_field eq 'read_when') {
            if ($line =~ /^-\s+(.+)$/) {
                my $hint = $1;
                $hint =~ s/^\s+|\s+$//g;
                push @read_when, $hint if $hint;
            } elsif ($line eq '') {
                # Allow blank lines inside the list
            } else {
                $collecting_field = undef;
            }
        }
    }
    
    unless (defined $summary_line) {
        return { summary => undef, read_when => \@read_when, error => 'summary key missing' };
    }
    
    my $summary_value = $summary_line;
    $summary_value =~ s/^summary:\s*//;
    $summary_value =~ s/^['"]|['"]$//g;
    $summary_value =~ s/\s+/ /g;
    $summary_value =~ s/^\s+|\s+$//g;
    
    unless (length($summary_value) > 0) {
        return { summary => undef, read_when => \@read_when, error => 'summary is empty' };
    }
    
    return { summary => $summary_value, read_when => \@read_when };
}

print "Listing all markdown files in docs folder:\n";

my @markdown_files = walk_markdown_files($DOCS_DIR);

for my $relative_path (@markdown_files) {
    my $full_path = File::Spec->catfile($DOCS_DIR, $relative_path);
    my $metadata = extract_metadata($full_path);
    my $summary = $metadata->{summary};
    my $read_when = $metadata->{read_when};
    my $error = $metadata->{error};
    
    if ($summary) {
        print "$relative_path - $summary\n";
        if (@$read_when > 0) {
            print "  Read when: " . join("; ", @$read_when) . "\n";
        }
    } else {
        my $reason = $error ? " - [$error]" : "";
        print "$relative_path$reason\n";
    }
}

print <<'EOF';

Reminder: keep docs up to date as behavior changes. When your task matches any "Read when" hint above (React hooks, cache directives, database work, tests, etc.), read that doc before coding, and suggest new coverage when it is missing.
EOF
