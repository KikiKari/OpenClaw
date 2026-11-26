// abstraction-provenance: {"artifact_sha256": "3fa0a2fb4ed690b35a0d0f84a8a787a95e5dfe3e42f54cda5ddd17a12b71c58a", "source_sha256": "b97ad7dc26be724af240b4c0c98ec196e729e0702664b99c65e0e3c435a1b5af", "target_language": "fsharp"}
// sync-local.ps1 — portiert nach fsharp
// Quelle: powershell, Onboarding@main:scripts/sync-local.ps1
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

open System
open System.Diagnostics
open System.IO
open System.Text.RegularExpressions

/// <summary>
/// Hält den lokalen Dev-Stack (docker-compose.dev.yml) inkrementell mit GitHub synchron.
/// </summary>
///
/// <description>
/// Pollt origin/&lt;Branch&gt; und zieht neue Commits per Fast-Forward. Danach entscheidet
/// der Diff, was nötig ist:
///   - nur Quellcode geändert            -> nichts tun, Hot-Reload übernimmt
///   - package.json / package-lock.json  -> Frontend-Container neu starten
///                                          (Entrypoint installiert Dependencies nur
///                                          bei geändertem Lockfile-Hash nach)
///   - backend/Dockerfile, requirements* -> Backend-Image gezielt neu bauen
///   - docker-compose.dev.yml            -> Dev-Stack neu erzeugen
/// Es wird nie „blind" der ganze Branch neu gebaut.
/// </description>
///
/// <example>
/// dotnet sync-local.dll                // Dauerbetrieb, 20-s-Intervall
/// dotnet sync-local.dll --once        // genau ein Sync-Durchlauf
/// dotnet sync-local.dll --branch main // anderen Branch verfolgen
/// </example>

[<EntryPoint>]
let main argv =
    let mutable branch = "claude/onboarding-persistent-sandbox-vjfmcx"
    let mutable intervalSeconds = 20
    let composeFile = "docker-compose.dev.yml"
    let mutable once = false

    // Argumente parsen
    let rec parseArgs args =
        match args with
        | "--branch" :: value :: rest ->
            branch <- value
            parseArgs rest
        | "--interval" :: value :: rest ->
            intervalSeconds <- int value
            parseArgs rest
        | "--once" :: rest ->
            once <- true
            parseArgs rest
        | _ :: rest -> parseArgs rest
        | [] -> ()

    parseArgs (List.ofArray argv)

    let repoRoot = Path.GetDirectoryName(Process.GetCurrentProcess().MainModule.FileName)
    Directory.SetCurrentDirectory(repoRoot)

    let log (msg: string) =
        printfn "[%s] %s" (DateTime.Now.ToString("HH:mm:ss")) msg

    let invokeCompose (composeArgs: string list) =
        let psi = ProcessStartInfo("docker", ["compose"; "-f"; composeFile] @ composeArgs |> List.toArray |> String.concat " ")
        psi.UseShellExecute <- false
        let proc = Process.Start(psi)
        proc.WaitForExit()
        if proc.ExitCode <> 0 then
            log $"WARNUNG: docker compose %s{String.concat " " composeArgs} fehlgeschlagen (Exit %i{proc.ExitCode})"

    // Sicherstellen, dass der Ziel-Branch ausgecheckt ist.
    let getCurrentBranch() =
        let psi = ProcessStartInfo("git", ["rev-parse"; "--abbrev-ref"; "HEAD"])
        psi.UseShellExecute <- false
        psi.RedirectStandardOutput <- true
        let proc = Process.Start(psi)
        let result = proc.StandardOutput.ReadToEnd().Trim()
        proc.WaitForExit()
        result

    let current = getCurrentBranch()
    if current <> branch then
        log $"Wechsle von '%s{current}' auf '%s{branch}' …"
        let fetchPsi = ProcessStartInfo("git", ["fetch"; "origin"; branch])
        fetchPsi.UseShellExecute <- false
        let fetchProc = Process.Start(fetchPsi)
        fetchProc.WaitForExit()

        let switchPsi = ProcessStartInfo("git", ["switch"; branch])
        switchPsi.UseShellExecute <- false
        switchPsi.RedirectStandardError <- true
        let switchProc = Process.Start(switchPsi)
        switchProc.WaitForExit()
        if switchProc.ExitCode <> 0 then
            let trackPsi = ProcessStartInfo("git", ["switch"; "-c"; branch; "--track"; $"origin/{branch}"])
            trackPsi.UseShellExecute <- false
            let trackProc = Process.Start(trackPsi)
            trackProc.WaitForExit()
            if trackProc.ExitCode <> 0 then
                failwith $"Branch '%s{branch}' konnte nicht ausgecheckt werden."

    log $"Sync aktiv: origin/%s{branch} -> %s{repoRoot} (Intervall %is-s, Compose: %s{composeFile})"

    while true do
        let fetchPsi = ProcessStartInfo("git", ["fetch"; "origin"; branch; "--quiet"])
        fetchPsi.UseShellExecute <- false
        let fetchProc = Process.Start(fetchPsi)
        fetchProc.WaitForExit()

        if fetchProc.ExitCode <> 0 then
            log $"Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in %is-s"
        else
            let getCommitHash (ref: string) =
                let psi = ProcessStartInfo("git", ["rev-parse"; ref])
                psi.UseShellExecute <- false
                psi.RedirectStandardOutput <- true
                let proc = Process.Start(psi)
                let result = proc.StandardOutput.ReadToEnd().Trim()
                proc.WaitForExit()
                result

            let local = getCommitHash "HEAD"
            let remote = getCommitHash $"origin/%s{branch}"

            if local <> remote then
                let checkAncestorPsi = ProcessStartInfo("git", ["merge-base"; "--is-ancestor"; local; remote])
                checkAncestorPsi.UseShellExecute <- false
                let checkAncestorProc = Process.Start(checkAncestorPsi)
                checkAncestorProc.WaitForExit()

                if checkAncestorProc.ExitCode <> 0 then
                    log "ACHTUNG: Lokaler Stand ist von origin/%s{branch} abgewichen (lokale Commits?). Kein automatischer Merge — bitte manuell auflösen."
                else
                    let getDiffFiles (fromRef: string) (toRef: string) =
                        let psi = ProcessStartInfo("git", ["diff"; "--name-only"; $"{fromRef}..{toRef}"])
                        psi.UseShellExecute <- false
                        psi.RedirectStandardOutput <- true
                        let proc = Process.Start(psi)
                        let output = proc.StandardOutput.ReadToEnd()
                        proc.WaitForExit()
                        output.Split('\n', StringSplitOptions.RemoveEmptyEntries) |> List.ofArray

                    let changed = getDiffFiles local remote

                    let mergePsi = ProcessStartInfo("git", ["merge"; "--ff-only"; remote; "--quiet"])
                    mergePsi.UseShellExecute <- false
                    let mergeProc = Process.Start(mergePsi)
                    mergeProc.WaitForExit()

                    log $"Aktualisiert %s{local.Substring(0, 7)} -> %s{remote.Substring(0, 7)} (%i{changed.Length} Datei(en))"

                    let frontendDeps = changed |> List.exists (fun f -> f = "package.json" || f = "package-lock.json")
                    let backendImage = changed |> List.exists (fun f -> Regex.IsMatch(f, @"^backend/(Dockerfile|requirements.*\.txt)$"))
                    let composeChanged = changed |> List.contains composeFile

                    if composeChanged then
                        log "Compose-Datei geändert — erzeuge Dev-Stack neu …"
                        invokeCompose ["up"; "-d"]

                    if backendImage then
                        log "Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …"
                        invokeCompose ["up"; "-d"; "--build"; "backend"]

                    if frontendDeps then
                        log "Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …"
                        invokeCompose ["restart"; "frontend"]

                    if not (composeChanged || backendImage || frontendDeps) then
                        log "Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig."

        if once then break
        System.Threading.Thread.Sleep(intervalSeconds * 1000)

    0
