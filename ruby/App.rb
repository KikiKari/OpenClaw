#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "a2176cce5ebbafae0a9315e277729ad48c1da9bbdf0ff591cdd3e3fb78c77d20", "source_sha256": "08fdd65a33a6ec90261b4ce48be82ca8338400da1b321dfc70a57bedabfa45aa", "target_language": "ruby"}
# App.css — portiert nach ruby
# Quelle: css, OpenClaw@main:src/App.css
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Generates CSS file with specified filename
# Usage: ruby script.rb output_filename

def generate_css
  css_rules = []

  # Root variables
  css_rules << ":root {"
  css_rules << "  color-scheme: dark;"
  css_rules << "  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif;"
  css_rules << "  background: #0b1020;"
  css_rules << "  color: #eef2ff;"
  css_rules << "}"
  css_rules << ""

  # Universal selector
  css_rules << "* {"
  css_rules << "  box-sizing: border-box;"
  css_rules << "}"
  css_rules << ""

  # Body styles
  css_rules << "body {"
  css_rules << "  margin: 0;"
  css_rules << "  min-width: 320px;"
  css_rules << "  min-height: 100vh;"
  css_rules << "  background:"
  css_rules << "    radial-gradient(circle at 20% 20%, rgba(56, 189, 248, 0.22), transparent 30rem),"
  css_rules << "    radial-gradient(circle at 80% 10%, rgba(168, 85, 247, 0.2), transparent 28rem),"
  css_rules << "    linear-gradient(135deg, #050816 0%, #111827 55%, #172033 100%);"
  css_rules << "}"
  css_rules << ""

  # Page shell
  css_rules << ".page-shell {"
  css_rules << "  min-height: 100vh;"
  css_rules << "  display: grid;"
  css_rules << "  place-items: center;"
  css_rules << "  padding: 2rem;"
  css_rules << "}"
  css_rules << ""

  # Hero card
  css_rules << ".hero-card {"
  css_rules << "  width: min(100%, 56rem);"
  css_rules << "  padding: clamp(2rem, 6vw, 4.5rem);"
  css_rules << "  border: 1px solid rgba(148, 163, 184, 0.28);"
  css_rules << "  border-radius: 2rem;"
  css_rules << "  background: rgba(15, 23, 42, 0.72);"
  css_rules << "  box-shadow: 0 2rem 6rem rgba(0, 0, 0, 0.35);"
  css_rules << "  backdrop-filter: blur(18px);"
  css_rules << "}"
  css_rules << ""

  # Eyebrow
  css_rules << ".eyebrow {"
  css_rules << "  margin: 0 0 1rem;"
  css_rules << "  color: #67e8f9;"
  css_rules << "  font-size: 0.8rem;"
  css_rules << "  font-weight: 700;"
  css_rules << "  letter-spacing: 0.18em;"
  css_rules << "  text-transform: uppercase;"
  css_rules << "}"
  css_rules << ""

  # Heading 1
  css_rules << "h1 {"
  css_rules << "  margin: 0;"
  css_rules << "  max-width: 12ch;"
  css_rules << "  font-size: clamp(2.75rem, 8vw, 6rem);"
  css_rules << "  line-height: 0.95;"
  css_rules << "  letter-spacing: -0.06em;"
  css_rules << "}"
  css_rules << ""

  # Lead paragraph
  css_rules << ".lead {"
  css_rules << "  margin: 1.5rem 0 0;"
  css_rules << "  max-width: 42rem;"
  css_rules << "  color: #cbd5e1;"
  css_rules << "  font-size: clamp(1.05rem, 2vw, 1.35rem);"
  css_rules << "  line-height: 1.65;"
  css_rules << "}"
  css_rules << ""

  # Link grid container
  css_rules << ".link-grid {"
  css_rules << "  display: grid;"
  css_rules << "  gap: 0.85rem;"
  css_rules << "  margin-top: 2rem;"
  css_rules << "}"
  css_rules << ""

  # Link grid links
  css_rules << ".link-grid a {"
  css_rules << "  display: flex;"
  css_rules << "  align-items: center;"
  css_rules << "  justify-content: space-between;"
  css_rules << "  gap: 1rem;"
  css_rules << "  padding: 1rem 1.15rem;"
  css_rules << "  border: 1px solid rgba(148, 163, 184, 0.25);"
  css_rules << "  border-radius: 1rem;"
  css_rules << "  color: #f8fafc;"
  css_rules << "  text-decoration: none;"
  css_rules << "  background: rgba(255, 255, 255, 0.06);"
  css_rules << "}"
  css_rules << ""

  # Link hover and focus states
  css_rules << ".link-grid a:hover,"
  css_rules << ".link-grid a:focus-visible {"
  css_rules << "  border-color: rgba(103, 232, 249, 0.75);"
  css_rules << "  outline: none;"
  css_rules << "  background: rgba(103, 232, 249, 0.12);"
  css_rules << "}"

  css_rules.join("\n")
end

# Main execution
if ARGV.length != 1
  puts "Usage: ruby #{$0} <output_filename>"
  exit 1
end

filename = ARGV[0]
css_content = generate_css

File.open(filename, 'w') do |file|
  file.write(css_content)
end

puts "CSS file generated: #{filename}"
