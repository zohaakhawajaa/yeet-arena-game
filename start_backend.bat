@echo off
rem ===========================================================================
rem  YEET ARENA - leaderboard backend (FastAPI + SQLite)
rem  Usage: start_backend.bat [port]
rem ===========================================================================
setlocal enabledelayedexpansion
cd /d "%~dp0"

set "PORT=%~1"
if "%PORT%"=="" set "PORT=8000"

where python >nul 2>nul
if errorlevel 1 (
    echo [YEET] Python 3.10+ is required but was not found on PATH.
    echo [YEET] Install it from https://www.python.org/downloads/ and try again.
    pause
    exit /b 1
)

python -c "import fastapi, uvicorn" >nul 2>nul
if errorlevel 1 (
    echo [YEET] Installing backend requirements...
    python -m pip install --disable-pip-version-check -r "backend\requirements.txt"
    if errorlevel 1 (
        echo [YEET] Could not install requirements. Check your network / pip setup.
        pause
        exit /b 1
    )
)

echo [YEET] Leaderboard API on http://127.0.0.1:%PORT%  (docs at /docs)
echo [YEET] Press Ctrl+C to stop.
python -m uvicorn app.main:app --host 127.0.0.1 --port %PORT% --app-dir backend
endlocal
