// abstraction-provenance: {"artifact_sha256": "132ca94ac7cd87a1c5cab2dacdbfe3d77e67a9d429c8ca1d3ea890221aa7c84c", "source_sha256": "eed3bdbc8fef27830c5850ddac7a0ed91929c33fde29bd0fc4729b45b78fada0", "target_language": "fsharp"}
// npm-runner.mjs — portiert nach fsharp
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/npm-runner.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

module NpmRunner

open System
open System.IO

type Platform =
    | Win32
    | Other of string

type PathImpl =
    { Join: string -> string -> string
      Resolve: string -> string -> string
      Dirname: string -> string }

type Params =
    { ExecPath: string option
      NpmArgs: string list
      ExistsSync: (string -> bool) option
      Env: Map<string, string> option
      Platform: Platform option
      ComSpec: string option }

let private win32PathImpl =
    { Join = fun p1 p2 -> Path.Combine(p1, p2)
      Resolve = fun p1 p2 -> Path.GetFullPath(Path.Combine(p1, p2))
      Dirname = fun p -> Path.GetDirectoryName(p) }

let private posixPathImpl =
    { Join = fun p1 p2 -> Path.Combine(p1, p2)
      Resolve = fun p1 p2 -> Path.GetFullPath(Path.Combine(p1, p2))
      Dirname = fun p -> Path.GetDirectoryName(p) }

let private buildCmdExeCommandLine (command: string) (args: string list) =
    let escapedArgs = 
        args 
        |> List.map (fun arg ->
            if arg.Contains(" ") then "\"" + arg + "\""
            else arg)
        |> String.concat " "
    command + " " + escapedArgs

let private resolveToolchainNpmRunner (comSpec: string) (existsSync: string -> bool) (nodeDir: string) (npmArgs: string list) (pathImpl: PathImpl) (platform: Platform) =
    let npmCliCandidates = [
        pathImpl.Resolve nodeDir "../lib/node_modules/npm/bin/npm-cli.js"
        pathImpl.Resolve nodeDir "node_modules/npm/bin/npm-cli.js"
    ]
    
    let npmCliPath = 
        npmCliCandidates 
        |> List.tryFind existsSync
    
    match npmCliPath with
    | Some path ->
        let command = 
            match platform with
            | Win32 -> pathImpl.Join(nodeDir, "node.exe")
            | _ -> pathImpl.Join(nodeDir, "node")
        Some {|
            Command = command
            Args = path :: npmArgs
            Shell = false
        |}
    | None ->
        match platform with
        | Win32 ->
            let npmExePath = pathImpl.Resolve(nodeDir, "npm.exe")
            if existsSync npmExePath then
                Some {|
                    Command = npmExePath
                    Args = npmArgs
                    Shell = false
                |}
            else
                let npmCmdPath = pathImpl.Resolve(nodeDir, "npm.cmd")
                if existsSync npmCmdPath then
                    Some {|
                        Command = comSpec
                        Args = ["/d"; "/s"; "/c"; buildCmdExeCommandLine npmCmdPath npmArgs]
                        Shell = false
                        WindowsVerbatimArguments = true
                    |}
                else
                    None
        | _ -> None

let resolveNpmRunner (params: Params option) =
    let params = defaultArg params { ExecPath = None; NpmArgs = []; ExistsSync = None; Env = None; Platform = None; ComSpec = None }
    
    let execPath = defaultArg params.ExecPath Environment.GetCommandLineArgs().[0]
    let npmArgs = params.NpmArgs
    let existsSync = defaultArg params.ExistsSync File.Exists
    let env = defaultArg params.Env (Environment.GetEnvironmentVariables() |> Seq.cast<System.Collections.DictionaryEntry> |> Seq.map (fun e -> (string e.Key, string e.Value)) |> Map.ofSeq)
    let platform = 
        match params.Platform with
        | Some p -> p
        | None -> 
            match Environment.OSVersion.Platform with
            | _ when Environment.OSVersion.Platform = PlatformID.Win32NT -> Win32
            | p -> Other (p.ToString())
    
    let comSpec = 
        match params.ComSpec with
        | Some cs -> cs
        | None -> 
            match env.TryFind "ComSpec" with
            | Some cs -> cs
            | None -> "cmd.exe"
    
    let pathImpl = 
        match platform with
        | Win32 -> win32PathImpl
        | _ -> posixPathImpl
    
    let nodeDir = pathImpl.Dirname execPath
    
    let npmToolchain = resolveToolchainNpmRunner comSpec existsSync nodeDir npmArgs pathImpl platform
    
    match npmToolchain with
    | Some toolchain -> toolchain
    | None ->
        match platform with
        | Win32 ->
            let expectedPaths = [
                pathImpl.Resolve nodeDir "../lib/node_modules/npm/bin/npm-cli.js"
                pathImpl.Resolve nodeDir "node_modules/npm/bin/npm-cli.js"
                pathImpl.Resolve nodeDir "npm.exe"
                pathImpl.Resolve nodeDir "npm.cmd"
            ]
            failwith (
                sprintf "failed to resolve a toolchain-local npm next to %s. Checked: %s. OpenClaw refuses to shell out to bare npm on Windows; install a Node.js toolchain that bundles npm or run with a matching Node installation."
                    execPath
                    (String.concat ", " expectedPaths)
            )
        | _ ->
            let pathKey = "PATH" // In F# we assume PATH, could be extended for case sensitivity
            let currentPath = 
                match env.TryFind pathKey with
                | Some p -> p
                | None -> ""
            
            let newPath = 
                if not (String.IsNullOrEmpty(currentPath)) then
                    nodeDir + Path.PathSeparator.ToString() + currentPath
                else
                    nodeDir
            
            {| 
                Command = "npm"
                Args = npmArgs
                Shell = false
                Env = env.Add(pathKey, newPath)
            |}
