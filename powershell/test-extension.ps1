#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "46e7143f6b08182cf4a961f470a24d208837cd3e2aa301c8b238de7856e9eefe", "source_sha256": "0f2bb155d699e769ad3eb99a6500cc6dbb27948a57f7493a3b98c731200853d4", "target_language": "powershell"}
# test-extension.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension.mjs
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

function PrintUsage {
  Write-Error "Usage: pnpm test:extension <extension-name|path> [vitest args...]"
  Write-Error "       node scripts/test-extension.mjs [extension-name|path] [vitest args...]"
}

function PrintNoTestsMessage($plan) {
  Write-Host "[test-extension] No tests found for $($plan.extensionDir). Skipping."
}

function FormatErrorMessage($error) {
  # Simplified error formatting - in real scenario would need more detailed implementation
  return $error.Exception.Message
}

function ResolveExtensionTestPlan($params) {
  # This is a placeholder for the actual implementation
  # In a real PowerShell version, this would be implemented natively
  throw "NotImplementedException: resolveExtensionTestPlan needs to be implemented"
}

function IsDirectScriptRun {
  # PowerShell equivalent check would depend on how the script is invoked
  return $true
}

function RunVitestBatch($params) {
  # This is a placeholder for the actual implementation
  # In a real PowerShell version, this would be implemented natively
  throw "NotImplementedException: runVitestBatch needs to be implemented"
}

async function Run {
  $rawArgs = $args[2..($args.Length-1)]
  
  if ($rawArgs -contains "--help" -or $rawArgs -contains "-h") {
    PrintUsage
    return
  }

  $passthroughArgs = $rawArgs | Where-Object { $_ -ne "--" }
  
  $targetArg = $null
  if ($passthroughArgs.Count -gt 0 -and -not $passthroughArgs[0].StartsWith("-")) {
    $targetArg = $passthroughArgs[0]
    $passthroughArgs = $passthroughArgs[1..($passthroughArgs.Length-1)]
  }

  try {
    $plan = ResolveExtensionTestPlan @{ 
      cwd = (Get-Location).Path
      targetArg = $targetArg 
    }
  } catch {
    PrintUsage
    Write-Error (FormatErrorMessage $_)
    exit 1
  }

  if (-not $plan.hasTests) {
    PrintNoTestsMessage $plan
    return
  }

  Write-Host "[test-extension] Running $($plan.testFileCount) test files for $($plan.extensionId)"
  
  $exitCode = RunVitestBatch @{
    args = $passthroughArgs
    config = $plan.config
    env = Get-ChildItem Env:
    targets = $plan.roots
  }
  
  exit $exitCode
}

if (IsDirectScriptRun) {
  Run
}
