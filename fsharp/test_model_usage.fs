// abstraction-provenance: {"artifact_sha256": "ecd1a05aa3475319704b9b5b26ce3846d86466842421e7cddd2d03c0be6a688f", "source_sha256": "95f62a3e3f38308dd9be80e09ec85e4a14455ab95457febb8f915c0f54685141", "target_language": "fsharp"}
// test_model_usage.py — portiert nach fsharp
// Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/test_model_usage.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

namespace Tests

open System
open NUnit.Framework
open ModelUsage

[<TestFixture>]
type TestModelUsage() =

    [<Test>]
    member this.TestPositiveIntAcceptsValidNumbers() =
        Assert.AreEqual(positiveInt "1", 1)
        Assert.AreEqual(positiveInt "7", 7)

    [<Test>]
    member this.TestPositiveIntRejectsZeroAndNegative() =
        Assert.Throws<ArgumentException>(fun () -> positiveInt "0" |> ignore) |> ignore
        Assert.Throws<ArgumentException>(fun () -> positiveInt "-3" |> ignore) |> ignore

    [<Test>]
    member this.TestFilterByDaysKeepsRecentEntries() =
        let today = DateTime.Today
        let entries = [
            { Date = (today - TimeSpan.FromDays(5.0)).ToString("yyyy-MM-dd"); ModelBreakdowns = [] }
            { Date = (today - TimeSpan.FromDays(1.0)).ToString("yyyy-MM-dd"); ModelBreakdowns = [] }
            { Date = today.ToString("yyyy-MM-dd"); ModelBreakdowns = [] }
        ]

        let filtered = filterByDays entries 2

        Assert.AreEqual(filtered.Length, 2)
        Assert.AreEqual(filtered.[0].Date, (today - TimeSpan.FromDays(1.0)).ToString("yyyy-MM-dd"))
        Assert.AreEqual(filtered.[1].Date, today.ToString("yyyy-MM-dd"))
