#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "d17c98a09de68c3142d22a466ab71a8ccb3c8a8e8d3ee18384e65c6e44aae335", "source_sha256": "cfa6fdcce252a97fa8be4d621d55955657d2f6616d52330d880db2123e1db43b", "target_language": "perl5"}
# check-ingress-agent-owner-context.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-ingress-agent-owner-context.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use File::Find;
use Cwd 'abs_path';

# Simulating the module imports and constants
my @sourceRoots = (
    "src/gateway",
    bundledPluginFile("discord", "src/voice")
);

my %enforcedFiles = map { $_ => 1 } (
    bundledPluginFile("discord", "src/voice/manager.ts"),
    "src/gateway/openai-http.ts",
    "src/gateway/openresponses-http.ts",
    "src/gateway/server-methods/agent.ts",
    "src/gateway/server-node-events.ts"
);

sub bundledPluginFile {
    my ($plugin, $path) = @_;
    return "plugins/$plugin/$path";
}

# Function to find legacy agent command call lines
sub findLegacyAgentCommandCallLines {
    my ($content, $fileName) = @_;
    $fileName //= "source.ts";
    
    # This is a simplified version - actual TypeScript AST parsing would require
    # a more complex implementation or external tools
    my @lines;
    my $lineNumber = 0;
    for my $line (split /\n/, $content) {
        $lineNumber++;
        if ($line =~ /agentCommand\s*\(/) {
            push @lines, $lineNumber;
        }
    }
    return @lines;
}

# Function to run callsite guard (simplified version)
sub runCallsiteGuard {
    my (%args) = @_;
    
    my $sourceRoots = $args{sourceRoots};
    my $findCallLines = $args{findCallLines};
    my $skipRelativePath = $args{skipRelativePath};
    my $header = $args{header};
    my $footer = $args{footer};
    
    print "$header\n" if $header;
    
    my @violations;
    
    for my $root (@$sourceRoots) {
        find(sub {
            return unless /\.ts$/;
            my $filePath = $File::Find::name;
            my $relativePath = File::Spec->abs2rel($filePath, $root);
            $relativePath =~ s!\\!/!g; # Normalize path separators
            
            return if $skipRelativePath->($relativePath);
            
            open my $fh, '<', $filePath or die "Cannot open $filePath: $!";
            my $content = do { local $/; <$fh> };
            close $fh;
            
            my @lines = $findCallLines->($content, $filePath);
            if (@lines) {
                push @violations, { file => $filePath, lines => \@lines };
            }
        }, $root);
    }
    
    if (@violations) {
        for my $violation (@violations) {
            print "File: $violation->{file}\n";
            print "  Lines: " . join(', ', @{$violation->{lines}}) . "\n";
        }
        print "\n$footer\n" if $footer;
        exit 1;
    }
}

# Main execution
sub main {
    runCallsiteGuard(
        sourceRoots => \@sourceRoots,
        findCallLines => \&findLegacyAgentCommandCallLines,
        skipRelativePath => sub {
            my $relPath = shift;
            return !$enforcedFiles{$relPath};
        },
        header => "Found ingress callsites using local agentCommand() (must be explicit owner-aware):",
        footer => "Use agentCommandFromIngress(...) and pass senderIsOwner explicitly at ingress boundaries."
    );
}

# Run as script
if (!$ENV{LOADED_AS_MODULE}) {
    main();
}

1;
