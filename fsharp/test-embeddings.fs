// abstraction-provenance: {"artifact_sha256": "e932aa2074c718ef2c60adb7185afc1a8b509455b78cc72c48a8865a9a66b992", "source_sha256": "28ad3a35010164ac39fa0365d55c13b161321427a1a3be5a36fa3f7c01805c2b", "target_language": "fsharp"}
// test-embeddings.sh — portiert nach fsharp
// Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: 4 weiteren Fundstellen
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Net.Http
open System.Text
open Newtonsoft.Json.Linq

let apiKey = 
    match Environment.GetEnvironmentVariable "PERPLEXITY_API_KEY" with
    | null -> failwith "PERPLEXITY_API_KEY is required"
    | key -> key

let tmpDir = 
    match Environment.GetEnvironmentVariable "TMPDIR" with
    | null -> "/tmp"
    | dir -> dir

let outFile = Path.Combine(tmpDir, "perplexity-embeddings-test.json")

let payload = """{
  "input": [
    "Scientists explore the universe driven by curiosity.",
    "Curiosity compels us to seek explanations, not just observations.",
    "Historical discoveries began with curious questions.",
    "The pursuit of knowledge distinguishes human curiosity from mere stimulus response.",
    "Philosophy examines the nature of curiosity."
  ],
  "model": "pplx-embed-v1-4b"
}"""

use client = new HttpClient()
client.DefaultRequestHeaders.Add("Authorization", $"Bearer {apiKey}")
client.DefaultRequestHeaders.Add("Content-Type", "application/json")

let content = new StringContent(payload, Encoding.UTF8, "application/json")
let! response = client.PostAsync("https://api.perplexity.ai/v1/embeddings", content)
let! responseBody = response.Content.ReadAsStringAsync()

File.WriteAllText(outFile, responseBody)

printfn "embeddings_http=%d" (int response.StatusCode)

let json = JObject.Parse(responseBody)
let result = JObject()

result.["keys"] <- JArray(json.Properties() |> Seq.map (fun p -> p.Name) |> Seq.toArray)
result.["model"] <- json.TryGetValue("model") |> function true -> json.["model"] | false -> null
result.["item_count"] <- match json.TryGetValue("data") with
                         | true -> json.["data"].AsArray().Count
                         | false -> 0
result.["first_dim"] <- match json.TryGetValue("data") with
                        | true when json.["data"].AsArray().Count > 0 ->
                            let firstEmbedding = json.["data"].[0].["embedding"]
                            if firstEmbedding <> null then firstEmbedding.AsArray().Count else 0
                        | _ -> 0
result.["error"] <- json.TryGetValue("error") |> function true -> json.["error"] | false -> null

printfn "%s" (result.ToString())
