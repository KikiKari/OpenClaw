// abstraction-provenance: {"artifact_sha256": "40e352eec139ec161d693bd065cff6d4fe94271cf5fde54ecd16dda99dcdc43d", "source_sha256": "2be00c164cb61020637d0364dc8387a8085522b6bfff7606f734a5274046be44", "target_language": "fsharp"}
// test_quick_validate.py — portiert nach fsharp
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_quick_validate.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_quick_validate.py
// auch in: workspace@local:git/skills/skill-creator/scripts/test_quick_validate.py
// auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/test_quick_validate.py
// auch in: 1 weiteren Fundstellen
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

module TestQuickValidate

open System
open System.IO
open NUnit.Framework

let mutable tempDir : string = ""

[<SetUp>]
let setUp () =
    tempDir <- Path.Combine(Path.GetTempPath(), "test_quick_validate_" + Guid.NewGuid().ToString())
    Directory.CreateDirectory(tempDir) |> ignore

[<TearDown>]
let tearDown () =
    if Directory.Exists(tempDir) then
        Directory.Delete(tempDir, true)

[<Test>]
let testAcceptsCrlfFrontmatter () =
    let skillDir = Path.Combine(tempDir, "crlf-skill")
    Directory.CreateDirectory(skillDir) |> ignore
    let content = "---\r\nname: crlf-skill\r\ndescription: ok\r\n---\r\n# Skill\r\n"
    File.WriteAllText(Path.Combine(skillDir, "SKILL.md"), content)
    
    let (valid, message) = QuickValidate.validateSkill skillDir
    
    Assert.IsTrue(valid, message)

[<Test>]
let testRejectsMissingFrontmatterClosingFence () =
    let skillDir = Path.Combine(tempDir, "bad-skill")
    Directory.CreateDirectory(skillDir) |> ignore
    let content = "---\nname: bad-skill\ndescription: missing end\n# no closing fence\n"
    File.WriteAllText(Path.Combine(skillDir, "SKILL.md"), content)
    
    let (valid, message) = QuickValidate.validateSkill skillDir
    
    Assert.IsFalse(valid)
    Assert.AreEqual("Invalid frontmatter format", message)

[<Test>]
let testFallbackParserHandlesMultilineFrontmatterWithoutPyyaml () =
    let skillDir = Path.Combine(tempDir, "multiline-skill")
    Directory.CreateDirectory(skillDir) |> ignore
    let content = """---
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
"""
    File.WriteAllText(Path.Combine(skillDir, "SKILL.md"), content)
    
    // Simulate absence of YAML library by temporarily disabling it
    let previousYamlAvailable = QuickValidate.yamlAvailable
    QuickValidate.yamlAvailable <- false
    try
        let (valid, message) = QuickValidate.validateSkill skillDir
        Assert.IsTrue(valid, message)
    finally
        QuickValidate.yamlAvailable <- previousYamlAvailable

[<EntryPoint>]
let main _ =
    setUp()
    try
        testAcceptsCrlfFrontmatter()
        testRejectsMissingFrontmatterClosingFence()
        testFallbackParserHandlesMultilineFrontmatterWithoutPyyaml()
        printfn "All tests passed!"
        0
    with ex ->
        printfn "Test failed: %s" ex.Message
        1
    finally
        tearDown()
