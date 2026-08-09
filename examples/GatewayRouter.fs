open System

// OpenClaw gateway router — upstream node selection (port of nginx-gateway)
let nodes = [| "gateway1.openclaw.internal"; "gateway2.openclaw.internal" |]

let getNode () = nodes.[Random.Shared.Next(nodes.Length)]

[<EntryPoint>]
let main _ =
    printfn "OpenClaw routing to: %s" (getNode ())
    0
