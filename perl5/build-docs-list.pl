#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "35149e4001de83df961b89ce18a99ce31e08838993613c620d310c143931e9bb", "source_sha256": "a1805aea1655d2760f0aa6fe9d137718ec6b67c1eb8b7d25c2b93d461eea3215", "target_language": "perl5"}
# build-docs-list.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-docs-list.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use File::Basename;
use Cwd 'abs_path';

# Get the directory of this script
my $script_dir = dirname(abs_path($0));
my $root = dirname($script_dir);
my $binDir = File::Spec->catdir($root, "bin");
my $binPath = File::Spec->catfile($binDir, "docs-list");

# Create bin directory recursively
mkpath($binDir) unless -d $binDir;

# Wrapper content
my $wrapper = <<'EOF';
#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const script = path.join(here, "..", "scripts", "docs-list.js");

const result = spawnSync(process.execPath, [script], { stdio: "inherit" });
process.exit(result.status ?? 1);
EOF

# Write wrapper to file with executable permissions
open(my $fh, '>', $binPath) or die "Could not open file '$binPath' for writing: $!";
print $fh $wrapper;
close $fh;

chmod 0755, $binPath or die "Could not chmod '$binPath': $!";

# Helper function to mimic mkdirSync with recursive option
sub mkpath {
    my ($dir) = @_;
    require File::Path;
    File::Path::make_path($dir);
}
