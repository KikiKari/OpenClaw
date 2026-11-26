// abstraction-provenance: {"artifact_sha256": "840b40fe79e4afa50fdf798403f4cbb699679dba4a9a8b3c2c92e7d1de7656ad", "source_sha256": "a34985d25128cedfc16fb8a861471a22db49d62133276bbab6c7492eee461c4d", "target_language": "fsharp"}
// npm-publish-plan.mjs — portiert nach fsharp
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/npm-publish-plan.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

module NpmPublishPlan

open System
open System.Text.RegularExpressions

let private stableVersionRegex = Regex(@"^(?<year>\d{4})\.(?<month>[1-9]\d?)\.(?<day>[1-9]\d?)$")
let private betaVersionRegex = Regex(@"^(?<year>\d{4})\.(?<month>[1-9]\d?)\.(?<day>[1-9]\d?)-beta\.(?<beta>[1-9]\d*)$")
let private correctionVersionRegex = Regex(@"^(?<year>\d{4})\.(?<month>[1-9]\d?)\.(?<day>[1-9]\d?)-(?<correction>[1-9]\d*)$")

type ParsedReleaseVersion = {
    Version: string
    BaseVersion: string
    Channel: string
    Year: int
    Month: int
    Day: int
    BetaNumber: int option
    CorrectionNumber: int option
    Date: DateTime
}

type NpmPublishPlan = {
    Channel: string
    PublishTag: string
    MirrorDistTags: string list
}

type NpmDistTagMirrorAuth = {
    HasAuth: bool
    Source: string
}

type NpmPublishMode = 
    | DryRun
    | Publish

let private parseDateParts (version: string) (groups: GroupCollection) (channel: string) : ParsedReleaseVersion option =
    let year = int groups.["year"].Value
    let month = int groups.["month"].Value
    let day = int groups.["day"].Value
    let betaNumber = 
        if channel = "beta" then 
            Some(int groups.["beta"].Value)
        else 
            None

    if month < 1 || month > 12 || day < 1 || day > 31 then
        None
    elif channel = "beta" && (betaNumber.IsNone || betaNumber.Value < 1) then
        None
    else
        let date = DateTime(year, month, day)
        if date.Year <> year || date.Month <> month || date.Day <> day then
            None
        else
            Some({
                Version = version
                BaseVersion = sprintf "%d.%d.%d" year month day
                Channel = channel
                Year = year
                Month = month
                Day = day
                BetaNumber = betaNumber
                CorrectionNumber = None
                Date = date
            })

let parseReleaseVersion (version: string) : ParsedReleaseVersion option =
    let trimmed = version.Trim()
    if String.IsNullOrEmpty(trimmed) then
        None
    else
        let stableMatch = stableVersionRegex.Match(trimmed)
        if stableMatch.Success then
            parseDateParts trimmed stableMatch.Groups "stable"
        else
            let betaMatch = betaVersionRegex.Match(trimmed)
            if betaMatch.Success then
                parseDateParts trimmed betaMatch.Groups "beta"
            else
                let correctionMatch = correctionVersionRegex.Match(trimmed)
                if correctionMatch.Success then
                    let parsedCorrection = parseDateParts trimmed correctionMatch.Groups "stable"
                    let correctionNumber = int correctionMatch.Groups.["correction"].Value
                    match parsedCorrection with
                    | Some pc when correctionNumber >= 1 ->
                        Some({ pc with CorrectionNumber = Some correctionNumber })
                    | _ -> None
                else
                    None

let compareReleaseVersions (left: string) (right: string) : int option =
    match parseReleaseVersion left, parseReleaseVersion right with
    | Some parsedLeft, Some parsedRight ->
        let dateDelta = parsedLeft.Date.CompareTo(parsedRight.Date)
        if dateDelta <> 0 then
            Some(Math.Sign(dateDelta))
        elif parsedLeft.Channel <> parsedRight.Channel then
            if parsedLeft.Channel = "stable" then Some(1) else Some(-1)
        elif parsedLeft.Channel = "beta" && parsedRight.Channel = "beta" then
            let leftBeta = defaultArg parsedLeft.BetaNumber 0
            let rightBeta = defaultArg parsedRight.BetaNumber 0
            Some(Math.Sign(leftBeta - rightBeta))
        else
            let leftCorrection = defaultArg parsedLeft.CorrectionNumber 0
            let rightCorrection = defaultArg parsedRight.CorrectionNumber 0
            Some(Math.Sign(leftCorrection - rightCorrection))
    | _ -> None

let resolveNpmPublishPlan (version: string) (currentBetaVersion: string option) : NpmPublishPlan =
    match parseReleaseVersion version with
    | None -> failwith $"Unsupported release version \"{version}\"."
    | Some parsedVersion ->
        if parsedVersion.Channel = "beta" then
            { Channel = "beta"; PublishTag = "beta"; MirrorDistTags = [] }
        else
            match currentBetaVersion with
            | Some normalizedCurrentBeta ->
                match compareReleaseVersions normalizedCurrentBeta version with
                | Some betaVsStable when betaVsStable > 0 ->
                    { Channel = "stable"; PublishTag = "latest"; MirrorDistTags = [] }
                | _ ->
                    { Channel = "stable"; PublishTag = "latest"; MirrorDistTags = ["beta"] }
            | None ->
                { Channel = "stable"; PublishTag = "latest"; MirrorDistTags = ["beta"] }

let resolveNpmDistTagMirrorAuth (params_: (string option * string option) option) : NpmDistTagMirrorAuth =
    match params_ with
    | Some(nodeAuthToken, _) ->
        match nodeAuthToken with
        | Some token when not(String.IsNullOrEmpty(token.Trim())) ->
            { HasAuth = true; Source = "node-auth-token" }
        | _ ->
            match snd params_.Value with
            | Some npmToken when not(String.IsNullOrEmpty(npmToken.Trim())) ->
                { HasAuth = true; Source = "npm-token" }
            | _ ->
                { HasAuth = false; Source = "none" }
    | None ->
        { HasAuth = false; Source = "none" }

let shouldRequireNpmDistTagMirrorAuth (mode: NpmPublishMode) (mirrorDistTags: string list) (hasAuth: bool) : bool =
    mode = Publish &&
    mirrorDistTags |> List.exists (fun tag -> not(String.IsNullOrEmpty(tag.Trim()))) &&
    not hasAuth
