#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "ecf467436e8a720ac37e829f237526ca26aa5d2b184968e37942a3441f2eb346", "source_sha256": "fe4ef822110d5a3d05561b87f0634182183de94f1130dc41ba19fd74bdff1653", "target_language": "ruby"}
# test-extension-batch.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension-batch.mjs
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

require_relative './lib/extension_test_plan'
require_relative './lib/vitest_batch_runner'

def print_usage
  STDERR.puts "Usage: pnpm test:extensions:batch <extension[,extension...]> [vitest args...]"
  STDERR.puts "       node scripts/test-extension-batch.mjs <extension[,extension...]> [vitest args...]"
end

def parse_extension_ids(raw_args)
  args = raw_args.dup
  extension_ids = []

  while args[0] && !args[0].start_with?('-')
    extension_ids.concat(
      args.shift
        .split(',')
        .map(&:strip)
        .reject(&:empty?)
    )
  end

  { extension_ids: extension_ids, passthrough_args: args }
end

async def run
  raw_args = ARGV.dup
  if raw_args.include?('--help') || raw_args.include?('-h')
    print_usage
    return
  end

  passthrough_args = raw_args.reject { |arg| arg == '--' }
  result = parse_extension_ids(passthrough_args)
  extension_ids = result[:extension_ids]
  vitest_args = result[:passthrough_args]

  if extension_ids.empty?
    print_usage
    exit(1)
  end

  batch_plan = resolve_extension_batch_plan({ cwd: Dir.pwd, extension_ids: extension_ids })
  unless batch_plan.has_tests
    puts "[test-extension-batch] No tests found for the requested extensions. Skipping."
    return
  end

  puts "[test-extension-batch] Running #{batch_plan.test_file_count} test files across #{batch_plan.extension_count} extensions"

  batch_plan.plan_groups.each do |group|
    puts "[test-extension-batch] #{group.config}: #{group.extension_ids.join(', ')} (#{group.test_file_count} files)"
    exit_code = run_vitest_batch({
      args: vitest_args,
      config: group.config,
      env: ENV.to_h,
      targets: group.roots
    })
    if exit_code != 0
      exit exit_code
    end
  end
end

if __FILE__ == $0
  run
end
