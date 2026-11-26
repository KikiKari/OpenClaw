// abstraction-provenance: {"artifact_sha256": "c80f4561f6809a02966f37484a1cd37c2e63a29e0b7d7a5eaab9863099dc6589", "source_sha256": "38390e5c16266050829f3193f79ca05d8ec898095dc834f407431d87ecfadeb8", "target_language": "fsharp"}
// server-maintenance.sh — portiert nach fsharp
// Quelle: shell, OpenClaw@gateway1:scripts/server-maintenance.sh
// auch in: OpenClaw@gateway2:scripts/server-maintenance.sh
// auch in: workspace@local:scripts/server-maintenance.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

open System
open System.Diagnostics
open System.IO
open System.Text.RegularExpressions

// Server Maintenance Script
// RAM: 8GB, Uhr: Europe/Berlin

let logFile = "/var/log/server-maintenance.log"
let date = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
let host = Environment.MachineName

// Farben für Terminal
let red = "\x1b[0;31m"
let green = "\x1b[0;32m"
let yellow = "\x1b[1;33m"
let nc = "\x1b[0m"

let writeLog (message: string) =
    let logMessage = $"[{date}] {message}"
    printfn "%s" logMessage
    File.AppendAllLines(logFile, [logMessage])

writeLog "=== Server Maintenance Check ==="

// 1. APT Update Check
writeLog "Checking for updates..."
let aptUpdateProcess = new Process()
aptUpdateProcess.StartInfo.FileName <- "apt"
aptUpdateProcess.StartInfo.Arguments <- "update -qq"
aptUpdateProcess.StartInfo.UseShellExecute <- false
aptUpdateProcess.StartInfo.RedirectStandardOutput <- true
aptUpdateProcess.StartInfo.RedirectStandardError <- true
aptUpdateProcess.Start() |> ignore
aptUpdateProcess.WaitForExit()
let aptUpdateOutput = aptUpdateProcess.StandardOutput.ReadToEnd()
let last5Lines = aptUpdateOutput.Split('\n') |> Array.rev |> Seq.take 5 |> Seq.toArray |> Array.rev
last5Lines |> Array.iter (fun line -> writeLog line)

let aptListProcess = new Process()
aptListProcess.StartInfo.FileName <- "apt"
aptListProcess.StartInfo.Arguments <- "list --upgradable"
aptListProcess.StartInfo.UseShellExecute <- false
aptListProcess.StartInfo.RedirectStandardOutput <- true
aptListProcess.Start()
aptListProcess.WaitForExit()
let upgradablePackages = aptListProcess.StandardOutput.ReadToEnd().Split('\n').Length - 1 // Subtract 1 for header
if upgradablePackages > 1 then
    writeLog $"⚠️ {upgradablePackages} packages can be upgraded"

// 2. RAM Check (8GB total)
writeLog "Checking RAM usage..."
let ramTotal = 8192 // 8GB in MB
let psi = new ProcessStartInfo()
psi.FileName <- "free"
psi.Arguments <- "-m"
psi.UseShellExecute <- false
psi.RedirectStandardOutput <- true
let freeProcess = Process.Start(psi)
let freeOutput = freeProcess.StandardOutput.ReadToEnd()
freeProcess.WaitForExit()

let ramUsedLine = freeOutput.Split('\n') |> Array.find (fun line -> line.StartsWith("Mem:"))
let ramUsed = ramUsedLine.Split(' ', StringSplitOptions.RemoveEmptyEntries).[1] |> int
let ramPercent = (ramUsed * 100) / ramTotal
writeLog $"RAM: {ramUsed}MB / {ramTotal}MB ({ramPercent}%)"
if ramPercent > 90 then
    writeLog "🔴 WARNING: RAM usage > 90%!"
elif ramPercent > 80 then
    writeLog "🟡 WARNING: RAM usage > 80%"

// 3. Disk Space Check
writeLog "Checking disk space..."
let dfPsi = new ProcessStartInfo()
dfPsi.FileName <- "df"
dfPsi.Arguments <- "-h /"
dfPsi.UseShellExecute <- false
dfPsi.RedirectStandardOutput <- true
let dfProcess = Process.Start(dfPsi)
let dfOutput = dfProcess.StandardOutput.ReadToEnd()
dfProcess.WaitForExit()

let dfLine = dfOutput.Split('\n') |> Array.last |> fun s -> if s = "" then dfOutput.Split('\n') |> Array.item (dfOutput.Split('\n').Length - 2) else s
let dfParts = dfLine.Split(' ', StringSplitOptions.RemoveEmptyEntries)
let diskUsed = dfParts.[2]
let diskTotal = dfParts.[1]
let diskUsage = dfParts.[4]
writeLog $"Disk: {diskUsed} / {diskTotal} ({diskUsage} used)"

let diskPercent = int (diskUsage.TrimEnd('%'))
if diskPercent > 90 then
    writeLog "🔴 WARNING: Disk > 90%!"
elif diskPercent > 80 then
    writeLog "🟡 WARNING: Disk > 80%"

// 4. NTP Check
writeLog "Checking NTP sync..."
let timedatectlPsi = new ProcessStartInfo()
timedatectlPsi.FileName <- "timedatectl"
timedatectlPsi.Arguments <- "status"
timedatectlPsi.UseShellExecute <- false
timedatectlPsi.RedirectStandardOutput <- true
let timedatectlProcess = Process.Start(timedatectlPsi)
let timedatectlOutput = timedatectlProcess.StandardOutput.ReadToEnd()
timedatectlProcess.WaitForExit()

if timedatectlOutput.Contains("NTP synchronized: yes") then
    writeLog "✅ NTP synchronized"
else
    writeLog "⚠️ NTP not synchronized"

// 5. OpenClaw Gateway Status
writeLog "Checking OpenClaw Gateway..."
let systemctlPsi = new ProcessStartInfo()
systemctlPsi.FileName <- "systemctl"
systemctlPsi.Arguments <- "is-active --quiet openclaw-gateway"
systemctlPsi.UseShellExecute <- false
let systemctlProcess = Process.Start(systemctlPsi)
systemctlProcess.WaitForExit()

if systemctlProcess.ExitCode = 0 then
    writeLog "✅ OpenClaw Gateway running"
else
    writeLog "🔴 OpenClaw Gateway NOT running!"
    let restartPsi = new ProcessStartInfo()
    restartPsi.FileName <- "systemctl"
    restartPsi.Arguments <- "restart openclaw-gateway"
    restartPsi.UseShellExecute <- false
    Process.Start(restartPsi) |> ignore

// 6. Load Average
let uptimePsi = new ProcessStartInfo()
uptimePsi.FileName <- "uptime"
uptimePsi.UseShellExecute <- false
uptimePsi.RedirectStandardOutput <- true
let uptimeProcess = Process.Start(uptimePsi)
let uptimeOutput = uptimeProcess.StandardOutput.ReadToEnd()
uptimeProcess.WaitForExit()

let loadMatch = Regex.Match(uptimeOutput, @"load average:\s*([0-9\.]+)")
let load = if loadMatch.Success then loadMatch.Groups.[1].Value else "unknown"
writeLog $"Load Average: {load}"

writeLog "=== Maintenance Complete ==="
writeLog ""
