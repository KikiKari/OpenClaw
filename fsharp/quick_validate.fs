// abstraction-provenance: {"artifact_sha256": "88615adb392c1fa757096de8ce8ae4db94d714113f9b6f5fd112a2b5ca86ef3d", "source_sha256": "3e3cdceba2daa893e260551c8c5f09937f94be1153307185c7fc7c24c0896750", "target_language": "fsharp"}
// quick_validate.py — portiert nach fsharp
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/quick_validate.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/quick_validate.py
// auch in: workspace@local:git/skills/skill-creator/scripts/quick_validate.py
// auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/quick_validate.py
// auch in: 1 weiteren Fundstellen
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

// Quick validation script for skills - minimal version

open System
open System.IO
open System.Text.RegularExpressions
open YamlDotNet.Serialization
open YamlDotNet.Serialization.NamingConventions

let MAX_SKILL_NAME_LENGTH = 64

let private extractFrontmatter (content: string) : string option =
    let lines = content.Split([| '\r'; '\n' |], StringSplitOptions.None)
    if lines.Length = 0 || lines.[0].Trim() <> "---" then
        None
    else
        let mutable endIndex = -1
        for i in 1 .. lines.Length - 1 do
            if lines.[i].Trim() = "---" then
                endIndex <- i
                break
        if endIndex = -1 then
            None
        else
            lines.[1..endIndex-1] |> String.concat Environment.NewLine |> Some

let private parseSimpleFrontmatter (frontmatterText: string) : Map<string, string> option =
    // Minimal fallback parser used when YamlDotNet is unavailable.
    // Supports simple `key: value` mappings used by SKILL.md frontmatter.
    let mutable parsed = Map.empty
    let mutable currentKey: string option = None
    
    for rawLine in frontmatterText.Split([| '\r'; '\n' |], StringSplitOptions.None) do
        let stripped = rawLine.Trim()
        if not (String.IsNullOrEmpty(stripped)) && not (stripped.StartsWith("#")) then
            let isIndented = 
                if String.IsNullOrEmpty(rawLine) then false
                else Char.IsWhiteSpace(rawLine.[0])
            
            if isIndented then
                match currentKey with
                | None -> 
                    // Invalid format - indented line without a preceding key
                    parsed <- Map.empty
                    currentKey <- None
                | Some key ->
                    let currentValue = parsed.[key]
                    let newValue = 
                        if String.IsNullOrEmpty(currentValue) then stripped
                        else sprintf "%s\n%s" currentValue stripped
                    parsed <- Map.add key newValue parsed
            else
                if not (stripped.Contains(":")) then
                    // Invalid format - no colon in non-indented line
                    parsed <- Map.empty
                    currentKey <- None
                else
                    let parts = stripped.Split([|':'|], 2)
                    let key = parts.[0].Trim()
                    let mutable value = parts.[1].Trim()
                    
                    if not (String.IsNullOrEmpty(key)) then
                        if (value.StartsWith("\"") && value.EndsWith("\"")) || 
                           (value.StartsWith("'") && value.EndsWith("'")) then
                            value <- value.Substring(1, value.Length - 2)
                        
                        parsed <- Map.add key value parsed
                        currentKey <- Some key
                    else
                        // Invalid format - empty key
                        parsed <- Map.empty
                        currentKey <- None
    
    if parsed.IsEmpty then None else Some parsed

let validateSkill (skillPath: string) : bool * string =
    let skillDir = DirectoryInfo(skillPath)
    let skillMd = FileInfo(Path.Combine(skillDir.FullName, "SKILL.md"))
    
    if not skillMd.Exists then
        (false, "SKILL.md not found")
    else
        let content = 
            try
                File.ReadAllText(skillMd.FullName, Text.Encoding.UTF8)
            with
            | :? IOException as e -> 
                return (false, sprintf "Could not read SKILL.md: %s" e.Message)
        
        match extractFrontmatter content with
        | None -> (false, "Invalid frontmatter format")
        | Some frontmatterText ->
            let frontmatter: Map<string, obj> = 
                try
                    let deserializer = DeserializerBuilder()
                                        .WithNamingConvention(CamelCaseNamingConvention.Instance)
                                        .Build()
                    let result = deserializer.Deserialize<Map<string, obj>>(frontmatterText)
                    if isNull result then Map.empty else result
                with
                | _ -> 
                    match parseSimpleFrontmatter frontmatterText with
                    | Some simpleMap -> 
                        simpleMap |> Map.map (fun _ v -> v :> obj)
                    | None -> 
                        return (false, "Invalid YAML in frontmatter: unsupported syntax")
            
            let allowedProperties = set ["name"; "description"; "license"; "allowed-tools"; "metadata"]
            let frontmatterKeys = frontmatter.Keys |> Set.ofSeq
            let unexpectedKeys = Set.difference frontmatterKeys allowedProperties
            
            if not (Set.isEmpty unexpectedKeys) then
                let allowedList = allowedProperties |> Set.toArray |> Array.sort |> String.concat ", "
                let unexpectedList = unexpectedKeys |> Set.toArray |> Array.sort |> String.concat ", "
                (false, sprintf "Unexpected key(s) in SKILL.md frontmatter: %s. Allowed properties are: %s" unexpectedList allowedList)
            else
                if not (frontmatter.ContainsKey("name")) then
                    (false, "Missing 'name' in frontmatter")
                elif not (frontmatter.ContainsKey("description")) then
                    (false, "Missing 'description' in frontmatter")
                else
                    let nameObj = frontmatter.["name"]
                    if not (nameObj :? string) then
                        (false, sprintf "Name must be a string, got %s" (nameObj.GetType().Name))
                    else
                        let name = (nameObj :?> string).Trim()
                        if not (String.IsNullOrEmpty(name)) then
                            if not (Regex.IsMatch(name, @"^[a-z0-9-]+$")) then
                                (false, sprintf "Name '%s' should be hyphen-case (lowercase letters, digits, and hyphens only)" name)
                            elif name.StartsWith("-") || name.EndsWith("-") || name.Contains("--") then
                                (false, sprintf "Name '%s' cannot start/end with hyphen or contain consecutive hyphens" name)
                            elif name.Length > MAX_SKILL_NAME_LENGTH then
                                (false, sprintf "Name is too long (%d characters). Maximum is %d characters." name.Length MAX_SKILL_NAME_LENGTH)
                            else
                                let descriptionObj = frontmatter.["description"]
                                if not (descriptionObj :? string) then
                                    (false, sprintf "Description must be a string, got %s" (descriptionObj.GetType().Name))
                                else
                                    let description = (descriptionObj :?> string).Trim()
                                    if description.Contains("<") || description.Contains(">") then
                                        (false, "Description cannot contain angle brackets (< or >)")
                                    elif description.Length > 1024 then
                                        (false, sprintf "Description is too long (%d characters). Maximum is 1024 characters." description.Length)
                                    else
                                        (true, "Skill is valid!")
                        else
                            (true, "Skill is valid!")

[<EntryPoint>]
let main argv =
    if argv.Length <> 1 then
        printfn "Usage: quick_validate.exe <skill_directory>"
        1
    else
        let valid, message = validateSkill argv.[0]
        printfn "%s" message
        if valid then 0 else 1
