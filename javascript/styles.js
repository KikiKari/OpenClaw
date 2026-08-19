#!/usr/bin/env node
// styles.css — portiert nach javascript
// Quelle: css, Projects@TikTok-Live-Companion:site/src/styles.css
// auch in: Projects@TikTok-Live-Companion-Android:site/src/styles.css
// auch in: Projects@TikTok-Live-Companion-iOS:site/src/styles.css
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import path from 'path';

// Helper function to create CSS rules
function createRule(selector, properties) {
    const propStrings = Object.entries(properties)
        .map(([key, value]) => `  ${key}: ${value};`)
        .join('\n');
    return `${selector} {\n${propStrings}\n}`;
}

// Generate the complete CSS content
function generateCSS() {
    let cssContent = '';

    // Root variables
    cssContent += ':root {\n';
    cssContent += '  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;\n';
    cssContent += '  color: #16233d;\n';
    cssContent += '  background: #fffdf9;\n';
    cssContent += '  font-synthesis: none;\n';
    cssContent += '  text-rendering: optimizeLegibility;\n';
    cssContent += '  --ink: #16233d;\n';
    cssContent += '  --muted: #60708b;\n';
    cssContent += '  --paper: #fffdf9;\n';
    cssContent += '  --panel: #ffffff;\n';
    cssContent += '  --wash: #eefaff;\n';
    cssContent += '  --line: #d9e2ec;\n';
    cssContent += '  --coral: #f15a58;\n';
    cssContent += '  --coral-dark: #c84245;\n';
    cssContent += '  --cyan: #10b6d4;\n';
    cssContent += '  --cyan-dark: #087e99;\n';
    cssContent += '  --navy: #14223c;\n';
    cssContent += '  --shadow: 0 22px 55px rgba(23, 54, 83, .14);\n';
    cssContent += '}\n\n';

    // Base styles
    cssContent += createRule('*', {
        'box-sizing': 'border-box'
    }) + '\n\n';
    
    cssContent += createRule('html', {
        'scroll-behavior': 'smooth',
        'max-width': '100%',
        'overflow-x': 'hidden'
    }) + '\n\n';
    
    cssContent += createRule('body', {
        'margin': '0',
        'min-width': '320px',
        'min-height': '100vh',
        'max-width': '100%',
        'overflow-x': 'hidden',
        'background': 'var(--paper)'
    }) + '\n\n';
    
    cssContent += createRule('a', {
        'color': 'inherit'
    }) + '\n\n';
    
    cssContent += createRule('button, input', {
        'font': 'inherit'
    }) + '\n\n';
    
    cssContent += createRule('button, a', {
        '-webkit-tap-highlight-color': 'transparent'
    }) + '\n\n';
    
    cssContent += createRule('button:focus-visible, a:focus-visible, input:focus-visible, summary:focus-visible', {
        'outline': '3px solid #0a7f9d',
        'outline-offset': '3px'
    }) + '\n\n';

    // Utility classes
    cssContent += createRule('.page-width', {
        'width': 'min(1180px, calc(100% - 40px))',
        'margin-inline': 'auto'
    }) + '\n\n';
    
    cssContent += createRule('.icon', {
        'width': '20px',
        'height': '20px',
        'flex': '0 0 auto'
    }) + '\n\n';

    // Skip link
    cssContent += createRule('.skip-link', {
        'position': 'fixed',
        'z-index': '100',
        'top': '12px',
        'left': '12px',
        'padding': '10px 16px',
        'border-radius': '8px',
        'background': 'var(--navy)',
        'color': 'white',
        'transform': 'translateY(-160%)'
    }) + '\n\n';
    
    cssContent += createRule('.skip-link:focus', {
        'transform': 'translateY(0)'
    }) + '\n\n';

    // Site header
    cssContent += createRule('.site-header', {
        'min-height': '74px',
        'display': 'flex',
        'align-items': 'center',
        'gap': '30px',
        'padding': '12px max(24px, calc((100vw - 1240px) / 2))',
        'border-bottom': '1px solid rgba(217, 226, 236, .8)',
        'background': 'rgba(255, 253, 249, .95)',
        'position': 'sticky',
        'top': '0',
        'z-index': '50',
        'backdrop-filter': 'blur(12px)'
    }) + '\n\n';
    
    cssContent += createRule('.brand', {
        'display': 'inline-flex',
        'align-items': 'center',
        'gap': '10px',
        'text-decoration': 'none',
        'font-weight': '800',
        'white-space': 'nowrap',
        'letter-spacing': '-.02em'
    }) + '\n\n';
    
    cssContent += createRule('.brand b', {
        'color': 'var(--coral-dark)'
    }) + '\n\n';
    
    cssContent += createRule('.brand-mark', {
        'width': '28px',
        'height': '28px',
        'display': 'block',
        'object-fit': 'contain',
        'flex': '0 0 auto'
    }) + '\n\n';
    
    cssContent += createRule('.site-header nav', {
        'display': 'flex',
        'align-items': 'center',
        'gap': '24px',
        'margin-inline': 'auto'
    }) + '\n\n';
    
    cssContent += createRule('.site-header nav a', {
        'text-decoration': 'none',
        'font-size': '.9rem',
        'font-weight': '650',
        'color': '#42516b',
        'padding': '11px 0',
        'border-bottom': '2px solid transparent'
    }) + '\n\n';
    
    cssContent += createRule('.site-header nav a:hover, .site-header nav a.active', {
        'color': 'var(--ink)',
        'border-bottom-color': 'var(--coral)'
    }) + '\n\n';
    
    cssContent += createRule('.header-tools', {
        'display': 'flex',
        'align-items': 'center',
        'gap': '16px'
    }) + '\n\n';
    
    cssContent += createRule('.search-button', {
        'border': '1px solid var(--line)',
        'border-radius': '10px',
        'background': 'white',
        'color': '#526078',
        'padding': '8px 10px',
        'display': 'inline-flex',
        'align-items': 'center',
        'gap': '8px',
        'cursor': 'pointer'
    }) + '\n\n';
    
    cssContent += createRule('.search-button kbd', {
        'color': '#758198',
        'background': '#f2f5f8',
        'border-radius': '5px',
        'padding': '2px 5px',
        'font-size': '.7rem'
    }) + '\n\n';
    
    cssContent += createRule('.language-switch', {
        'text-decoration': 'none',
        'font-size': '.82rem',
        'font-weight': '800'
    }) + '\n\n';
    
    cssContent += createRule('.language-switch span', {
        'color': '#a9b2bf',
        'margin-inline': '4px'
    }) + '\n\n';

    // Hero section
    cssContent += createRule('.hero', {
        'min-height': '600px',
        'display': 'grid',
        'grid-template-columns': '.9fr 1.1fr',
        'gap': '54px',
        'align-items': 'center',
        'padding-block': '78px 64px'
    }) + '\n\n';
    
    cssContent += createRule('.hero h1, .content-page > h1', {
        'margin': '0',
        'font-size': 'clamp(2.35rem, 5vw, 4.4rem)',
        'line-height': '1.04',
        'letter-spacing': '-.055em',
        'max-width': '780px'
    }) + '\n\n';
    
    cssContent += createRule('.hero-copy > p', {
        'max-width': '590px',
        'color': 'var(--muted)',
        'font-size': '1.14rem',
        'line-height': '1.75'
    }) + '\n\n';
    
    cssContent += createRule('.hero-actions', {
        'display': 'flex',
        'flex-wrap': 'wrap',
        'gap': '12px',
        'margin-block': '28px 20px'
    }) + '\n\n';
    
    cssContent += createRule('.button', {
        'min-height': '48px',
        'display': 'inline-flex',
        'align-items': 'center',
        'justify-content': 'center',
        'gap': '9px',
        'padding': '12px 19px',
        'border-radius': '10px',
        'text-decoration': 'none',
        'border': '1px solid transparent',
        'font-weight': '800',
        'transition': 'transform .18s ease, background .18s ease'
    }) + '\n\n';
    
    cssContent += createRule('.button:hover', {
        'transform': 'translateY(-2px)'
    }) + '\n\n';
    
    cssContent += createRule('.button.primary', {
        'color': 'white',
        'background': 'var(--coral)',
        'box-shadow': '0 8px 22px rgba(241, 90, 88, .25)'
    }) + '\n\n';
    
    cssContent += createRule('.button.primary:hover', {
        'background': 'var(--coral-dark)'
    }) + '\n\n';
    
    cssContent += createRule('.button.secondary', {
        'background': 'white',
        'border-color': '#cbd6e1',
        'color': 'var(--ink)'
    }) + '\n\n';
    
    cssContent += createRule('.compatibility', {
        'font-size': '.82rem !important',
        'display': 'flex',
        'align-items': 'center',
        'gap': '7px'
    }) + '\n\n';
    
    cssContent += createRule('.edge-dot, .chrome-dot', {
        'width': '18px',
        'height': '18px',
        'border-radius': '50%',
        'display': 'inline-block'
    }) + '\n\n';
    
    cssContent += createRule('.edge-dot', {
        'background': 'conic-gradient(#0e9ede, #0ac18e, #0e9ede)'
    }) + '\n\n';
    
    cssContent += createRule('.chrome-dot', {
        'background': 'conic-gradient(#e64b3f 0 33%, #f0c646 0 66%, #42a75b 0)',
        'border': '5px solid #4385de'
    }) + '\n\n';

    // Browser mockup
    cssContent += createRule('.browser-mockup', {
        'min-height': '440px',
        'position': 'relative',
        'border': '1px solid #cdd7e1',
        'border-radius': '15px',
        'background': '#f7f7f7',
        'box-shadow': 'var(--shadow)',
        'overflow': 'hidden',
        'transform': 'perspective(1300px) rotateY(-2deg)'
    }) + '\n\n';
    
    cssContent += createRule('.browser-bar', {
        'height': '39px',
        'display': 'flex',
        'align-items': 'center',
        'gap': '9px',
        'background': '#e9ebef',
        'padding': '0 13px',
        'color': '#59657a',
        'font-size': '.75rem'
    }) + '\n\n';
    
    cssContent += createRule('.browser-dot', {
        'width': '11px',
        'height': '11px',
        'border-radius': '50%',
        'background': '#c3c8d0'
    }) + '\n\n';
    
    cssContent += createRule('.browser-actions', {
        'margin-left': 'auto'
    }) + '\n\n';
    
    cssContent += createRule('.browser-content', {
        'display': 'grid',
        'grid-template-columns': '1.5fr .8fr',
        'gap': '8px',
        'padding': '10px',
        'height': '400px',
        'background': 'white'
    }) + '\n\n';
    
    cssContent += createRule('.video-placeholder', {
        'position': 'relative',
        'border-radius': '6px',
        'background': 'radial-gradient(circle at 62% 38%, #3b4b68 0 5%, transparent 6%), linear-gradient(145deg, #071020, #223654 58%, #0b1325)',
        'overflow': 'hidden'
    }) + '\n\n';
    
    cssContent += createRule('.live-label', {
        'position': 'absolute',
        'top': '13px',
        'left': '13px',
        'padding': '4px 7px',
        'color': 'white',
        'background': 'var(--coral)',
        'font-size': '.62rem',
        'font-weight': '900',
        'border-radius': '4px'
    }) + '\n\n';
    
    cssContent += createRule('.video-play', {
        'position': 'absolute',
        'inset': '0',
        'margin': 'auto',
        'width': '48px',
        'height': '48px',
        'border-radius': '50%',
        'display': 'grid',
        'place-items': 'center',
        'background': 'rgba(255,255,255,.85)',
        'color': 'var(--navy)'
    }) + '\n\n';
    
    cssContent += createRule('.video-controls', {
        'position': 'absolute',
        'bottom': '15px',
        'left': '18px',
        'color': 'white',
        'font-size': '.75rem'
    }) + '\n\n';
    
    cssContent += createRule('.chat-ghost', {
        'padding': '18px 10px',
        'display': 'flex',
        'flex-direction': 'column',
        'gap': '14px',
        'background': '#f8f9fb'
    }) + '\n\n';
    
    cssContent += createRule('.chat-ghost span', {
        'height': '7px',
        'border-radius': '5px',
        'background': '#d8dde4'
    }) + '\n\n';
    
    cssContent += createRule('.panel-mockup', {
        'position': 'absolute',
        'width': '48%',
        'right': '18px',
        'top': '70px',
        'background': 'white',
        'border-radius': '10px',
        'box-shadow': '0 18px 34px rgba(5, 18, 37, .28)',
        'overflow': 'hidden'
    }) + '\n\n';
    
    cssContent += createRule('.panel-title', {
        'display': 'flex',
        'align-items': 'center',
        'gap': '8px',
        'padding': '12px',
        'border-bottom': '1px solid var(--line)',
        'background': 'white',
        'font-size': '.78rem'
    }) + '\n\n';
    
    cssContent += createRule('.panel-title .brand-mark', {
        'width': '20px',
        'height': '20px',
        'border-width': '2px'
    }) + '\n\n';
    
    cssContent += createRule('.panel-title > span:last-child', {
        'margin-left': 'auto'
    }) + '\n\n';
    
    cssContent += createRule('.panel-row', {
        'display': 'flex',
        'align-items': 'center',
        'gap': '10px',
        'padding': '13px 15px',
        'border-bottom': '1px solid #edf0f3',
        'font-size': '.77rem'
    }) + '\n\n';
    
    cssContent += createRule('.panel-row .icon', {
        'color': 'var(--cyan-dark)',
        'width': '17px'
    }) + '\n\n';
    
    cssContent += createRule('.panel-row b', {
        'margin-left': 'auto'
    }) + '\n\n';

    // Why band
    cssContent += createRule('.why-band', {
        'background': 'var(--wash)',
        'padding': '66px 0 76px',
        'border-block': '1px solid #d7eef5'
    }) + '\n\n';
    
    cssContent += createRule('.why-band h2', {
        'text-align': 'center',
        'font-size': 'clamp(2rem, 4vw, 3rem)',
        'margin': '0 0 12px',
        'letter-spacing': '-.04em'
    }) + '\n\n';
    
    cssContent += createRule('.why-band > div > p', {
        'text-align': 'center',
        'color': 'var(--muted)',
        'margin': '0 auto 44px'
    }) + '\n\n';
    
    cssContent += createRule('.benefit-rail', {
        'display': 'grid',
        'grid-template-columns': 'repeat(3, 1fr)',
        'gap': '20px'
    }) + '\n\n';
    
    cssContent += createRule('.benefit-rail article', {
        'border-top': '3px solid var(--cyan)',
        'padding': '25px 28px',
        'background': 'rgba(255,255,255,.65)',
        'border-radius': '3px 3px 12px 12px'
    }) + '\n\n';
    
    cssContent += createRule('.benefit-rail article .icon', {
        'width': '30px',
        'height': '30px',
        'color': 'var(--cyan-dark)'
    }) + '\n\n';
    
    cssContent += createRule('.benefit-rail h3', {
        'margin': '18px 0 9px'
    }) + '\n\n';
    
    cssContent += createRule('.benefit-rail p', {
        'color': 'var(--muted)',
        'line-height': '1.6'
    }) + '\n\n';
    
    cssContent += createRule('.platform-section', {
        'padding-block': '68px'
    }) + '\n\n';
    
    cssContent += createRule('.platform-section > h2', {
        'margin': '0 0 10px',
        'font-size': 'clamp(1.8rem, 3vw, 2.55rem)',
        'letter-spacing': '-.035em'
    }) + '\n\n';
    
    cssContent += createRule('.platform-section > p', {
        'color': 'var(--muted)',
        'margin': '0 0 32px'
    }) + '\n\n';
    
    cssContent += createRule('.platform-grid', {
        'display': 'grid',
        'grid-template-columns': 'repeat(3, 1fr)',
        'gap': '18px'
    }) + '\n\n';
    
    cssContent += createRule('.platform-grid article', {
        'padding': '26px',
        'border': '1px solid var(--line)',
        'border-top': '4px solid var(--coral)',
        'border-radius': '10px',
        'background': 'white'
    }) + '\n\n';
    
    cssContent += createRule('.platform-grid article:nth-child(2)', {
        'border-top-color': 'var(--cyan)'
    }) + '\n\n';
    
    cssContent += createRule('.platform-grid .icon', {
        'width': '30px',
        'height': '30px',
        'color': 'var(--navy)'
    }) + '\n\n';
    
    cssContent += createRule('.platform-grid h3', {
        'margin': '18px 0 6px'
    }) + '\n\n';
    
    cssContent += createRule('.platform-grid strong', {
        'color': 'var(--coral-dark)',
        'font-size': '.82rem'
    }) + '\n\n';
    
    cssContent += createRule('.platform-grid p', {
        'color': 'var(--muted)',
        'line-height': '1.6',
        'margin-bottom': '0'
    }) + '\n\n';

    // Content page
    cssContent += createRule('.content-page', {
        'padding-block': '72px 100px',
        'min-height': '680px'
    }) + '\n\n';
    
    cssContent += createRule('.content-page > h1', {
        'font-size': 'clamp(2.4rem, 5vw, 4rem)'
    }) + '\n\n';
    
    cssContent += createRule('.page-lead', {
        'font-size': '1.24rem',
        'color': 'var(--coral-dark)',
        'font-weight': '750',
        'margin': '15px 0 40px'
    }) + '\n\n';
    
    cssContent += createRule('.installation-layout', {
        'display': 'grid',
        'grid-template-columns': '.72fr 1.28fr',
        'gap': '60px',
        'align-items': 'center',
        'margin-top': '45px'
    }) + '\n\n';
    
    cssContent += createRule('.step-rail', {
        'list-style': 'none',
        'margin': '0',
        'padding': '0'
    }) + '\n\n';
    
    cssContent += createRule('.step-rail li', {
        'position': 'relative',
        'display': 'grid',
        'grid-template-columns': '48px 1fr',
        'gap': '17px',
        'padding-bottom': '34px'
    }) + '\n\n';
    
    cssContent += createRule('.step-rail li:not(:last-child)::before', {
        'content': '""',
        'position': 'absolute',
        'left': '23px',
        'top': '45px',
        'bottom': '4px',
        'width': '2px',
        'background': '#d7e1e9'
    }) + '\n\n';
    
    cssContent += createRule('.step-rail li > span', {
        'width': '46px',
        'height': '46px',
        'border': '2px solid #c8d3dd',
        'color': '#66758a',
        'border-radius': '50%',
        'display': 'grid',
        'place-items': 'center',
        'font-weight': '800',
        'background': 'var(--paper)',
        'z-index': '1'
    }) + '\n\n';
    
    cssContent += createRule('.step-rail li.current > span', {
        'background': 'var(--coral)',
        'border-color': 'var(--coral)',
        'color': 'white'
    }) + '\n\n';
    
    cssContent += createRule('.step-rail h2', {
        'font-size': '1.08rem',
        'margin': '2px 0 5px'
    }) + '\n\n';
    
    cssContent += createRule('.step-rail p', {
        'color': 'var(--muted)',
        'line-height': '1.55',
        'margin': '0'
    }) + '\n\n';
    
    cssContent += createRule('.extension-window', {
        'position': 'relative',
        'border': '1px solid #cad5df',
        'border-radius': '13px',
        'background': 'white',
        'box-shadow': 'var(--shadow)',
        'overflow': 'visible',
        'min-height': '370px'
    }) + '\n\n';
    
    cssContent += createRule('.extension-toolbar', {
        'height': '50px',
        'background': '#eef1f4',
        'padding': '14px 17px',
        'display': 'flex',
        'align-items': 'center',
        'font-size': '.74rem'
    }) + '\n\n';
    
    cssContent += createRule('.extension-toolbar > span', {
        'margin-left': 'auto',
        'display': 'inline-flex',
        'align-items': 'center'
    }) + '\n\n';
    
    cssContent += createRule('.toggle', {
        'width': '31px',
        'height': '17px',
        'display': 'inline-block',
        'background': '#c4ccd4',
        'border-radius': '20px',
        'position': 'relative',
        'vertical-align': 'middle'
    }) + '\n\n';
    
    cssContent += createRule('.toggle::after', {
        'content': '""',
        'width': '13px',
        'height': '13px',
        'background': 'white',
        'border-radius': '50%',
        'position': 'absolute',
        'left': '2px',
        'top': '2px'
    }) + '\n\n';
    
    cssContent += createRule('.toggle.on', {
        'background': 'var(--cyan-dark)'
    }) + '\n\n';
    
    cssContent += createRule('.toggle.on::after', {
        'left': '16px'
    }) + '\n\n';
    
    cssContent += createRule('.extension-body', {
        'padding': '24px'
    }) + '\n\n';
    
    cssContent += createRule('.extension-body > button', {
        'padding': '9px 12px',
        'border': '1px solid #c3ced9',
        'background': 'white',
        'border-radius': '5px',
        'margin-right': '7px',
        'font-size': '.75rem'
    }) + '\n\n';
    
    cssContent += createRule('.extension-body > button.focused', {
        'border': '2px solid var(--coral)',
        'position': 'relative'
    }) + '\n\n';
    
    cssContent += createRule('.installed-extension', {
        'display': 'grid',
        'grid-template-columns': '36px 1fr auto',
        'gap': '15px',
        'align-items': 'center',
        'border': '1px solid #dae1e8',
        'border-radius': '8px',
        'padding': '18px',
        'margin-top': '25px',
        'font-size': '.78rem'
    }) + '\n\n';
    
    cssContent += createRule('.installed-extension p', {
        'color': 'var(--muted)',
        'margin': '6px 0 0'
    }) + '\n\n';
    
    cssContent += createRule('.extension-window aside', {
        'position': 'absolute',
        'right': '-26px',
        'bottom': '-72px',
        'width': '55%',
        'padding': '17px',
        'background': '#fff5e7',
        'border-left': '4px solid #f0a23a',
        'box-shadow': '0 10px 25px rgba(80, 57, 24, .16)',
        'font-size': '.76rem'
    }) + '\n\n';
    
    cssContent += createRule('.extension-window aside .icon', {
        'color': '#bd6f0a'
    }) + '\n\n';
    
    cssContent += createRule('.extension-window aside p', {
        'color': '#705d45',
        'margin-bottom': '0',
        'line-height': '1.45'
    }) + '\n\n';
    
    cssContent += createRule('.workflow', {
        'margin-top': '120px',
        'padding': '22px',
        'display': 'grid',
        'grid-template-columns': 'repeat(5, 1fr)',
        'gap': '10px',
        'background': 'var(--wash)',
        'border-radius': '12px'
    }) + '\n\n';
    
    cssContent += createRule('.workflow > div', {
        'position': 'relative',
        'text-align': 'center',
        'display': 'grid',
        'justify-items': 'center',
        'gap': '8px',
        'font-size': '.78rem'
    }) + '\n\n';
    
    cssContent += createRule('.workflow > div > span', {
        'width': '29px',
        'height': '29px',
        'display': 'grid',
        'place-items': 'center',
        'border-radius': '50%',
        'background': 'white',
        'color': 'var(--cyan-dark)',
        'font-weight': '900'
    }) + '\n\n';
    
    cssContent += createRule('.workflow b', {
        'position': 'absolute',
        'right': '-13px',
        'top': '4px',
        'color': 'var(--cyan-dark)'
    }) + '\n\n';
    
    cssContent += createRule('.feature-layout', {
        'display': 'grid',
        'grid-template-columns': '.6fr 1fr 1.1fr',
        'gap': '28px',
        'margin-top': '50px',
        'align-items': 'stretch'
    }) + '\n\n';
    
    cssContent += createRule('.feature-tabs', {
        'display': 'flex',
        'flex-direction': 'column',
        'border': '1px solid var(--line)',
        'border-radius': '10px',
        'overflow': 'hidden',
        'align-self': 'start'
    }) + '\n\n';
    
    cssContent += createRule('.feature-tabs button', {
        'text-align': 'left',
        'display': 'flex',
        'gap': '12px',
        'align-items': 'center',
        'min-height': '58px',
        'padding': '13px 15px',
        'border': '0',
        'border-bottom': '1px solid var(--line)',
        'background': 'white',
        'color': '#42516a',
        'cursor': 'pointer'
    }) + '\n\n';
    
    cssContent += createRule('.feature-tabs button:last-child', {
        'border-bottom': '0'
    }) + '\n\n';
    
    cssContent += createRule('.feature-tabs button[aria-selected="true"]', {
        'background': 'var(--coral)',
        'color': 'white',
        'font-weight': '800'
    }) + '\n\n';
    
    cssContent += createRule('.feature-detail', {
        'padding': '30px',
        'background': '#fff8f4',
        'border-radius': '12px',
        'border-top': '4px solid var(--coral)'
    }) + '\n\n';
    
    cssContent += createRule('.feature-detail h2', {
        'margin-top': '0'
    }) + '\n\n';
    
    cssContent += createRule('.feature-detail p', {
        'color': 'var(--muted)',
        'line-height': '1.75'
    }) + '\n\n';
    
    cssContent += createRule('.info-callout', {
        'display': 'flex',
        'gap': '10px',
        'margin-top': '25px',
        'padding': '14px',
        'background': 'white',
        'color': '#6e542b',
        'border-left': '3px solid #e7a84d',
        'font-size': '.85rem'
    }) + '\n\n';
    
    cssContent += createRule('.player-panel', {
        'padding': '18px',
        'background': '#f8f9fb',
        'border': '1px solid #cfd7e0',
        'border-radius': '12px',
        'box-shadow': '0 15px 35px rgba(21, 40, 66, .13)',
        'font-size': '.76rem'
    }) + '\n\n';
    
    cssContent += createRule('.player-panel > small', {
        'display': 'block',
        'color': '#6d7890',
        'letter-spacing': '.12em',
        'margin': '14px 0 9px'
    }) + '\n\n';
    
    cssContent += createRule('.player-buttons', {
        'display': 'flex',
        'align-items': 'center',
        'gap': '10px'
    }) + '\n\n';
    
    cssContent += createRule('.player-buttons button', {
        'width': '34px',
        'height': '34px',
        'border': '0',
        'border-radius': '50%',
        'display': 'grid',
        'place-items': 'center',
        'background': 'var(--coral)',
        'color': 'white'
    }) + '\n\n';
    
    cssContent += createRule('.slider, .setting-line', {
        'flex': '1',
        'height': '4px',
        'border-radius': '4px',
        'background': '#cad4de',
        'position': 'relative'
    }) + '\n\n';
    
    cssContent += createRule('.slider span', {
        'display': 'block',
        'width': '56%',
        'height': '100%',
        'background': 'var(--cyan)'
    }) + '\n\n';
    
    cssContent += createRule('.meter-label, .panel-setting', {
        'display': 'flex',
        'align-items': 'center',
        'justify-content': 'space-between',
        'gap': '12px',
        'margin': '9px 0'
    }) + '\n\n';
    
    cssContent += createRule('.meter', {
        'display': 'flex',
        'gap': '2px',
        'height': '20px'
    }) + '\n\n';
    
    cssContent += createRule('.meter i', {
        'flex': '1',
        'background': '#d9e0e7'
    }) + '\n\n';
    
    cssContent += createRule('.meter i
