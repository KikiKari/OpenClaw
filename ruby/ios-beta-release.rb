#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "a2e262e8bf88929e38cc8c982710c2da12f43be84b95d67d324f4d1020819d24", "source_sha256": "74168ccc75bdca2481fb7bf1298fad30cea4e5fdd917205e7f1815e86948ca0c", "target_language": "ruby"}
# ios-beta-release.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-release.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

def usage
  puts <<~EOF
    Usage:
      scripts/ios-beta-release.sh [--build-number 7]

    Archives and uploads a beta-release IPA to TestFlight locally.
  EOF
end

build_number = ENV['IOS_BETA_BUILD_NUMBER'] || ''
root_dir = File.expand_path('..', File.dirname(__FILE__))

# Parse command line arguments
while ARGV.length > 0
  case ARGV[0]
  when '--'
    ARGV.shift
  when '--build-number'
    build_number = ARGV[1] || ''
    ARGV.shift(2)
  when '-h', '--help'
    usage
    exit 0
  else
    STDERR.puts "Unknown argument: #{ARGV[0]}"
    usage
    exit 1
  end
end

# Change to iOS app directory and execute fastlane
Dir.chdir(File.join(root_dir, 'apps', 'ios')) do
  ENV['IOS_BETA_BUILD_NUMBER'] = build_number
  system('fastlane ios beta')
  
  # Check if fastlane command failed
  unless $?.success?
    exit $?.exitstatus
  end
end
