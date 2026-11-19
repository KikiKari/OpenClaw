#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "be348007c6114fc74fa049c5ebeb4403e185dd62c0b7e2989b5791c3c1d98970", "source_sha256": "e3bab1624f203b949716145357872ec8001a11d44b45121002215386ca7164b3", "target_language": "perl5"}
# style.css — portiert nach perl5
# Quelle: css, workspace@local:skills/github-clones/openclaw/docs/style.css
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

# Function to generate the CSS content
sub generate_css {
    return <<'CSS';
#content > h1:first-of-type {
  display: none !important;
}

.nav-tabs {
  position: relative;
}

.nav-tabs-item > div {
  opacity: 0;
}

.nav-tabs-underline {
  position: absolute;
  left: 0;
  bottom: 0;
  height: 1.5px;
  width: var(--nav-tab-underline-width, 0);
  transform: translateX(var(--nav-tab-underline-x, 0));
  background-color: rgb(var(--primary));
  border-radius: 999px;
  pointer-events: none;
  opacity: 0;
  transition:
    transform 260ms ease-in-out,
    width 260ms ease-in-out,
    opacity 160ms ease-in-out;
  will-change: transform, width;
}

html.dark .nav-tabs-underline {
  background-color: rgb(var(--primary-light));
}

.nav-tabs-underline-ready .nav-tabs-underline {
  opacity: 1;
}
CSS
}

# Main function to write CSS to a file
sub main {
    my $filename = shift @ARGV || 'style.css';
    
    open(my $fh, '>', $filename) or die "Could not open file '$filename': $!";
    print $fh generate_css();
    close($fh);
    
    print "CSS file generated: $filename\n";
}

main();
