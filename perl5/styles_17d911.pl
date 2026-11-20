#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "3445825e42f5aaf2597fddf5db6823a7d811ed12b5759c60c842f962d65f8daa", "source_sha256": "17d9118c74c9951b6bd9c5e3475b496be57f796a591823384aa44dbdad5a115d", "target_language": "perl5"}
# styles.css — portiert nach perl5
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles.css
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

# CSS Document Generator
# This script generates a CSS file with imported stylesheets and custom properties

sub generate_css {
    my ($output_file) = @_;
    
    # Define the imports array
    my @imports = (
        './styles/base.css',
        './styles/layout.css',
        './styles/layout.mobile.css',
        './styles/components.css',
        './styles/chat.css',
        './styles/config.css',
        './styles/usage.css',
        './styles/dreams.css',
        '@create-markdown/preview/themes/system.css'
    );
    
    # Open file for writing
    open(my $fh, '>', $output_file) or die "Could not open file '$output_file' $!";
    
    # Write imports
    for my $import (@imports) {
        print $fh '@import "' . $import . "\";\n";
    }
    
    # Write empty line for separation
    print $fh "\n";
    
    # Write CSS rule for cm-preview
    print $fh ".cm-preview {\n";
    print $fh "  --cm-mono: var(--mono);\n";
    print $fh "  --cm-link: var(--accent);\n";
    print $fh "  --cm-info: var(--info);\n";
    print $fh "  --cm-warning: var(--warn);\n";
    print $fh "  --cm-success: var(--ok);\n";
    print $fh "  --cm-danger: var(--danger);\n";
    print $fh "}\n";
    
    close($fh);
}

# Main execution
if (@ARGV != 1) {
    die "Usage: $0 <output_file>\n";
}

generate_css($ARGV[0]);
print "CSS file generated: $ARGV[0]\n";
