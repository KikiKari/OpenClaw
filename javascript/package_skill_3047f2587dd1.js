#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "9f22eed10f1ddfaa9baaa089f1388eefddcddc69ab5345be3ec4ab1a98e452a7", "source_sha256": "f290101073ee6a167f46edadda164d2c88affc03c554135fe101a4e422c44c22", "target_language": "javascript"}
// package_skill.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/package_skill.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/package_skill.py
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

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
const archiver = require('archiver');

function _isWithin(filePath, rootPath) {
    const relative = path.relative(rootPath, filePath);
    return relative && !relative.startsWith('..') && !path.isAbsolute(relative);
}

async function packageSkill(skillPath, outputDir = null) {
    /**
     * Package a skill folder into a .skill file.
     * 
     * Args:
     *     skillPath: Path to the skill folder
     *     outputDir: Optional output directory for the .skill file (defaults to current directory)
     * 
     * Returns:
     *     Path to the created .skill file, or null if error
     */
    const resolvedSkillPath = path.resolve(skillPath);

    // Validate skill folder exists
    if (!fs.existsSync(resolvedSkillPath)) {
        console.error(`[ERROR] Skill folder not found: ${resolvedSkillPath}`);
        return null;
    }

    const stats = fs.statSync(resolvedSkillPath);
    if (!stats.isDirectory()) {
        console.error(`[ERROR] Path is not a directory: ${resolvedSkillPath}`);
        return null;
    }

    // Validate SKILL.md exists
    const skillMd = path.join(resolvedSkillPath, 'SKILL.md');
    if (!fs.existsSync(skillMd)) {
        console.error(`[ERROR] SKILL.md not found in ${resolvedSkillPath}`);
        return null;
    }

    // Run validation before packaging
    console.log('Validating skill...');
    try {
        const validateScript = path.join(__dirname, 'quick_validate.js');
        const result = execSync(`node "${validateScript}" "${resolvedSkillPath}"`, { encoding: 'utf8' });
        console.log(`[OK] ${result.trim()}\n`);
    } catch (error) {
        console.error(`[ERROR] Validation failed: ${error.stdout || error.message}`);
        console.error('   Please fix the validation errors before packaging.');
        return null;
    }

    // Determine output location
    const skillName = path.basename(resolvedSkillPath);
    let outputPath;
    if (outputDir) {
        outputPath = path.resolve(outputDir);
        fs.mkdirSync(outputPath, { recursive: true });
    } else {
        outputPath = process.cwd();
    }

    const skillFilename = path.join(outputPath, `${skillName}.skill`);

    const EXCLUDED_DIRS = new Set(['.git', '.svn', '.hg', '__pycache__', 'node_modules']);

    // Create the .skill file (zip format)
    try {
        const output = fs.createWriteStream(skillFilename);
        const archive = archiver('zip', { zlib: { level: 9 } });

        return new Promise((resolve, reject) => {
            output.on('close', () => {
                console.log(`\n[OK] Successfully packaged skill to: ${skillFilename}`);
                resolve(skillFilename);
            });

            archive.on('warning', (err) => {
                if (err.code === 'ENOENT') {
                    console.warn(`[WARN] ${err}`);
                } else {
                    reject(err);
                }
            });

            archive.on('error', (err) => {
                console.error(`[ERROR] Error creating .skill file: ${err}`);
                reject(err);
            });

            archive.pipe(output);

            // Walk through the skill directory
            function addFilesToArchive(dir, baseDir) {
                const files = fs.readdirSync(dir);
                
                for (const file of files) {
                    const filePath = path.join(dir, file);
                    const stat = fs.lstatSync(filePath);
                    
                    // Security: never follow or package symlinks.
                    if (stat.isSymbolicLink()) {
                        console.warn(`[WARN] Skipping symlink: ${filePath}`);
                        continue;
                    }

                    const relativePath = path.relative(baseDir, filePath);
                    const relParts = relativePath.split(path.sep);
                    
                    if (relParts.some(part => EXCLUDED_DIRS.has(part))) {
                        continue;
                    }

                    if (stat.isFile()) {
                        const resolvedFile = path.resolve(filePath);
                        if (!_isWithin(resolvedFile, baseDir)) {
                            console.error(`[ERROR] File escapes skill root: ${filePath}`);
                            reject(new Error(`File escapes skill root: ${filePath}`));
                            return;
                        }
                        
                        // If output lives under skillPath, avoid writing archive into itself.
                        if (resolvedFile === path.resolve(skillFilename)) {
                            console.warn(`[WARN] Skipping output archive: ${filePath}`);
                            continue;
                        }

                        // Calculate the relative path within the zip.
                        const arcname = path.join(skillName, path.relative(baseDir, filePath));
                        archive.file(filePath, { name: arcname });
                        console.log(`  Added: ${arcname}`);
                    } else if (stat.isDirectory()) {
                        addFilesToArchive(filePath, baseDir);
                    }
                }
            }

            addFilesToArchive(resolvedSkillPath, resolvedSkillPath);
            archive.finalize();
        });

    } catch (error) {
        console.error(`[ERROR] Error creating .skill file: ${error}`);
        return null;
    }
}

function main() {
    if (process.argv.length < 3) {
        console.log('Usage: node utils/package_skill.js <path/to/skill-folder> [output-directory]');
        console.log('\nExample:');
        console.log('  node utils/package_skill.js skills/public/my-skill');
        console.log('  node utils/package_skill.js skills/public/my-skill ./dist');
        process.exit(1);
    }

    const skillPath = process.argv[2];
    const outputDir = process.argv[3] || null;

    console.log(`Packaging skill: ${skillPath}`);
    if (outputDir) {
        console.log(`   Output directory: ${outputDir}`);
    }
    console.log();

    packageSkill(skillPath, outputDir)
        .then(result => {
            if (result) {
                process.exit(0);
            } else {
                process.exit(1);
            }
        })
        .catch(error => {
            console.error(`[ERROR] ${error}`);
            process.exit(1);
        });
}

if (require.main === module) {
    main();
}
