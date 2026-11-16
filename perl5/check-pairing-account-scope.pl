#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "26dc2a6a0a34c58203c12ecdcdb840be2536f798a54bd8b8c83bbccbd5bebb0e", "source_sha256": "03602fb41765aad7878e52af85d1c4c5a8d1d8a752b53a46602deb38e8783f73", "target_language": "perl5"}
# check-pairing-account-scope.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-pairing-account-scope.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use Cwd 'abs_path';
use lib '.';
require "./lib/pairing-guard-context.pl";
require "./lib/ts-guard-utils.pl";

my ($repoRoot, @sourceRoots) = createPairingGuardContext(__FILE__);

sub isUndefinedLikeExpression {
    my ($node) = @_;
    if ($node->{kind} eq 'Identifier' && $node->{text} eq 'undefined') {
        return 1;
    }
    return $node->{kind} eq 'NullKeyword';
}

sub hasRequiredAccountIdProperty {
    my ($node) = @_;
    return 0 unless $node->{kind} eq 'ObjectLiteralExpression';
    for my $property (@{$node->{properties}}) {
        if ($property->{kind} eq 'ShorthandPropertyAssignment' && $property->{name}{text} eq 'accountId') {
            return 1;
        }
        next unless $property->{kind} eq 'PropertyAssignment';
        next unless getPropertyNameText($property->{name}) eq 'accountId';
        return 0 if isUndefinedLikeExpression($property->{initializer});
        return 1;
    }
    return 0;
}

sub findViolations {
    my ($content, $filePath) = @_;
    my $sourceFile = createSourceFile($filePath, $content);
    my @violations = ();

    my $visit;
    $visit = sub {
        my ($node) = @_;
        if ($node->{kind} eq 'CallExpression' && $node->{expression}{kind} eq 'Identifier') {
            my $callName = $node->{expression}{text};
            if ($callName eq 'readChannelAllowFromStore') {
                if (@{$node->{arguments}} < 3 || isUndefinedLikeExpression($node->{arguments}[2])) {
                    push @violations, {
                        line => toLine($sourceFile, $node),
                        reason => 'readChannelAllowFromStore call must pass explicit accountId as 3rd arg',
                    };
                }
            } elsif ($callName eq 'readLegacyChannelAllowFromStore' || $callName eq 'readLegacyChannelAllowFromStoreSync') {
                push @violations, {
                    line => toLine($sourceFile, $node),
                    reason => "${callName} is legacy-only; use account-scoped readChannelAllowFromStore* APIs",
                };
            } elsif ($callName eq 'upsertChannelPairingRequest') {
                my $firstArg = $node->{arguments}[0];
                unless ($firstArg && hasRequiredAccountIdProperty($firstArg)) {
                    push @violations, {
                        line => toLine($sourceFile, $node),
                        reason => 'upsertChannelPairingRequest call must include accountId in params',
                    };
                }
            }
        }
        forEachChild($node, $visit);
    };

    $visit->($sourceFile);
    return @violations;
}

sub main {
    my @violations = collectFileViolations({
        sourceRoots => \@sourceRoots,
        repoRoot => $repoRoot,
        findViolations => \&findViolations,
    });

    return if @violations == 0;

    print STDERR "Found unscoped pairing-store calls:\n";
    for my $violation (@violations) {
        print STDERR "- $violation->{path}:$violation->{line} ($violation->{reason})\n";
    }
    exit 1;
}

runAsScript(__FILE__, \&main);
