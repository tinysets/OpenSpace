@echo off
setlocal

cd /d "%~dp0"

set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"
set "NO_PROXY=127.0.0.1,localhost"

set "OPENSPACE_MODEL=openai/gpt-5.5"
set "OPENSPACE_LLM_API_BASE=http://127.0.0.1:7666/v1"
set "OPENSPACE_LLM_API_KEY=local-proxy"

set "OPENSPACE_WORKSPACE=%CD%"
set "OPENSPACE_HOST_SKILL_DIRS=%CD%\.codex-learning\runtime"
set "OPENSPACE_BACKEND_SCOPE=shell,mcp,system"
set "OPENSPACE_ENABLE_RECORDING=true"
set "OPENSPACE_MAX_ITERATIONS=20"

if not exist "%CD%\.venv\Scripts\python.exe" (
  echo Missing virtual environment: %CD%\.venv\Scripts\python.exe
  echo Run: python -m venv .venv
  exit /b 1
)

if not exist "%OPENSPACE_HOST_SKILL_DIRS%" (
  mkdir "%OPENSPACE_HOST_SKILL_DIRS%"
)

echo Starting OpenSpace MCP server
echo Endpoint: http://127.0.0.1:8081/mcp
echo Skill dir: %OPENSPACE_HOST_SKILL_DIRS%
echo Press Ctrl+C to stop.
echo.

"%CD%\.venv\Scripts\python.exe" -m openspace.mcp_server --transport streamable-http --host 127.0.0.1 --port 8081
