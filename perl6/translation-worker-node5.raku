#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "8ce12f3c9e984185f845dd52ee2631eca3873f4d746d1864f3186c255859b930", "source_sha256": "e31da3d72f8d806a159d6709f37f55500c7f16939f04c094f2ab46a959e70c57", "target_language": "perl6"}
# translation-worker-node5.ps1 — portiert nach perl6
# Quelle: powershell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node5.ps1
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

use MONKEY-SEE-NO-EVAL;

subset Action of Str where * eq any <prepare run>;

sub MAIN(Action $action) {
    # Error handling: die will stop execution like 'Stop' in PowerShell
    
    # Define paths and expected values
    my $worker = "$*HOME/.openclaw/workers/translation_worker.py";
    my $expected = '9f8e810dd49f30fbc05064a98faf280d1f2480fdb8f125115ad006d486cd555b';
    
    # Check if worker file exists (equivalent to Test-Path -Leaf)
    unless $worker.IO.e && $worker.IO.f {
        die "Worker missing: $worker";
    }
    
    # Check for reparse point (symbolic link) - Raku doesn't have direct attribute access,
    # but we can check if it's a symlink
    if $worker.IO.l {
        die 'Worker link rejected';
    }
    
    # Calculate SHA256 hash of the file
    my $hash = run(<sha256sum>, $worker, :out).out.slurp.chomp.split(' ')[0];
    if $hash ne $expected {
        die 'Worker checksum mismatch';
    }
    
    # Find python executable
    my $python = run(<which python>, :out).out.slurp.chomp;
    unless $python {
        die "Python executable not found";
    }
    
    # Handle prepare action
    if $action eq 'prepare' {
        say "Worker verified: $worker";
        exit 0;
    }
    
    # Run the worker script
    my $proc = run($python, $worker);
    exit $proc.exitcode;
}
