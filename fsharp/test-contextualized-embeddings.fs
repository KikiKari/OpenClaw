// abstraction-provenance: {"artifact_sha256": "52d5cde59ea406c809fcc111d8548923bff7720f8aa7ea609a9971b2b0c7db2d", "source_sha256": "9b72cb69e140323c5b1a7fb2297d54571e6dc00329fc26e09bf42f52e6dae2ba", "target_language": "fsharp"}
// test-contextualized-embeddings.sh — portiert nach fsharp
// Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: 4 weiteren Fundstellen
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Net.Http
open System.Text
open System.Text.Json
open System.Threading.Tasks

let perplexityApiKey = 
    match Environment.GetEnvironmentVariable("PERPLEXITY_API_KEY") with
    | null | "" -> failwith "PERPLEXITY_API_KEY is required"
    | key -> key

let tmpDir = 
    match Environment.GetEnvironmentVariable("TMPDIR") with
    | null | "" -> "/tmp"
    | dir -> dir

let outFile = Path.Combine(tmpDir, "perplexity-contextualized-embeddings-test.json")

let payload = 
    let inputs = [|
        "OpenClaw can route web search through Perplexity."
        "The Perplexity MCP server exposes search and reasoning tools."
        "Contextualized embeddings improve document chunk retrieval."
    |]
    
    let json = JsonSerializer.Serialize({|
        input = [|inputs|]
        model = "pplx-embed-context-v1-4b"
    |})
    
    json

let client = new HttpClient()

let makeRequest() =
    task {
        let request = new HttpRequestMessage(HttpMethod.Post, "https://api.perplexity.ai/v1/contextualizedembeddings")
        request.Headers.Add("Authorization", $"Bearer {perplexityApiKey}")
        request.Content <- new StringContent(payload, Encoding.UTF8, "application/json")
        
        use response = await client.SendAsync(request)
        let! content = response.Content.ReadAsStringAsync()
        
        do! File.WriteAllTextAsync(outFile, content)
        
        return (int response.StatusCode, content)
    }

let extractInfo (json: string) =
    let doc = JsonDocument.Parse(json)
    let root = doc.RootElement
    
    let keys = 
        root.EnumerateObject()
        |> Seq.map (fun prop -> prop.Name)
        |> Seq.toArray
    
    let model = 
        match root.TryGetProperty("model") with
        | true, elem -> elem.GetString()
        | false, _ -> null
    
    let data = 
        match root.TryGetProperty("data") with
        | true, elem -> elem.EnumerateArray() |> Seq.toArray
        | false, _ -> [||]
    
    let documentCount = data.Length
    
    let firstChunkCount = 
        if data.Length > 0 then
            let firstData = data.[0]
            match firstData.TryGetProperty("data") with
            | true, elem -> elem.EnumerateArray() |> Seq.toArray |> Array.length
            | false, _ -> 0
        else
            0
    
    let error = 
        match root.TryGetProperty("error") with
        | true, elem -> elem.ToString()
        | false, _ -> null
    
    {| 
        keys = keys
        model = model
        document_count = documentCount
        first_chunk_count = firstChunkCount
        error = error
    |}

[<EntryPoint>]
let main argv =
    try
        let statusCode, content = makeRequest().Result
        printfn "contextualized_embeddings_http=%d" statusCode
        
        let info = extractInfo content
        printfn "{keys: %A, model: %s, document_count: %d, first_chunk_count: %d, error: %s}" 
            info.keys 
            (if info.model = null then "null" else info.model)
            info.document_count
            info.first_chunk_count
            (if info.error = null then "null" else info.error)
            
        0
    with
    | ex -> 
        eprintfn "Error: %s" ex.Message
        1
