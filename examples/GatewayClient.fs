module GatewayClient

open System
open System.Net.Http

// OpenClaw Gateway Client (F#)
let private client = new HttpClient(Timeout = TimeSpan.FromSeconds 5.0)

let checkHealth (baseUrl: string) =
    async {
        use! response = client.GetAsync(baseUrl + "/health") |> Async.AwaitTask
        return int response.StatusCode
    }

[<EntryPoint>]
let main argv =
    let url = if argv.Length > 0 then argv.[0] else "http://localhost:8080"
    let status = checkHealth url |> Async.RunSynchronously
    printfn "Gateway %s -> HTTP %d" url status
    0
