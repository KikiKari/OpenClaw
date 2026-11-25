// abstraction-provenance: {"artifact_sha256": "c7a0f1f5c4e1ecb5aee2278fefbb17e4498e8396151ba9bd1aa4f52d357b72ae", "source_sha256": "2be00c164cb61020637d0364dc8387a8085522b6bfff7606f734a5274046be44", "target_language": "cpp"}
// test_quick_validate.py — portiert nach cpp
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_quick_validate.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_quick_validate.py
// auch in: workspace@local:git/skills/skill-creator/scripts/test_quick_validate.py
// auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/test_quick_validate.py
// auch in: 1 weiteren Fundstellen
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <filesystem>
#include <fstream>
#include <gtest/gtest.h>
#include "quick_validate.h"

namespace fs = std::filesystem;

class TestQuickValidate : public ::testing::Test {
protected:
    fs::path temp_dir;

    void SetUp() override {
        // Create temporary directory with prefix
        std::string temp_prefix = "/tmp/test_quick_validate_XXXXXX";
        char* temp_dir_cstr = mkdtemp(temp_prefix.data());
        ASSERT_NE(temp_dir_cstr, nullptr) << "Failed to create temporary directory";
        temp_dir = fs::path(temp_dir_cstr);
    }

    void TearDown() override {
        // Clean up temporary directory
        if (fs::exists(temp_dir)) {
            fs::remove_all(temp_dir);
        }
    }

    void write_file(const fs::path& filepath, const std::string& content) {
        std::ofstream file(filepath);
        file << content;
        file.close();
    }
};

TEST_F(TestQuickValidate, AcceptsCrlfFrontmatter) {
    fs::path skill_dir = temp_dir / "crlf-skill";
    fs::create_directories(skill_dir);
    
    std::string content = "---\r\nname: crlf-skill\r\ndescription: ok\r\n---\r\n# Skill\r\n";
    write_file(skill_dir / "SKILL.md", content);
    
    auto [valid, message] = quick_validate::validate_skill(skill_dir);
    
    EXPECT_TRUE(valid) << message;
}

TEST_F(TestQuickValidate, RejectsMissingFrontmatterClosingFence) {
    fs::path skill_dir = temp_dir / "bad-skill";
    fs::create_directories(skill_dir);
    
    std::string content = "---\nname: bad-skill\ndescription: missing end\n# no closing fence\n";
    write_file(skill_dir / "SKILL.md", content);
    
    auto [valid, message] = quick_validate::validate_skill(skill_dir);
    
    EXPECT_FALSE(valid);
    EXPECT_EQ(message, "Invalid frontmatter format");
}

TEST_F(TestQuickValidate, FallbackParserHandlesMultilineFrontmatterWithoutPyyaml) {
    fs::path skill_dir = temp_dir / "multiline-skill";
    fs::create_directories(skill_dir);
    
    std::string content = R"(---
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
)";
    write_file(skill_dir / "SKILL.md", content);
    
    // Temporarily disable YAML support by setting yaml_enabled to false
    bool original_yaml_enabled = quick_validate::yaml_enabled;
    quick_validate::yaml_enabled = false;
    
    auto [valid, message] = quick_validate::validate_skill(skill_dir);
    
    // Restore original value
    quick_validate::yaml_enabled = original_yaml_enabled;
    
    EXPECT_TRUE(valid) << message;
}
