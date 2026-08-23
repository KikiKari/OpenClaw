#!/usr/bin/env node
// test_package_skill.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_package_skill.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_package_skill.py
// Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

/**
 * Regression tests for skill packaging security behavior.
 */

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');
const { strict: assert } = require('assert');

// Mock the quick_validate module
const Module = require('module');
const originalRequire = Module.prototype.require;

// Temporarily replace require to mock quick_validate
Module.prototype.require = function(modulePath) {
  if (modulePath === 'quick_validate') {
    return {
      validate_skill: (_path) => [true, "Skill is valid!"]
    };
  }
  return originalRequire.call(this, modulePath);
};

// Load the module under test
const packageSkillModule = require('./package_skill');
const { package_skill } = require('./package_skill');

// Restore original require
Module.prototype.require = originalRequire;

class TestCase {
  constructor() {
    this.assert = assert;
    this.testMethods = [];
  }

  setUp() {
    this.tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'test_skill_'));
  }

  tearDown() {
    if (fs.existsSync(this.tempDir)) {
      fs.rmSync(this.tempDir, { recursive: true });
    }
  }

  create_skill(name = "test-skill") {
    const skillDir = path.join(this.tempDir, name);
    fs.mkdirSync(skillDir, { recursive: true });
    fs.writeFileSync(
      path.join(skillDir, "SKILL.md"),
      "---\nname: test-skill\ndescription: test\n---\n"
    );
    fs.writeFileSync(
      path.join(skillDir, "script.py"),
      "print('ok')\n"
    );
    return skillDir;
  }

  skipTest(reason) {
    console.log(`Skipping test: ${reason}`);
    throw new Error('SKIP_TEST');
  }
}

class TestPackageSkillSecurity extends TestCase {
  test_packages_normal_files() {
    const skillDir = this.create_skill("normal-skill");
    const outDir = path.join(this.tempDir, "out");
    fs.mkdirSync(outDir);

    const result = package_skill(skillDir, outDir);

    this.assert.ok(result !== null);
    const skillFile = path.join(outDir, "normal-skill.skill");
    this.assert.ok(fs.existsSync(skillFile));
    
    const zip = new require('adm-zip')(skillFile);
    const entries = zip.getEntries();
    const names = new Set(entries.map(entry => entry.entryName));
    
    this.assert.ok(names.has("normal-skill/SKILL.md"));
    this.assert.ok(names.has("normal-skill/script.py"));
  }

  test_skips_symlink_to_external_file() {
    const skillDir = this.create_skill("symlink-file-skill");
    const outside = path.join(this.tempDir, "outside-secret.txt");
    fs.writeFileSync(outside, "super-secret\n");
    const link = path.join(skillDir, "loot.txt");
    const outDir = path.join(this.tempDir, "out");
    fs.mkdirSync(outDir);

    try {
      // Create symlink
      fs.symlinkSync(outside, link);
    } catch (error) {
      if (error.code === 'EPERM' || error.code === 'EACCES' || error.code === 'ENOENT') {
        this.skipTest("symlink unsupported on this platform");
      }
      throw error;
    }

    const result = package_skill(skillDir, outDir);
    this.assert.ok(result !== null);
    const skillFile = path.join(outDir, "symlink-file-skill.skill");
    this.assert.ok(fs.existsSync(skillFile));
    
    const zip = new require('adm-zip')(skillFile);
    const entries = zip.getEntries();
    const names = new Set(entries.map(entry => entry.entryName));
    
    this.assert.ok(names.has("symlink-file-skill/SKILL.md"));
    this.assert.ok(names.has("symlink-file-skill/script.py"));
    this.assert.ok(!names.has("symlink-file-skill/loot.txt"));
  }

  test_skips_symlink_directory() {
    const skillDir = this.create_skill("symlink-dir-skill");
    const outsideDir = path.join(this.tempDir, "outside");
    fs.mkdirSync(outsideDir);
    fs.writeFileSync(path.join(outsideDir, "secret.txt"), "secret\n");
    const link = path.join(skillDir, "docs");
    const outDir = path.join(this.tempDir, "out");
    fs.mkdirSync(outDir);

    try {
      // Create directory symlink
      fs.symlinkSync(outsideDir, link, 'dir');
    } catch (error) {
      if (error.code === 'EPERM' || error.code === 'EACCES' || error.code === 'ENOENT') {
        this.skipTest("symlink unsupported on this platform");
      }
      throw error;
    }

    const result = package_skill(skillDir, outDir);
    this.assert.ok(result !== null);
    const skillFile = path.join(outDir, "symlink-dir-skill.skill");
    
    const zip = new require('adm-zip')(skillFile);
    const entries = zip.getEntries();
    const names = new Set(entries.map(entry => entry.entryName));
    
    this.assert.ok(names.has("symlink-dir-skill/SKILL.md"));
    this.assert.ok(names.has("symlink-dir-skill/script.py"));
    this.assert.ok(!names.has("symlink-dir-skill/docs/secret.txt"));
  }

  test_rejects_resolved_path_outside_skill_root() {
    const skillDir = this.create_skill("escape-skill");
    const outDir = path.join(this.tempDir, "out");
    fs.mkdirSync(outDir);

    // Save original function
    const originalIsWithin = packageSkillModule._is_within;

    // Replace with mock
    packageSkillModule._is_within = (pathObj, root) => {
      if (path.basename(pathObj) === "script.py") {
        return false;
      }
      return originalIsWithin(pathObj, root);
    };

    try {
      const result = package_skill(skillDir, outDir);
      this.assert.strictEqual(result, null);
    } finally {
      // Restore original function
      packageSkillModule._is_within = originalIsWithin;
    }
  }

  test_allows_nested_regular_files() {
    const skillDir = this.create_skill("nested-skill");
    const nested = path.join(skillDir, "lib", "helpers");
    fs.mkdirSync(nested, { recursive: true });
    fs.writeFileSync(
      path.join(nested, "util.py"),
      "def run():\n    return 1\n"
    );
    const outDir = path.join(this.tempDir, "out");
    fs.mkdirSync(outDir);

    const result = package_skill(skillDir, outDir);

    this.assert.ok(result !== null);
    const skillFile = path.join(outDir, "nested-skill.skill");
    
    const zip = new require('adm-zip')(skillFile);
    const entries = zip.getEntries();
    const names = new Set(entries.map(entry => entry.entryName));
    
    this.assert.ok(names.has("nested-skill/lib/helpers/util.py"));
  }

  test_skips_output_archive_when_output_dir_is_skill_dir() {
    const skillDir = this.create_skill("self-output-skill");

    const result = package_skill(skillDir, skillDir);

    this.assert.ok(result !== null);
    const skillFile = path.join(skillDir, "self-output-skill.skill");
    this.assert.ok(fs.existsSync(skillFile));
    
    const zip = new require('adm-zip')(skillFile);
    const entries = zip.getEntries();
    const names = new Set(entries.map(entry => entry.entryName));
    
    this.assert.ok(names.has("self-output-skill/SKILL.md"));
    this.assert.ok(names.has("self-output-skill/script.py"));
    this.assert.ok(!names.has("self-output-skill/self-output-skill.skill"));
  }
}

function runTests() {
  const testInstance = new TestPackageSkillSecurity();
  const methods = Object.getOwnPropertyNames(TestPackageSkillSecurity.prototype)
    .filter(name => name.startsWith('test_'));

  let passed = 0;
  let failed = 0;
  let skipped = 0;

  for (const method of methods) {
    testInstance.setUp();
    try {
      console.log(`Running ${method}...`);
      testInstance[method]();
      console.log(`✓ ${method} passed`);
      passed++;
    } catch (error) {
      if (error.message === 'SKIP_TEST') {
        console.log(`○ ${method} skipped`);
        skipped++;
      } else {
        console.log(`✗ ${method} failed: ${error.message}`);
        console.error(error.stack);
        failed++;
      }
    } finally {
      testInstance.tearDown();
    }
  }

  console.log(`\nResults: ${passed} passed, ${failed} failed, ${skipped} skipped`);
  
  if (failed > 0) {
    process.exit(1);
  }
}

if (require.main === module) {
  runTests();
}
