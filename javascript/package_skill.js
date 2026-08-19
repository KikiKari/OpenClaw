#!/usr/bin/env node
// package_skill.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/package_skill.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/package_skill.py
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

/**
 * Skill Packager - Creates a distributable .skill file of a skill folder
 *
 * Usage:
 *     node utils/package_skill.js <path/to/skill-folder> [output-directory]
 *
 * Example:
 *     node utils/package_skill.js skills/public/my-skill
 *     node utils/package_skill.js skills/public/my-skill ./dist
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Import validate_skill function
function validate_skill(skillPath) {
    // Check if required files exist
    const requiredFiles = ['SKILL.md'];
    for (const file of requiredFiles) {
        if (!fs.existsSync(path.join(skillPath, file))) {
            return [false, `Missing required file: ${file}`];
        }
    }

    // Try to run skill validation script if it exists
    try {
        const validationScript = path.join(skillPath, 'validate.js');
        if (fs.existsSync(validationScript)) {
            execSync(`node "${validationScript}"`, { stdio: 'pipe' });
        }
        return [true, 'Validation passed'];
    } catch (error) {
        return [false, `Validation script failed: ${error.message}`];
    }
}

function _is_within(filePath, rootPath) {
    const relative = path.relative(rootPath, filePath);
    return relative && !relative.startsWith('..') && !path.isAbsolute(relative);
}

function package_skill(skillPath, outputDir = null) {
    // Resolve paths
    skillPath = path.resolve(skillPath);

    // Validate skill folder exists
    if (!fs.existsSync(skillPath)) {
        console.error(`[ERROR] Skill folder not found: ${skillPath}`);
        return null;
    }

    if (!fs.statSync(skillPath).isDirectory()) {
        console.error(`[ERROR] Path is not a directory: ${skillPath}`);
        return null;
    }

    // Validate SKILL.md exists
    const skillMd = path.join(skillPath, 'SKILL.md');
    if (!fs.existsSync(skillMd)) {
        console.error(`[ERROR] SKILL.md not found in ${skillPath}`);
        return null;
    }

    // Run validation before packaging
    console.log('Validating skill...');
    const [valid, message] = validate_skill(skillPath);
    if (!valid) {
        console.error(`[ERROR] Validation failed: ${message}`);
        console.error('   Please fix the validation errors before packaging.');
        return null;
    }
    console.log(`[OK] ${message}\n`);

    // Determine output location
    const skillName = path.basename(skillPath);
    let outputPath;
    if (outputDir) {
        outputPath = path.resolve(outputDir);
        fs.mkdirSync(outputPath, { recursive: true });
    } else {
        outputPath = process.cwd();
    }

    const skillFilename = path.join(outputPath, `${skillName}.skill`);

    const EXCLUDED_DIRS = new Set(['.git', '.svn', '.hg', '__pycache__', 'node_modules']);

    // Create the .skill file (zip format) using system zip command
    try {
        // Create temporary directory for packaging
        const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-package-'));
        const tempSkillDir = path.join(tempDir, skillName);
        fs.mkdirSync(tempSkillDir);

        // Copy files to temporary directory
        function copyRecursiveSync(src, dest) {
            const stats = fs.statSync(src);
            if (stats.isDirectory()) {
                fs.mkdirSync(dest, { recursive: true });
                fs.readdirSync(src).forEach((childItemName) => {
                    // Skip excluded directories
                    if (EXCLUDED_DIRS.has(childItemName)) return;
                    
                    const srcPath = path.join(src, childItemName);
                    const destPath = path.join(dest, childItemName);
                    
                    // Security: never follow or package symlinks
                    if (fs.lstatSync(srcPath).isSymbolicLink()) {
                        console.warn(`[WARN] Skipping symlink: ${srcPath}`);
                        return;
                    }
                    
                    // Check if file escapes skill root
                    if (!_is_within(srcPath, skillPath)) {
                        console.error(`[ERROR] File escapes skill root: ${srcPath}`);
                        throw new Error('File escape detected');
                    }
                    
                    copyRecursiveSync(srcPath, destPath);
                });
            } else {
                // If output lives under skillPath, avoid writing archive into itself
                if (path.resolve(src) === path.resolve(skillFilename)) {
                    console.warn(`[WARN] Skipping output archive: ${src}`);
                    return;
                }
                
                fs.copyFileSync(src, dest);
                console.log(`  Added: ${path.join(skillName, path.relative(skillPath, src))}`);
            }
        }

        copyRecursiveSync(skillPath, tempSkillDir);

        // Create zip file
        const zipCommand = `cd "${tempDir}" && zip -r "${skillFilename}" "${skillName}"`;
        execSync(zipCommand, { stdio: 'inherit' });

        // Clean up temporary directory
        fs.rmSync(tempDir, { recursive: true, force: true });

        console.log(`\n[OK] Successfully packaged skill to: ${skillFilename}`);
        return skillFilename;

    } catch (error) {
        console.error(`[ERROR] Error creating .skill file: ${error.message}`);
        return null;
    }
}

function main() {
    const args = process.argv.slice(2);
    
    if (args.length < 1) {
        console.log('Usage: node utils/package_skill.js <path/to/skill-folder> [output-directory]');
        console.log('\nExample:');
        console.log('  node utils/package_skill.js skills/public/my-skill');
        console.log('  node utils/package_skill.js skills/public/my-skill ./dist');
        process.exit(1);
    }

    const skillPath = args[0];
    const outputDir = args[1];

    console.log(`Packaging skill: ${skillPath}`);
    if (outputDir) {
        console.log(`   Output directory: ${outputDir}`);
    }
    console.log();

    const result = package_skill(skillPath, outputDir);

    if (result) {
        process.exit(0);
    } else {
        process.exit(1);
    }
}

// Polyfill for os.tmpdir() since we're using it
const os = {
    tmpdir: () => process.env.TMPDIR || process.env.TEMP || process.env.TMP || '/tmp'
};

if (require.main === module) {
    main();
}

module.exports = { package_skill };
