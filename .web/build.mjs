import { readFile, mkdir, writeFile } from 'node:fs/promises';

const readme = await readFile('README.md', 'utf8');
const escape = text => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');

const html = `<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>OpenClaw · Gateway 1</title>
  <style>
    body{font:16px/1.6 system-ui,sans-serif;background:#0b1422;color:#e9eef7;margin:0}
    main{max-width:1000px;margin:auto;padding:2rem}
    nav{display:flex;gap:1rem;flex-wrap:wrap}
    a{color:#8ee6da}
    pre{white-space:pre-wrap;overflow-wrap:anywhere;font:inherit;background:#142238;border:1px solid #304158;border-radius:8px;padding:1.5rem}
  </style>
</head>
<body><main>
  <h1>OpenClaw · Gateway 1</h1>
  <nav aria-label="Branches">
    <a href="https://github.com/KikiKari/OpenClaw/tree/main">main</a>
    <a href="https://github.com/KikiKari/OpenClaw/tree/gateway1">gateway1</a>
    <a href="https://github.com/KikiKari/OpenClaw/tree/gateway1-abstractions">gateway1-abstractions</a>
  </nav>
  <h2>README</h2><pre>${escape(readme)}</pre>
</main></body></html>`;

await mkdir('dist', { recursive: true });
await writeFile('dist/index.html', html, 'utf8');
