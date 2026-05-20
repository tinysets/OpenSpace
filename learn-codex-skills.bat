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

set "OPENSPACE_WORKSPACE=%CD%"
set "OPENSPACE_HOST_SKILL_DIRS=%CD%\.codex-learning\runtime"
set "OPENSPACE_BACKEND_SCOPE=shell,system"
set "OPENSPACE_ENABLE_RECORDING=false"
set "OPENSPACE_SHELL_SECURITY_AUTO_ALLOW=1"

if not defined OPENSPACE_LEARN_MAX_ITERATIONS set "OPENSPACE_LEARN_MAX_ITERATIONS=500"
if not defined OPENSPACE_LEARN_TIMEOUT set "OPENSPACE_LEARN_TIMEOUT=600"
if not defined OPENSPACE_LEARN_DRAFT_LIMIT set "OPENSPACE_LEARN_DRAFT_LIMIT=20"
if not defined OPENSPACE_LEARN_RUNS set "OPENSPACE_LEARN_RUNS=1"

set "OPENSPACE_MAX_ITERATIONS=%OPENSPACE_LEARN_MAX_ITERATIONS%"

set "CODEX_HOME=%USERPROFILE%\.codex"
set "DRAFT_DIR=%CD%\.codex-learning\drafts"
set "REPORT_DIR=%CD%\.codex-learning\reports"
set "RUNTIME_DIR=%CD%\.codex-learning\runtime"
set "OPENSPACE_LEARN_RAW_MODE=no-raw"
set "OPENSPACE_LEARN_SESSION="
set "OPENSPACE_LEARN_DRY_RUN=0"

:parse_args
if "%~1"=="" goto :args_done
if /I "%~1"=="raw" set "OPENSPACE_LEARN_RAW_MODE=raw"
if /I "%~1"=="--runs" (
  set "OPENSPACE_LEARN_RUNS=%~2"
  shift
)
if /I "%~1"=="--session" (
  set "OPENSPACE_LEARN_SESSION=%~2"
  set "OPENSPACE_LEARN_RAW_MODE=single-session"
  shift
)
if /I "%~1"=="--dry-run" set "OPENSPACE_LEARN_DRY_RUN=1"
shift
goto :parse_args

:args_done
if not exist "%CD%\.venv\Scripts\python.exe" (
  echo Missing virtual environment: %CD%\.venv\Scripts\python.exe
  echo Run setup first: python -m venv .venv
  exit /b 1
)

if not exist "%DRAFT_DIR%" mkdir "%DRAFT_DIR%"
if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%"
if not exist "%RUNTIME_DIR%" mkdir "%RUNTIME_DIR%"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CD%\learn-codex-skills.ps1"
exit /b %ERRORLEVEL%
