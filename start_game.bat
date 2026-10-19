@echo off
rem ===========================================================================
rem  YEET ARENA - launch the game (starts the leaderboard backend if needed)
rem
rem  Godot 4.7.x is required but NOT bundled. Point this script at it either by
rem  setting GODOT_BIN, dropping godot.exe in tools\godot\, or having it on PATH.
rem ===========================================================================
setlocal enabledelayedexpansion
cd /d "%~dp0"

set "GODOT="
if exist "%GODOT_BIN%" set "GODOT=%GODOT_BIN%"
if not defined GODOT if exist "tools\godot\godot.exe" set "GODOT=%cd%\tools\godot\godot.exe"
if not defined GODOT for /f "delims=" %%i in ('where godot 2^>nul') do if not defined GODOT set "GODOT=%%i"

if not defined GODOT (
    echo.
    echo [YEET] Could not find a Godot 4.7.x executable.
    echo.
    echo   Set it once with, for example:
    echo       setx GODOT_BIN "C:\Godot\Godot_v4.7.2-stable_win64.exe"
    echo   ...or copy the executable to  tools\godot\godot.exe  in this folder.
    echo.
    echo   Download: https://godotengine.org/download/windows/
    echo.
    pause
    exit /b 1
)

echo [YEET] Using Godot: "%GODOT%"

rem --- make sure the backend is up (the game works offline too) -------------
curl -s -o nul --max-time 2 http://127.0.0.1:8000/health >nul 2>nul
if not errorlevel 1 (
    echo [YEET] Leaderboard backend already running.
    goto launch
)

echo [YEET] Starting leaderboard backend in a separate window...
start "YEET ARENA backend" cmd /c "%~dp0start_backend.bat"
for /l %%i in (1,1,10) do (
    ping -n 2 127.0.0.1 >nul
    curl -s -o nul --max-time 1 http://127.0.0.1:8000/health >nul 2>nul
    if not errorlevel 1 goto launch
)
echo [YEET] Backend did not answer yet - starting the game anyway (offline mode).

:launch
echo [YEET] Launching YEET ARENA...
"%GODOT%" --path "%cd%"
endlocal
