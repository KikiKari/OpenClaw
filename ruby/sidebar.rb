#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "9179f6a9646d279ddc4d74b30b29b7cf0670f6b56dbb12ef952719df8f1511a0", "source_sha256": "495ea0a0b976b10360709637ad086ec1b1fd4496c479c1d93db8b3acf95f1318", "target_language": "ruby"}
# sidebar.css — portiert nach ruby
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat/sidebar.css
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Split View Layout
def chat_split_container
  {
    display: 'flex',
    gap: '0',
    flex: '1',
    'min-height': '0',
    height: '100%'
  }
end

def chat_main
  {
    'min-width': '312px',
    display: 'flex',
    'flex-direction': 'column',
    overflow: 'hidden',
    # Smooth transition when sidebar opens/closes
    transition: 'flex 250ms ease-out'
  }
end

def chat_sidebar
  {
    flex: '1',
    'min-width': '300px',
    'border-left': '1px solid var(--border)',
    display: 'flex',
    'flex-direction': 'column',
    overflow: 'hidden',
    animation: 'slide-in 200ms ease-out'
  }
end

def keyframes_slide_in
  {
    from: {
      opacity: '0',
      transform: 'translateX(20px)'
    },
    to: {
      opacity: '1',
      transform: 'translateX(0)'
    }
  }
end

# Sidebar Panel
def sidebar_panel
  {
    display: 'flex',
    'flex-direction': 'column',
    height: '100%',
    background: 'var(--panel)'
  }
end

def sidebar_header
  {
    display: 'flex',
    'justify-content': 'space-between',
    'align-items': 'center',
    padding: '12px 16px',
    'border-bottom': '1px solid var(--border)',
    'flex-shrink': '0',
    position: 'sticky',
    top: '0',
    'z-index': '10',
    background: 'var(--panel)'
  }
end

# Smaller close button for sidebar
def sidebar_header_btn
  {
    padding: '4px 8px',
    'font-size': '14px',
    'min-width': 'auto',
    'line-height': '1'
  }
end

def sidebar_title
  {
    'font-weight': '600',
    'font-size': '14px'
  }
end

def sidebar_content
  {
    flex: '1',
    overflow: 'auto',
    padding: '16px'
  }
end

def sidebar_markdown
  {
    'font-size': '14px',
    'line-height': '1.6',
    color: 'var(--text)'
  }
end

# ── Headings ──

def sidebar_markdown_h1
  {
    'font-size': '1.65em',
    'font-weight': '700',
    'letter-spacing': '-0.025em',
    margin: '1.6em 0 0.6em',
    'padding-bottom': '0.35em',
    'border-bottom': '1px solid var(--border)',
    'line-height': '1.25'
  }
end

def sidebar_markdown_h2
  {
    'font-size': '1.35em',
    'font-weight': '650',
    'letter-spacing': '-0.02em',
    margin: '1.4em 0 0.5em',
    'padding-bottom': '0.25em',
    'border-bottom': '1px solid var(--border)',
    'line-height': '1.3'
  }
end

def sidebar_markdown_h3
  {
    'font-size': '1.15em',
    'font-weight': '600',
    'letter-spacing': '-0.01em',
    margin: '1.2em 0 0.4em',
    'line-height': '1.35'
  }
end

def sidebar_markdown_h4_h5_h6
  {
    'font-size': '1em',
    'font-weight': '600',
    margin: '1em 0 0.35em',
    'line-height': '1.4',
    color: 'var(--text-strong)'
  }
end

def sidebar_markdown_first_child_heading
  {
    'margin-top': '0'
  }
end

# ── Paragraphs & spacing ──

def sidebar_markdown_paragraph_spacing
  {
    margin: '0'
  }
end

def sidebar_markdown_paragraph_spacing_next
  {
    'margin-top': '0.75em'
  }
end

def sidebar_markdown_heading_paragraph_spacing
  {
    'margin-top': '0'
  }
end

# ── Lists ──

def sidebar_markdown_lists
  {
    'padding-left': '1.6em'
  }
end

def sidebar_markdown_list_items
  {
    'margin-top': '0.3em'
  }
end

def sidebar_markdown_list_paragraphs
  {
    'margin-top': '0.25em'
  }
end

def sidebar_markdown_nested_lists
  {
    'margin-top': '0.25em'
  }
end

# ── Links ──

def sidebar_markdown_links
  {
    color: 'var(--accent)',
    'text-decoration': 'underline',
    'text-underline-offset': '2px',
    'text-decoration-color': 'color-mix(in srgb, var(--accent) 40%, transparent)',
    transition: 'text-decoration-color var(--duration-fast) ease'
  }
end

def sidebar_markdown_links_hover
  {
    'text-decoration-color': 'var(--accent)'
  }
end

# ── Inline code ──

def sidebar_markdown_code
  {
    'font-family': 'var(--mono)',
    'font-size': '0.88em'
  }
end

def sidebar_markdown_inline_code
  {
    padding: '0.15em 0.4em',
    'border-radius': 'var(--radius-sm)',
    background: 'rgba(0, 0, 0, 0.12)',
    border: '1px solid var(--border)'
  }
end

def sidebar_markdown_inline_code_light
  {
    background: 'rgba(0, 0, 0, 0.06)'
  }
end

# ── Code blocks ──

def sidebar_markdown_pre
  {
    background: 'rgba(0, 0, 0, 0.12)',
    border: '1px solid var(--border)',
    'border-radius': 'var(--radius-md)',
    padding: '14px 16px',
    'overflow-x': 'auto',
    'margin-top': '0.75em'
  }
end

def sidebar_markdown_pre_light
  {
    background: 'rgba(0, 0, 0, 0.04)'
  }
end

def sidebar_markdown_pre_code
  {
    background: 'none',
    border: 'none',
    padding: '0',
    'font-size': '12.5px',
    'line-height': '1.55'
  }
end

# ── Blockquotes ──

def sidebar_markdown_blockquote
  {
    'border-left': '3px solid var(--border-strong)',
    padding: '8px 14px',
    'margin-left': '0',
    'margin-top': '0.75em',
    color: 'var(--muted)',
    background: 'rgba(255, 255, 255, 0.02)',
    'border-radius': '0 var(--radius-sm) var(--radius-sm) 0'
  }
end

def sidebar_markdown_blockquote_light
  {
    background: 'rgba(0, 0, 0, 0.025)'
  }
end

def sidebar_markdown_nested_blockquote
  {
    'margin-top': '8px'
  }
end

# ── Tables ──

def sidebar_markdown_table
  {
    'margin-top': '0.75em',
    'border-collapse': 'collapse',
    width: '100%',
    'font-size': '13px',
    display: 'block',
    'overflow-x': 'auto'
  }
end

def sidebar_markdown_table_cells
  {
    border: '1px solid var(--border)',
    padding: '8px 12px',
    'text-align': 'left',
    'vertical-align': 'top'
  }
end

def sidebar_markdown_th
  {
    'font-weight': '600',
    'font-size': '12px',
    color: 'var(--muted)',
    background: 'var(--secondary)',
    'text-transform': 'uppercase',
    'letter-spacing': '0.03em'
  }
end

def sidebar_markdown_tr_hover
  {
    background: 'var(--bg-hover)'
  }
end

# ── Horizontal rules ──

def sidebar_markdown_hr
  {
    border: 'none',
    'border-top': '1px solid var(--border)',
    margin: '1.5em 0'
  }
end

# ── Bold / italic ──

def sidebar_markdown_strong
  {
    'font-weight': '600',
    color: 'var(--text-strong)'
  }
end

# ── Images ──

def sidebar_markdown_image
  {
    display: 'block',
    'max-width': '100%',
    'max-height': '420px',
    width: 'auto',
    height: 'auto',
    border: '1px solid var(--border)',
    'border-radius': 'var(--radius-md)',
    background: 'color-mix(in srgb, var(--secondary) 70%, transparent)',
    'object-fit': 'contain',
    'margin-top': '0.75em'
  }
end

# ── Details / summary ──

def sidebar_markdown_details
  {
    'margin-top': '0.75em',
    border: '1px solid var(--border)',
    'border-radius': 'var(--radius-md)',
    background: 'var(--bg-elevated)',
    overflow: 'hidden'
  }
end

def sidebar_markdown_summary
  {
    cursor: 'pointer',
    padding: '8px 12px',
    'font-weight': '500',
    'font-size': '13px',
    'user-select': 'none',
    transition: 'background var(--duration-fast) ease'
  }
end

def sidebar_markdown_summary_hover
  {
    background: 'var(--bg-hover)'
  }
end

def sidebar_markdown_details_open
  {
    padding: '0 12px 10px'
  }
end

# Mobile: Full-screen modal
def media_max_width_768_chat_split_container_open
  {
    position: 'fixed',
    top: '0',
    left: '0',
    right: '0',
    bottom: '0',
    'z-index': '1000'
  }
end

def media_max_width_768_chat_main
  {
    display: 'none' # Hide chat on mobile when sidebar open
  }
end

def media_max_width_768_chat_sidebar
  {
    width: '100%',
    'min-width': '0',
    'border-left': 'none'
  }
end

# Helper method to convert hash to CSS string
def hash_to_css(selector, properties)
  css_props = properties.map { |prop, value| "  #{prop}: #{value};" }.join("\n")
  "#{selector} {\n#{css_props}\n}"
end

# Generate the complete CSS
def generate_css
  css_parts = []
  
  # Split View Layout
  css_parts << hash_to_css('.chat-split-container', chat_split_container)
  css_parts << hash_to_css('.chat-main', chat_main)
  css_parts << hash_to_css('.chat-sidebar', chat_sidebar)
  
  # Keyframes
  css_parts << "@keyframes slide-in {\n  from {\n    opacity: 0;\n    transform: translateX(20px);\n  }\n  to {\n    opacity: 1;\n    transform: translateX(0);\n  }\n}"
  
  # Sidebar Panel
  css_parts << hash_to_css('.sidebar-panel', sidebar_panel)
  css_parts << hash_to_css('.sidebar-header', sidebar_header)
  css_parts << hash_to_css('.sidebar-header .btn', sidebar_header_btn)
  css_parts << hash_to_css('.sidebar-title', sidebar_title)
  css_parts << hash_to_css('.sidebar-content', sidebar_content)
  css_parts << hash_to_css('.sidebar-markdown', sidebar_markdown)
  
  # Headings
  css_parts << hash_to_css('.sidebar-markdown :where(h1)', sidebar_markdown_h1)
  css_parts << hash_to_css('.sidebar-markdown :where(h2)', sidebar_markdown_h2)
  css_parts << hash_to_css('.sidebar-markdown :where(h3)', sidebar_markdown_h3)
  css_parts << hash_to_css('.sidebar-markdown :where(h4, h5, h6)', sidebar_markdown_h4_h5_h6)
  css_parts << hash_to_css('.sidebar-markdown > :where(h1, h2, h3, h4, h5, h6):first-child', sidebar_markdown_first_child_heading)
  
  # Paragraphs & spacing
  css_parts << hash_to_css('.sidebar-markdown :where(p, ul, ol, pre, blockquote, table, details)', sidebar_markdown_paragraph_spacing)
  css_parts << hash_to_css('.sidebar-markdown :where(p + p, p + ul, p + ol, p + pre, p + blockquote, p + table, p + details)', sidebar_markdown_paragraph_spacing_next)
  css_parts << hash_to_css('.sidebar-markdown :where(h1 + p, h2 + p, h3 + p, h4 + p)', sidebar_markdown_heading_paragraph_spacing)
  
  # Lists
  css_parts << hash_to_css('.sidebar-markdown :where(ul, ol)', sidebar_markdown_lists)
  css_parts << hash_to_css('.sidebar-markdown :where(li + li)', sidebar_markdown_list_items)
  css_parts << hash_to_css('.sidebar-markdown :where(li > p)', sidebar_markdown_list_paragraphs)
  css_parts << hash_to_css('.sidebar-markdown :where(li > ul, li > ol)', sidebar_markdown_nested_lists)
  
  # Links
  css_parts << hash_to_css('.sidebar-markdown :where(a)', sidebar_markdown_links)
  css_parts << hash_to_css('.sidebar-markdown :where(a:hover)', sidebar_markdown_links_hover)
  
  # Inline code
  css_parts << hash_to_css('.sidebar-markdown code', sidebar_markdown_code)
  css_parts << hash_to_css('.sidebar-markdown :where(:not(pre) > code)', sidebar_markdown_inline_code)
  css_parts << ":root[data-theme-mode=\"light\"] .sidebar-markdown :where(:not(pre) > code) {\n  background: rgba(0, 0, 0, 0.06);\n}"
  
  # Code blocks
  css_parts << hash_to_css('.sidebar-markdown pre', sidebar_markdown_pre)
  css_parts << ":root[data-theme-mode=\"light\"] .sidebar-markdown pre {\n  background: rgba(0, 0, 0, 0.04);\n}"
  css_parts << hash_to_css('.sidebar-markdown :where(pre code)', sidebar_markdown_pre_code)
  
  # Blockquotes
  css_parts << hash_to_css('.sidebar-markdown :where(blockquote)', sidebar_markdown_blockquote)
  css_parts << ":root[data-theme-mode=\"light\"] .sidebar-markdown :where(blockquote) {\n  background: rgba(0, 0, 0, 0.025);\n}"
  css_parts << hash_to_css('.sidebar-markdown :where(blockquote blockquote)', sidebar_markdown_nested_blockquote)
  
  # Tables
  css_parts << hash_to_css('.sidebar-markdown :where(table)', sidebar_markdown_table)
  css_parts << hash_to_css('.sidebar-markdown :where(th, td)', sidebar_markdown_table_cells)
  css_parts << hash_to_css('.sidebar-markdown :where(th)', sidebar_markdown_th)
  css_parts << hash_to_css('.sidebar-markdown :where(tbody tr:hover)', sidebar_markdown_tr_hover)
  
  # Horizontal rules
  css_parts << hash_to_css('.sidebar-markdown :where(hr)', sidebar_markdown_hr)
  
  # Bold / italic
  css_parts << hash_to_css('.sidebar-markdown :where(strong)', sidebar_markdown_strong)
  
  # Images
  css_parts << hash_to_css('.sidebar-markdown .markdown-inline-image', sidebar_markdown_image)
  
  # Details / summary
  css_parts << hash_to_css('.sidebar-markdown :where(details)', sidebar_markdown_details)
  css_parts << hash_to_css('.sidebar-markdown :where(summary)', sidebar_markdown_summary)
  css_parts << hash_to_css('.sidebar-markdown :where(summary:hover)', sidebar_markdown_summary_hover)
  css_parts << hash_to_css('.sidebar-markdown :where(details[open] > :not(summary))', sidebar_markdown_details_open)
  
  # Media queries
  css_parts << "@media (max-width: 768px) {\n  .chat-split-container--open {\n    position: fixed;\n    top: 0;\n    left: 0;\n    right: 0;\n    bottom: 0;\n    z-index: 1000;\n  }\n\n  .chat-split-container--open .chat-main {\n    display: none; /* Hide chat on mobile when sidebar open */\n  }\n\n  .chat-split-container--open .chat-sidebar {\n    width: 100%;\n    min-width: 0;\n    border-left: none;\n  }\n}"
  
  css_parts.join("\n\n")
end

# Main execution
if __FILE__ == $0
  output_file = ARGV[0] || 'sidebar.css'
  
  File.open(output_file, 'w') do |file|
    file.write(generate_css)
  end
  
  puts "CSS file generated: #{output_file}"
end
