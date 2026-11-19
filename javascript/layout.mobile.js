#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "9e49e64183201992b37e3913f35170480baed9b2ca6bec903e9a287b159a6994", "source_sha256": "5712dd46fb92b3dc310552cb9baf6971767b66e882a9cb77625ed4ead9a18a79", "target_language": "javascript"}
// layout.mobile.css — portiert nach javascript
// Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/layout.mobile.css
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');

function generateCSS() {
  const cssRules = [];

  // Helper function to add media query rules
  function addMediaQuery(query, rules) {
    cssRules.push(`@media ${query} {`);
    rules.forEach(rule => {
      if (typeof rule === 'string') {
        cssRules.push(`  ${rule}`);
      } else {
        cssRules.push(`  ${rule.selector} {`);
        Object.entries(rule.properties).forEach(([prop, value]) => {
          cssRules.push(`    ${prop}: ${value};`);
        });
        cssRules.push(`  }`);
      }
    });
    cssRules.push(`}`);
  }

  // Tablet and smaller styles
  addMediaQuery('(max-width: 1100px)', [
    {
      selector: '.shell, .shell--nav-collapsed',
      properties: {
        'grid-template-columns': 'minmax(0, 1fr)',
        'grid-template-rows': 'var(--shell-topbar-height) minmax(0, 1fr)',
        'grid-template-areas': '"topbar" "content"'
      }
    },
    {
      selector: '.shell--chat-focus',
      properties: {
        'grid-template-rows': 'var(--shell-topbar-height) minmax(0, 1fr)'
      }
    },
    {
      selector: '.shell-nav, .shell--nav-collapsed .shell-nav',
      properties: {
        'position': 'fixed',
        'top': '0',
        'bottom': '0',
        'left': '0',
        'z-index': '70',
        'width': 'min(86vw, 320px)',
        'min-width': '0',
        'border-right': 'none',
        'box-shadow': '0 30px 80px color-mix(in srgb, black 40%, transparent)',
        'transform': 'translateX(-100%)',
        'opacity': '0',
        'pointer-events': 'none',
        'transition': 'transform var(--shell-focus-duration) var(--shell-focus-ease), opacity var(--shell-focus-duration) var(--shell-focus-ease)'
      }
    },
    {
      selector: '.shell--nav-collapsed:not(.shell--nav-drawer-open) .shell-nav',
      properties: {
        'width': 'var(--shell-nav-rail-width)',
        'transform': 'translateX(0)',
        'opacity': '1',
        'pointer-events': 'auto',
        'box-shadow': 'none'
      }
    },
    {
      selector: '.shell--nav-drawer-open .shell-nav, .shell--nav-collapsed.shell--nav-drawer-open .shell-nav',
      properties: {
        'transform': 'translateX(0)',
        'opacity': '1',
        'pointer-events': 'auto'
      }
    },
    {
      selector: '.shell-nav-backdrop',
      properties: {
        'display': 'block',
        'position': 'fixed',
        'inset': '0',
        'z-index': '65',
        'border': '0',
        'background': 'color-mix(in srgb, black 52%, transparent)',
        'opacity': '0',
        'pointer-events': 'none',
        'transition': 'opacity var(--shell-focus-duration) var(--shell-focus-ease)'
      }
    },
    {
      selector: '.shell--nav-drawer-open .shell-nav-backdrop',
      properties: {
        'opacity': '1',
        'pointer-events': 'auto'
      }
    },
    {
      selector: '.topbar-nav-toggle',
      properties: {
        'display': 'inline-flex',
        'align-items': 'center',
        'justify-content': 'center',
        'width': '38px',
        'height': '38px',
        'padding': '0',
        'border': '1px solid color-mix(in srgb, var(--border) 84%, transparent)',
        'border-radius': 'var(--radius-full)',
        'background': 'color-mix(in srgb, var(--bg-elevated) 80%, transparent)',
        'color': 'var(--muted)',
        'box-shadow': 'inset 0 1px 0 color-mix(in srgb, white 8%, transparent)'
      }
    },
    {
      selector: '.sidebar, .sidebar--collapsed',
      properties: {
        'width': '100%',
        'min-width': '0',
        'flex': '1 1 auto',
        'flex-direction': 'column',
        'align-items': 'stretch',
        'border-right': 'none'
      }
    },
    {
      selector: '.sidebar-shell, .sidebar--collapsed .sidebar-shell',
      properties: {
        'padding': '18px 16px 14px',
        'border-radius': '0'
      }
    },
    {
      selector: '.shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar-shell, .shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar--collapsed .sidebar-shell',
      properties: {
        'padding': '12px 8px 10px'
      }
    },
    {
      selector: '.sidebar-shell__header',
      properties: {
        'min-height': '0',
        'padding': '0 4px 16px'
      }
    },
    {
      selector: '.sidebar-shell__header .nav-collapse-toggle',
      properties: {
        'display': 'none'
      }
    },
    {
      selector: '.shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar-shell__header',
      properties: {
        'justify-content': 'center',
        'align-items': 'center',
        'gap': '0',
        'padding': '0 2px 16px'
      }
    },
    {
      selector: '.sidebar-nav, .sidebar--collapsed .sidebar-nav',
      properties: {
        'flex': '1 1 auto',
        'display': 'block',
        'padding': '0',
        'overflow-x': 'hidden',
        'overflow-y': 'auto',
        'scrollbar-width': 'none'
      }
    },
    '.sidebar-nav::-webkit-scrollbar, .sidebar--collapsed .sidebar-nav::-webkit-scrollbar { display: none; }',
    {
      selector: '.nav-section, .sidebar--collapsed .nav-section',
      properties: {
        'display': 'grid',
        'margin-bottom': '16px'
      }
    },
    {
      selector: '.sidebar-nav .nav-section__label, .sidebar--collapsed .nav-section__label',
      properties: {
        'display': 'flex'
      }
    },
    {
      selector: '.nav-item, .sidebar--collapsed .nav-item',
      properties: {
        'margin': '0',
        'min-height': '40px',
        'padding': '0 12px',
        'font-size': '13px',
        'border-radius': 'var(--radius-md)',
        'white-space': 'nowrap',
        'flex': '0 0 auto',
        'width': 'auto'
      }
    },
    {
      selector: '.shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar--collapsed .nav-item',
      properties: {
        'justify-content': 'center',
        'width': '44px',
        'min-height': '44px',
        'padding': '0',
        'margin': '0 auto',
        'border-radius': 'var(--radius-lg)'
      }
    },
    {
      selector: '.sidebar--collapsed .nav-item--active::before, .sidebar--collapsed .nav-item.active::before',
      properties: {
        'content': 'none'
      }
    },
    {
      selector: '.sidebar--collapsed .nav-item__text, .sidebar--collapsed .nav-item__external-icon',
      properties: {
        'display': 'inline-flex'
      }
    },
    {
      selector: '.shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar--collapsed .nav-item__text, .shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar--collapsed .nav-item__external-icon',
      properties: {
        'display': 'none'
      }
    },
    {
      selector: '.shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar--collapsed .nav-item--active::before, .shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar--collapsed .nav-item.active::before',
      properties: {
        'content': '""',
        'position': 'absolute',
        'left': '8px',
        'top': '10px',
        'bottom': '10px',
        'width': '3px',
        'border-radius': 'var(--radius-full)',
        'background': 'color-mix(in srgb, var(--accent) 86%, transparent)',
        'box-shadow': '0 0 14px color-mix(in srgb, var(--accent) 34%, transparent)'
      }
    },
    {
      selector: '.sidebar--collapsed .sidebar-shell__footer',
      properties: {
        'padding': '12px 8px 0'
      }
    },
    {
      selector: '.sidebar--collapsed .sidebar-version',
      properties: {
        'width': 'auto',
        'min-height': '40px',
        'padding': '0 12px'
      }
    },
    {
      selector: '.shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar--collapsed .sidebar-shell__footer',
      properties: {
        'padding': '8px 0 2px'
      }
    },
    {
      selector: '.shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar--collapsed .sidebar-version',
      properties: {
        'width': '44px',
        'min-height': '44px',
        'padding': '0',
        'justify-content': 'center'
      }
    },
    {
      selector: '.shell--nav-collapsed:not(.shell--nav-drawer-open) .sidebar-mode-switch',
      properties: {
        'display': 'none'
      }
    }
  ]);

  // Mobile-specific styles
  addMediaQuery('(max-width: 768px)', [
    '.shell { --shell-pad: 8px; --shell-gap: 8px; }',
    {
      selector: '.topbar',
      properties: {
        'padding': '10px 12px',
        'min-height': 'auto'
      }
    },
    {
      selector: '.topnav-shell',
      properties: {
        'flex-wrap': 'wrap',
        'gap': '10px'
      }
    },
    {
      selector: '.topnav-shell__actions',
      properties: {
        'min-width': '0',
        'flex': '1 1 auto',
        'justify-content': 'space-between',
        'gap': '10px',
        'align-items': 'stretch'
      }
    },
    {
      selector: '.topnav-shell__content',
      properties: {
        'display': 'none',
        'width': '100%'
      }
    },
    {
      selector: '.topbar-nav-toggle',
      properties: {
        'display': 'inline-flex',
        'align-items': 'center',
        'justify-content': 'center',
        'flex-shrink': '0',
        'width': '38px',
        'height': '38px',
        'padding': '0',
        'border': '1px solid color-mix(in srgb, var(--border) 84%, transparent)',
        'border-radius': 'var(--radius-full)',
        'background': 'color-mix(in srgb, var(--bg-elevated) 80%, transparent)',
        'color': 'var(--muted)',
        'box-shadow': 'inset 0 1px 0 color-mix(in srgb, white 8%, transparent)'
      }
    },
    {
      selector: '.topbar-status',
      properties: {
        'gap': '6px',
        'width': 'auto',
        'flex-wrap': 'nowrap'
      }
    },
    {
      selector: '.topbar-search',
      properties: {
        'min-width': '0',
        'flex': '1'
      }
    },
    {
      selector: '.topbar-theme-mode',
      properties: {
        'display': 'none'
      }
    },
    {
      selector: '.sidebar-mode-switch',
      properties: {
        'display': 'block'
      }
    },
    {
      selector: '.sidebar-mode-switch .topbar-theme-mode',
      properties: {
        'display': 'inline-flex',
        'width': '100%',
        'justify-content': 'center'
      }
    },
    {
      selector: '.topbar-status .pill',
      properties: {
        'padding': '4px 8px',
        'font-size': '11px',
        'gap': '4px'
      }
    },
    {
      selector: '.topbar-status .pill .mono',
      properties: {
        'display': 'none'
      }
    },
    '.topbar-status .pill span:nth-child(2) { display: none; }',
    {
      selector: '.shell-nav, .shell--nav-collapsed .shell-nav',
      properties: {
        'width': 'min(92vw, 320px)'
      }
    },
    {
      selector: '.shell--nav-collapsed:not(.shell--nav-drawer-open) .shell-nav',
      properties: {
        'width': '78px'
      }
    },
    {
      selector: '.sidebar-shell, .sidebar--collapsed .sidebar-shell',
      properties: {
        'padding': '16px 14px 12px'
      }
    },
    {
      selector: '.nav-item, .sidebar--collapsed .nav-item',
      properties: {
        'font-size': '12px'
      }
    },
    {
      selector: '.content-header',
      properties: {
        'display': 'none'
      }
    },
    '.content--chat .content-header { display: none; }',
    {
      selector: '.content--chat',
      properties: {
        'gap': '2px'
      }
    },
    {
      selector: '.chat-mobile-controls-wrapper',
      properties: {
        'display': 'flex',
        'position': 'relative'
      }
    },
    {
      selector: '.chat-mobile-controls-wrapper .chat-controls-mobile-toggle',
      properties: {
        'display': 'flex'
      }
    },
    {
      selector: '.chat-mobile-controls-wrapper .chat-controls-dropdown',
      properties: {
        'display': 'none',
        'position': 'absolute',
        'top': '100%',
        'right': '0',
        'z-index': '100',
        'background': 'var(--card, #161b22)',
        'border': '1px solid var(--border, #30363d)',
        'border-radius': 'var(--radius-md)',
        'padding': '8px',
        'box-shadow': '0 8px 24px rgba(0, 0, 0, 0.4)',
        'flex-direction': 'column',
        'gap': '4px',
        'min-width': '220px'
      }
    },
    '.chat-mobile-controls-wrapper .chat-controls-dropdown.open { display: flex; }',
    {
      selector: '.chat-mobile-controls-wrapper .chat-controls-dropdown .chat-controls',
      properties: {
        'display': 'flex',
        'flex-direction': 'column',
        'gap': '4px',
        'width': '100%'
      }
    },
    {
      selector: '.chat-mobile-controls-wrapper .chat-controls-dropdown .chat-controls__session',
      properties: {
        'min-width': 'unset',
        'max-width': 'unset',
        'width': '100%'
      }
    },
    {
      selector: '.chat-mobile-controls-wrapper .chat-controls-dropdown .chat-controls__session select',
      properties: {
        'width': '100%',
        'font-size': '14px',
        'padding': '10px 12px'
      }
    },
    {
      selector: '.chat-mobile-controls-wrapper .chat-controls-dropdown .chat-controls__thinking',
      properties: {
        'display': 'flex',
        'flex-direction': 'row',
        'gap': '6px',
        'padding': '4px 0',
        'justify-content': 'center'
      }
    },
    {
      selector: '.chat-mobile-controls-wrapper .chat-controls-dropdown .btn--icon',
      properties: {
        'min-width': '44px',
        'height': '44px'
      }
    },
    {
      selector: '.content',
      properties: {
        'padding': '4px 4px 16px',
        'gap': '12px'
      }
    },
    {
      selector: '.card',
      properties: {
        'padding': '12px',
        'border-radius': 'var(--radius-md)'
      }
    },
    {
      selector: '.card-title',
      properties: {
        'font-size': '13px'
      }
    },
    {
      selector: '.stat-grid',
      properties: {
        'gap': '8px',
        'grid-template-columns': 'repeat(2, 1fr)'
      }
    },
    {
      selector: '.stat',
      properties: {
        'padding': '10px',
        'border-radius': 'var(--radius-md)'
      }
    },
    {
      selector: '.stat-label',
      properties: {
        'font-size': '11px'
      }
    },
    {
      selector: '.stat-value',
      properties: {
        'font-size': '18px'
      }
    },
    {
      selector: '.note-grid',
      properties: {
        'grid-template-columns': '1fr',
        'gap': '8px'
      }
    },
    {
      selector: '.form-grid',
      properties: {
        'grid-template-columns': '1fr',
        'gap': '10px'
      }
    },
    {
      selector: '.field input, .field textarea, .field select',
      properties: {
        'padding': '8px 10px',
        'border-radius': 'var(--radius-md)',
        'font-size': '14px'
      }
    },
    {
      selector: '.btn',
      properties: {
        'padding': '8px 12px',
        'font-size': '12px'
      }
    },
    {
      selector: '.pill',
      properties: {
        'padding': '4px 10px',
        'font-size': '12px'
      }
    },
    {
      selector: '.chat-header',
      properties: {
        'flex-direction': 'column',
        'align-items': 'stretch',
        'gap': '8px'
      }
    },
    {
      selector: '.chat-header__left',
      properties: {
        'flex-direction': 'column',
        'align-items': 'stretch'
      }
    },
    {
      selector: '.chat-header__right',
      properties: {
        'justify-content': 'space-between'
      }
    },
    {
      selector: '.chat-session',
      properties: {
        'min-width': 'unset',
        'width': '100%'
      }
    },
    {
      selector: '.chat-thread',
      properties: {
        'margin-top': '0',
        'padding': '0 8px 12px'
      }
    },
    {
      selector: '.chat-msg',
      properties: {
        'max-width': '90%'
      }
    },
    {
      selector: '.chat-bubble',
      properties: {
        'padding': '8px 12px',
        'border-radius': 'var(--radius-md)'
      }
    },
    {
      selector: '.chat-compose',
      properties: {
        'gap': '8px'
      }
    },
    {
      selector: '.chat-compose__field textarea',
      properties: {
        'min-height': '60px',
        'padding': '8px 10px',
        'border-radius': 'var(--radius-md)',
        'font-size': '14px'
      }
    },
    {
      selector: '.agent-chat__input',
      properties: {
        'margin': '0 8px 10px'
      }
    },
    {
      selector: '.agent-chat__toolbar',
      properties: {
        'padding': '4px 8px'
      }
    },
    {
      selector: '.agent-chat__input-btn, .agent-chat__toolbar .btn--ghost',
      properties: {
        'width': '28px',
        'height': '28px'
      }
    },
    {
      selector: '.agent-chat__input-btn svg, .agent-chat__toolbar .btn--ghost svg',
      properties: {
        'width': '14px',
        'height': '14px'
      }
    },
    {
      selector: '.log-stream',
      properties: {
        'border-radius': 'var(--radius-md)',
        'max-height': '380px'
      }
    },
    {
      selector: '.log-row',
      properties: {
        'grid-template-columns': '1fr',
        'gap': '4px',
        'padding': '8px'
      }
    },
    {
      selector: '.log-time',
      properties: {
        'font-size': '10px'
      }
    },
    {
      selector: '.log-level',
      properties: {
        'font-size': '9px'
      }
    },
    {
      selector: '.log-subsystem',
      properties: {
        'font-size': '11px'
      }
    },
    {
      selector: '.log-message',
      properties: {
        'font-size': '12px'
      }
    },
    {
      selector: '.list-item',
      properties: {
        'padding': '10px',
        'border-radius': 'var(--radius-md)'
      }
    },
    {
      selector: '.list-title',
      properties: {
        'font-size': '13px'
      }
    },
    {
      selector: '.list-sub',
      properties: {
        'font-size': '11px'
      }
    },
    {
      selector: '.code-block',
      properties: {
        'padding': '8px',
        'border-radius': 'var(--radius-md)',
        'font-size': '11px'
      }
    },
    {
      selector: '.theme-orb__trigger',
      properties: {
        'width': '26px',
        'height': '26px',
        'font-size': '13px'
      }
    }
  ]);

  // Small mobile styles
  addMediaQuery('(max-width: 400px)', [
    '.shell { --shell-pad: 4px; }',
    {
      selector: '.topbar',
      properties: {
        'padding': '8px 10px'
      }
    },
    {
      selector: '.brand-title',
      properties: {
        'font-size': '13px'
      }
    },
    {
      selector: '.nav-item',
      properties: {
        'padding': '6px 8px',
        'font-size': '11px'
      }
    },
    {
      selector: '.content',
      properties: {
        'padding': '4px 4px 12px',
        'gap': '10px'
      }
    },
    {
      selector: '.card',
      properties: {
        'padding': '10px'
      }
    },
    {
      selector: '.stat',
      properties: {
        'padding': '8px'
      }
    },
    {
      selector: '.stat-value',
      properties: {
        'font-size': '16px'
      }
    },
    {
      selector: '.chat-bubble',
      properties: {
        'padding': '8px 10px'
      }
    },
    {
      selector: '.chat-compose__field textarea',
      properties: {
        'min-height': '52px',
        'padding': '8px 10px',
        'font-size': '13px'
      }
    },
    {
      selector: '.btn',
      properties: {
        'padding': '6px 10px',
        'font-size': '11px'
      }
    },
    {
      selector: '.topbar-status .pill',
      properties: {
        'padding': '3px 6px',
        'font-size': '10px'
      }
    },
    {
      selector: '.theme-orb__trigger',
      properties: {
        'width': '24px',
        'height': '24px',
        'font-size': '12px'
      }
    }
  ]);

  // Sessions table responsive column hiding
  addMediaQuery('(max-width: 1400px)', [
    '.data-table th:nth-child(9), .data-table td:nth-child(9), .data-table th:nth-child(10), .data-table td:nth-child(10) { display: none; }'
  ]);

  addMediaQuery('(max-width: 1100px)', [
    '.data-table th:nth-child(4), .data-table td:nth-child(4), .data-table th:nth-child(8), .data-table td:nth-child(8) { display: none; }',
    {
      selector: '.data-table th, .data-table td',
      properties: {
        'padding': '8px 10px'
      }
    }
  ]);

  addMediaQuery('(max-width: 900px)', [
    '.data-table th:nth-child(3), .data-table td:nth-child(3), .data-table th:nth-child(7), .data-table td:nth-child(7) { display: none; }'
  ]);

  addMediaQuery('(max-width: 768px)', [
    '.data-table th:nth-child(6), .data-table td:nth-child(6) { display: none; }',
    {
      selector: '.data-table th, .data-table td',
      properties: {
        'padding': '8px 6px',
        'font-size': '12px'
      }
    },
    {
      selector: '.data-table-pagination',
      properties: {
        'flex-direction': 'column',
        'align-items': 'stretch',
        'gap': '8px',
        'padding': '10px 8px'
      }
    },
    {
      selector: '.data-table-pagination__info',
      properties: {
        'text-align': 'center'
      }
    },
    {
      selector: '.data-table-pagination__controls',
      properties: {
        'justify-content': 'center'
      }
    },
    {
      selector: '.data-table-search input',
      properties: {
        'font-size': '14px',
        'padding': '8px 10px'
      }
    },
    {
      selector: '.data-table-wrapper',
      properties: {
        'border-radius': 'var(--radius-sm)'
      }
    },
    {
      selector: '.session-key-cell',
      properties: {
        'max-width': '200px'
      }
    },
    '.session-key-cell .session-link, .session-key-cell .session-key-display-name { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; overflow-wrap: normal; word-break: normal; }',
    {
      selector: '.filters',
      properties: {
        'flex-wrap': 'wrap',
        'gap': '8px'
      }
    }
  ]);

  addMediaQuery('(max-width: 500px)', [
    {
      selector: '.data-table th, .data-table td',
      properties: {
        'padding': '6px 4px',
        'font-size': '11px'
      }
    },
    {
      selector: '.session-key-cell',
      properties: {
        'max-width': '140px'
      }
    }
  ]);

  return cssRules.join('\n\n');
}

function main() {
  const args = process.argv.slice(2);
  
  if (args.length !== 1) {
    console.error('Usage: node script.js <output-file>');
    process.exit(1);
  }
  
  const outputFile = args[0];
  const cssContent = generateCSS();
  
  try {
    fs.writeFileSync(outputFile, cssContent);
    console.log(`CSS file generated successfully: ${outputFile}`);
  } catch (error) {
    console.error(`Error writing file: ${error.message}`);
    process.exit(1);
  }
}

main();
