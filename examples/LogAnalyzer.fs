open System
open System.Collections.Generic
open System.Text.RegularExpressions

// OpenClaw log analyzer (F#) — parses gateway access logs from stdin
let pattern = Regex(@"^(\S+)\s+(INFO|WARN|ERROR)\s+(\S+)\s+(.+)$")

[<EntryPoint>]
let main _ =
    let counts = Dictionary<string, int>()
    for level in [ "INFO"; "WARN"; "ERROR" ] do
        counts.[level] <- 0

    let rec loop () =
        match Console.ReadLine() with
        | null -> ()
        | line ->
            let m = pattern.Match(line)
            if m.Success then
                let level = m.Groups.[2].Value
                counts.[level] <- counts.[level] + 1
                if level = "ERROR" then
                    printfn "⚠ %s [%s] %s" m.Groups.[1].Value m.Groups.[3].Value m.Groups.[4].Value
            loop ()
    loop ()

    printfn "\n--- Summary ---"
    for level in [ "ERROR"; "INFO"; "WARN" ] do
        printfn "%s: %d" level counts.[level]
    0
