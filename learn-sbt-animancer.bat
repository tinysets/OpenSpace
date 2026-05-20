@echo off
setlocal EnableExtensions
chcp 65001 >nul

cd /d "%~dp0"

set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"
set "NO_PROXY=127.0.0.1,localhost"

set "OPENSPACE_ROOT=%CD%"
set "OPENSPACE_MODEL=openai/gpt-5.5"
set "OPENSPACE_LLM_API_BASE=http://127.0.0.1:7666/v1"
set "OPENSPACE_LLM_API_KEY=local-proxy"

set "OPENSPACE_BACKEND_SCOPE=shell,system"
set "OPENSPACE_ENABLE_RECORDING=false"
set "OPENSPACE_SHELL_SECURITY_AUTO_ALLOW=1"

set "SBT_ANIMANCER_ROOT=%CD%\.learn-sbt-animancer"
set "SBT_ANIMANCER_EVIDENCE_DIR=%SBT_ANIMANCER_ROOT%\evidence"
set "SBT_ANIMANCER_DRAFT_DIR=%SBT_ANIMANCER_ROOT%\drafts"
set "SBT_ANIMANCER_REPORT_DIR=%SBT_ANIMANCER_ROOT%\reports"
set "SBT_ANIMANCER_RUNTIME_DIR=%SBT_ANIMANCER_ROOT%\runtime"

if not defined SBT_ANIMANCER_MAX_ITERATIONS set "SBT_ANIMANCER_MAX_ITERATIONS=300"
if not defined SBT_ANIMANCER_TIMEOUT set "SBT_ANIMANCER_TIMEOUT=600"
if not defined SBT_ANIMANCER_RUNS set "SBT_ANIMANCER_RUNS=1"
if not defined SBT_ANIMANCER_DRAFT_LIMIT set "SBT_ANIMANCER_DRAFT_LIMIT=10"
if not defined SBT_ANIMANCER_MAX_EVIDENCE set "SBT_ANIMANCER_MAX_EVIDENCE=2000"
if not defined SBT_ANIMANCER_CHUNK_SIZE set "SBT_ANIMANCER_CHUNK_SIZE=250"
if not defined SBT_ANIMANCER_CONTEXT_TOKENS set "SBT_ANIMANCER_CONTEXT_TOKENS=500000"
if not defined SBT_ANIMANCER_MAX_CHUNK_TOKENS set "SBT_ANIMANCER_MAX_CHUNK_TOKENS=auto"
if not defined SBT_ANIMANCER_INCLUDE_TOOLS set "SBT_ANIMANCER_INCLUDE_TOOLS=0"

set "OPENSPACE_MAX_ITERATIONS=%SBT_ANIMANCER_MAX_ITERATIONS%"
set "OPENSPACE_WORKSPACE=%SBT_ANIMANCER_ROOT%"
set "OPENSPACE_HOST_SKILL_DIRS=%SBT_ANIMANCER_RUNTIME_DIR%"

set "SBT_ANIMANCER_SESSION="
set "SBT_ANIMANCER_DRY_RUN=0"

:parse_args
if "%~1"=="" goto :args_done
if /I "%~1"=="--session" (
  set "SBT_ANIMANCER_SESSION=%~2"
  shift
) else if /I "%~1"=="--runs" (
  set "SBT_ANIMANCER_RUNS=%~2"
  shift
) else if /I "%~1"=="--dry-run" (
  set "SBT_ANIMANCER_DRY_RUN=1"
) else if /I "%~1"=="--chunk-size" (
  set "SBT_ANIMANCER_CHUNK_SIZE=%~2"
  shift
) else if /I "%~1"=="--max-evidence" (
  set "SBT_ANIMANCER_MAX_EVIDENCE=%~2"
  shift
) else if /I "%~1"=="--context-tokens" (
  set "SBT_ANIMANCER_CONTEXT_TOKENS=%~2"
  shift
) else if /I "%~1"=="--max-chunk-tokens" (
  set "SBT_ANIMANCER_MAX_CHUNK_TOKENS=%~2"
  shift
) else if /I "%~1"=="--include-tools" (
  set "SBT_ANIMANCER_INCLUDE_TOOLS=1"
) else if not defined SBT_ANIMANCER_SESSION (
  set "SBT_ANIMANCER_SESSION=%~1"
)
shift
goto :parse_args

:args_done
if not defined SBT_ANIMANCER_SESSION (
  echo Usage:
  echo   learn-sbt-animancer.bat --session "C:\path\to\large-session.jsonl"
  echo   learn-sbt-animancer.bat "C:\path\to\large-session.jsonl" --runs 3
  echo   learn-sbt-animancer.bat --session "C:\path\to\large-session.jsonl" --context-tokens 500000 --max-evidence 2000 --chunk-size 250
  echo   learn-sbt-animancer.bat --session "C:\path\to\large-session.jsonl" --max-chunk-tokens 30000
  echo   learn-sbt-animancer.bat --session "C:\path\to\large-session.jsonl" --include-tools
  exit /b 2
)

if not exist "%CD%\.venv\Scripts\python.exe" (
  echo Missing virtual environment: %CD%\.venv\Scripts\python.exe
  echo Run setup first: python -m venv .venv
  exit /b 1
)

if not exist "%SBT_ANIMANCER_ROOT%" mkdir "%SBT_ANIMANCER_ROOT%"
if not exist "%SBT_ANIMANCER_EVIDENCE_DIR%" mkdir "%SBT_ANIMANCER_EVIDENCE_DIR%"
if not exist "%SBT_ANIMANCER_DRAFT_DIR%" mkdir "%SBT_ANIMANCER_DRAFT_DIR%"
if not exist "%SBT_ANIMANCER_REPORT_DIR%" mkdir "%SBT_ANIMANCER_REPORT_DIR%"
if not exist "%SBT_ANIMANCER_RUNTIME_DIR%" mkdir "%SBT_ANIMANCER_RUNTIME_DIR%"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CD%\learn-sbt-animancer.ps1"
exit /b %ERRORLEVEL%
