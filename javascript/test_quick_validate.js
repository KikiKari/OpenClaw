#!/usr/bin/env node
// test_quick_validate.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_quick_validate.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_quick_validate.py
// Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

/**
 * Regression tests for quick skill validation.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { describe, it, before, after } = require('node:test');
const assert = require('assert');

// Import the module to test
const quickValidate = require('./quick_validate');

describe('TestQuickValidate', () => {
  let tempDir;

  before(() => {
    // Create temporary directory
    const tempRoot = process.env.TEMP || process.env.TMPDIR || '/tmp';
    tempDir = fs.mkdtempSync(path.join(tempRoot, 'test_quick_validate_'));
  });

  after(() => {
    // Clean up temporary directory
    if (fs.existsSync(tempDir)) {
      execSync(`rm -rf ${tempDir}`, { stdio: 'pipe' });
    }
  });

  it('should accept CRLF frontmatter', () => {
    const skillDir = path.join(tempDir, 'crlf-skill');
    fs.mkdirSync(skillDir, { recursive: true });
    const content = "---\r\nname: crlf-skill\r\ndescription: ok\r\n---\r\n# Skill\r\n";
    fs.writeFileSync(path.join(skillDir, 'SKILL.md'), content, 'utf-8');

    const [valid, message] = quickValidate.validateSkill(skillDir);

    assert.strictEqual(valid, true, message);
  });

  it('should reject missing frontmatter closing fence', () => {
    const skillDir = path.join(tempDir, 'bad-skill');
    fs.mkdirSync(skillDir, { recursive: true });
    const content = "---\nname: bad-skill\ndescription: missing end\n# no closing fence\n";
    fs.writeFileSync(path.join(skillDir, 'SKILL.md'), content, 'utf-8');

    const [valid, message] = quickValidate.validateSkill(skillDir);

    assert.strictEqual(valid, false);
    assert.strictEqual(message, 'Invalid frontmatter format');
  });

  it('should handle multiline frontmatter without YAML library', () => {
    const skillDir = path.join(tempDir, 'multiline-skill');
    fs.mkdirSync(skillDir, { recursive: true });
    const content = `---
name: multiline-skill
description: Works without pyyaml
allowed-tools:
  - gh
metadata: |
  {
    "owners": ["team-openclaw"]
  }
---
# Skill
`;
    fs.writeFileSync(path.join(skillDir, 'SKILL.md'), content, 'utf-8');

    // Temporarily disable YAML support
    const previousYaml = quickValidate.yaml;
    quickValidate.yaml = null;
    
    try {
      const [valid, message] = quickValidate.validateSkill(skillDir);
      assert.strictEqual(valid, true, message);
    } finally {
      quickValidate.yaml = previousYaml;
    }
  });
});
