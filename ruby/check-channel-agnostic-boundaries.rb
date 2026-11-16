#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "399dc0b2768e9ac9db84ba0208eedaaef5069c9524e0c08c65ee07d1afde0d11", "source_sha256": "a2afe873e78fca9f7a9bf66785f17d7cad24c6285fd2c0dc6c6bb2abf1e375fa", "target_language": "ruby"}
# check-channel-agnostic-boundaries.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-channel-agnostic-boundaries.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'pathname'
require 'set'
require_relative './lib/ts_guard_utils'

repo_root = resolve_repo_root(__FILE__)

acp_core_protected_sources = [
  File.join(repo_root, 'src', 'acp'),
  File.join(repo_root, 'src', 'agents', 'acp-spawn.ts'),
  File.join(repo_root, 'src', 'auto-reply', 'reply', 'commands-acp'),
  File.join(repo_root, 'src', 'infra', 'outbound', 'conversation-id.ts'),
]

channel_core_protected_sources = [
  File.join(repo_root, 'src', 'channels', 'thread-bindings-policy.ts'),
  File.join(repo_root, 'src', 'channels', 'thread-bindings-messages.ts'),
]
acp_user_facing_text_sources = [
  File.join(repo_root, 'src', 'auto-reply', 'reply', 'commands-acp'),
]
system_mark_literal_guard_sources = [
  File.join(repo_root, 'src', 'auto-reply', 'reply', 'commands-acp'),
  File.join(repo_root, 'src', 'auto-reply', 'reply', 'dispatch-acp.ts'),
  File.join(repo_root, 'src', 'auto-reply', 'reply', 'directive-handling.shared.ts'),
  File.join(repo_root, 'src', 'channels', 'thread-bindings-messages.ts'),
]

channel_ids = [
  'bluebubbles',
  'discord',
  'googlechat',
  'imessage',
  'irc',
  'line',
  'matrix',
  'msteams',
  'signal',
  'slack',
  'telegram',
  'web',
  'whatsapp',
  'zalo',
  'zalouser',
]

channel_id_set = Set.new(channel_ids)
channel_segment_re = Regexp.new("(^|[._/\\-])(?:#{channel_ids.join('|')})([._/\\-]|$)")
comparison_operators = Set.new([
  :equals_equals_equals_token,
  :exclamation_equals_equals_token,
  :equals_equals_token,
  :exclamation_equals_token,
])

allowed_violations = Set.new([])

def is_channels_property_access(node)
  if node.type == :property_access_expression
    return node.name.text == 'channels'
  end
  if node.type == :element_access_expression && node.argument_expression.type == :string_literal
    return node.argument_expression.text == 'channels'
  end
  false
end

def read_string_literal(node)
  if node.type == :string_literal
    return node.text
  end
  if node.type == :no_substitution_template_literal
    return node.text
  end
  nil
end

def is_channel_literal_node(node)
  text = read_string_literal(node)
  return text ? channel_id_set.include?(text) : false
end

def matches_channel_module_specifier(specifier)
  channel_segment_re.match?(specifier.gsub('\\', '/'))
end

user_facing_channel_name_re = /\b(?:discord|telegram|slack|signal|imessage|whatsapp|google\s*chat|irc|line|zalo|matrix|msteams|bluebubbles)\b/i
system_mark_literal = '⚙️'

def is_module_specifier_string_node(node)
  parent = node.parent
  if parent.type == :import_declaration || parent.type == :export_declaration
    return true
  end
  return (
    parent.type == :call_expression &&
    parent.expression.type == :import_keyword &&
    parent.arguments[0] == node
  )
end

def find_channel_agnostic_boundary_violations(content, file_name = 'source.ts', options = {})
  check_module_specifiers = options[:check_module_specifiers] != false
  check_config_paths = options[:check_config_paths] != false
  check_channel_comparisons = options[:check_channel_comparisons] != false
  check_channel_assignments = options[:check_channel_assignments] != false
  module_specifier_matcher = options[:module_specifier_matcher] || method(:matches_channel_module_specifier)

  source_file = TypeScript::create_source_file(file_name, content, :latest, true)
  violations = []

  visit = lambda do |node|
    if (
      check_module_specifiers &&
      node.type == :import_declaration &&
      node.module_specifier.type == :string_literal
    )
      specifier = node.module_specifier.text
      if module_specifier_matcher.call(specifier)
        violations.push({
          line: to_line(source_file, node.module_specifier),
          reason: "imports channel module \"#{specifier}\"",
        })
      end
    end

    if (
      check_module_specifiers &&
      node.type == :export_declaration &&
      node.module_specifier &&
      node.module_specifier.type == :string_literal
    )
      specifier = node.module_specifier.text
      if module_specifier_matcher.call(specifier)
        violations.push({
          line: to_line(source_file, node.module_specifier),
          reason: "re-exports channel module \"#{specifier}\"",
        })
      end
    end

    if (
      check_module_specifiers &&
      node.type == :call_expression &&
      node.expression.type == :import_keyword &&
      node.arguments.length > 0 &&
      node.arguments[0].type == :string_literal
    )
      specifier = node.arguments[0].text
      if module_specifier_matcher.call(specifier)
        violations.push({
          line: to_line(source_file, node.arguments[0]),
          reason: "dynamically imports channel module \"#{specifier}\"",
        })
      end
    end

    if (
      check_config_paths &&
      node.type == :property_access_expression &&
      channel_id_set.include?(node.name.text)
    )
      if is_channels_property_access(node.expression)
        violations.push({
          line: to_line(source_file, node.name),
          reason: "references config path \"channels.#{node.name.text}\"",
        })
      end
    end

    if (
      check_config_paths &&
      node.type == :element_access_expression &&
      node.argument_expression.type == :string_literal &&
      channel_id_set.include?(node.argument_expression.text)
    )
      if is_channels_property_access(node.expression)
        violations.push({
          line: to_line(source_file, node.argument_expression),
          reason: "references config path \"channels[#{node.argument_expression.text.to_json}]\"",
        })
      end
    end

    if (
      check_channel_comparisons &&
      node.type == :binary_expression &&
      comparison_operators.include?(node.operator_token.type)
    )
      if is_channel_literal_node(node.left) || is_channel_literal_node(node.right)
        left_text = node.left.get_text(source_file)
        right_text = node.right.get_text(source_file)
        violations.push({
          line: to_line(source_file, node.operator_token),
          reason: "compares with channel id literal (#{left_text} #{node.operator_token.get_text(source_file)} #{right_text})",
        })
      end
    end

    if check_channel_assignments && node.type == :property_assignment
      prop_name = get_property_name_text(node.name)
      if prop_name == 'channel' && is_channel_literal_node(node.initializer)
        violations.push({
          line: to_line(source_file, node.initializer),
          reason: "assigns channel id literal to \"channel\" (#{node.initializer.get_text(source_file)})",
        })
      end
    end

    node.each_child(&visit)
  end

  visit.call(source_file)
  violations
end

def find_channel_core_reverse_dependency_violations(content, file_name = 'source.ts')
  find_channel_agnostic_boundary_violations(content, file_name, {
    check_module_specifiers: true,
    check_config_paths: false,
    check_channel_comparisons: false,
    check_channel_assignments: false,
    module_specifier_matcher: method(:matches_channel_module_specifier),
  })
end

def find_acp_user_facing_channel_name_violations(content, file_name = 'source.ts')
  source_file = TypeScript::create_source_file(file_name, content, :latest, true)
  violations = []

  visit = lambda do |node|
    text = read_string_literal(node)
    if text && user_facing_channel_name_re.match?(text) && !is_module_specifier_string_node(node)
      violations.push({
        line: to_line(source_file, node),
        reason: "user-facing text references channel name (#{text.to_json})",
      })
    end
    node.each_child(&visit)
  end

  visit.call(source_file)
  violations
end

def find_system_mark_literal_violations(content, file_name = 'source.ts')
  source_file = TypeScript::create_source_file(file_name, content, :latest, true)
  violations = []

  visit = lambda do |node|
    text = read_string_literal(node)
    if text && text.include?(system_mark_literal) && !is_module_specifier_string_node(node)
      violations.push({
        line: to_line(source_file, node),
        reason: "hardcoded system mark literal (#{text.to_json})",
      })
    end
    node.each_child(&visit)
  end

  visit.call(source_file)
  violations
end

boundary_rule_sets = [
  {
    id: 'acp-core',
    sources: acp_core_protected_sources,
    scan: lambda { |content, file_name| find_channel_agnostic_boundary_violations(content, file_name) },
  },
  {
    id: 'channel-core-reverse-deps',
    sources: channel_core_protected_sources,
    scan: lambda { |content, file_name| find_channel_core_reverse_dependency_violations(content, file_name) },
  },
  {
    id: 'acp-user-facing-text',
    sources: acp_user_facing_text_sources,
    scan: lambda { |content, file_name| find_acp_user_facing_channel_name_violations(content, file_name) },
  },
  {
    id: 'system-mark-literal-usage',
    sources: system_mark_literal_guard_sources,
    scan: lambda { |content, file_name| find_system_mark_literal_violations(content, file_name) },
  },
]

def main
  violations = []
  boundary_rule_sets.each do |rule_set|
    files = rule_set[:sources].flat_map do |source_path|
      collect_type_script_files(source_path, { ignore_missing: true })
    end
    files.each do |file_path|
      relative_file = Pathname.new(file_path).relative_path_from(Pathname.new(repo_root)).to_s
      if allowed_violations.include?("#{rule_set[:id]}:#{relative_file}") || allowed_violations.include?(relative_file)
        next
      end
      content = File.read(file_path, encoding: 'UTF-8')
      rule_set[:scan].call(content, relative_file).each do |violation|
        violations.push("#{rule_set[:id]} #{relative_file}:#{violation[:line]}: #{violation[:reason]}")
      end
    end
  end

  if violations.length == 0
    return
  end

  puts 'Found channel-specific references in channel-agnostic sources:'
  violations.each do |violation|
    puts "- #{violation}"
  end
  puts 'Move channel-specific logic to channel adapters or add a justified allowlist entry.'
  exit(1)
end

run_as_script(__FILE__, method(:main))
