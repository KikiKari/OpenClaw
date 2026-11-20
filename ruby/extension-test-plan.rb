#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f33f95be8f0d1ea5ba193057d3c60dafdce985877020844f763de35163d2ccdc", "source_sha256": "c28e85cfc52b92ed64eb8e20b072fd218cfe0e1ab0787781c1a9abd3355c3514", "target_language": "ruby"}
# extension-test-plan.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/extension-test-plan.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'json'
require 'pathname'

# Helper methods to simulate JavaScript behavior
def path_join(*args)
  File.join(*args)
end

def path_resolve(*args)
  Pathname.new(File.join(*args)).cleanpath.to_s
end

def path_relative(from, to)
  Pathname.new(to).relative_path_from(Pathname.new(from)).to_s
end

def path_basename(path)
  File.basename(path)
end

def path_dirname(path)
  File.dirname(path)
end

def exists?(path)
  File.exist?(path)
end

def read_dir_sync(path)
  Dir.entries(path).reject { |f| f.start_with?('.') }
rescue
  []
end

def is_file?(path)
  File.file?(path)
end

def is_directory?(path)
  File.directory?(path)
end

# Constants
REPO_ROOT = path_resolve(__dir__, '..', '..')
DEFAULT_EXTENSION_TEST_SHARD_COUNT = 6
BUNDLED_PLUGIN_PATH_PREFIX = 'packages/bundled-plugins'
BUNDLED_PLUGIN_ROOT_DIR = 'packages/bundled-plugins'

# Import-like constants (simulated)
CHANNEL_TEST_ROOTS = ['packages/bundled-plugins/slack', 'packages/bundled-plugins/discord']
def is_acpx_extension_root(root); root.include?('acpx'); end
def is_blue_bubbles_extension_root(root); root.include?('bluebubbles'); end
def is_diffs_extension_root(root); root.include?('diffs'); end
def is_feishu_extension_root(root); root.include?('feishu'); end
def is_irc_extension_root(root); root.include?('irc'); end
def is_matrix_extension_root(root); root.include?('matrix'); end
def is_mattermost_extension_root(root); root.include?('mattermost'); end
def is_memory_extension_root(root); root.include?('memory'); end
def is_messaging_extension_root(root); root.include?('messaging'); end
def is_ms_teams_extension_root(root); root.include?('msteams'); end
def is_provider_extension_root(root); root.include?('provider'); end
def is_telegram_extension_root(root); root.include?('telegram'); end
def is_voice_call_extension_root(root); root.include?('voice-call'); end
def is_whats_app_extension_root(root); root.include?('whatsapp'); end
def is_zalo_extension_root(root); root.include?('zalo'); end

def normalize_relative(input_path)
  input_path.gsub(File::SEPARATOR, '/')
end

def count_test_files(root_path)
  total = 0
  stack = [root_path]

  while !stack.empty?
    current = stack.pop
    next unless exists?(current)

    begin
      entries = read_dir_sync(current)
      entries.each do |entry_name|
        full_path = path_join(current, entry_name)
        if is_directory?(full_path)
          next if entry_name == 'node_modules' || entry_name == 'dist'
          stack.push(full_path)
          next
        end
        if is_file?(full_path) && (full_path.end_with?('.test.ts') || full_path.end_with?('.test.tsx'))
          total += 1
        end
      end
    rescue
      # Ignore errors
    end
  end

  total
end

def resolve_extension_directory(target_arg, cwd = Dir.pwd)
  if target_arg
    as_given = path_resolve(cwd, target_arg)
    if exists?(path_join(as_given, 'package.json'))
      return as_given
    end

    by_name = path_join(REPO_ROOT, BUNDLED_PLUGIN_ROOT_DIR, target_arg)
    if exists?(path_join(by_name, 'package.json'))
      return by_name
    end

    raise "Unknown extension target \"#{target_arg}\". Use a plugin name like \"slack\" or a path inside the bundled plugin workspace tree."
  end

  current = cwd
  loop do
    rel_path = normalize_relative(path_relative(REPO_ROOT, current))
    if rel_path.start_with?(BUNDLED_PLUGIN_PATH_PREFIX) && exists?(path_join(current, 'package.json'))
      return current
    end
    parent = path_dirname(current)
    break if parent == current
    current = parent
  end

  raise "No extension target provided, and current working directory is not inside the bundled plugin workspace tree."
end

def resolve_extension_test_plan(params = {})
  cwd = params[:cwd] || Dir.pwd
  target_arg = params[:target_arg]
  extension_dir = resolve_extension_directory(target_arg, cwd)
  extension_id = path_basename(extension_dir)
  relative_extension_dir = normalize_relative(path_relative(REPO_ROOT, extension_dir))

  roots = [relative_extension_dir]

  uses_channel_config = roots.any? { |root| CHANNEL_TEST_ROOTS.include?(root) }
  uses_acpx_config = roots.any? { |root| is_acpx_extension_root(root) }
  uses_diffs_config = roots.any? { |root| is_diffs_extension_root(root) }
  uses_blue_bubbles_config = roots.any? { |root| is_blue_bubbles_extension_root(root) }
  uses_feishu_config = roots.any? { |root| is_feishu_extension_root(root) }
  uses_irc_config = roots.any? { |root| is_irc_extension_root(root) }
  uses_mattermost_config = roots.any? { |root| is_mattermost_extension_root(root) }
  uses_telegram_config = roots.any? { |root| is_telegram_extension_root(root) }
  uses_voice_call_config = roots.any? { |root| is_voice_call_extension_root(root) }
  uses_whats_app_config = roots.any? { |root| is_whats_app_extension_root(root) }
  uses_zalo_config = roots.any? { |root| is_zalo_extension_root(root) }
  uses_matrix_config = roots.any? { |root| is_matrix_extension_root(root) }
  uses_memory_config = roots.any? { |root| is_memory_extension_root(root) }
  uses_ms_teams_config = roots.any? { |root| is_ms_teams_extension_root(root) }
  uses_messaging_config = roots.any? { |root| is_messaging_extension_root(root) }
  uses_provider_config = roots.any? { |root| is_provider_extension_root(root) }

  config =
    if uses_channel_config
      'test/vitest/vitest.extension-channels.config.ts'
    elsif uses_acpx_config
      'test/vitest/vitest.extension-acpx.config.ts'
    elsif uses_diffs_config
      'test/vitest/vitest.extension-diffs.config.ts'
    elsif uses_blue_bubbles_config
      'test/vitest/vitest.extension-bluebubbles.config.ts'
    elsif uses_feishu_config
      'test/vitest/vitest.extension-feishu.config.ts'
    elsif uses_irc_config
      'test/vitest/vitest.extension-irc.config.ts'
    elsif uses_mattermost_config
      'test/vitest/vitest.extension-mattermost.config.ts'
    elsif uses_matrix_config
      'test/vitest/vitest.extension-matrix.config.ts'
    elsif uses_telegram_config
      'test/vitest/vitest.extension-telegram.config.ts'
    elsif uses_voice_call_config
      'test/vitest/vitest.extension-voice-call.config.ts'
    elsif uses_whats_app_config
      'test/vitest/vitest.extension-whatsapp.config.ts'
    elsif uses_zalo_config
      'test/vitest/vitest.extension-zalo.config.ts'
    elsif uses_memory_config
      'test/vitest/vitest.extension-memory.config.ts'
    elsif uses_ms_teams_config
      'test/vitest/vitest.extension-msteams.config.ts'
    elsif uses_messaging_config
      'test/vitest/vitest.extension-messaging.config.ts'
    elsif uses_provider_config
      'test/vitest/vitest.extension-providers.config.ts'
    else
      'test/vitest/vitest.extensions.config.ts'
    end

  test_file_count = roots.sum { |root| count_test_files(path_join(REPO_ROOT, root)) }

  {
    config: config,
    extension_dir: relative_extension_dir,
    extension_id: extension_id,
    has_tests: test_file_count > 0,
    roots: roots,
    test_file_count: test_file_count
  }
end

def merge_test_plans(plans)
  groups_by_config = {}

  plans.each do |plan|
    current = groups_by_config[plan[:config]] || {
      config: plan[:config],
      extension_ids: [],
      roots: [],
      test_file_count: 0
    }

    current[:extension_ids] << plan[:extension_id]
    current[:roots].concat(plan[:roots])
    current[:test_file_count] += plan[:test_file_count]
    groups_by_config[plan[:config]] = current
  end

  plan_groups = groups_by_config.values.map do |group|
    {
      config: group[:config],
      extension_ids: group[:extension_ids].sort,
      roots: group[:roots].uniq
    }.merge(group.reject { |k, _| [:config, :extension_ids, :roots].include?(k) })
  end.sort { |a, b| a[:config] <=> b[:config] }

  {
    extension_count: plans.length,
    extension_ids: plans.map { |plan| plan[:extension_id] }.sort,
    has_tests: plans.length > 0,
    plan_groups: plan_groups,
    test_file_count: plans.sum { |plan| plan[:test_file_count] }
  }
end

def resolve_extension_batch_plan(params = {})
  cwd = params[:cwd] || Dir.pwd
  extension_ids = params[:extension_ids] || list_available_extension_ids()
  plans = extension_ids.map do |extension_id|
    resolve_extension_test_plan(cwd: cwd, target_arg: extension_id)
  end.select { |plan| plan[:has_tests] }

  merge_test_plans(plans)
end

def pick_least_loaded_shard(shards)
  best_index = -1

  shards.each_with_index do |shard, index|
    if best_index == -1
      best_index = index
      next
    end

    best = shards[best_index]
    if shard[:test_file_count] != best[:test_file_count]
      best_index = shard[:test_file_count] < best[:test_file_count] ? index : best_index
      next
    end

    if shard[:plans].length != best[:plans].length
      best_index = shard[:plans].length < best[:plans].length ? index : best_index
      next
    end

    best_index = index < best_index ? index : best_index
  end

  best_index
end

def create_extension_test_shards(params = {})
  cwd = params[:cwd] || Dir.pwd
  extension_ids = params[:extension_ids] || list_available_extension_ids()
  shard_count = [1, (params[:shard_count] || 1).to_i].max

  plans = extension_ids.map do |extension_id|
    resolve_extension_test_plan(cwd: cwd, target_arg: extension_id)
  end.select { |plan| plan[:has_tests] }.sort do |left, right|
    if left[:test_file_count] != right[:test_file_count]
      right[:test_file_count] <=> left[:test_file_count]
    else
      left[:extension_id] <=> right[:extension_id]
    end
  end

  effective_shard_count = [shard_count, [1, plans.length].max].min
  shards = Array.new(effective_shard_count) { { plans: [], test_file_count: 0 } }

  plans.each do |plan|
    target_index = pick_least_loaded_shard(shards)
    shards[target_index][:plans] << plan
    shards[target_index][:test_file_count] += plan[:test_file_count]
  end

  shards.map.with_index do |shard, index|
    result = merge_test_plans(shard[:plans])
    result.merge({
      index: index,
      check_name: "checks-node-extensions-shard-#{index + 1}"
    })
  end.select { |shard| shard[:has_tests] }
end

# Placeholder for list_available_extension_ids function
def list_available_extension_ids
  # This should be implemented based on actual logic
  ['slack', 'discord', 'telegram']
end
