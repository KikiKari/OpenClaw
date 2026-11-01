#!/usr/bin/env python3
# status-overview-panel.css — portiert nach python
# Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview-panel.css
# Erzeugt: 2026-11-01 durch ABSTRACTIONS_MANAGER.py

import sys
import argparse
from pathlib import Path

def generate_css():
    """Generate the CSS content for status overview panel"""
    css_rules = []
    
    # Overview row styling
    css_rules.append(".overview-row {")
    css_rules.append("  display: grid;")
    css_rules.append("  grid-template-columns: 24px minmax(0, 1fr) 11px 22px auto;")
    css_rules.append("  gap: 7px;")
    css_rules.append("  align-items: center;")
    css_rules.append("  margin: 6px 0;")
    css_rules.append("}")
    
    css_rules.append("")
    
    css_rules.append(".overview-row input {")
    css_rules.append("  min-width: 0;")
    css_rules.append("  width: 100%;")
    css_rules.append("}")
    
    css_rules.append("")
    
    # State indicators
    css_rules.append(".overview-state {")
    css_rules.append("  width: 11px;")
    css_rules.append("  height: 11px;")
    css_rules.append("  border-radius: 50%;")
    css_rules.append("  background: #888;")
    css_rules.append("}")
    
    css_rules.append("")
    
    css_rules.append(".overview-state.online {")
    css_rules.append("  background: var(--good);")
    css_rules.append("  box-shadow: 0 0 0 3px color-mix(in srgb, var(--good) 15%, transparent);")
    css_rules.append("}")
    
    css_rules.append("")
    
    css_rules.append(".overview-state.offline {")
    css_rules.append("  background: var(--bad);")
    css_rules.append("  box-shadow: 0 0 0 3px color-mix(in srgb, var(--bad) 15%, transparent);")
    css_rules.append("}")
    
    css_rules.append("")
    
    css_rules.append(".overview-state.checking, .overview-state.error {")
    css_rules.append("  background: var(--warn);")
    css_rules.append("}")
    
    css_rules.append("")
    
    # Count display
    css_rules.append(".overview-count {")
    css_rules.append("  font-size: 11px;")
    css_rules.append("  text-align: center;")
    css_rules.append("  font-variant-numeric: tabular-nums;")
    css_rules.append("}")
    
    css_rules.append("")
    
    # Action buttons
    css_rules.append(".overview-actions {")
    css_rules.append("  display: grid;")
    css_rules.append("  grid-template-columns: 44px repeat(2, minmax(0, 1fr));")
    css_rules.append("  gap: 6px;")
    css_rules.append("  align-items: stretch;")
    css_rules.append("}")
    
    css_rules.append("")
    
    css_rules.append(".overview-actions button {")
    css_rules.append("  min-width: 0;")
    css_rules.append("  padding: 8px 2px;")
    css_rules.append("  font-size: 11px;")
    css_rules.append("  white-space: nowrap;")
    css_rules.append("}")
    
    css_rules.append("")
    
    # Rows container
    css_rules.append("#overview-rows {")
    css_rules.append("  display: flex;")
    css_rules.append("  flex-direction: column;")
    css_rules.append("}")
    
    css_rules.append("")
    
    # Monitor settings
    css_rules.append(".monitor-settings > label:not(.option-row) {")
    css_rules.append("  display: block;")
    css_rules.append("  margin: 12px 0;")
    css_rules.append("}")
    
    css_rules.append("")
    
    css_rules.append(".monitor-settings .option-row input {")
    css_rules.append("  appearance: auto;")
    css_rules.append("  width: 13px;")
    css_rules.append("  height: 13px;")
    css_rules.append("  min-width: 13px;")
    css_rules.append("  background: none;")
    css_rules.append("}")
    
    css_rules.append("")
    
    # Link styling
    css_rules.append(".overview-link {")
    css_rules.append("  padding: 8px 0;")
    css_rules.append("  border-bottom: 1px solid #bbb;")
    css_rules.append("  overflow-wrap: anywhere;")
    css_rules.append("}")
    
    css_rules.append("")
    
    css_rules.append(".overview-link p {")
    css_rules.append("  margin: 4px 0;")
    css_rules.append("}")
    
    css_rules.append("")
    
    # Retry button
    css_rules.append(".overview-row .overview-retry {")
    css_rules.append("  width: 24px;")
    css_rules.append("  min-width: 24px;")
    css_rules.append("  height: 26px;")
    css_rules.append("  min-height: 26px;")
    css_rules.append("  padding: 0;")
    css_rules.append("  background-image: var(--icon-reset);")
    css_rules.append("  background-size: 20px;")
    css_rules.append("  background-position: center;")
    css_rules.append("  background-repeat: no-repeat;")
    css_rules.append("}")
    
    css_rules.append("")
    
    # Top setting checkbox
    css_rules.append(".top-setting input {")
    css_rules.append("  appearance: auto;")
    css_rules.append("  -webkit-appearance: checkbox;")
    css_rules.append("  width: 13px;")
    css_rules.append("  height: 13px;")
    css_rules.append("  min-width: 13px;")
    css_rules.append("  background: none;")
    css_rules.append("}")
    
    css_rules.append("")
    
    # Visually hidden elements
    css_rules.append(".overview-visually-hidden {")
    css_rules.append("  position: absolute;")
    css_rules.append("  width: 1px;")
    css_rules.append("  height: 1px;")
    css_rules.append("  padding: 0;")
    css_rules.append("  margin: -1px;")
    css_rules.append("  overflow: hidden;")
    css_rules.append("  clip: rect(0, 0, 0, 0);")
    css_rules.append("  white-space: nowrap;")
    css_rules.append("  border: 0;")
    css_rules.append("}")
    
    css_rules.append("")
    
    # Hidden rows
    css_rules.append(".overview-row[hidden] {")
    css_rules.append("  display: none;")
    css_rules.append("}")
    
    return "\n".join(css_rules)

def main():
    parser = argparse.ArgumentParser(description="Generate status-overview-panel.css file")
    parser.add_argument("output_file", help="Path to the output CSS file")
    
    args = parser.parse_args()
    
    try:
        css_content = generate_css()
        output_path = Path(args.output_file)
        output_path.write_text(css_content, encoding='utf-8')
        print(f"CSS file successfully written to {output_path}")
    except Exception as e:
        print(f"Error writing CSS file: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
