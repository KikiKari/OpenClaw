// abstraction-provenance: {"artifact_sha256": "a66455114292c02d14f512e09b77ca898da17f07967f89f7d83387abfcc00426", "source_sha256": "5e833080809c70bbbe1eee5fa14d9d07d639ca0b16c37253625f4dc46ca1e64f", "target_language": "fsharp"}
// model_usage.py — portiert nach fsharp
// Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/model_usage.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Text.Json
open System.Diagnostics
open System.Collections.Generic
open System.Globalization

type Args = {
    Provider: string
    Mode: string
    Model: string option
    Input: string option
    Days: int option
    Format: string
    Pretty: bool
}

type ModelCost = {
    Model: string
    Cost: float
}

type JsonCurrentOutput = {
    Provider: string
    Mode: string
    Model: string
    LatestModelDate: string option
    TotalCostUSD: float option
    LatestDayCostUSD: float option
    LatestDayCostDate: string option
    DailyRowCount: int
}

type JsonAllOutput = {
    Provider: string
    Mode: string
    Models: ModelInfo array
}

and ModelInfo = {
    Model: string
    TotalCostUSD: float
}

let positiveInt (value: string) =
    match Int32.TryParse(value) with
    | (true, i) when i >= 1 -> i
    | _ -> failwith "must be an integer >= 1"

let eprint (msg: string) =
    eprintfn "%s" msg

let runCodexbarCost (provider: string) =
    let psi = ProcessStartInfo("codexbar", $"cost --format json --provider {provider}")
    psi.UseShellExecute <- false
    psi.RedirectStandardOutput <- true
    psi.StandardOutputEncoding <- Text.Encoding.UTF8
    
    use proc = new Process()
    proc.StartInfo <- psi
    try
        if not (proc.Start()) then
            failwith "Failed to start codexbar process"
        
        let output = proc.StandardOutput.ReadToEnd()
        proc.WaitForExit()
        
        if proc.ExitCode <> 0 then
            failwith $"codexbar cost failed (exit {proc.ExitCode})"
            
        JsonSerializer.Deserialize<JsonElement>(output)
    with
    | :? FileNotFoundException -> failwith "codexbar not found on PATH. Install CodexBar CLI first."
    | :? JsonException as ex -> failwith $"Failed to parse codexbar JSON output: {ex.Message}"

let loadPayload (inputPath: string option) (provider: string) =
    let data =
        match inputPath with
        | Some "-" -> 
            let raw = Console.In.ReadToEnd()
            JsonSerializer.Deserialize<JsonElement>(raw)
        | Some path ->
            let raw = File.ReadAllText(path, Text.Encoding.UTF8)
            JsonSerializer.Deserialize<JsonElement>(raw)
        | None -> runCodexbarCost(provider)
    
    match data.ValueKind with
    | JsonValueKind.Object -> data
    | JsonValueKind.Array ->
        let mutable result = None
        for entry in data.EnumerateArray() do
            if entry.ValueKind = JsonValueKind.Object then
                match entry.GetProperty("provider") with
                | prop when prop.GetString() = provider -> 
                    result <- Some(entry)
                    break
                | _ -> ()
        match result with
        | Some r -> r
        | None -> failwith $"Provider '{provider}' not found in codexbar payload."
    | _ -> failwith "Unsupported JSON input format."

let parseDailyEntries (payload: JsonElement) =
    match payload.TryGetProperty("daily") with
    | (true, daily) when daily.ValueKind = JsonValueKind.Array ->
        [for entry in daily.EnumerateArray() do
            if entry.ValueKind = JsonValueKind.Object then yield entry]
    | _ -> []

let parseDate (value: string) =
    match DateTime.TryParseExact(value, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None) with
    | (true, dt) -> Some(dt.Date)
    | _ -> None

let filterByDays (entries: JsonElement list) (days: int option) =
    match days with
    | None -> entries
    | Some n ->
        let cutoff = DateTime.Today.AddDays(-float (n - 1))
        [for entry in entries do
            match entry.TryGetProperty("date") with
            | (true, dateProp) when dateProp.ValueKind = JsonValueKind.String ->
                match parseDate(dateProp.GetString()) with
                | Some dt when dt >= cutoff -> yield entry
                | _ -> ()
            | _ -> ()]

let aggregateCosts (entries: JsonElement seq) =
    let totals = Dictionary<string, float>()
    for entry in entries do
        match entry.TryGetProperty("modelBreakdowns") with
        | (true, breakdowns) when breakdowns.ValueKind = JsonValueKind.Array ->
            for item in breakdowns.EnumerateArray() do
                if item.ValueKind = JsonValueKind.Object then
                    match item.TryGetProperty("modelName"), item.TryGetProperty("cost") with
                    | (true, modelNameProp), (true, costProp) 
                      when modelNameProp.ValueKind = JsonValueKind.String && 
                           (costProp.ValueKind = JsonValueKind.Number || costProp.ValueKind = JsonValueKind.String) ->
                        let model = modelNameProp.GetString()
                        let cost = 
                            match costProp.TryGetDouble() with
                            | (true, d) -> d
                            | _ -> 
                                match Double.TryParse(costProp.GetString()) with
                                | (true, d) -> d
                                | _ -> 0.0
                        
                        if totals.ContainsKey(model) then
                            totals.[model] <- totals.[model] + cost
                        else
                            totals.[model] <- cost
                    | _ -> ()
        | _ -> ()
    totals

let pickCurrentModel (entries: JsonElement list) =
    if List.isEmpty entries then
        None, None
    else
        let sortedEntries = 
            entries 
            |> List.sortBy (fun entry -> 
                match entry.TryGetProperty("date") with
                | (true, dateProp) when dateProp.ValueKind = JsonValueKind.String -> dateProp.GetString()
                | _ -> "")
        
        for entry in List.rev sortedEntries do
            match entry.TryGetProperty("modelBreakdowns") with
            | (true, breakdowns) when breakdowns.ValueKind = JsonValueKind.Array && breakdowns.GetArrayLength() > 0 ->
                let scored = ResizeArray<ModelCost>()
                for item in breakdowns.EnumerateArray() do
                    if item.ValueKind = JsonValueKind.Object then
                        match item.TryGetProperty("modelName"), item.TryGetProperty("cost") with
                        | (true, modelNameProp), (true, costProp) 
                          when modelNameProp.ValueKind = JsonValueKind.String && 
                               (costProp.ValueKind = JsonValueKind.Number || costProp.ValueKind = JsonValueKind.String) ->
                            let model = modelNameProp.GetString()
                            let cost = 
                                match costProp.TryGetDouble() with
                                | (true, d) -> d
                                | _ -> 
                                    match Double.TryParse(costProp.GetString()) with
                                    | (true, d) -> d
                                    | _ -> 0.0
                            scored.Add({Model = model; Cost = cost})
                        | _ -> ()
                
                if scored.Count > 0 then
                    scored.Sort(fun a b -> compare b.Cost a.Cost)
                    let latestModel = scored.[0].Model
                    let latestDate = 
                        match entry.TryGetProperty("date") with
                        | (true, dateProp) when dateProp.ValueKind = JsonValueKind.String -> Some(dateProp.GetString())
                        | _ -> None
                    return Some(latestModel), latestDate
            | _ ->
                match entry.TryGetProperty("modelsUsed") with
                | (true, modelsUsed) when modelsUsed.ValueKind = JsonValueKind.Array && modelsUsed.GetArrayLength() > 0 ->
                    let lastItem = modelsUsed.EnumerateArray() |> Seq.last
                    if lastItem.ValueKind = JsonValueKind.String then
                        let latestModel = lastItem.GetString()
                        let latestDate = 
                            match entry.TryGetProperty("date") with
                            | (true, dateProp) when dateProp.ValueKind = JsonValueKind.String -> Some(dateProp.GetString())
                            | _ -> None
                        return Some(latestModel), latestDate
                | _ -> ()
        None, None

let usd (value: float option) =
    match value with
    | None -> "—"
    | Some v -> v.ToString("C2", CultureInfo.CreateSpecificCulture("en-US")).Replace("$", "$")

let latestDayCost (entries: JsonElement list) (model: string) =
    if List.isEmpty entries then
        None, None
    else
        let sortedEntries = 
            entries 
            |> List.sortBy (fun entry -> 
                match entry.TryGetProperty("date") with
                | (true, dateProp) when dateProp.ValueKind = JsonValueKind.String -> dateProp.GetString()
                | _ -> "")
        
        for entry in List.rev sortedEntries do
            match entry.TryGetProperty("modelBreakdowns") with
            | (true, breakdowns) when breakdowns.ValueKind = JsonValueKind.Array ->
                for item in breakdowns.EnumerateArray() do
                    if item.ValueKind = JsonValueKind.Object then
                        match item.TryGetProperty("modelName") with
                        | (true, modelNameProp) when modelNameProp.GetString() = model ->
                            let cost = 
                                match item.TryGetProperty("cost") with
                                | (true, costProp) when costProp.ValueKind = JsonValueKind.Number -> Some(costProp.GetDouble())
                                | (true, costProp) when costProp.ValueKind = JsonValueKind.String -> 
                                    match Double.TryParse(costProp.GetString()) with
                                    | (true, d) -> Some(d)
                                    | _ -> None
                                | _ -> None
                            
                            let day = 
                                match entry.TryGetProperty("date") with
                                | (true, dateProp) when dateProp.ValueKind = JsonValueKind.String -> Some(dateProp.GetString())
                                | _ -> None
                            
                            return day, cost
                        | _ -> ()
            | _ -> ()
        None, None

let renderTextCurrent (provider: string) (model: string) (latestDate: string option) (totalCost: float option) (latestCost: float option) (latestCostDate: string option) (entryCount: int) =
    let lines = [
        $"Provider: {provider}"
        $"Current model: {model}"
        match latestDate with Some d -> [$"Latest model date: {d}"] | None -> []
        $"Total cost (rows): {usd totalCost}"
        match latestCost, latestCostDate with
        | Some cost, Some date -> [$"Latest day cost: {usd (Some cost)} ({date})"]
        | _ -> []
        $"Daily rows: {entryCount}"
    ] |> List.collect id
    
    String.Join("\n", lines)

let renderTextAll (provider: string) (totals: Dictionary<string, float>) =
    let sortedTotals = 
        totals 
        |> Seq.toList 
        |> List.sortByDescending snd
    
    let lines = [
        $"Provider: {provider}"
        "Models:"
    ] @ [for (model, cost) in sortedTotals -> $"- {model}: {usd (Some cost)}"]
    
    String.Join("\n", lines)

let buildJsonCurrent (provider: string) (model: string) (latestDate: string option) (totalCost: float option) (latestCost: float option) (latestCostDate: string option) (entryCount: int) =
    {
        Provider = provider
        Mode = "current"
        Model = model
        LatestModelDate = latestDate
        TotalCostUSD = totalCost
        LatestDayCostUSD = latestCost
        LatestDayCostDate = latestCostDate
        DailyRowCount = entryCount
    }

let buildJsonAll (provider: string) (totals: Dictionary<string, float>) =
    let sortedModels = 
        totals 
        |> Seq.map (fun kvp -> {Model = kvp.Key; TotalCostUSD = kvp.Value})
        |> Seq.sortByDescending (fun m -> m.TotalCostUSD)
        |> Seq.toArray
    
    {
        Provider = provider
        Mode = "all"
        Models = sortedModels
    }

let main argv =
    let provider = ref "codex"
    let mode = ref "current"
    let model = ref None
    let input = ref None
    let days = ref None
    let format = ref "text"
    let pretty = ref false
    
    let rec parseArgs args =
        match args with
        | "--provider" :: p :: rest -> provider := p; parseArgs rest
        | "--mode" :: m :: rest -> mode := m; parseArgs rest
        | "--model" :: m :: rest -> model := Some m; parseArgs rest
        | "--input" :: i :: rest -> input := Some i; parseArgs rest
        | "--days" :: d :: rest -> 
            try
                days := Some(positiveInt d)
                parseArgs rest
            with _ -> failwith "Invalid --days value"
        | "--format" :: f :: rest -> format := f; parseArgs rest
        | "--pretty" :: rest -> pretty := true; parseArgs rest
        | [] -> ()
        | _ -> failwith "Unknown argument"
    
    try
        parseArgs (List.ofArray argv)
        
        let payload = loadPayload !input !provider
        let entries = parseDailyEntries payload |> filterByDays !days
        
        if !mode = "current" then
            let modelToUse, latestDate = 
                match !model with
                | Some m -> Some m, None
                | None -> pickCurrentModel entries
            
            match modelToUse with
            | None -> 
                eprint "No model data found in codexbar cost payload."
                2
            | Some m ->
                let totals = aggregateCosts entries
                let totalCost = if totals.ContainsKey(m) then Some(totals.[m]) else None
                let latestCostDate, latestCost = latestDayCost entries m
                
                if !format = "json" then
                    let payloadOut = buildJsonCurrent !provider m latestDate totalCost latestCost latestCostDate entries.Length
                    let options = JsonSerializerOptions()
                    options.WriteIndented <- !pretty
                    options.PropertyNamingPolicy <- JsonNamingPolicy.CamelCase
                    printfn "%s" (JsonSerializer.Serialize(payloadOut, options))
                else
                    printfn "%s" (renderTextCurrent !provider m latestDate totalCost latestCost latestCostDate entries.Length)
                0
        else
            let totals = aggregateCosts entries
            if totals.Count = 0 then
                eprint "No model breakdowns found in codexbar cost payload."
                2
            else
                if !format = "json" then
                    let payloadOut = buildJsonAll !provider totals
                    let options = JsonSerializerOptions()
                    options.WriteIndented <- !pretty
                    options.PropertyNamingPolicy <- JsonNamingPolicy.CamelCase
                    printfn "%s" (JsonSerializer.Serialize(payloadOut, options))
                else
                    printfn "%s" (renderTextAll !provider totals)
                0
    with
    | ex ->
        eprint ex.Message
        1

[<EntryPoint>]
let entryPoint argv =
    main argv
