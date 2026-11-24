// abstraction-provenance: {"artifact_sha256": "a19ce23ef0e1bf515493ada8f6cf79c1e2890504be4d2e6351125c3d6a56bfaf", "source_sha256": "0f2bb155d699e769ad3eb99a6500cc6dbb27948a57f7493a3b98c731200853d4", "target_language": "fsharp"}
// test-extension.mjs — portiert nach fsharp
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension.mjs
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

module Program

open System
open System.IO
open System.Diagnostics

let printUsage () =
    eprintfn "Usage: pnpm test:extension <extension-name|path> [vitest args...]"
    eprintfn "       dotnet run --project scripts/test-extension.fsproj [extension-name|path] [vitest args...]"

let printNoTestsMessage (plan: ExtensionTestPlan) =
    printfn $"[test-extension] No tests found for {plan.ExtensionDir}. Skipping."

let formatErrorMessage (ex: Exception) =
    match ex with
    | :? AggregateException as ae -> String.concat Environment.NewLine (ae.InnerExceptions |> Seq.map (fun e -> e.Message))
    | _ -> ex.Message

let resolveExtensionTestPlan (cwd: string) (targetArg: string option) =
    // Placeholder implementation - would need actual logic from extension-test-plan module
    { ExtensionDir = cwd; ExtensionId = "default"; HasTests = true; TestFileCount = 1; Config = ""; Roots = [] }

type VitestBatchRunnerOptions = {
    Args: string list
    Config: string
    Env: Map<string, string>
    Targets: string list
}

let runVitestBatch (options: VitestBatchRunnerOptions) =
    async {
        // Placeholder implementation - would need actual logic from vitest-batch-runner module
        return 0
    }

let isDirectScriptRun (metaUrl: string) =
    // In F#, we can't easily check import.meta.url like in JS
    // This would typically be handled by how the application is invoked
    true

let rec removeFlagPrefixes lst =
    match lst with
    | [] -> []
    | head :: tail when head.StartsWith("-") -> removeFlagPrefixes tail
    | _ -> lst

let shift lst =
    match lst with
    | [] -> (None, [])
    | head :: tail -> (Some head, tail)

[<EntryPoint>]
let main argv =
    async {
        let rawArgs = Array.toList argv
        if List.contains "--help" rawArgs || List.contains "-h" rawArgs then
            printUsage()
            return 0

        let passthroughArgs = List.filter (fun (arg: string) -> arg <> "--") rawArgs

        let mutable targetArgOpt = None
        let remainingArgs = 
            if not passthroughArgs.IsEmpty && not (passthroughArgs.Head.StartsWith("-")) then
                let (head, tail) = shift passthroughArgs
                targetArgOpt <- head
                tail
            else
                passthroughArgs

        let plan =
            try
                resolveExtensionTestPlan (Directory.GetCurrentDirectory()) targetArgOpt
            with
            | ex ->
                printUsage()
                eprintfn "%s" (formatErrorMessage ex)
                Process.GetCurrentProcess().Kill()
                failwith "Exit"

        if not plan.HasTests then
            printNoTestsMessage plan
            return 0

        printfn $"[test-extension] Running {plan.TestFileCount} test files for {plan.ExtensionId}"
        
        let options = {
            Args = remainingArgs
            Config = plan.Config
            Env = Map.empty // In real implementation, populate with environment variables
            Targets = plan.Roots
        }
        
        let! exitCode = runVitestBatch options
        return exitCode
    } |> Async.RunSynchronously
