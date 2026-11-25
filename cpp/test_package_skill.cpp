// abstraction-provenance: {"artifact_sha256": "36db499e047f1281ef936c77c9033a43b492183b9864c2c5f9da7fbbb60dbe9b", "source_sha256": "6b261a50fe632846e59e96b1c3e1f6787ffd534f7204d14bd7df8784873ac691", "target_language": "cpp"}
// test_package_skill.py — portiert nach cpp
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_package_skill.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_package_skill.py
// auch in: workspace@local:git/skills/skill-creator/scripts/test_package_skill.py
// auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/test_package_skill.py
// auch in: 1 weiteren Fundstellen
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <gtest/gtest.h>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <zip.h>
#include <cstdlib>
#include <set>
#include <iostream>

namespace fs = std::filesystem;

class TestPackageSkillSecurity : public ::testing::Test {
protected:
    fs::path temp_dir;

    void SetUp() override {
        // Create temporary directory
        std::string temp_template = "/tmp/test_skill_XXXXXX";
        char* temp_dir_cstr = mkdtemp(temp_template.data());
        if (!temp_dir_cstr) {
            FAIL() << "Failed to create temporary directory";
        }
        temp_dir = fs::path(temp_dir_cstr);
    }

    void TearDown() override {
        // Clean up temporary directory
        if (fs::exists(temp_dir)) {
            fs::remove_all(temp_dir);
        }
    }

    fs::path create_skill(const std::string& name = "test-skill") {
        fs::path skill_dir = temp_dir / name;
        fs::create_directories(skill_dir);
        
        std::ofstream md_file(skill_dir / "SKILL.md");
        md_file << "---\nname: test-skill\ndescription: test\n---\n";
        md_file.close();
        
        std::ofstream script_file(skill_dir / "script.py");
        script_file << "print('ok')\n";
        script_file.close();
        
        return skill_dir;
    }

    std::set<std::string> get_zip_contents(const fs::path& zip_path) {
        std::set<std::string> contents;
        int err;
        zip_t* archive = zip_open(zip_path.string().c_str(), 0, &err);
        if (!archive) {
            throw std::runtime_error("Failed to open zip file");
        }
        
        zip_int64_t num_entries = zip_get_num_entries(archive, 0);
        for (zip_int64_t i = 0; i < num_entries; ++i) {
            const char* name = zip_get_name(archive, i, 0);
            if (name) {
                contents.insert(name);
            }
        }
        
        zip_close(archive);
        return contents;
    }
};

// Mock implementation of package_skill function
// In a real scenario, this would be the actual implementation
bool package_skill(const std::string& skill_path, const std::string& out_path) {
    // This is a simplified mock - in reality this would implement the actual packaging logic
    fs::path skill_dir(skill_path);
    fs::path output_dir(out_path);
    
    if (!fs::exists(skill_dir) || !fs::is_directory(skill_dir)) {
        return false;
    }
    
    fs::path skill_name = skill_dir.filename();
    fs::path output_file = output_dir / (skill_name.string() + ".skill");
    
    int zip_err;
    zip_t* archive = zip_open(output_file.string().c_str(), ZIP_CREATE | ZIP_TRUNCATE, &zip_err);
    if (!archive) {
        return false;
    }
    
    // Add files to zip (simplified)
    for (const auto& entry : fs::recursive_directory_iterator(skill_dir)) {
        if (fs::is_regular_file(entry)) {
            std::string relative_path = fs::relative(entry.path(), skill_dir).string();
            std::string zip_path = (skill_name / relative_path).string();
            
            // Skip symlinks for security (mock implementation)
            if (entry.is_symlink()) {
                continue;
            }
            
            // Skip the output file itself
            if (entry.path() == output_file) {
                continue;
            }
            
            zip_source_t* source = zip_source_file(archive, entry.path().string().c_str(), 0, 0);
            if (source) {
                zip_file_add(archive, zip_path.c_str(), source, ZIP_FL_OVERWRITE);
            }
        }
    }
    
    zip_close(archive);
    return true;
}

TEST_F(TestPackageSkillSecurity, PackagesNormalFiles) {
    fs::path skill_dir = create_skill("normal-skill");
    fs::path out_dir = temp_dir / "out";
    fs::create_directories(out_dir);

    bool result = package_skill(skill_dir.string(), out_dir.string());

    ASSERT_TRUE(result);
    fs::path skill_file = out_dir / "normal-skill.skill";
    ASSERT_TRUE(fs::exists(skill_file));
    
    auto names = get_zip_contents(skill_file);
    EXPECT_NE(names.find("normal-skill/SKILL.md"), names.end());
    EXPECT_NE(names.find("normal-skill/script.py"), names.end());
}

TEST_F(TestPackageSkillSecurity, SkipsSymlinkToExternalFile) {
    fs::path skill_dir = create_skill("symlink-file-skill");
    fs::path outside = temp_dir / "outside-secret.txt";
    std::ofstream outside_file(outside);
    outside_file << "super-secret\n";
    outside_file.close();
    
    fs::path link = skill_dir / "loot.txt";
    fs::path out_dir = temp_dir / "out";
    fs::create_directories(out_dir);

    try {
        fs::create_symlink(outside, link);
    } catch (const fs::filesystem_error&) {
        GTEST_SKIP() << "symlink unsupported on this platform";
    }

    bool result = package_skill(skill_dir.string(), out_dir.string());
    ASSERT_TRUE(result);
    fs::path skill_file = out_dir / "symlink-file-skill.skill";
    ASSERT_TRUE(fs::exists(skill_file));
    
    auto names = get_zip_contents(skill_file);
    EXPECT_NE(names.find("symlink-file-skill/SKILL.md"), names.end());
    EXPECT_NE(names.find("symlink-file-skill/script.py"), names.end());
    EXPECT_EQ(names.find("symlink-file-skill/loot.txt"), names.end());
}

TEST_F(TestPackageSkillSecurity, SkipsSymlinkDirectory) {
    fs::path skill_dir = create_skill("symlink-dir-skill");
    fs::path outside_dir = temp_dir / "outside";
    fs::create_directories(outside_dir);
    std::ofstream secret_file(outside_dir / "secret.txt");
    secret_file << "secret\n";
    secret_file.close();
    
    fs::path link = skill_dir / "docs";
    fs::path out_dir = temp_dir / "out";
    fs::create_directories(out_dir);

    try {
        fs::create_directory_symlink(outside_dir, link);
    } catch (const fs::filesystem_error&) {
        GTEST_SKIP() << "symlink unsupported on this platform";
    }

    bool result = package_skill(skill_dir.string(), out_dir.string());
    ASSERT_TRUE(result);
    fs::path skill_file = out_dir / "symlink-dir-skill.skill";
    
    auto names = get_zip_contents(skill_file);
    EXPECT_NE(names.find("symlink-dir-skill/SKILL.md"), names.end());
    EXPECT_NE(names.find("symlink-dir-skill/script.py"), names.end());
    EXPECT_EQ(names.find("symlink-dir-skill/docs/secret.txt"), names.end());
}

TEST_F(TestPackageSkillSecurity, AllowsNestedRegularFiles) {
    fs::path skill_dir = create_skill("nested-skill");
    fs::path nested = skill_dir / "lib" / "helpers";
    fs::create_directories(nested);
    std::ofstream util_file(nested / "util.py");
    util_file << "def run():\n    return 1\n";
    util_file.close();
    
    fs::path out_dir = temp_dir / "out";
    fs::create_directories(out_dir);

    bool result = package_skill(skill_dir.string(), out_dir.string());

    ASSERT_TRUE(result);
    fs::path skill_file = out_dir / "nested-skill.skill";
    
    auto names = get_zip_contents(skill_file);
    EXPECT_NE(names.find("nested-skill/lib/helpers/util.py"), names.end());
}

TEST_F(TestPackageSkillSecurity, SkipsOutputArchiveWhenOutputDirIsSkillDir) {
    fs::path skill_dir = create_skill("self-output-skill");

    bool result = package_skill(skill_dir.string(), skill_dir.string());

    ASSERT_TRUE(result);
    fs::path skill_file = skill_dir / "self-output-skill.skill";
    ASSERT_TRUE(fs::exists(skill_file));
    
    auto names = get_zip_contents(skill_file);
    EXPECT_NE(names.find("self-output-skill/SKILL.md"), names.end());
    EXPECT_NE(names.find("self-output-skill/script.py"), names.end());
    EXPECT_EQ(names.find("self-output-skill/self-output-skill.skill"), names.end());
}

int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
