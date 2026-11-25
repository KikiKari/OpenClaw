// abstraction-provenance: {"artifact_sha256": "f96aee80997fecc945797bd61a4c1e078d9c45b6246bdc7cf5704c177ea62ae4", "source_sha256": "6b261a50fe632846e59e96b1c3e1f6787ffd534f7204d14bd7df8784873ac691", "target_language": "java"}
// test_package_skill.py — portiert nach java
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_package_skill.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_package_skill.py
// auch in: workspace@local:git/skills/skill-creator/scripts/test_package_skill.py
// auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/test_package_skill.py
// auch in: 1 weiteren Fundstellen
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.MockedStatic;
import org.mockito.Mockito;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.zip.*;
import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;

/**
 * Regression tests for skill packaging security behavior.
 */
public class TestPackageSkillSecurity {

    @TempDir
    Path tempDir;

    private Path createSkill(String name) throws IOException {
        Path skillDir = tempDir.resolve(name);
        Files.createDirectories(skillDir);
        
        Path skillMd = skillDir.resolve("SKILL.md");
        Files.write(skillMd, "---\nname: test-skill\ndescription: test\n---\n".getBytes(StandardCharsets.UTF_8));
        
        Path scriptPy = skillDir.resolve("script.py");
        Files.write(scriptPy, "print('ok')\n".getBytes(StandardCharsets.UTF_8));
        
        return skillDir;
    }

    private Set<String> getArchiveEntries(Path archivePath) throws IOException {
        Set<String> entries = new HashSet<>();
        try (ZipInputStream zis = new ZipInputStream(Files.newInputStream(archivePath))) {
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                entries.add(entry.getName());
            }
        }
        return entries;
    }

    @Test
    public void testPackagesNormalFiles() throws IOException {
        Path skillDir = createSkill("normal-skill");
        Path outDir = tempDir.resolve("out");
        Files.createDirectory(outDir);

        String result = PackageSkill.packageSkill(skillDir.toString(), outDir.toString());

        assertNotNull(result);
        Path skillFile = outDir.resolve("normal-skill.skill");
        assertTrue(Files.exists(skillFile));
        
        Set<String> names = getArchiveEntries(skillFile);
        assertTrue(names.contains("normal-skill/SKILL.md"));
        assertTrue(names.contains("normal-skill/script.py"));
    }

    @Test
    public void testSkipsSymlinkToExternalFile() throws IOException {
        Path skillDir = createSkill("symlink-file-skill");
        Path outside = tempDir.resolve("outside-secret.txt");
        Files.write(outside, "super-secret\n".getBytes(StandardCharsets.UTF_8));
        Path link = skillDir.resolve("loot.txt");
        Path outDir = tempDir.resolve("out");
        Files.createDirectory(outDir);

        try {
            Files.createSymbolicLink(link, outside);
        } catch (UnsupportedOperationException e) {
            // Symlinks not supported, skip test
            assumeTrue(false, "symlink unsupported on this platform");
        }

        String result = PackageSkill.packageSkill(skillDir.toString(), outDir.toString());
        assertNotNull(result);
        Path skillFile = outDir.resolve("symlink-file-skill.skill");
        assertTrue(Files.exists(skillFile));
        
        Set<String> names = getArchiveEntries(skillFile);
        assertTrue(names.contains("symlink-file-skill/SKILL.md"));
        assertTrue(names.contains("symlink-file-skill/script.py"));
        assertFalse(names.contains("symlink-file-skill/loot.txt"));
    }

    @Test
    public void testSkipsSymlinkDirectory() throws IOException {
        Path skillDir = createSkill("symlink-dir-skill");
        Path outsideDir = tempDir.resolve("outside");
        Files.createDirectories(outsideDir);
        Path secretFile = outsideDir.resolve("secret.txt");
        Files.write(secretFile, "secret\n".getBytes(StandardCharsets.UTF_8));
        Path link = skillDir.resolve("docs");
        Path outDir = tempDir.resolve("out");
        Files.createDirectory(outDir);

        try {
            Files.createSymbolicLink(link, outsideDir);
        } catch (UnsupportedOperationException e) {
            // Symlinks not supported, skip test
            assumeTrue(false, "symlink unsupported on this platform");
        }

        String result = PackageSkill.packageSkill(skillDir.toString(), outDir.toString());
        assertNotNull(result);
        Path skillFile = outDir.resolve("symlink-dir-skill.skill");
        
        Set<String> names = getArchiveEntries(skillFile);
        assertTrue(names.contains("symlink-dir-skill/SKILL.md"));
        assertTrue(names.contains("symlink-dir-skill/script.py"));
        assertFalse(names.contains("symlink-dir-skill/docs/secret.txt"));
    }

    @Test
    public void testRejectsResolvedPathOutsideSkillRoot() throws IOException {
        Path skillDir = createSkill("escape-skill");
        Path outDir = tempDir.resolve("out");
        Files.createDirectory(outDir);

        // Mock the _is_within method to simulate path validation failure
        try (MockedStatic<PackageSkill> mocked = Mockito.mockStatic(PackageSkill.class)) {
            mocked.when(() -> PackageSkill._isWithin(any(Path.class), any(Path.class)))
                 .thenCallRealMethod(); // Keep original behavior except for specific case
            
            // Override behavior for script.py
            mocked.when(() -> PackageSkill._isWithin(Mockito.argThat(path -> 
                path != null && path.getFileName().toString().equals("script.py")), any(Path.class)))
                 .thenReturn(false);

            String result = PackageSkill.packageSkill(skillDir.toString(), outDir.toString());
            assertNull(result);
        }
    }

    @Test
    public void testAllowsNestedRegularFiles() throws IOException {
        Path skillDir = createSkill("nested-skill");
        Path nested = skillDir.resolve("lib").resolve("helpers");
        Files.createDirectories(nested);
        Path utilPy = nested.resolve("util.py");
        Files.write(utilPy, "def run():\n    return 1\n".getBytes(StandardCharsets.UTF_8));
        Path outDir = tempDir.resolve("out");
        Files.createDirectory(outDir);

        String result = PackageSkill.packageSkill(skillDir.toString(), outDir.toString());

        assertNotNull(result);
        Path skillFile = outDir.resolve("nested-skill.skill");
        Set<String> names = getArchiveEntries(skillFile);
        assertTrue(names.contains("nested-skill/lib/helpers/util.py"));
    }

    @Test
    public void testSkipsOutputArchiveWhenOutputDirIsSkillDir() throws IOException {
        Path skillDir = createSkill("self-output-skill");

        String result = PackageSkill.packageSkill(skillDir.toString(), skillDir.toString());

        assertNotNull(result);
        Path skillFile = skillDir.resolve("self-output-skill.skill");
        assertTrue(Files.exists(skillFile));
        
        Set<String> names = getArchiveEntries(skillFile);
        assertTrue(names.contains("self-output-skill/SKILL.md"));
        assertTrue(names.contains("self-output-skill/script.py"));
        assertFalse(names.contains("self-output-skill/self-output-skill.skill"));
    }
}
