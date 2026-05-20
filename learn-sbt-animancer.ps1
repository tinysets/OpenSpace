$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$root = $env:OPENSPACE_ROOT
if (-not $root) {
    $root = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$sessionPath = [Environment]::ExpandEnvironmentVariables($env:SBT_ANIMANCER_SESSION)
if (-not (Test-Path -LiteralPath $sessionPath)) {
    throw "Session file not found: $sessionPath"
}
$sessionPath = (Resolve-Path -LiteralPath $sessionPath).Path

$outputRoot = $env:SBT_ANIMANCER_ROOT
$evidenceDir = $env:SBT_ANIMANCER_EVIDENCE_DIR
$draftDir = $env:SBT_ANIMANCER_DRAFT_DIR
$reportDir = $env:SBT_ANIMANCER_REPORT_DIR
$runtimeDir = $env:SBT_ANIMANCER_RUNTIME_DIR
$chunkReportDir = Join-Path $reportDir 'chunks'
$runCount = [Math]::Max(1, [int]$env:SBT_ANIMANCER_RUNS)
$contextTokens = [Math]::Max(1, [int]$env:SBT_ANIMANCER_CONTEXT_TOKENS)
$maxChunkTokensRaw = [string]$env:SBT_ANIMANCER_MAX_CHUNK_TOKENS
if ([string]::IsNullOrWhiteSpace($maxChunkTokensRaw) -or $maxChunkTokensRaw.Trim().ToLowerInvariant() -eq 'auto') {
    # Keep room for the prompt, manifest/summary files, tool results, reports, and model output.
    $maxChunkTokens = [Math]::Max(1000, [int][Math]::Floor($contextTokens * 0.70))
    $env:SBT_ANIMANCER_MAX_CHUNK_TOKENS = [string]$maxChunkTokens
} else {
    $maxChunkTokens = [Math]::Max(1, [int]$maxChunkTokensRaw)
}
$toolSummarizeThresholdChars = [Math]::Max(200000, $maxChunkTokens * 4)
$env:OPENSPACE_TOOL_SUMMARIZE_THRESHOLD_CHARS = [string]$toolSummarizeThresholdChars
$env:OPENSPACE_MAX_TOOL_RESULT_CHARS = [string]$toolSummarizeThresholdChars

foreach ($dir in @($outputRoot, $evidenceDir, $draftDir, $reportDir, $runtimeDir, $chunkReportDir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

$pythonExe = Join-Path $root '.venv\Scripts\python.exe'
$openSpaceExe = Join-Path $root '.venv\Scripts\openspace.exe'
$extractor = Join-Path $root 'learn-sbt-animancer.extract.py'
$templatePath = Join-Path $root 'learn-sbt-animancer.prompt.zh.md'

foreach ($path in @($pythonExe, $openSpaceExe, $extractor, $templatePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required file not found: $path"
    }
}

Write-Host 'Preparing SBT Animancer evidence package'
Write-Host "Session:  $sessionPath"
Write-Host "Output:   $outputRoot"
Write-Host "Evidence: $evidenceDir"
Write-Host "Drafts:   $draftDir"
Write-Host "Reports:  $reportDir"
Write-Host "Runs:     $runCount"
Write-Host "Max evidence records: $env:SBT_ANIMANCER_MAX_EVIDENCE"
Write-Host "Chunk size: $env:SBT_ANIMANCER_CHUNK_SIZE"
Write-Host "Context tokens: $contextTokens"
Write-Host "Max chunk tokens: $maxChunkTokens"
Write-Host "Tool summarize threshold chars: $toolSummarizeThresholdChars"
Write-Host "Max iterations per run: $env:SBT_ANIMANCER_MAX_ITERATIONS"
Write-Host "Include tool records: $env:SBT_ANIMANCER_INCLUDE_TOOLS"
Write-Host "Shell security auto-allow: $env:OPENSPACE_SHELL_SECURITY_AUTO_ALLOW"
Write-Host ''

$extractArgs = @(
    $extractor,
    '--session', $sessionPath,
    '--out', $evidenceDir,
    '--max-records', $env:SBT_ANIMANCER_MAX_EVIDENCE,
    '--chunk-size', $env:SBT_ANIMANCER_CHUNK_SIZE,
    '--max-chunk-tokens', $maxChunkTokens
)
if ($env:SBT_ANIMANCER_INCLUDE_TOOLS -eq '1') {
    $extractArgs += '--include-tools'
}

& $pythonExe @extractArgs

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$manifestPath = Join-Path $evidenceDir 'manifest.json'
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
$chunkCount = [int]$manifest.chunk_count
if ($chunkCount -lt 1) {
    throw "No evidence chunks were generated. Check keywords or session content: $manifestPath"
}

Write-Host ''
Write-Host "Generated evidence chunks: $chunkCount"

function New-SbtAnimancerQuery {
    param(
        [int]$RunIndex,
        [int]$RunCount,
        [string]$TaskMode,
        [int]$ChunkIndex,
        [int]$ChunkCount,
        [string]$ChunkFile,
        [string]$ChunkReportFile,
        [string]$ChunkReports,
        [string]$ReportFile,
        [string]$IsFinalPass
    )

    $query = Get-Content -Raw -Encoding UTF8 -LiteralPath $templatePath
    $replacements = @{
        '{{SESSION_PATH}}' = $sessionPath
        '{{OUTPUT_ROOT}}' = $outputRoot
        '{{EVIDENCE_DIR}}' = $evidenceDir
        '{{DRAFT_DIR}}' = $draftDir
        '{{REPORT_DIR}}' = $reportDir
        '{{RUNTIME_DIR}}' = $runtimeDir
        '{{CHUNK_REPORT_DIR}}' = $chunkReportDir
        '{{DRAFT_LIMIT}}' = $env:SBT_ANIMANCER_DRAFT_LIMIT
        '{{MAX_ITERATIONS}}' = $env:SBT_ANIMANCER_MAX_ITERATIONS
        '{{RUN_INDEX}}' = [string]$RunIndex
        '{{RUN_COUNT}}' = [string]$RunCount
        '{{TASK_MODE}}' = $TaskMode
        '{{CHUNK_INDEX}}' = [string]$ChunkIndex
        '{{CHUNK_COUNT}}' = [string]$ChunkCount
        '{{CHUNK_FILE}}' = $ChunkFile
        '{{CHUNK_REPORT_FILE}}' = $ChunkReportFile
        '{{CHUNK_REPORTS}}' = $ChunkReports
        '{{REPORT_FILE}}' = $ReportFile
        '{{IS_FINAL_PASS}}' = $IsFinalPass
    }
    foreach ($key in $replacements.Keys) {
        $query = $query.Replace($key, [string]$replacements[$key])
    }
    return $query
}

function Get-ChunkFile {
    param([int]$ChunkIndex)

    $entry = @($manifest.chunks)[$ChunkIndex - 1]
    $relative = [string]$entry.file
    return Join-Path $evidenceDir $relative
}

function Get-ChunkReportFile {
    param(
        [int]$RunIndex,
        [int]$ChunkIndex
    )

    return Join-Path $chunkReportDir ("sbt-animancer-learning-report-pass-{0:D3}-chunk-{1:D3}.md" -f $RunIndex, $ChunkIndex)
}

function Get-ChunkReportsText {
    param([int]$RunIndex)

    $paths = for ($chunkIndex = 1; $chunkIndex -le $chunkCount; $chunkIndex++) {
        Get-ChunkReportFile -RunIndex $RunIndex -ChunkIndex $chunkIndex
    }
    return ($paths | ForEach-Object { "- $_" }) -join [Environment]::NewLine
}

if ($env:SBT_ANIMANCER_DRY_RUN -eq '1') {
    Write-Host 'Command is configured but not executed.'
    Write-Host ''
    Write-Host "Model: $env:OPENSPACE_MODEL"
    Write-Host "API:   $env:OPENSPACE_LLM_API_BASE"
    Write-Host ''
    Write-Host 'Query for pass 1 chunk 1:'
    $chunkOneFile = Get-ChunkFile -ChunkIndex 1
    $chunkOneReport = Get-ChunkReportFile -RunIndex 1 -ChunkIndex 1
    Write-Host (New-SbtAnimancerQuery `
        -RunIndex 1 `
        -RunCount $runCount `
        -TaskMode 'chunk' `
        -ChunkIndex 1 `
        -ChunkCount $chunkCount `
        -ChunkFile $chunkOneFile `
        -ChunkReportFile $chunkOneReport `
        -ChunkReports '' `
        -ReportFile '' `
        -IsFinalPass 'false')
    Write-Host ''
    Write-Host 'Query for pass 1 merge:'
    $mergeReport = Join-Path $reportDir 'sbt-animancer-learning-report-pass-1.md'
    Write-Host (New-SbtAnimancerQuery `
        -RunIndex 1 `
        -RunCount $runCount `
        -TaskMode 'merge' `
        -ChunkIndex 0 `
        -ChunkCount $chunkCount `
        -ChunkFile '' `
        -ChunkReportFile '' `
        -ChunkReports (Get-ChunkReportsText -RunIndex 1) `
        -ReportFile $mergeReport `
        -IsFinalPass 'true')
    exit 0
}

for ($runIndex = 1; $runIndex -le $runCount; $runIndex++) {
    for ($chunkIndex = 1; $chunkIndex -le $chunkCount; $chunkIndex++) {
        Write-Host ''
        Write-Host "===== SBT Animancer learning pass $runIndex / $runCount, chunk $chunkIndex / $chunkCount ====="
        $chunkFile = Get-ChunkFile -ChunkIndex $chunkIndex
        $chunkReportFile = Get-ChunkReportFile -RunIndex $runIndex -ChunkIndex $chunkIndex
        $query = New-SbtAnimancerQuery `
            -RunIndex $runIndex `
            -RunCount $runCount `
            -TaskMode 'chunk' `
            -ChunkIndex $chunkIndex `
            -ChunkCount $chunkCount `
            -ChunkFile $chunkFile `
            -ChunkReportFile $chunkReportFile `
            -ChunkReports '' `
            -ReportFile '' `
            -IsFinalPass 'false'

        & $openSpaceExe `
            --no-ui `
            --workspace $outputRoot `
            --max-iterations $env:SBT_ANIMANCER_MAX_ITERATIONS `
            --timeout $env:SBT_ANIMANCER_TIMEOUT `
            --query $query

        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }

    Write-Host ''
    Write-Host "===== SBT Animancer learning pass $runIndex / $runCount, merge ====="
    $reportFile = Join-Path $reportDir ("sbt-animancer-learning-report-pass-{0}.md" -f $runIndex)
    $isFinalPass = if ($runIndex -eq $runCount) { 'true' } else { 'false' }
    $query = New-SbtAnimancerQuery `
        -RunIndex $runIndex `
        -RunCount $runCount `
        -TaskMode 'merge' `
        -ChunkIndex 0 `
        -ChunkCount $chunkCount `
        -ChunkFile '' `
        -ChunkReportFile '' `
        -ChunkReports (Get-ChunkReportsText -RunIndex $runIndex) `
        -ReportFile $reportFile `
        -IsFinalPass $isFinalPass

    & $openSpaceExe `
        --no-ui `
        --workspace $outputRoot `
        --max-iterations $env:SBT_ANIMANCER_MAX_ITERATIONS `
        --timeout $env:SBT_ANIMANCER_TIMEOUT `
        --query $query

    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

exit $LASTEXITCODE
