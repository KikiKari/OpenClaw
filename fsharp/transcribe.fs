// abstraction-provenance: {"artifact_sha256": "2486e40fbbb830f4a731d813a3eef1f862224f0c7f67821ba2c080a782827219", "source_sha256": "9c8abc93c198b77f804a6837db7baf1e85c902dc35a853c8086222a89f83fc89", "target_language": "fsharp"}
// transcribe.sh — portiert nach fsharp
// Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/openai-whisper-api/scripts/transcribe.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Net.Http
open System.Net.Http.Headers
open System.Text.Json
open System.Threading.Tasks

let usage () =
    eprintfn "Usage:"
    eprintfn "  transcribe.sh <audio-file> [--model whisper-1] [--out /path/to/out.txt] [--language en] [--prompt \"hint\"] [--json]"
    exit 2

type Args = {
    InputFile: string
    Model: string
    OutputFile: string
    Language: string
    Prompt: string
    JsonResponse: bool
}

let parseArgs (args: string[]) =
    let rec parse args acc =
        match args with
        | [| |] -> acc
        | [| first; rest |] when first = "-h" || first = "--help" -> usage()
        | input :: rest ->
            let mutable model = "whisper-1"
            let mutable out = ""
            let mutable language = ""
            let mutable prompt = ""
            let mutable json = false
            
            let rec parseOptions opts =
                match opts with
                | "--model" :: value :: rest ->
                    model <- value
                    parseOptions rest
                | "--out" :: value :: rest ->
                    out <- value
                    parseOptions rest
                | "--language" :: value :: rest ->
                    language <- value
                    parseOptions rest
                | "--prompt" :: value :: rest ->
                    prompt <- value
                    parseOptions rest
                | "--json" :: rest ->
                    json <- true
                    parseOptions rest
                | unknown :: _ ->
                    eprintfn "Unknown arg: %s" unknown
                    usage()
                | [] -> ()
                | _ -> usage()
            
            parseOptions rest
            
            { InputFile = input
              Model = model
              OutputFile = out
              Language = language
              Prompt = prompt
              JsonResponse = json }
        | _ -> usage()
    
    if args.Length = 0 then
        usage()
    
    parse (Array.toList args) { InputFile = ""; Model = "whisper-1"; OutputFile = ""; Language = ""; Prompt = ""; JsonResponse = false }

let validateAndSetDefaults (args: Args) =
    if not (File.Exists args.InputFile) then
        eprintfn "File not found: %s" args.InputFile
        exit 1
    
    let apiKey = 
        match Environment.GetEnvironmentVariable "OPENAI_API_KEY" with
        | null | "" -> 
            eprintfn "Missing OPENAI_API_KEY"
            exit 1
        | key -> key
    
    let outputFile = 
        if args.OutputFile = "" then
            let baseName = Path.GetFileNameWithoutExtension args.InputFile
            let dir = Path.GetDirectoryName args.InputFile
            if args.JsonResponse then
                Path.Combine(dir, baseName + ".json")
            else
                Path.Combine(dir, baseName + ".txt")
        else
            args.OutputFile
    
    Directory.CreateDirectory(Path.GetDirectoryName outputFile) |> ignore
    
    (args, apiKey, outputFile)

let createMultipartContent (args: Args) =
    let content = new MultipartFormDataContent()
    
    // Add file
    let fileBytes = File.ReadAllBytes args.InputFile
    let fileContent = new ByteArrayContent(fileBytes)
    fileContent.Headers.ContentDisposition <- ContentDispositionHeaderValue.Parse(sprintf "form-data; name=\"file\"; filename=\"%s\"" (Path.GetFileName args.InputFile))
    content.Add(fileContent)
    
    // Add model
    content.Add(new StringContent(args.Model), "model")
    
    // Add response format
    let responseFormat = if args.JsonResponse then "json" else "text"
    content.Add(new StringContent(responseFormat), "response_format")
    
    // Add optional parameters
    if args.Language <> "" then
        content.Add(new StringContent(args.Language), "language")
    
    if args.Prompt <> "" then
        content.Add(new StringContent(args.Prompt), "prompt")
    
    content

let sendRequest (apiKey: string) (content: MultipartFormDataContent) =
    task {
        use client = new HttpClient()
        client.DefaultRequestHeaders.Authorization <- AuthenticationHeaderValue("Bearer", apiKey)
        client.DefaultRequestHeaders.Accept.Add(MediaTypeWithQualityHeaderValue("application/json"))
        
        let baseUrl = 
            match Environment.GetEnvironmentVariable "OPENAI_BASE_URL" with
            | null | "" -> "https://api.openai.com/v1"
            | url -> url.TrimEnd('/')
        
        let! response = client.PostAsync(sprintf "%s/audio/transcriptions" baseUrl, content)
        return! response.Content.ReadAsStringAsync()
    }

[<EntryPoint>]
let main argv =
    let args = parseArgs argv
    let (parsedArgs, apiKey, outputFile) = validateAndSetDefaults args
    let content = createMultipartContent parsedArgs
    
    let result = sendRequest apiKey content |> Async.AwaitTask |> Async.RunSynchronously
    File.WriteAllText(outputFile, result)
    printfn "%s" outputFile
    0
