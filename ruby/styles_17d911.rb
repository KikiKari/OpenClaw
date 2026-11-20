#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "34f1a9c904fea26e6743c81d208d78237eb7655532df0f2a341ac5d8ba013c16", "source_sha256": "17d9118c74c9951b6bd9c5e3475b496be57f796a591823384aa44dbdad5a115d", "target_language": "ruby"}
# styles.css — portiert nach ruby
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles.css
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

def generate_css_content
  imports = [
    './styles/base.css',
    './styles/layout.css',
    './styles/layout.mobile.css',
    './styles/components.css',
    './styles/chat.css',
    './styles/config.css',
    './styles/usage.css',
    './styles/dreams.css',
    '@create-markdown/preview/themes/system.css'
  ]
  
  import_rules = imports.map { |path| "@import \"#{path}\";" }.join("\n")
  
  cm_preview_rule = <<~CSS
    .cm-preview {
      --cm-mono: var(--mono);
      --cm-link: var(--accent);
      --cm-info: var(--info);
      --cm-warning: var(--warn);
      --cm-success: var(--ok);
      --cm-danger: var(--danger);
    }
  CSS
  
  "#{import_rules}\n\n#{cm_preview_rule}"
end

def write_css_to_file(filename)
  File.write(filename, generate_css_content)
end

if __FILE__ == $0
  if ARGV.length != 1
    puts "Usage: #{$0} <output_filename>"
    exit 1
  end
  
  output_filename = ARGV[0]
  write_css_to_file(output_filename)
  puts "CSS content written to #{output_filename}"
end
