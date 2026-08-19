#!/usr/bin/env node
// vision-check.html — portiert nach javascript
// Quelle: html, Projects@Vision-Check:Vision-Check/vision-check.html
// auch in: Onboarding@main:docs/reference-library/examples/vision-check.html
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

function generateHTML() {
  return `<!DOCTYPE html>
<html lang="de" data-theme="dark">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Vision-Check</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300..700&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@4.22.0/dist/tf.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@tensorflow-models/coco-ssd@2.2.3/dist/coco-ssd.min.js"></script>
<style>
:root,[data-theme="dark"]{
  --color-bg:#0e1117;--color-surface:#161b22;--color-surface-2:#1c2230;
  --color-surface-offset:#1f2937;--color-border:#30363d;--color-divider:#21262d;
  --color-text:#e6edf3;--color-text-muted:#8b949e;--color-text-faint:#484f58;
  --color-primary:#3fb950;--color-primary-hover:#2ea043;--color-primary-highlight:#0d2c14;
  --color-accent:#58a6ff;--color-accent-hover:#388bfd;--color-warning:#d29922;
  --color-error:#f85149;--color-purple:#bc8cff;
  --font-body:'Inter',system-ui,sans-serif;
  --font-mono:'JetBrains Mono',monospace;
  --text-xs:clamp(0.75rem,0.7rem + 0.25vw,0.875rem);
  --text-sm:clamp(0.875rem,0.8rem + 0.35vw,1rem);
  --text-base:clamp(1rem,0.95rem + 0.25vw,1.125rem);
  --text-lg:clamp(1.125rem,1rem + 0.75vw,1.5rem);
  --text-xl:clamp(1.5rem,1.2rem + 1.25vw,2.25rem);
  --space-1:0.25rem;--space-2:0.5rem;--space-3:0.75rem;--space-4:1rem;
  --space-5:1.25rem;--space-6:1.5rem;--space-8:2rem;--space-10:2.5rem;
  --space-12:3rem;--space-16:4rem;
  --radius-sm:0.375rem;--radius-md:0.5rem;--radius-lg:0.75rem;--radius-xl:1rem;
  --radius-full:9999px;
  --transition:180ms cubic-bezier(0.16,1,0.3,1);
  --shadow-md:0 4px 12px rgba(0,0,0,0.4);--shadow-lg:0 12px 32px rgba(0,0,0,0.5);
}
[data-theme="light"]{
  --color-bg:#f0f6ff;--color-surface:#ffffff;--color-surface-2:#f6f8fa;
  --color-surface-offset:#eaeef2;--color-border:#d0d7de;--color-divider:#e1e4e8;
  --color-text:#1f2328;--color-text-muted:#57606a;--color-text-faint:#8c959f;
  --color-primary:#1a7f37;--color-primary-hover:#116329;--color-primary-highlight:#d4efdb;
  --color-accent:#0969da;--color-accent-hover:#0550ae;--color-warning:#9a6700;
  --color-error:#cf222e;--color-purple:#8250df;
  --shadow-md:0 4px 12px rgba(0,0,0,0.1);--shadow-lg:0 12px 32px rgba(0,0,0,0.15);
}
*,*::before,*::after{box-sizing:border-box;marg
