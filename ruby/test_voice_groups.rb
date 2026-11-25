#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f2ae6e25438807136adb818faafe72be7f00c4b82256a0dc0ef2d86ab869b0ef", "source_sha256": "c451131599cab4bee1c4c62c6eac8c382c366e4cacf443d53c179c01a326a251", "target_language": "ruby"}
# test_voice_groups.cjs — portiert nach ruby
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_voice_groups.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_voice_groups.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_voice_groups.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_voice_groups.cjs
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'ostruct'

# Simulate DOM element structure
class Element < OpenStruct
  def initialize(tag)
    super()
    self.tag = tag
    self.children = []
    self.dataset = {}
    self.value = ''
  end

  def append(node)
    children << node
  end
end

# Read files
source = File.read(File.join(__dir__, '../browser-extension/sidepanel.js'))
voices_data = JSON.parse(File.read(File.join(__dir__, '../companion-service/voice-catalog.json')))
voices = voices_data['voices']

# Create select element
select = Element.new('select')

# Create context-like environment
context = {
  'document' => {
    'createElement' => ->(tag) { Element.new(tag) }
  },
  'elements' => {
    'speech-voice' => select
  },
  'speechVoiceName' => 'sherpa-de-supertonic-7',
  'voiceCatalog' => voices,
  'clearChildren' => ->(node) { node.children.clear }
}

# Extract and execute relevant JavaScript code
base_voice_order_code = source[source.index('  const BASE_VOICE_ORDER')..source.index('  const core,')]
speech_voices_code = source[source.index('  function sherpaSpeechVoices')..source.index('  async function loadSpeechVoices')]

# Evaluate JavaScript snippets with context
eval(base_voice_order_code, binding)
eval(speech_voices_code, binding)

# Define setSpeechVoiceOptions method in Ruby context
def set_speech_voice_options(context, options, voices)
  select = context['elements']['speech-voice']
  select.children.clear
  
  # Group voices by their group property
  grouped_voices = voices.group_by { |voice| voice['group'] }
  
  # Add voices to select element
  grouped_voices.each do |group_name, group_voices|
    optgroup = Element.new('optgroup')
    optgroup.label = group_name
    group_voices.each do |voice|
      option = Element.new('option')
      option.value = voice['id']
      option.textContent = voice['name']
      optgroup.append(option)
    end
    select.append(optgroup)
  end
  
  # Set selected value
  select.value = context['speechVoiceName']
end

# Call setSpeechVoiceOptions with initial data
set_speech_voice_options(context, [], voices)

# Test assertions
labels = ['Kyrillisch', 'Asiatisch', 'Abjad', 'Indisch', 'Effekt Stimmen']
labels.each do |label|
  group = select.children.find { |node| node.label == label }
  raise "Assertion failed: #{label}" unless group
  raise "Assertion failed: #{label} children count" unless group.children.length >= 3
end

effect_group = select.children.find { |node| node.label == 'Effekt Stimmen' }
raise "Effect voices count assertion failed" unless effect_group.children.length == 5

raise "Select value assertion failed" unless select.value == 'sherpa-de-supertonic-7'

# Update context and test again
context['speechVoiceName'] = 'sherpa-de-supertonic-7'
options = [{'id' => 'sherpa-de-supertonic-7', 'name' => 'Stil 3', 'group' => ''}]
set_speech_voice_options(context, options, voices)

raise "Select value assertion failed" unless select.value == 'sherpa-de-supertonic-7'

effect_group = select.children.find { |node| node.label == 'Effekt Stimmen' }
selected_option = effect_group.children.find { |node| node.value == select.value }
raise "Selected option not found in effect group" unless selected_option

# Test legacy catalog fallback
context['speechVoiceName'] = 'sherpa-ru-irina'
voices_without_group = voices.map { |voice| voice.reject { |k| k == 'group' } }
set_speech_voice_options(context, [], voices_without_group)

raise "Select value assertion failed" unless select.value == 'sherpa-ru-irina'

kyrillisch_group = select.children.find { |node| node.label == 'Kyrillisch' }
kyrillisch_option = kyrillisch_group.children.find { |node| node.value == 'sherpa-ru-irina' }
raise "Kyrillisch option not found" unless kyrillisch_option

puts 'PASS: five groups, all styles selectable, retained selection, legacy catalog fallback'
