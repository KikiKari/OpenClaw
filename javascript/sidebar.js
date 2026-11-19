#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "d7879843ccc5c67b3b1994e494591fd6c6c989d506244c3440f6eb22b1988c0b", "source_sha256": "495ea0a0b976b10360709637ad086ec1b1fd4496c479c1d93db8b3acf95f1318", "target_language": "javascript"}
// sidebar.css — portiert nach javascript
// Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat/sidebar.css
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

// Helper function to generate CSS from structured data
function generateCSS(rules) {
  let css = '';
  
  for (const [selector, properties] of Object.entries(rules)) {
    css += `${selector} {\n`;
    for (const [prop, value] of Object.entries(properties)) {
      // Convert camelCase to kebab-case for CSS properties
      const kebabProp = prop.replace(/([A-Z])/g, '-$1').toLowerCase();
      css += `  ${kebabProp}: ${value};\n`;
    }
    css += '}\n\n';
  }
  
  return css;
}

// Define the CSS structure
const cssRules = {
  '/* Split View Layout */': {},
  '.chat-split-container': {
    display: 'flex',
    gap: '0',
    flex: '1',
    minHeight: '0',
    height: '100%'
  },
  '.chat-main': {
    minWidth: '312px',
    display: 'flex',
    flexDirection: 'column',
    overflow: 'hidden',
    transition: 'flex 250ms ease-out'
  },
  '.chat-sidebar': {
    flex: '1',
    minWidth: '300px',
    borderLeft: '1px solid var(--border)',
    display: 'flex',
    flexDirection: 'column',
    overflow: 'hidden',
    animation: 'slide-in 200ms ease-out'
  },
  '@keyframes slide-in': {
    from: {
      opacity: '0',
      transform: 'translateX(20px)'
    },
    to: {
      opacity: '1',
      transform: 'translateX(0)'
    }
  },
  '/* Sidebar Panel */': {},
  '.sidebar-panel': {
    display: 'flex',
    flexDirection: 'column',
    height: '100%',
    background: 'var(--panel)'
  },
  '.sidebar-header': {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '12px 16px',
    borderBottom: '1px solid var(--border)',
    flexShrink: '0',
    position: 'sticky',
    top: '0',
    zIndex: '10',
    background: 'var(--panel)'
  },
  '.sidebar-header .btn': {
    padding: '4px 8px',
    fontSize: '14px',
    minWidth: 'auto',
    lineHeight: '1'
  },
  '.sidebar-title': {
    fontWeight: '600',
    fontSize: '14px'
  },
  '.sidebar-content': {
    flex: '1',
    overflow: 'auto',
    padding: '16px'
  },
  '.sidebar-markdown': {
    fontSize: '14px',
    lineHeight: '1.6',
    color: 'var(--text)'
  },
  '/* ── Headings ── */': {},
  '.sidebar-markdown :where(h1)': {
    fontSize: '1.65em',
    fontWeight: '700',
    letterSpacing: '-0.025em',
    margin: '1.6em 0 0.6em',
    paddingBottom: '0.35em',
    borderBottom: '1px solid var(--border)',
    lineHeight: '1.25'
  },
  '.sidebar-markdown :where(h2)': {
    fontSize: '1.35em',
    fontWeight: '650',
    letterSpacing: '-0.02em',
    margin: '1.4em 0 0.5em',
    paddingBottom: '0.25em',
    borderBottom: '1px solid var(--border)',
    lineHeight: '1.3'
  },
  '.sidebar-markdown :where(h3)': {
    fontSize: '1.15em',
    fontWeight: '600',
    letterSpacing: '-0.01em',
    margin: '1.2em 0 0.4em',
    lineHeight: '1.35'
  },
  '.sidebar-markdown :where(h4, h5, h6)': {
    fontSize: '1em',
    fontWeight: '600',
    margin: '1em 0 0.35em',
    lineHeight: '1.4',
    color: 'var(--text-strong)'
  },
  '.sidebar-markdown > :where(h1, h2, h3, h4, h5, h6):first-child': {
    marginTop: '0'
  },
  '/* ── Paragraphs & spacing ── */': {},
  '.sidebar-markdown :where(p, ul, ol, pre, blockquote, table, details)': {
    margin: '0'
  },
  '.sidebar-markdown :where(p + p, p + ul, p + ol, p + pre, p + blockquote, p + table, p + details)': {
    marginTop: '0.75em'
  },
  '.sidebar-markdown :where(h1 + p, h2 + p, h3 + p, h4 + p)': {
    marginTop: '0'
  },
  '/* ── Lists ── */': {},
  '.sidebar-markdown :where(ul, ol)': {
    paddingLeft: '1.6em'
  },
  '.sidebar-markdown :where(li + li)': {
    marginTop: '0.3em'
  },
  '.sidebar-markdown :where(li > p)': {
    marginTop: '0.25em'
  },
  '.sidebar-markdown :where(li > ul, li > ol)': {
    marginTop: '0.25em'
  },
  '/* ── Links ── */': {},
  '.sidebar-markdown :where(a)': {
    color: 'var(--accent)',
    textDecoration: 'underline',
    textUnderlineOffset: '2px',
    textDecorationColor: 'color-mix(in srgb, var(--accent) 40%, transparent)',
    transition: 'text-decoration-color var(--duration-fast) ease'
  },
  '.sidebar-markdown :where(a:hover)': {
    textDecorationColor: 'var(--accent)'
  },
  '/* ── Inline code ── */': {},
  '.sidebar-markdown code': {
    fontFamily: 'var(--mono)',
    fontSize: '0.88em'
  },
  '.sidebar-markdown :where(:not(pre) > code)': {
    padding: '0.15em 0.4em',
    borderRadius: 'var(--radius-sm)',
    background: 'rgba(0, 0, 0, 0.12)',
    border: '1px solid var(--border)'
  },
  ':root[data-theme-mode="light"] .sidebar-markdown :where(:not(pre) > code)': {
    background: 'rgba(0, 0, 0, 0.06)'
  },
  '/* ── Code blocks ── */': {},
  '.sidebar-markdown pre': {
    background: 'rgba(0, 0, 0, 0.12)',
    border: '1px solid var(--border)',
    borderRadius: 'var(--radius-md)',
    padding: '14px 16px',
    overflowX: 'auto',
    marginTop: '0.75em'
  },
  ':root[data-theme-mode="light"] .sidebar-markdown pre': {
    background: 'rgba(0, 0, 0, 0.04)'
  },
  '.sidebar-markdown :where(pre code)': {
    background: 'none',
    border: 'none',
    padding: '0',
    fontSize: '12.5px',
    lineHeight: '1.55'
  },
  '/* ── Blockquotes ── */': {},
  '.sidebar-markdown :where(blockquote)': {
    borderLeft: '3px solid var(--border-strong)',
    padding: '8px 14px',
    marginLeft: '0',
    marginTop: '0.75em',
    color: 'var(--muted)',
    background: 'rgba(255, 255, 255, 0.02)',
    borderRadius: '0 var(--radius-sm) var(--radius-sm) 0'
  },
  ':root[data-theme-mode="light"] .sidebar-markdown :where(blockquote)': {
    background: 'rgba(0, 0, 0, 0.025)'
  },
  '.sidebar-markdown :where(blockquote blockquote)': {
    marginTop: '8px'
  },
  '/* ── Tables ── */': {},
  '.sidebar-markdown :where(table)': {
    marginTop: '0.75em',
    borderCollapse: 'collapse',
    width: '100%',
    fontSize: '13px',
    display: 'block',
    overflowX: 'auto'
  },
  '.sidebar-markdown :where(th, td)': {
    border: '1px solid var(--border)',
    padding: '8px 12px',
    textAlign: 'left',
    verticalAlign: 'top'
  },
  '.sidebar-markdown :where(th)': {
    fontWeight: '600',
    fontSize: '12px',
    color: 'var(--muted)',
    background: 'var(--secondary)',
    textTransform: 'uppercase',
    letterSpacing: '0.03em'
  },
  '.sidebar-markdown :where(tbody tr:hover)': {
    background: 'var(--bg-hover)'
  },
  '/* ── Horizontal rules ── */': {},
  '.sidebar-markdown :where(hr)': {
    border: 'none',
    borderTop: '1px solid var(--border)',
    margin: '1.5em 0'
  },
  '/* ── Bold / italic ── */': {},
  '.sidebar-markdown :where(strong)': {
    fontWeight: '600',
    color: 'var(--text-strong)'
  },
  '/* ── Images ── */': {},
  '.sidebar-markdown .markdown-inline-image': {
    display: 'block',
    maxWidth: '100%',
    maxHeight: '420px',
    width: 'auto',
    height: 'auto',
    border: '1px solid var(--border)',
    borderRadius: 'var(--radius-md)',
    background: 'color-mix(in srgb, var(--secondary) 70%, transparent)',
    objectFit: 'contain',
    marginTop: '0.75em'
  },
  '/* ── Details / summary ── */': {},
  '.sidebar-markdown :where(details)': {
    marginTop: '0.75em',
    border: '1px solid var(--border)',
    borderRadius: 'var(--radius-md)',
    background: 'var(--bg-elevated)',
    overflow: 'hidden'
  },
  '.sidebar-markdown :where(summary)': {
    cursor: 'pointer',
    padding: '8px 12px',
    fontWeight: '500',
    fontSize: '13px',
    userSelect: 'none',
    transition: 'background var(--duration-fast) ease'
  },
  '.sidebar-markdown :where(summary:hover)': {
    background: 'var(--bg-hover)'
  },
  '.sidebar-markdown :where(details[open] > :not(summary))': {
    padding: '0 12px 10px'
  },
  '/* Mobile: Full-screen modal */': {},
  '@media (max-width: 768px)': {
    '.chat-split-container--open': {
      position: 'fixed',
      top: '0',
      left: '0',
      right: '0',
      bottom: '0',
      zIndex: '1000'
    },
    '.chat-split-container--open .chat-main': {
      display: 'none'
    },
    '.chat-split-container--open .chat-sidebar': {
      width: '100%',
      minWidth: '0',
      borderLeft: 'none'
    }
  }
};

// Generate CSS content
let cssContent = '';

// Add comments and rules in order
Object.keys(cssRules).forEach(key => {
  if (key.startsWith('/*') && key.endsWith('*/')) {
    cssContent += `${key}\n\n`;
  } else if (key === '@keyframes slide-in') {
    cssContent += '@keyframes slide-in {\n';
    const frames = cssRules[key];
    Object.keys(frames.from).forEach(prop => {
      const kebabProp = prop.replace(/([A-Z])/g, '-$1').toLowerCase();
      cssContent += `  from { ${kebabProp}: ${frames.from[prop]}; }\n`;
    });
    Object.keys(frames.to).forEach(prop => {
      const kebabProp = prop.replace(/([A-Z])/g, '-$1').toLowerCase();
      cssContent += `  to { ${kebabProp}: ${frames.to[prop]}; }\n`;
    });
    cssContent += '}\n\n';
  } else if (key === '@media (max-width: 768px)') {
    cssContent += '@media (max-width: 768px) {\n';
    const mediaRules = cssRules[key];
    Object.keys(mediaRules).forEach(selector => {
      cssContent += `  ${selector} {\n`;
      const props = mediaRules[selector];
      Object.keys(props).forEach(prop => {
        const kebabProp = prop.replace(/([A-Z])/g, '-$1').toLowerCase();
        cssContent += `    ${kebabProp}: ${props[prop]};\n`;
      });
      cssContent += '  }\n';
    });
    cssContent += '}\n\n';
  } else {
    const props = cssRules[key];
    cssContent += `${key} {\n`;
    Object.keys(props).forEach(prop => {
      const kebabProp = prop.replace(/([A-Z])/g, '-$1').toLowerCase();
      cssContent += `  ${kebabProp}: ${props[prop]};\n`;
    });
    cssContent += '}\n\n';
  }
});

// Write to file if output path provided
if (process.argv[2]) {
  const outputPath = resolve(process.argv[2]);
  writeFileSync(outputPath, cssContent.trim());
} else {
  console.log(cssContent.trim());
}
