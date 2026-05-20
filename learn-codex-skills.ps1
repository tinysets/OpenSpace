$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$root = $env:OPENSPACE_ROOT
if (-not $root) {
    $root = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$templatePath = Join-Path $root 'learn-codex-skills.prompt.zh.md'
$exePath = Join-Path $root '.venv\Scripts\openspace.exe'

if (-not (Test-Path -LiteralPath $templatePath)) {
    throw "Missing prompt template: $templatePath"
}
if (-not (Test-Path -LiteralPath $exePath)) {
    throw "Missing OpenSpace executable: $exePath"
}

$draftDir = $env:DRAFT_DIR
$reportDir = $env:REPORT_DIR
$runtimeDir = $env:RUNTIME_DIR
$sessionSource = $env:OPENSPACE_LEARN_SESSION
$runCount = 1
if ($env:OPENSPACE_LEARN_RUNS) {
    $runCount = [Math]::Max(1, [int]$env:OPENSPACE_LEARN_RUNS)
}
foreach ($dir in @($draftDir, $reportDir, $runtimeDir)) {
    if ($dir) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
}

if ($sessionSource) {
    $expanded = [Environment]::ExpandEnvironmentVariables($sessionSource)
    if (Test-Path -LiteralPath $expanded) {
        $sessionSource = (Resolve-Path -LiteralPath $expanded).Path
    }
}

function New-LearnQuery {
    param(
        [int]$RunIndex,
        [int]$RunCount
    )

    $query = Get-Content -Raw -Encoding UTF8 -LiteralPath $templatePath
    $replacements = @{
        '{{CODEX_HOME}}' = $env:CODEX_HOME
        '{{DRAFT_DIR}}' = $draftDir
        '{{REPORT_DIR}}' = $reportDir
        '{{RUNTIME_DIR}}' = $runtimeDir
        '{{RAW_MODE}}' = $env:OPENSPACE_LEARN_RAW_MODE
        '{{SESSION_SOURCE}}' = $sessionSource
        '{{DRAFT_LIMIT}}' = $env:OPENSPACE_LEARN_DRAFT_LIMIT
        '{{MAX_ITERATIONS}}' = $env:OPENSPACE_LEARN_MAX_ITERATIONS
        '{{RUN_INDEX}}' = [string]$RunIndex
        '{{RUN_COUNT}}' = [string]$RunCount
    }

    foreach ($key in $replacements.Keys) {
        $query = $query.Replace($key, [string]$replacements[$key])
    }
    return $query
}

Write-Host 'Learning Codex history into Chinese draft skills'
Write-Host "Sources: $env:CODEX_HOME\memories\MEMORY.md"
Write-Host "Sources: $env:CODEX_HOME\memories\rollout_summaries"
Write-Host "Drafts:  $draftDir"
Write-Host "Reports: $reportDir"
Write-Host "Runtime: $runtimeDir will not be modified by request"
Write-Host "Raw mode: $env:OPENSPACE_LEARN_RAW_MODE"
if ($sessionSource) {
    Write-Host "Extra session: $sessionSource"
}
Write-Host "Max iterations: $env:OPENSPACE_LEARN_MAX_ITERATIONS"
Write-Host "Run count:      $runCount"
Write-Host "LLM timeout:    $env:OPENSPACE_LEARN_TIMEOUT s"
Write-Host "Draft limit:    $env:OPENSPACE_LEARN_DRAFT_LIMIT"
Write-Host "Shell security auto-allow: $env:OPENSPACE_SHELL_SECURITY_AUTO_ALLOW"
Write-Host ''

if ($env:OPENSPACE_LEARN_DRY_RUN -eq '1') {
    Write-Host 'Command is configured but not executed.'
    Write-Host ''
    Write-Host "Model:   $env:OPENSPACE_MODEL"
    Write-Host "API:     $env:OPENSPACE_LLM_API_BASE"
    Write-Host ''
    Write-Host 'Query for pass 1:'
    Write-Host (New-LearnQuery -RunIndex 1 -RunCount $runCount)
    exit 0
}

for ($runIndex = 1; $runIndex -le $runCount; $runIndex++) {
    Write-Host ''
    Write-Host "===== OpenSpace learning pass $runIndex / $runCount ====="
    $query = New-LearnQuery -RunIndex $runIndex -RunCount $runCount

    & $exePath `
        --no-ui `
        --workspace $root `
        --max-iterations $env:OPENSPACE_LEARN_MAX_ITERATIONS `
        --timeout $env:OPENSPACE_LEARN_TIMEOUT `
        --query $query

    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

exit $LASTEXITCODE
