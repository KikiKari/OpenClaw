#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "a5bf1bfdd13fb79a9c932267d38ac05a907ad3af9e3af8c6af4f2e426681580d", "source_sha256": "13f974bf78b140bc88bd9f3afe27c500660ef59498ed533c38c18bca0c6f6331", "target_language": "perl5"}
# changelog-to-html.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/changelog-to-html.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Basename;
use Cwd qw(abs_path);

my $VERSION = $ARGV[0] // '';
my $CHANGELOG_FILE = $ARGV[1] // '';

if (!$VERSION) {
    print STDERR "Usage: $0 <version> [changelog_file]\n";
    exit 1;
}

my $script_dir = dirname(abs_path($0));
if (!$CHANGELOG_FILE) {
    if (-f "$script_dir/../CHANGELOG.md") {
        $CHANGELOG_FILE = "$script_dir/../CHANGELOG.md";
    } elsif (-f "CHANGELOG.md") {
        $CHANGELOG_FILE = "CHANGELOG.md";
    } elsif (-f "../CHANGELOG.md") {
        $CHANGELOG_FILE = "../CHANGELOG.md";
    } else {
        print STDERR "Error: Could not find CHANGELOG.md\n";
        exit 1;
    }
}

if (!-f $CHANGELOG_FILE) {
    print STDERR "Error: Changelog file '$CHANGELOG_FILE' not found\n";
    exit 1;
}

sub extract_version_section {
    my ($version, $file) = @_;
    open my $fh, '<', $file or die "Cannot open $file: $!";
    my @lines = <$fh>;
    close $fh;

    my $found = 0;
    my @result = ();
    for my $line (@lines) {
        chomp $line;
        if ($line =~ /^## /) {
            if ($line =~ /^##\s+$version(\s.*|$)/) {
                $found = 1;
                next;
            }
            if ($found) {
                last;
            }
        }
        if ($found) {
            push @result, $line;
        }
    }
    return join("\n", @result);
}

sub markdown_to_html {
    my ($text) = @_;
    $text =~ s/^##### (.*)$/$1/;
    $text = "<h5>$text<\/h5>" if $text =~ /^##### /;
    $text =~ s/^#### (.*)$/$1/;
    $text = "<h4>$text<\/h4>" if $text =~ /^#### /;
    $text =~ s/^### (.*)$/$1/;
    $text = "<h3>$text<\/h3>" if $text =~ /^### /;
    $text =~ s/^## (.*)$/$1/;
    $text = "<h2>$text<\/h2>" if $text =~ /^## /;
    $text =~ s/^- \*\*([^*]*)\*\*(.*)$/\1\2/;
    $text = "<li><strong>$text<\/strong><\/li>" if $text =~ /^- \*\*[^*]*\*\*/;
    $text =~ s/^- ([^*].*)$/$1/;
    $text = "<li>$text<\/li>" if $text =~ /^- [^*]/;
    $text =~ s/\*\*([^*]*)\*\*/<strong>$1<\/strong>/g;
    $text =~ s/`([^`]*)`/<code>$1<\/code>/g;
    $text =~ s/\[([^\]]*)\]\(([^)]*)\)/<a href="$2">$1<\/a>/g;
    return $text;
}

my $version_content = extract_version_section($VERSION, $CHANGELOG_FILE);
if (!$version_content) {
    print "<h2>OpenClaw $VERSION<\/h2>\n";
    print "<p>Latest OpenClaw update.<\/p>\n";
    print "<p><a href=\"https:\/\/github.com\/openclaw\/openclaw\/blob\/main\/CHANGELOG.md\">View full changelog<\/a><\/p>\n";
    exit 0;
}

print "<h2>OpenClaw $VERSION<\/h2>\n";

my $in_list = 0;
for my $line (split /\n/, $version_content) {
    if ($line =~ /^-/) {
        if (!$in_list) {
            print "<ul>\n";
            $in_list = 1;
        }
        print markdown_to_html($line) . "\n";
    } else {
        if ($in_list) {
            print "<\/ul>\n";
            $in_list = 0;
        }
        if ($line ne '') {
            print markdown_to_html($line) . "\n";
        }
    }
}

if ($in_list) {
    print "<\/ul>\n";
}

print "<p><a href=\"https:\/\/github.com\/openclaw\/openclaw\/blob\/main\/CHANGELOG.md\">View full changelog<\/a><\/p>\n";
