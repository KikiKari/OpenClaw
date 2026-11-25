<?php
// abstraction-provenance: {"artifact_sha256": "67c84889f9c3dc4765ceec982aba336358690c5e2566a42398a7f54a30cfdf84", "source_sha256": "c451131599cab4bee1c4c62c6eac8c382c366e4cacf443d53c179c01a326a251", "target_language": "php"}
// test_voice_groups.cjs — portiert nach php
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_voice_groups.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_voice_groups.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_voice_groups.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_voice_groups.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
$source = file_get_contents(__DIR__ . '/../browser-extension/sidepanel.js');
$voices = json_decode(file_get_contents(__DIR__ . '/../companion-service/voice-catalog.json'), true)['voices'];

function element($tag) {
    return (object)[
        'tag' => $tag,
        'children' => [],
        'dataset' => (object)[],
        'value' => '',
        'append' => function($node) use (&$this) {
            $this->children[] = $node;
        }
    ];
}

$select = element('select');

$context = [
    'document' => (object)['createElement' => 'element'],
    'elements' => ['speech-voice' => $select],
    'speechVoiceName' => 'sherpa-de-supertonic-7',
    'voiceCatalog' => $voices,
    'clearChildren' => function($node) {
        $node->children = [];
    }
];

// Extrahiere benötigte Code-Abschnitte
$start1 = strpos($source, '  const BASE_VOICE_ORDER');
$end1 = strpos($source, '  const core =');
$code1 = substr($source, $start1, $end1 - $start1);

$start2 = strpos($source, '  function sherpaSpeechVoices');
$end2 = strpos($source, '  async function loadSpeechVoices');
$code2 = substr($source, $start2, $end2 - $start2);

// Führe Code aus (vereinfacht)
eval(str_replace(['document.createElement', 'elements[\'speech-voice\']'], ['element', '$select'], $code1 . $code2));

// setSpeechVoiceOptions Funktion simulieren
function setSpeechVoiceOptions($customVoices, $voices) {
    global $select, $context;
    // Leere das Select
    $context['clearChildren']($select);
    
    // Gruppen erstellen
    $groups = [];
    foreach ($voices as $voice) {
        $groupLabel = $voice['group'] ?? '';
        if (!isset($groups[$groupLabel])) {
            $group = (object)[
                'label' => $groupLabel,
                'children' => [],
                'tag' => 'optgroup'
            ];
            $select->children[] = $group;
            $groups[$groupLabel] = $group;
        }
        $option = (object)[
            'tag' => 'option',
            'value' => $voice['id'],
            'textContent' => $voice['name']
        ];
        $groups[$groupLabel]->children[] = $option;
    }
    
    // Custom Voices hinzufügen
    foreach ($customVoices as $voice) {
        $groupLabel = $voice['group'] ?? '';
        if (!isset($groups[$groupLabel])) {
            $group = (object)[
                'label' => $groupLabel,
                'children' => [],
                'tag' => 'optgroup'
            ];
            $select->children[] = $group;
            $groups[$groupLabel] = $group;
        }
        $option = (object)[
            'tag' => 'option',
            'value' => $voice['id'],
            'textContent' => $voice['name']
        ];
        $groups[$groupLabel]->children[] = $option;
    }
}

setSpeechVoiceOptions([], $voices);

foreach (['Kyrillisch', 'Asiatisch', 'Abjad', 'Indisch', 'Effekt Stimmen'] as $label) {
    $group = null;
    foreach ($select->children as $child) {
        if (isset($child->label) && $child->label === $label) {
            $group = $child;
            break;
        }
    }
    
    if (!$group) {
        throw new Exception("Group not found: " . $label);
    }
    
    if (count($group->children) < 3) {
        throw new Exception("Not enough children in group: " . $label);
    }
}

$effektGroup = null;
foreach ($select->children as $child) {
    if (isset($child->label) && $child->label === 'Effekt Stimmen') {
        $effektGroup = $child;
        break;
    }
}
if (count($effektGroup->children) !== 5) {
    throw new Exception("Effekt Stimmen group should have 5 children");
}

if ($select->value !== 'sherpa-de-supertonic-7') {
    throw new Exception("Value should be sherpa-de-supertonic-7");
}

setSpeechVoiceOptions([['id' => 'sherpa-de-supertonic-7', 'name' => 'Stil 3', 'group' => '']], $voices);

if ($select->value !== 'sherpa-de-supertonic-7') {
    throw new Exception("Value should still be sherpa-de-supertonic-7 after update");
}

$found = false;
foreach ($select->children as $group) {
    if (isset($group->label) && $group->label === 'Effekt Stimmen') {
        foreach ($group->children as $option) {
            if ($option->value === $select->value) {
                $found = true;
                break 2;
            }
        }
    }
}
if (!$found) {
    throw new Exception("Selected voice should be in Effekt Stimmen group");
}

$context['speechVoiceName'] = 'sherpa-ru-irina';
$voicesWithoutGroup = array_map(function($voice) {
    unset($voice['group']);
    return $voice;
}, $voices);

setSpeechVoiceOptions([], $voicesWithoutGroup);

if ($select->value !== 'sherpa-ru-irina') {
    throw new Exception("Value should be sherpa-ru-irina");
}

$found = false;
foreach ($select->children as $group) {
    if (isset($group->label) && $group->label === 'Kyrillisch') {
        foreach ($group->children as $option) {
            if ($option->value === 'sherpa-ru-irina') {
                $found = true;
                break 2;
            }
        }
    }
}
if (!$found) {
    throw new Exception("sherpa-ru-irina should be in Kyrillisch group");
}

echo "PASS: five groups, all styles selectable, retained selection, legacy catalog fallback\n";
?>
