#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "85e49fa9fc086e65be2400f55a361ab459c8f69aaab238e981bea332213879dc", "source_sha256": "635ed6e934aa27ffc7ad156af00126e0797ae1d1c065daddb996e2bddc8cbeb3", "target_language": "perl5"}
# index.html — portiert nach perl5
# Quelle: html, workspace@local:skills/github-clones/openclaw/extensions/qa-lab/web/index.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

# Function to generate the HTML document
sub generate_html {
    my $html = <<'EOF';
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="color-scheme" content="light dark" />
    <title>QA Lab</title>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>
EOF
    return $html;
}

# Main execution
sub main {
    my $filename = $ARGV[0] || 'index.html';
    
    # Generate the HTML content
    my $content = generate_html();
    
    # Write to file
    open(my $fh, '>', $filename) or die "Could not open file '$filename': $!";
    print $fh $content;
    close($fh);
    
    print "HTML document written to $filename\n";
}

# Run main function
main() if $0 eq __FILE__;
