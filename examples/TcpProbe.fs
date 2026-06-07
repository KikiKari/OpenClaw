open System.Net.Sockets

// OpenClaw TCP port probe (F#) — checks gateway nodes
let probe (host: string) (port: int) (timeoutMs: int) : bool =
    use client = new TcpClient()
    try
        let task = client.ConnectAsync(host, port)
        task.Wait(timeoutMs) && client.Connected
    with _ -> false

[<EntryPoint>]
let main _ =
    let nodes = [ ("localhost", 8080); ("localhost", 8081) ]
    for (host, port) in nodes do
        let status = if probe host port 3000 then "OK  " else "FAIL"
        printfn "%s %s:%d" status host port
    0
