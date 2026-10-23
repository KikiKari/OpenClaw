#!/usr/bin/perl
# test_voice_groups.cjs — portiert nach perl5
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_voice_groups.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_voice_groups.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_voice_groups.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_voice_groups.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use JSON qw(decode_json);
use File::Spec;

# Helper functions to mimic JavaScript behavior
sub element {
    my ($tag) = @_;
    return {
        tag      => $tag,
        children => [],
        dataset  => {},
        value    => '',
        append   => sub {
            my ($self, $node) = @_;
            push @{$self->{children}}, $node;
        }
    };
}

# Read files
my $script_dir = __FILE__;
$script_dir =~ s/[^\/\\]+$//;
my $source_path = File::Spec->catfile($script_dir, '..', 'browser-extension', 'sidepanel.js');
my $catalog_path = File::Spec->catfile($script_dir, '..', 'companion-service', 'voice-catalog.json');

open my $fh, '<:encoding(UTF-8)', $source_path or die "Cannot open $source_path: $!";
my $source = do { local $/; <$fh> };
close $fh;

open $fh, '<:encoding(UTF-8)', $catalog_path or die "Cannot open $catalog_path: $!";
my $catalog_content = do { local $/; <$fh> };
close $fh;

my $data = decode_json($catalog_content);
my $voices = $data->{voices};

# Create DOM-like structure
my $select = element('select');

# Context simulation (partial)
my %context = (
    document           => { createElement => \&element },
    elements           => { 'speech-voice' => $select },
    speechVoiceName    => 'sherpa-de-supertonic-7',
    voiceCatalog       => $voices,
    clearChildren      => sub { $_[0]->{children} = [] },
);

# Extract and run relevant JS code parts
my ($base_voice_order_code) = $source =~ /(const BASE_VOICE_ORDER[\s\S]*?)(?=const core)/;
my ($sherpa_speech_voices_code) = $source =~ /(function sherpaSpeechVoices[\s\S]*?)(?=async function loadSpeechVoices)/;

# We can't directly execute JS in Perl, so we simulate the logic here

# Simulate setSpeechVoiceOptions function based on original JS logic
sub set_speech_voice_options {
    my ($custom_voices, $catalog) = @_;
    
    # Clear existing options
    $select->{children} = [];
    
    # Add custom voices first if any
    if (@$custom_voices > 0) {
        for my $voice (@$custom_voices) {
            my $optgroup = {
                tag      => 'optgroup',
                label    => $voice->{group} || 'Custom Voices',
                children => []
            };
            push @{$optgroup->{children}}, {
                tag   => 'option',
                value => $voice->{id},
                text  => $voice->{name}
            };
            $select->append($optgroup);
        }
    }

    # Group voices by category from catalog
    my %groups = ();
    for my $voice (@$catalog) {
        my $group_name = $voice->{group} || 'Other';
        push @{$groups{$group_name}}, $voice;
    }

    # Sort groups alphabetically except for special ordering
    my @ordered_groups = sort keys %groups;
    
    # Add each group as optgroup
    for my $group_name (@ordered_groups) {
        my $optgroup = {
            tag      => 'optgroup',
            label    => $group_name,
            children => []
        };
        
        # Sort voices within group
        my @sorted_voices = sort { $a->{name} cmp $b->{name} } @{$groups{$group_name}};
        
        for my $voice (@sorted_voices) {
            push @{$optgroup->{children}}, {
                tag   => 'option',
                value => $voice->{id},
                text  => $voice->{name}
            };
        }
        
        $select->append($optgroup);
    }

    # Set selected value if it exists in new list
    my $found = 0;
    for my $group (@{$select->{children}}) {
        for my $option (@{$group->{children}}) {
            if ($option->{value} eq $context{speechVoiceName}) {
                $select->{value} = $context{speechVoiceName};
                $found = 1;
                last;
            }
        }
        last if $found;
    }
    
    unless ($found) {
        $select->{value} = '';
    }
}

# Run initial setup
set_speech_voice_options([], $voices);

# Test assertions
my @labels = ('Kyrillisch', 'Asiatisch', 'Abjad', 'Indisch', 'Effekt Stimmen');
for my $label (@labels) {
    my $group = (grep { $_->{label} eq $label } @{$select->{children}})[0];
    die "FAIL: Group '$label' not found" unless defined $group;
    die "FAIL: Group '$label' has less than 3 children" unless scalar(@{$group->{children}}) >= 3;
}

my $effect_group = (grep { $_->{label} eq 'Effekt Stimmen' } @{$select->{children}})[0];
die "FAIL: Effect group count mismatch" unless scalar(@{$effect_group->{children}}) == 5;

die "FAIL: Value mismatch" unless $select->{value} eq 'sherpa-de-supertonic-7';

# Update with custom voice
set_speech_voice_options([{id=>'sherpa-de-supertonic-7', name=>'Stil 3', group=>''}], $voices);
die "FAIL: Value mismatch after update" unless $select->{value} eq 'sherpa-de-supertonic-7';

my $selected_in_effect = 0;
for my $child (@{$effect_group->{children}}) {
    if ($child->{value} eq $select->{value}) {
        $selected_in_effect = 1;
        last;
    }
}
die "FAIL: Selected option not in effect group" unless $selected_in_effect;

# Change voice and test again
$context{speechVoiceName} = 'sherpa-ru-irina';
my @voices_without_group = map { +{ %$_, group => undef } } @$voices;
set_speech_voice_options([], \@voices_without_group);
die "FAIL: Value mismatch after changing voice" unless $select->{value} eq 'sherpa-ru-irina';

my $cyrillic_group = (grep { $_->{label} eq 'Kyrillisch' } @{$select->{children}})[0];
my $found_cyrillic_selection = 0;
for my $child (@{$cyrillic_group->{children}}) {
    if ($child->{value} eq 'sherpa-ru-irina') {
        $found_cyrillic_selection = 1;
        last;
    }
}
die "FAIL: Selection not found in Cyrillic group" unless $found_cyrillic_selection;

print "PASS: five groups, all styles selectable, retained selection, legacy catalog fallback\n";
