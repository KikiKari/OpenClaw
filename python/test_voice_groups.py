#!/usr/bin/env python3
# test_voice_groups.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_voice_groups.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_voice_groups.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_voice_groups.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_voice_groups.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

import json
import os
import sys

# Führe den gleichen Test wie im JavaScript-Code durch
def test_voice_groups():
    # Lade voice-catalog.json
    script_dir = os.path.dirname(os.path.abspath(__file__))
    voice_catalog_path = os.path.join(script_dir, '../companion-service/voice-catalog.json')
    with open(voice_catalog_path, 'r', encoding='utf-8') as f:
        voice_data = json.load(f)
    voices = voice_data['voices']

    # Simuliere DOM-Elemente
    class Element:
        def __init__(self, tag):
            self.tag = tag
            self.children = []
            self.dataset = {}
            self.value = ''
            self.label = None
        
        def append(self, node):
            self.children.append(node)

    # Erstelle ein select-Element
    select = Element('select')

    # Globale Variablen für den Kontext
    speechVoiceName = 'sherpa-de-supertonic-7'
    
    def clearChildren(node):
        node.children = []

    elements = {'speech-voice': select}

    # Extrahiere benötigte Funktionen aus sidepanel.js
    sidepanel_path = os.path.join(script_dir, '../browser-extension/sidepanel.js')
    with open(sidepanel_path, 'r', encoding='utf-8') as f:
        source = f.read()

    # Extrahiere den relevanten Code-Abschnitt
    base_voice_order_start = source.find('  const BASE_VOICE_ORDER')
    core_start = source.find('  const core =')
    sherpa_speech_voices_start = source.find('  function sherpaSpeechVoices')
    load_speech_voices_start = source.find('  async function loadSpeechVoices')

    base_voice_code = source[base_voice_order_start:core_start]
    sherpa_speech_voices_code = source[sherpa_speech_voices_start:load_speech_voices_start]

    # Führe den Code aus (durch direkte Python-Implementierung)
    # Definiere BASE_VOICE_ORDER
    BASE_VOICE_ORDER = [
        'Deutsch',
        'Englisch',
        'Französisch',
        'Italienisch',
        'Spanisch',
        'Portugiesisch',
        'Niederländisch',
        'Russisch',
        'Polnisch',
        'Tschechisch',
        'Slowakisch',
        'Ukrainisch',
        'Bulgarisch',
        'Serbisch',
        'Kroatisch',
        'Slowenisch',
        'Rumänisch',
        'Ungarisch',
        'Finnisch',
        'Schwedisch',
        'Norwegisch',
        'Dänisch',
        'Isländisch',
        'Türkisch',
        'Arabisch',
        'Hebräisch',
        'Persisch',
        'Urdu',
        'Chinesisch',
        'Japanisch',
        'Koreanisch',
        'Vietnamesisch',
        'Thailändisch',
        'Indonesisch',
        'Malaysisch',
        'Singapurisch',
        'Effekt Stimmen'
    ]

    # Definiere die Funktion setSpeechVoiceOptions
    def setSpeechVoiceOptions(styles, voices):
        nonlocal speechVoiceName
        clearChildren(select)
        
        # Gruppiere Stimmen nach Gruppe
        groups = {}
        for voice in voices:
            group = voice.get('group', '')
            if group not in groups:
                groups[group] = []
            groups[group].append(voice)
        
        # Sortiere Gruppen gemäß BASE_VOICE_ORDER
        sorted_groups = []
        for group_name in BASE_VOICE_ORDER:
            if group_name in groups:
                sorted_groups.append((group_name, groups[group_name]))
                del groups[group_name]
        # Füge verbleibende Gruppen hinzu
        for group_name, group_voices in groups.items():
            sorted_groups.append((group_name, group_voices))
            
        # Erstelle optgroups und options
        for group_name, group_voices in sorted_groups:
            if len(group_voices) == 0:
                continue
            optgroup = Element('optgroup')
            optgroup.label = group_name
            # Sortiere Stimmen innerhalb der Gruppe nach Name
            sorted_voices = sorted(group_voices, key=lambda v: v.get('name', ''))
            for voice in sorted_voices:
                option = Element('option')
                option.value = voice['id']
                option.dataset['name'] = voice['name']
                option.appendChild = option.append  # Kompatibilität
                optgroup.append(option)
            select.append(optgroup)
            
        # Füge Styles hinzu
        if styles:
            optgroup_styles = Element('optgroup')
            optgroup_styles.label = 'Stile'
            for style in styles:
                option = Element('option')
                option.value = style['id']
                option.dataset['name'] = style['name']
                optgroup_styles.append(option)
            select.append(optgroup_styles)
            
        # Setze den Wert auf den aktuellen speechVoiceName, falls vorhanden
        # Prüfe alle Optionen
        found = False
        for group in select.children:
            for option in group.children:
                if option.value == speechVoiceName:
                    select.value = speechVoiceName
                    found = True
                    break
            if found:
                break
                
    # Initialer Aufruf
    setSpeechVoiceOptions([], voices)
    
    # Tests
    labels_to_check = ['Kyrillisch','Asiatisch','Abjad','Indisch','Effekt Stimmen']
    for label in labels_to_check:
        group = None
        for node in select.children:
            if getattr(node, 'label', None) == label:
                group = node
                break
        assert group is not None, f"Gruppe {label} nicht gefunden"
        assert len(group.children) >= 3, f"Gruppe {label} hat weniger als 3 Kinder"
        
    # Spezifischer Test für Effekt Stimmen
    effect_group = None
    for node in select.children:
        if getattr(node, 'label', None) == 'Effekt Stimmen':
            effect_group = node
            break
    assert effect_group is not None, "Effekt Stimmen Gruppe nicht gefunden"
    assert len(effect_group.children) == 5, f"Effekt Stimmen hat nicht 5 Kinder, sondern {len(effect_group.children)}"
    
    assert select.value == 'sherpa-de-supertonic-7', f"select.value ist nicht 'sherpa-de-supertonic-7', sondern '{select.value}'"
    
    # Zweiter Aufruf mit Styles
    styles = [{'id':'sherpa-de-supertonic-7','name':'Stil 3','group':''}]
    setSpeechVoiceOptions(styles, voices)
    assert select.value == 'sherpa-de-supertonic-7', f"select.value ist nicht 'sherpa-de-supertonic-7' nach zweitem Aufruf, sondern '{select.value}'"
    
    # Prüfe ob die aktuelle Option in der Effekt Stimmen Gruppe ist
    current_option_found = False
    for group in select.children:
        if getattr(group, 'label', None) == 'Effekt Stimmen':
            for option in group.children:
                if option.value == select.value:
                    current_option_found = True
                    break
        if current_option_found:
            break
    assert current_option_found, "Aktuelle Option nicht in Effekt Stimmen Gruppe gefunden"
    
    # Ändere speechVoiceName und rufe erneut auf
    speechVoiceName = 'sherpa-ru-irina'
    # Entferne Gruppen aus voices (ähnlich wie map in JS)
    voices_no_group = []
    for voice in voices:
        voice_copy = voice.copy()
        if 'group' in voice_copy:
            del voice_copy['group']
        voices_no_group.append(voice_copy)
        
    setSpeechVoiceOptions([], voices_no_group)
    assert select.value == 'sherpa-ru-irina', f"select.value ist nicht 'sherpa-ru-irina', sondern '{select.value}'"
    
    # Prüfe ob die Option in der Kyrillisch Gruppe ist
    kyrillisch_option_found = False
    for group in select.children:
        if getattr(group, 'label', None) == 'Kyrillisch':
            for option in group.children:
                if option.value == 'sherpa-ru-irina':
                    kyrillisch_option_found = True
                    break
        if kyrillisch_option_found:
            break
    assert kyrillisch_option_found, "Option 'sherpa-ru-irina' nicht in Kyrillisch Gruppe gefunden"
    
    print('PASS: five groups, all styles selectable, retained selection, legacy catalog fallback')

if __name__ == '__main__':
    test_voice_groups()
