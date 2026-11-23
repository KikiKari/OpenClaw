import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { gunzipSync } from 'node:zlib';
import config from '../vite.config.js';

test('Katalog enthält neue Sprachdateien und toleriert fehlende Verzeichnisse', async () => {
  const root = await mkdtemp(join(tmpdir(), 'abstractions-catalog-'));
  const original = process.cwd();
  try {
    for (const language of ['java', 'c', 'cpp', 'php', 'fsharp', 'css', 'python']) {
      await mkdir(join(root, language));
      await writeFile(join(root, language, 'sample.txt'), `sample ${language}`);
    }
    process.chdir(root);
    let asset;
    await config.plugins[0].generateBundle.call({ emitFile(value) { asset = value; } });
    const entries = JSON.parse(gunzipSync(asset.source).toString('utf8'));
    assert.equal(asset.fileName, 'catalog.json.gz');
    assert.deepEqual(entries.map(entry => entry.language).sort(), ['c', 'cpp', 'css', 'fsharp', 'java', 'php', 'python']);
    assert.equal(entries.find(entry => entry.language === 'css').content, 'sample css');
    assert.equal(entries.find(entry => entry.language === 'fsharp').path, 'fsharp/sample.txt');
  } finally {
    process.chdir(original);
    await rm(root, { recursive: true, force: true });
  }
});
