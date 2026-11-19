#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "8cbc425f6cb28bdc6f1aa8d6d89ed6285c700969098c520d323c600dcca7fa76", "source_sha256": "c2445d9bf4b0ccf8c05eb944692addc1436cc68504dfc0ab9e6677d90ced3ec9", "target_language": "javascript"}
// index.html — portiert nach javascript
// Quelle: html, workspace@local:skills/github-clones/openclaw/ui/index.html
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

// Helper function to create HTML elements
function createElement(tag, attributes = {}, children = []) {
  const attrs = Object.entries(attributes)
    .map(([key, value]) => `${key}="${value}"`)
    .join(' ');
  
  const openingTag = attrs ? `<${tag} ${attrs}>` : `<${tag}>`;
  const closingTag = `</${tag}>`;
  
  if (Array.isArray(children)) {
    return `${openingTag}${children.join('')}${closingTag}`;
  } else {
    return `${openingTag}${children}${closingTag}`;
  }
}

// Helper function to create self-closing tags
function createSelfClosingElement(tag, attributes = {}) {
  const attrs = Object.entries(attributes)
    .map(([key, value]) => `${key}="${value}"`)
    .join(' ');
  
  return attrs ? `<${tag} ${attrs} />` : `<${tag} />`;
}

// Create the inline script content
const inlineScriptContent = `
      (function () {
        var THEMES = { claw: 1, knot: 1, dash: 1 };
        var MODES = { system: 1, light: 1, dark: 1 };
        var LEGACY = {
          dark: "claw:dark",
          light: "claw:light",
          openknot: "knot:dark",
          fieldmanual: "dash:dark",
          clawdash: "dash:light",
          system: "claw:system",
        };
        try {
          var keys = Object.keys(localStorage);
          var raw;
          for (var i = 0; i < keys.length; i++) {
            if (keys[i].indexOf("openclaw.control.settings.v1") === 0) {
              raw = localStorage.getItem(keys[i]);
              if (raw) break;
            }
          }
          if (!raw) return;
          var s = JSON.parse(raw);
          var t = s && s.theme;
          var m = s && s.themeMode;
          if (typeof t !== "string") t = "";
          if (typeof m !== "string") m = "";
          var legacy = LEGACY[t];
          var theme = THEMES[t] ? t : legacy ? legacy.split(":")[0] : "claw";
          var mode = MODES[m] ? m : legacy ? legacy.split(":")[1] : "system";
          if (mode === "system") {
            mode = window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
          }
          var resolved =
            theme === "knot"
              ? mode === "light"
                ? "openknot-light"
                : "openknot"
              : theme === "dash"
                ? mode === "light"
                  ? "dash-light"
                  : "dash"
                : mode === "light"
                  ? "light"
                  : "dark";
          document.documentElement.setAttribute("data-theme", resolved);
          document.documentElement.setAttribute(
            "data-theme-mode",
            resolved.indexOf("light") !== -1 ? "light" : "dark",
          );
        } catch (e) {}
      })();
    `.trim();

// Build the HTML structure
const doctype = '<!doctype html>';
const htmlAttributes = { lang: 'en' };

const headChildren = [
  createSelfClosingElement('meta', { charset: 'UTF-8' }),
  createSelfClosingElement('meta', { 
    name: 'viewport', 
    content: 'width=device-width, initial-scale=1.0' 
  }),
  createElement('title', {}, ['OpenClaw Control']),
  createSelfClosingElement('meta', { 
    name: 'color-scheme', 
    content: 'dark light' 
  }),
  createSelfClosingElement('link', { 
    rel: 'icon', 
    type: 'image/svg+xml', 
    href: '/favicon.svg' 
  }),
  createSelfClosingElement('link', { 
    rel: 'icon', 
    type: 'image/png', 
    sizes: '32x32', 
    href: '/favicon-32.png' 
  }),
  createSelfClosingElement('link', { 
    rel: 'apple-touch-icon', 
    sizes: '180x180', 
    href: '/apple-touch-icon.png' 
  }),
  createElement('script', {}, [inlineScriptContent])
];

const bodyChildren = [
  createElement('openclaw-app'),
  createElement('script', { 
    type: 'module', 
    src: '/src/main.ts' 
  })
];

const head = createElement('head', {}, headChildren);
const body = createElement('body', {}, bodyChildren);
const htmlContent = createElement('html', htmlAttributes, [head, body]);

// Combine everything into final HTML
const fullHtml = `${doctype}\n${htmlContent}`;

// Write to file if argument provided, otherwise to stdout
if (process.argv[2]) {
  writeFileSync(process.argv[2], fullHtml);
  console.log(`HTML file written to ${process.argv[2]}`);
} else {
  console.log(fullHtml);
}
