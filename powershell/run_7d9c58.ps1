#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "859a01c03669d4108d9c64c958f2aef7a1b11adda4b2906f9690a39572585e5b", "source_sha256": "7d9c583822b7f56d89ce608cb8d469719c8a0d1dda7229ea2e4bbf717e511afe", "target_language": "powershell"}
# run.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-e2e/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$VerifyHelperPath = "/usr/local/install-sh-common/version-parse.sh"
if (-not (Test-Path $VerifyHelperPath)) {
    $VerifyHelperPath = Join-Path $ScriptDir "../install-sh-common/version-parse.sh"
}
. $VerifyHelperPath

$InstallUrl = if ($env:OPENCLAW_INSTALL_URL) { $env:OPENCLAW_INSTALL_URL } else { "https://openclaw.bot/install.sh" }
$ModelsMode = if ($env:OPENCLAW_E2E_MODELS) { $env:OPENCLAW_E2E_MODELS } else { "both" } # both|openai|anthropic
$InstallTag = if ($env:OPENCLAW_INSTALL_TAG) { $env:OPENCLAW_INSTALL_TAG } else { "latest" }
$E2EPreviousVersion = if ($env:OPENCLAW_INSTALL_E2E_PREVIOUS) { $env:OPENCLAW_INSTALL_E2E_PREVIOUS } else { "" }
$SkipPrevious = if ($env:OPENCLAW_INSTALL_E2E_SKIP_PREVIOUS) { $env:OPENCLAW_INSTALL_E2E_SKIP_PREVIOUS } else { "0" }
$OpenAiApiKey = if ($env:OPENAI_API_KEY) { $env:OPENAI_API_KEY } else { "" }
$AnthropicApiKey = if ($env:ANTHROPIC_API_KEY) { $env:ANTHROPIC_API_KEY } else { "" }
$AnthropicApiToken = if ($env:ANTHROPIC_API_TOKEN) { $env:ANTHROPIC_API_TOKEN } else { "" }

$NpmConfigPrefix = if ($env:NPM_CONFIG_PREFIX) { $env:NPM_CONFIG_PREFIX } else { "$HOME/.npm-global" }
New-Item -ItemType Directory -Path $NpmConfigPrefix -Force | Out-Null
$env:NPM_CONFIG_PREFIX = $NpmConfigPrefix
$env:PATH = "$NpmConfigPrefix/bin" + [System.IO.Path]::PathSeparator + $env:PATH

if ($ModelsMode -ne "both" -and $ModelsMode -ne "openai" -and $ModelsMode -ne "anthropic") {
    Write-Error "ERROR: OPENCLAW_E2E_MODELS must be one of: both|openai|anthropic" -ErrorAction Stop
}

if ($ModelsMode -eq "both") {
    if ([string]::IsNullOrEmpty($OpenAiApiKey)) {
        Write-Error "ERROR: OPENCLAW_E2E_MODELS=both requires OPENAI_API_KEY." -ErrorAction Stop
    }
    if ([string]::IsNullOrEmpty($AnthropicApiToken) -and [string]::IsNullOrEmpty($AnthropicApiKey)) {
        Write-Error "ERROR: OPENCLAW_E2E_MODELS=both requires ANTHROPIC_API_TOKEN or ANTHROPIC_API_KEY." -ErrorAction Stop
    }
} elseif ($ModelsMode -eq "openai" -and [string]::IsNullOrEmpty($OpenAiApiKey)) {
    Write-Error "ERROR: OPENCLAW_E2E_MODELS=openai requires OPENAI_API_KEY." -ErrorAction Stop
} elseif ($ModelsMode -eq "anthropic" -and [string]::IsNullOrEmpty($AnthropicApiToken) -and [string]::IsNullOrEmpty($AnthropicApiKey)) {
    Write-Error "ERROR: OPENCLAW_E2E_MODELS=anthropic requires ANTHROPIC_API_TOKEN or ANTHROPIC_API_KEY." -ErrorAction Stop
}

Write-Host "==> Resolve npm versions"
$ExpectedVersion = & npm view "openclaw@$InstallTag" version --silent 2>$null
if ([string]::IsNullOrEmpty($ExpectedVersion) -or $ExpectedVersion -eq "undefined" -or $ExpectedVersion -eq "null") {
    Write-Error "ERROR: unable to resolve openclaw@$InstallTag version" -ErrorAction Stop
}
if (-not [string]::IsNullOrEmpty($E2EPreviousVersion)) {
    $PreviousVersion = $E2EPreviousVersion
} else {
    $VersionsJson = & npm view openclaw versions --json --silent 2>$null
    $PreviousVersion = node - `
        @"
const versions = JSON.parse(process.env.VERSIONS_JSON || "[]");
if (!Array.isArray(versions) || versions.length === 0) process.exit(1);
process.stdout.write(versions.length >= 2 ? versions[versions.length - 2] : versions[0]);
"@
}
Write-Host "expected=$ExpectedVersion previous=$PreviousVersion"

if ($SkipPrevious -eq "1") {
    Write-Host "==> Skip preinstall previous (OPENCLAW_INSTALL_E2E_SKIP_PREVIOUS=1)"
} else {
    Write-Host "==> Preinstall previous (forces installer upgrade path; avoids read() prompt)"
    & npm install -g "openclaw@$PreviousVersion" --silent 2>$null
}

Write-Host "==> Run official installer one-liner"
if ($InstallTag -eq "beta") {
    $env:OPENCLAW_BETA = "1"
    Invoke-WebRequest -Uri $InstallUrl -UseBasicParsing | Select-Object -ExpandProperty Content | bash
} elseif ($InstallTag -ne "latest") {
    $env:OPENCLAW_VERSION = $InstallTag
    Invoke-WebRequest -Uri $InstallUrl -UseBasicParsing | Select-Object -ExpandProperty Content | bash
} else {
    Invoke-WebRequest -Uri $InstallUrl -UseBasicParsing | Select-Object -ExpandProperty Content | bash
}

Write-Host "==> Verify installed version"
$InstalledVersion = & openclaw --version 2>$null | Select-Object -First 1
$InstalledVersion = $InstalledVersion.Trim()
$InstalledVersion = ExtractOpenClawSemver $InstalledVersion
Write-Host "installed=$InstalledVersion expected=$ExpectedVersion"
if ($InstalledVersion -ne $ExpectedVersion) {
    Write-Error "ERROR: expected openclaw@$ExpectedVersion, got openclaw@$InstalledVersion" -ErrorAction Stop
}

function SetImageModel {
    param(
        [string]$Profile,
        [string[]]$Candidates
    )
    foreach ($Candidate in $Candidates) {
        if (& openclaw --profile $Profile models set-image $Candidate 2>$null) {
            return $Candidate
        }
    }
    Write-Error "ERROR: could not set an image model (tried: $($Candidates -join ', '))" -ErrorAction Stop
}

function SetAgentModel {
    param(
        [string]$Profile,
        [string[]]$Candidates
    )
    foreach ($Candidate in $Candidates) {
        if (& openclaw --profile $Profile models set $Candidate 2>$null) {
            return $Candidate
        }
    }
    Write-Error "ERROR: could not set agent model (tried: $($Candidates -join ', '))" -ErrorAction Stop
}

function WritePngLrRg {
    param(
        [string]$Out
    )
    node - `
        @"
const fs = require("node:fs");
const zlib = require("node:zlib");

const out = process.argv[2];
const width = 96;
const height = 64;

const crcTable = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
    table[i] = c >>> 0;
  }
  return table;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const typeBuf = Buffer.from(type, "ascii");
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(width, 0);
ihdr.writeUInt32BE(height, 4);
ihdr[8] = 8; // bit depth
ihdr[9] = 2; // color type: truecolor
ihdr[10] = 0; // compression
ihdr[11] = 0; // filter
ihdr[12] = 0; // interlace

const rows = [];
for (let y = 0; y < height; y++) {
  const row = Buffer.alloc(1 + width * 3);
  row[0] = 0; // filter: none
  for (let x = 0; x < width; x++) {
    const i = 1 + x * 3;
    const left = x < width / 2;
    row[i + 0] = left ? 255 : 0;
    row[i + 1] = left ? 0 : 255;
    row[i + 2] = 0;
  }
  rows.push(row);
}
const raw = Buffer.concat(rows);
const idat = zlib.deflateSync(raw, { level: 9 });

const png = Buffer.concat([
  sig,
  chunk("IHDR", ihdr),
  chunk("IDAT", idat),
  chunk("IEND", Buffer.alloc(0)),
]);
fs.writeFileSync(out, png);
"@
}

function RunAgentTurn {
    param(
        [string]$Profile,
        [string]$SessionId,
        [string]$Prompt,
        [string]$OutJson
    )
    # Installer E2E validates install + onboard + embedded agent tooling. It does
    # not need a paired Gateway control-plane hop, which is flaky/non-deterministic
    # in the isolated container and already covered by gateway-specific lanes.
    & openclaw --profile $Profile agent `
        --local `
        --session-id $SessionId `
        --message $Prompt `
        --thinking off `
        --json > $OutJson 2>&1
    
    node - `
        @"
const fs = require("node:fs");

const path = process.argv[2];
const raw = fs.readFileSync(path, "utf8");

function extractTrailingJsonObject(input) {
  const trimmed = input.trim();
  if (!trimmed) {
    throw new Error("agent output was empty");
  }
  try {
    return JSON.parse(trimmed);
  } catch {
    // Some local runs emit stderr diagnostics before the final JSON payload.
    // Walk backward and keep the last parseable top-level object.
    for (let index = trimmed.lastIndexOf("{"); index >= 0; index = trimmed.lastIndexOf("{", index - 1)) {
      const candidate = trimmed.slice(index);
      try {
        return JSON.parse(candidate);
      } catch {
        // keep scanning
      }
    }
    throw new Error(`could not extract JSON payload from agent output:\n${trimmed}`);
  }
}

const parsed = extractTrailingJsonObject(raw);
fs.writeFileSync(path, `${JSON.stringify(parsed, null, 2)}\n`, "utf8");
"@
}

function AssertAgentJsonHasText {
    param(
        [string]$Path
    )
    node - `
        @"
const fs = require("node:fs");
const p = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const payloads =
  Array.isArray(p?.result?.payloads) ? p.result.payloads :
  Array.isArray(p?.payloads) ? p.payloads :
  [];
const texts = payloads.map((x) => String(x?.text ?? "").trim()).filter(Boolean);
if (texts.length === 0) process.exit(1);
"@
}

function AssertAgentJsonOk {
    param(
        [string]$JsonPath,
        [string]$ExpectProvider
    )
    node - `
        @"
const fs = require("node:fs");
const jsonPath = process.argv[2];
const expectProvider = process.argv[3];
const p = JSON.parse(fs.readFileSync(jsonPath, "utf8"));

if (typeof p?.status === "string" && p.status !== "ok" && p.status !== "accepted") {
  console.error(`ERROR: gateway status=${p.status}`);
  process.exit(1);
}

const result = p?.result ?? p;
const payloads = Array.isArray(result?.payloads) ? result.payloads : [];
const anyError = payloads.some((pl) => pl && pl.isError === true);
const combinedText = payloads.map((pl) => String(pl?.text ?? "")).filter(Boolean).join("\n").trim();
if (anyError) {
  console.error(`ERROR: agent returned error payload: ${combinedText}`);
  process.exit(1);
}
if (/rate_limit_error/i.test(combinedText) || /^429\\b/.test(combinedText)) {
  console.error(`ERROR: agent rate limited: ${combinedText}`);
  process.exit(1);
}

const meta = result?.meta;
const provider =
  (typeof meta?.agentMeta?.provider === "string" && meta.agentMeta.provider.trim()) ||
  (typeof meta?.provider === "string" && meta.provider.trim()) ||
  "";
if (expectProvider && provider && provider !== expectProvider) {
  console.error(`ERROR: expected provider=${expectProvider}, got provider=${provider}`);
  process.exit(1);
}
"@
}

function ExtractMatchingText {
    param(
        [string]$Path,
        [string]$Expected
    )
    node - `
        @"
const fs = require("node:fs");
const p = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const expected = String(process.argv[3] ?? "");
const payloads =
  Array.isArray(p?.result?.payloads) ? p.result.payloads :
  Array.isArray(p?.payloads) ? p.payloads :
  [];
const texts = payloads.map((x) => String(x?.text ?? "").trim()).filter(Boolean);
const match = texts.find((text) => text === expected);
process.stdout.write(match ?? texts[0] ?? "");
"@
}

function AssertSessionUsedTools {
    param(
        [string]$Jsonl,
        [string[]]$RequiredTools
    )
    $RequiredArgs = $RequiredTools -join " "
    node - `
        @"
const fs = require("node:fs");
const jsonl = process.argv[2];
const required = new Set(process.argv.slice(3));

const raw = fs.readFileSync(jsonl, "utf8");
const lines = raw.split("\n").map((l) => l.trim()).filter(Boolean);
const seen = new Set();

const toolTypes = new Set([
  "tool_use",
  "tool_result",
  "tool",
  "tool-call",
  "tool_call",
  "tooluse",
  "tool-use",
  "toolresult",
  "tool-result",
]);
function walk(node, parent) {
  if (!node) return;
  if (Array.isArray(node)) {
    for (const item of node) walk(item, node);
    return;
  }
  if (typeof node !== "object") return;
  const obj = node;
  const t = typeof obj.type === "string" ? obj.type : null;
  if (t && (toolTypes.has(t) || /tool/i.test(t))) {
    const name =
      typeof obj.name === "string" ? obj.name :
      typeof obj.toolName === "string" ? obj.toolName :
      typeof obj.tool_name === "string" ? obj.tool_name :
      (obj.tool && typeof obj.tool.name === "string") ? obj.tool.name :
      null;
    if (name) seen.add(name);
  }
  if (typeof obj.name === "string" && typeof obj.input === "object" && obj.input) {
    // Many tool-use blocks look like { type: "...", name: "exec", input: {...} }
    // but some transcripts omit/rename type.
    seen.add(obj.name);
  }
  // OpenAI-ish tool call shapes.
  if (Array.isArray(obj.tool_calls)) {
    for (const c of obj.tool_calls) {
      const fn = c?.function;
      if (fn && typeof fn.name === "string") seen.add(fn.name);
    }
  }
  if (obj.function && typeof obj.function.name === "string") seen.add(obj.function.name);
  for (const v of Object.values(obj)) walk(v, obj);
}

for (const line of lines) {
  try {
    const entry = JSON.parse(line);
    walk(entry, null);
  } catch {
    // ignore unparsable lines
  }
}

const missing = [...required].filter((t) => !seen.has(t));
if (missing.length > 0) {
  console.error(`Missing tools in transcript: ${missing.join(", ")}`);
  console.error(`Seen tools: ${[...seen].sort().join(", ")}`);
  console.error("Transcript head:");
  console.error(lines.slice(0, 5).join("\n"));
  process.exit(1);
}
"@
}

function RunProfile {
    param(
        [string]$Profile,
        [string]$Port,
        [string]$Workspace,
        [string]$AgentModelProvider # "openai"|"anthropic"
    )
    
    Write-Host "==> Onboard ($Profile)"
    if ($AgentModelProvider -eq "openai") {
        & openclaw --profile $Profile onboard `
            --non-interactive `
            --accept-risk `
            --flow quickstart `
            --auth-choice openai-api-key `
            --openai-api-key $OpenAiApiKey `
            --gateway-port $Port `
            --gateway-bind loopback `
            --gateway-auth token `
            --workspace $Workspace `
            --skip-health
    } elseif (-not [string]::IsNullOrEmpty($AnthropicApiKey)) {
        & openclaw --profile $Profile onboard `
            --non-interactive `
            --accept-risk `
            --flow quickstart `
            --auth-choice apiKey `
            --anthropic-api-key $AnthropicApiKey `
            --gateway-port $Port `
            --gateway-bind loopback `
            --gateway-auth token `
            --workspace $Workspace `
            --skip-health
    } elseif (-not [string]::IsNullOrEmpty($AnthropicApiToken)) {
        & openclaw --profile $Profile onboard `
            --non-interactive `
            --accept-risk `
            --flow quickstart `
            --auth-choice token `
            --token-provider anthropic `
            --token $AnthropicApiToken `
            --gateway-port $Port `
            --gateway-bind loopback `
            --gateway-auth token `
            --workspace $Workspace `
            --skip-health
    } else {
        & openclaw --profile $Profile onboard `
            --non-interactive `
            --accept-risk `
            --flow quickstart `
            --auth-choice apiKey `
            --anthropic-api-key $AnthropicApiKey `
            --gateway-port $Port `
            --gateway-bind loopback `
            --gateway-auth token `
            --workspace $Workspace `
            --skip-health
    }

    Write-Host "==> Verify workspace identity files ($Profile)"
    if (-not (Test-Path "$Workspace/AGENTS.md")) { throw "Missing AGENTS.md" }
    if (-not (Test-Path "$Workspace/IDENTITY.md")) { throw "Missing IDENTITY.md" }
    if (-not (Test-Path "$Workspace/USER.md")) { throw "Missing USER.md" }
    if (-not (Test-Path "$Workspace/SOUL.md")) { throw "Missing SOUL.md" }
    if (-not (Test-Path "$Workspace/TOOLS.md")) { throw "Missing TOOLS.md" }

    Write-Host "==> Configure models ($Profile)"
    if ($AgentModelProvider -eq "openai") {
        $AgentModel = SetAgentModel $Profile @("openai/gpt-5.4", "openai/gpt-4o-mini", "openai/gpt-4o")
        $ImageModel = SetImageModel $Profile @("openai/gpt-4o-mini", "openai/gpt-4o")
    } else {
        $AgentModel = SetAgentModel $Profile @("anthropic/claude-opus-4-6", "claude-opus-4-6")
        $ImageModel = SetImageModel $Profile @("anthropic/claude-opus-4-6", "claude-opus-4-6")
    }
    Write-Host "model=$AgentModel"
    Write-Host "imageModel=$ImageModel"

    Write-Host "==> Prepare tool fixtures ($Profile)"
    $ProofTxt = "$Workspace/proof.txt"
    $ProofCopy = "$Workspace/copy.txt"
    $HostnameTxt = "$Workspace/hostname.txt"
    $ImagePng = "$Workspace/proof.png"
    $ImageTxt = "$Workspace/image.txt"
    $SessionId = "e2e-tools-${Profile}"
    $SessionJsonl = "$HOME/.openclaw-${Profile}/agents/main/sessions/${SessionId}.jsonl"

    $ProofValue = node -e 'console.log(require("node:crypto").randomBytes(16).toString("hex"))'
    Set-Content -Path $ProofTxt -Value $ProofValue -NoNewline
    WritePngLrRg $ImagePng
    $ExpectedHostname = [System.Net.Dns]::GetHostName()

    Write-Host "==> Start gateway ($Profile)"
    $GatewayLog = "$Workspace/gateway.log"
    $GatewayProcess = Start-Process -FilePath "openclaw" -ArgumentList "--profile", $Profile, "gateway", "--port", $Port, "--bind", "loopback" -RedirectStandardOutput $GatewayLog -RedirectStandardError $GatewayLog -PassThru
    $GatewayPid = $GatewayProcess.Id
    
    function CleanupProfile {
        if (Get-Process -Id $GatewayPid -ErrorAction SilentlyContinue) {
            Stop-Process -Id $GatewayPid -Force -ErrorAction SilentlyContinue
        }
    }
    
    try {
        Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { CleanupProfile } | Out-Null

        Write-Host "==> Wait for health ($Profile)"
        for ($i = 1; $i -le 240; $i++) {
            if (& openclaw --profile $Profile health --timeout 5000 --json 2>$null) {
                break
            }
            Start-Sleep -Milliseconds 250
        }
        & openclaw --profile $Profile health --timeout 60000 --json 2>$null | Out-Null

        Write-Host "==> Agent turns ($Profile)"
        $Turn1Json = "/tmp/agent-${Profile}-1.json"
        $Turn2Json = "/tmp/agent-${Profile}-2.json"
        $Turn2BJson = "/tmp/agent-${Profile}-2b.json"
        $Turn3Json = "/tmp/agent-${Profile}-3.json"
        $Turn3BJson = "/tmp/agent-${Profile}-3b.json"
        $Turn4Json = "/tmp/agent-${Profile}-4.json"

        RunAgentTurn $Profile $SessionId `
            "Use the read tool (not exec) to read ${ProofTxt}. Reply with the exact contents only (no extra whitespace)." `
            $Turn1Json
        AssertAgentJsonHasText $Turn1Json
        AssertAgentJsonOk $Turn1Json $AgentModelProvider
        $Reply1 = (ExtractMatchingText $Turn1Json $ProofValue).Trim()
        if ($Reply1 -ne $ProofValue) {
            Write-Error "ERROR: agent did not read proof.txt correctly ($Profile): $Reply1" -ErrorAction Stop
        }

        $Prompt2 = "Use the write tool (not exec) to write exactly this string into ${ProofCopy}:`n${Reply1}`nReply with exactly: WROTE"
        RunAgentTurn $Profile $SessionId $Prompt2 $Turn2Json
        AssertAgentJsonHasText $Turn2Json
        AssertAgentJsonOk $Turn2Json $AgentModelProvider
        $CopyValue = Get-Content -Path $ProofCopy -Raw -ErrorAction SilentlyContinue
        if ($CopyValue -ne $ProofValue) {
            Write-Error "ERROR: copy.txt did not match proof.txt ($Profile)" -ErrorAction Stop
        }
        RunAgentTurn $Profile $SessionId `
            "Use the read tool (not exec) to read ${ProofCopy}. Reply with the exact contents only (no extra whitespace)." `
            $Turn2BJson
        AssertAgentJsonHasText $Turn2BJson
        AssertAgentJsonOk $Turn2BJson $AgentModelProvider
        $Reply2 = (ExtractMatchingText $Turn2BJson $ProofValue).Trim()
        if ($Reply2 -ne $ProofValue) {
            Write-Error "ERROR: agent did not read copy.txt correctly ($Profile): $Reply2" -ErrorAction Stop
        }

        RunAgentTurn $Profile $SessionId `
            "Use the exec tool to run this command: hostname. Reply with the exact stdout only (trim trailing newline)." `
            $Turn3Json
        AssertAgentJsonHasText $Turn3Json
        AssertAgentJsonOk $Turn3Json $AgentModelProvider
        $Reply3 = (ExtractMatchingText $Turn3Json $ExpectedHostname).Trim()
        if ($Reply3 -ne $ExpectedHostname) {
            Write-Error "ERROR: agent did not run hostname correctly ($Profile): $Reply3" -ErrorAction Stop
        }
        $Prompt3B = "Use the write tool to write exactly this string into ${HostnameTxt}:`n${Reply3}`nReply with exactly: WROTE"
        RunAgentTurn $Profile $SessionId $Prompt3B $Turn3BJson
        AssertAgentJsonHasText $Turn3BJson
        AssertAgentJsonOk $Turn3BJson $AgentModelProvider
        $HostnameTxtContent = Get-Content -Path $HostnameTxt -Raw -ErrorAction SilentlyContinue
        if ($HostnameTxtContent -ne $ExpectedHostname) {
            Write-Error "ERROR: hostname.txt did not match hostname output ($Profile)" -ErrorAction Stop
        }

        RunAgentTurn $Profile $SessionId `
            "Use the image tool on ${ImagePng}. Determine which color is on the left half and which is on the right half. Then use the write tool to write exactly: LEFT=RED RIGHT=GREEN into ${ImageTxt}. Reply with exactly: LEFT=RED RIGHT=GREEN" `
            $Turn4Json
        AssertAgentJsonHasText $Turn4Json
        AssertAgentJsonOk $Turn4Json $AgentModelProvider
        $ImageTxtContent = Get-Content -Path $ImageTxt -Raw -ErrorAction SilentlyContinue
        if ($ImageTxtContent -ne "LEFT=RED RIGHT=GREEN") {
            Write-Error "ERROR: image.txt did not contain expected marker ($Profile)" -ErrorAction Stop
        }
        $Reply4 = ExtractMatchingText $Turn4Json "LEFT=RED RIGHT=GREEN"
        if ($Reply4 -ne "LEFT=RED RIGHT=GREEN") {
            Write-Error "ERROR: agent reply did not contain expected marker ($Profile): $Reply4" -ErrorAction Stop
        }

        Write-Host "==> Verify tool usage via session transcript ($Profile)"
        # Give the gateway a moment to flush transcripts.
        Start-Sleep -Seconds 1
        if (-not (Test-Path $SessionJsonl)) {
            Write-Error "ERROR: missing session transcript ($Profile): $SessionJsonl" -ErrorAction Stop
        }
        AssertSessionUsedTools $SessionJsonl @("read", "write", "exec", "image")
    } finally {
        CleanupProfile
    }
}

if ($ModelsMode -eq "openai" -or $ModelsMode -eq "both") {
    RunProfile "e2e-openai" "18789" "/tmp/openclaw-e2e-openai" "openai"
}

if ($ModelsMode -eq "anthropic" -or $ModelsMode -eq "both") {
    RunProfile "e2e-anthropic" "18799" "/tmp/openclaw-e2e-anthropic" "anthropic"
}

Write-Host "OK"
