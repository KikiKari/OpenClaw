#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "a6ec7d44a236fed412f5d8bac3001bd1a29b4e0fee91aa08a335c41245b3a496", "source_sha256": "646ce6bf1521c1200f2204aa19a05521f8f53d734ec8c000b61f4290f2a05074", "target_language": "perl5"}
# changelog.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/changelog.sh
# Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Slurp qw(read_file write_file);

sub normalize_pr_changelog_entries {
    my ($pr) = @_;
    my $changelog_path = "CHANGELOG.md";

    return 0 unless -f $changelog_path;

    $ENV{PR_NUMBER_FOR_CHANGELOG} = $pr;
    my $original = read_file($changelog_path);
    chomp(my @lines = split(/\n/, $original));
    my $pr_pattern = qr/(?:\(#$pr\)|openclaw#$pr)/i;

    sub find_active_section_index {
        my @arr = @_;
        for my $i (0 .. $#arr) {
            return $i if $arr[$i] =~ /^## Unreleased\s*$/;
        }
        return -1;
    }

    sub find_section_end {
        my ($arr_ref, $start) = @_;
        for my $i (($start + 1) .. $#{$arr_ref}) {
            return $i if $arr_ref->[$i] =~ /^## /;
        }
        return scalar(@{$arr_ref});
    }

    sub ensure_active_section {
        my @arr = @_;
        my $active_index = find_active_section_index(@arr);
        return $active_index if $active_index != -1;

        my $insert_at = -1;
        for my $i (1 .. $#arr) {
            if ($arr[$i] =~ /^## /) {
                $insert_at = $i;
                last;
            }
        }
        $insert_at = @arr if $insert_at == -1;

        my @block = ("## Unreleased", "", "### Changes", "");
        unshift @block, "" if $insert_at > 0 && $arr[$insert_at - 1] ne "";

        splice(@arr, $insert_at, 0, @block);
        return find_active_section_index(@arr);
    }

    sub context_for {
        my ($arr_ref, $index) = @_;
        my ($major, $minor) = ("", "");
        for my $i (reverse(0 .. $index)) {
            my $line = $arr_ref->[$i];
            $minor = $line if !$minor && $line =~ /^### /;
            if ($line =~ /^## /) {
                $major = $line;
                last;
            }
        }
        return { major => $major, minor => $minor };
    }

    sub ensure_subsection {
        my ($arr_ref, $subsection) = @_;
        my $active_index = ensure_active_section(@$arr_ref);
        my $active_end = find_section_end($arr_ref, $active_index);
        my $desired = ($subsection && $subsection =~ /^### /) ? $subsection : "### Changes";

        for my $i (($active_index + 1) .. ($active_end - 1)) {
            return $i if $arr_ref->[$i] eq $desired;
        }

        my $insert_at = $active_end;
        while ($insert_at > $active_index + 1 && $arr_ref->[$insert_at - 1] eq "") {
            $insert_at--;
        }
        splice(@$arr_ref, $insert_at, 0, "", $desired, "");
        return $insert_at + 1;
    }

    sub section_tail_insert_index {
        my ($arr_ref, $subsection_index) = @_;
        my $next_heading = @$arr_ref;
        for my $i (($subsection_index + 1) .. $#{$arr_ref}) {
            if ($arr_ref->[$i] =~ /^### / || $arr_ref->[$i] =~ /^## /) {
                $next_heading = $i;
                last;
            }
        }

        my $insert_at = $next_heading;
        while ($insert_at > $subsection_index + 1 && $arr_ref->[$insert_at - 1] eq "") {
            $insert_at--;
        }
        return $insert_at;
    }

    ensure_active_section(@lines);

    my @moved;
    for my $i (0 .. $#lines) {
        next unless $lines[$i] =~ /$pr_pattern/;
        my $ctx = context_for(\@lines, $i);
        next if $ctx->{major} eq "## Unreleased";
        push @moved, {
            line => $lines[$i],
            subsection => $ctx->{minor} || "### Changes",
            index => $i
        };
    }

    exit(0) if @moved == 0;

    my %remove_indexes = map { $_->{index} => 1 } @moved;
    my @next_lines = grep { !$remove_indexes{$_} } @lines;

    for my $entry (@moved) {
        my $subsection_index = ensure_subsection(\@next_lines, $entry->{subsection});
        my $insert_at = section_tail_insert_index(\@next_lines, $subsection_index);

        my $next_heading = @next_lines;
        for my $i (($subsection_index + 1) .. $#next_lines) {
            if ($next_lines[$i] =~ /^### / || $next_lines[$i] =~ /^## /) {
                $next_heading = $i;
                last;
            }
        }

        my $already_present = 0;
        for my $j (($subsection_index + 1) .. ($next_heading - 1)) {
            if ($next_lines[$j] eq $entry->{line}) {
                $already_present = 1;
                last;
            }
        }
        next if $already_present;

        splice(@next_lines, $insert_at, 0, $entry->{line});
    }

    my $updated = join("\n", @next_lines) . "\n";
    if ($updated ne $original) {
        write_file($changelog_path, $updated);
    }
}

sub validate_changelog_entry_for_pr {
    my ($pr, $contrib) = @_;

    open(my $fh, '-|', 'git diff --unified=0 origin/main...HEAD -- CHANGELOG.md') or die "git diff failed: $!";
    my @diff_lines = <$fh>;
    close($fh);

    my @added_lines = map { s/^\+//r } grep { /^\+/ && !/^\+\+\+/ } @diff_lines;
    if (@added_lines == 0) {
        print "CHANGELOG.md is in diff but no added lines were detected.\n";
        exit 1;
    }

    my $pr_pattern = "(#$pr|openclaw#$pr)";
    my @with_pr = grep { /$pr_pattern/i } @added_lines;
    if (@with_pr == 0) {
        print "CHANGELOG.md update must reference PR #$pr (for example, (#$pr)).\n";
        exit 1;
    }

    my $tmpfile = "/tmp/changelog_diff.$$";
    open($fh, '>', $tmpfile) or die "Cannot create temp file: $!";
    print $fh @diff_lines;
    close($fh);

    open($fh, '-|', "awk -v pr_pattern='$pr_pattern' 'BEGIN { line_no = 0; file_line_count = 0; issue_count = 0 } FNR == NR { if (\$0 ~ /^@@ /) { if (match(\$0, /\\\\+[0-9]+/)) { line_no = substr(\$0, RSTART + 1, RLENGTH - 1) + 0 } else { line_no = 0 } next } if (\$0 ~ /^\\\\+\\\\+/) { next } if (\$0 ~ /^\\\\+/) { if (line_no > 0) { added[line_no] = 1; added_text = substr(\$0, 2); if (added_text ~ pr_pattern) { pr_added_lines[++pr_added_count] = line_no; pr_added_text[line_no] = added_text } line_no++ } next } if (\$0 ~ /^-/) { next } if (line_no > 0) { line_no++ } next } { changelog[FNR] = \$0; file_line_count = FNR } END { for (idx = 1; idx <= pr_added_count; idx++) { entry_line = pr_added_lines[idx]; release_line = 0; section_line = 0; for (i = entry_line; i >= 1; i--) { if (section_line == 0 && changelog[i] ~ /^### /) { section_line = i; continue } if (changelog[i] ~ /^## /) { release_line = i; break } } if (release_line == 0 || changelog[release_line] != \"## Unreleased\") { printf \"CHANGELOG.md PR-linked entry must be in ## Unreleased: line %d: %s\\\\n\", entry_line, pr_added_text[entry_line]; issue_count++; continue } if (section_line == 0) { printf \"CHANGELOG.md entry must be inside a subsection (### ...): line %d: %s\\\\n\", entry_line, pr_added_text[entry_line]; issue_count++; continue } section_name = changelog[section_line]; next_heading = file_line_count + 1; for (i = entry_line + 1; i <= file_line_count; i++) { if (changelog[i] ~ /^### / || changelog[i] ~ /^## /) { next_heading = i; break } } for (i = entry_line + 1; i < next_heading; i++) { line_text = changelog[i]; if (line_text ~ /^[[:space:]]*\$/) { continue } if (i in added) { continue } printf \"CHANGELOG.md PR-linked entry must be appended at the end of section %s: line %d: %s\\\\n\", section_name, entry_line, pr_added_text[entry_line]; printf \"Found existing non-added line below it at line %d: %s\\\\n\", i, line_text; issue_count++; break } } if (issue_count > 0) { print \"Move this PR changelog entry to the end of its section (just before the next heading).\"; exit 1 } }' '$tmpfile' CHANGELOG.md") or die "awk failed: $!";
    my @awk_output = <$fh>;
    close($fh);
    unlink($tmpfile);

    if (@awk_output) {
        print @awk_output;
        exit 1;
    }

    print "changelog placement validated: PR-linked entries are appended at section tail\n";

    if (defined $contrib && $contrib ne "" && $contrib ne "null") {
        my @with_pr_and_thanks = grep { /$pr_pattern/i && /thanks \@$contrib/i } @added_lines;
        if (@with_pr_and_thanks == 0) {
            print "CHANGELOG.md update must include both PR #$pr and thanks \@$contrib on the changelog entry line.\n";
            exit 1;
        }
        print "changelog validated: found PR #$pr + thanks \@$contrib\n";
        return 0;
    }

    print "changelog validated: found PR #$pr (contributor handle unavailable, skipping thanks check)\n";
    return 0;
}

sub validate_changelog_merge_hygiene {
    open(my $fh, '-|', 'git diff --unified=0 origin/main...HEAD -- CHANGELOG.md') or die "git diff failed: $!";
    my @diff_lines = <$fh>;
    close($fh);

    my @removed_lines = map { s/^-//r } grep { /^-/ && !/^- ---/ } @diff_lines;
    return 0 if @removed_lines == 0;

    my @removed_refs;
    for my $line (@removed_lines) {
        push @removed_refs, $1 while $line =~ /#([0-9]+)/g;
    }
    my %unique_removed_refs = map { $_ => 1 } @removed_refs;
    @removed_refs = keys %unique_removed_refs;
    return 0 if @removed_refs == 0;

    my @added_lines = map { s/^\+//r } grep { /^\+/ && !/^\+\+\+/ } @diff_lines;

    for my $ref (@removed_refs) {
        my $found = 0;
        for my $line (@added_lines) {
            if ($line =~ /#$ref\b/) {
                $found = 1;
                last;
            }
        }
        if (!$found) {
            print "CHANGELOG.md drops existing entry reference #$ref without re-adding it.\n";
            print "Likely merge conflict loss; restore the dropped entry (or keep the same PR ref in rewritten text).\n";
            exit 1;
        }
    }

    print "changelog merge hygiene validated: no dropped PR references\n";
}

# Main execution would go here if needed
# For now, these are just library functions that can be called from other Perl scripts
