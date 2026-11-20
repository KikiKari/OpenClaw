#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "c3dc76199d125b88a521b6824928b5ebfa695b12b0692038f42912e66c1288cf", "source_sha256": "2cdcdc862375b173b06398d139b611f6f002e0435191f56d26d3e48a3cef02cf", "target_language": "ruby"}
# ios-beta-archive.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-archive.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

require 'optparse'
require 'pathname'

def usage
  puts <<~EOF
    Usage:
      scripts/ios-beta-archive.sh [--build-number 7]

    Archives and exports a beta-release IPA locally without uploading.
  EOF
end

build_number = ENV['IOS_BETA_BUILD_NUMBER'] || ''
root_dir = Pathname.new(__FILE__).dirname.parent.realpath

OptionParser.new do |opts|
  opts.on('--build-number BUILD_NUMBER', 'Set build number') do |bn|
    build_number = bn
  end

  opts.on('-h', '--help', 'Show this help message') do
    usage
    exit 0
  end
end.parse!

Dir.chdir(root_dir.join('apps/ios')) do
  ENV['IOS_BETA_BUILD_NUMBER'] = build_number
  system('fastlane', 'ios', 'beta_archive') or exit($?.exitstatus)
end
