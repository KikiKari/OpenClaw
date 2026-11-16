#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "bf521a6ade69b1dc89546b6b30fa0c27a9a2f87c8fe509d75ffa628cce1690c2", "source_sha256": "cff712785adbfe2fa94661b7b8457fbc21ec0b21bc3bc77e5cfa7018f473e486", "target_language": "ruby"}
# build_icon.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build_icon.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Render the macOS .icon bundle to a padded .icns like Trimmy's pipeline.
# Defaults target the OpenClaw assets so you can just run the script from repo root.

require 'fileutils'
require 'pathname'

def main
  root_dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
  
  icon_file = ARGV[0] || "#{root_dir}/apps/macos/Icon.icon"
  basename = ARGV[1] || "OpenClaw"
  out_root = ARGV[2] || "#{root_dir}/apps/macos/build/icon"
  xcode_app = ENV['XCODE_APP'] || "/Applications/Xcode.app"
  dest_icns = ENV['DEST_ICNS'] || "#{root_dir}/apps/macos/Sources/OpenClaw/Resources/OpenClaw.icns"
  
  ictool = "#{xcode_app}/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
  unless File.executable?(ictool)
    ictool = "#{xcode_app}/Contents/Applications/Icon Composer.app/Contents/Executables/icontool"
  end
  
  unless File.executable?(ictool)
    STDERR.puts "ictool/icontool not found. Set XCODE_APP if Xcode is elsewhere."
    exit 1
  end
  
  iconset_dir = "#{out_root}/#{basename}.iconset"
  tmp_dir = "#{out_root}/tmp"
  FileUtils.mkdir_p([iconset_dir, tmp_dir])
  
  master_art = "#{tmp_dir}/icon_art_824.png"
  master_1024 = "#{tmp_dir}/icon_1024.png"
  
  # Render inner art (no margin) with macOS Default appearance
  system(ictool, icon_file,
         '--export-preview', 'macOS', 'Default', '824', '824', '1', '-45', master_art)
  
  # Pad to 1024x1024 with transparent border
  system('sips', '--padToHeightWidth', '1024', '1024', master_art, '--out', master_1024, out: '/dev/null')
  
  # Generate required sizes
  sizes = [16, 32, 64, 128, 256, 512, 1024]
  sizes.each do |sz|
    out = "#{iconset_dir}/icon_#{sz}x#{sz}.png"
    system('sips', '-z', sz.to_s, sz.to_s, master_1024, '--out', out, out: '/dev/null')
    
    unless sz == 1024
      dbl = sz * 2
      out2 = "#{iconset_dir}/icon_#{sz}x#{sz}@2x.png"
      system('sips', '-z', dbl.to_s, dbl.to_s, master_1024, '--out', out2, out: '/dev/null')
    end
  end
  
  # 512x512@2x already covered by 1024; ensure it exists
  FileUtils.cp(master_1024, "#{iconset_dir}/icon_512x512@2x.png")
  
  system('iconutil', '-c', 'icns', iconset_dir, '-o', "#{out_root}/#{basename}.icns")
  
  FileUtils.mkdir_p(File.dirname(dest_icns))
  FileUtils.cp("#{out_root}/#{basename}.icns", dest_icns)
  
  puts "Icon.icns generated at #{dest_icns}"
end

main if __FILE__ == $0
