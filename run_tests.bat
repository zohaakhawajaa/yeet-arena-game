@echo off
rem ===========================================================================
rem  YEET ARENA - full test suite
rem    1. backend unit/integration tests (pytest)
rem    2. Godot menu smoke test        (headless)
rem    3. Godot full match test        (headless, plays a whole arcade match)
rem    4. Godot to backend API test    (starts the backend if needed)
rem ===========================================================================
setlocal enabledelayedexpansion
cd /d "%~dp0"

set "FAILED=0"
set "KILL_BACKEND="
set "GODOT="
if exist "%GODOT_BIN%" set "GODOT=%GODOT_BIN%"
if not defined GODOT if exist "tools\godot\godot.exe" set "GODOT=%cd%\tools\godot\godot.exe"
if not defined GODOT for /f "delims=" %%i in ('where godot 2^>nul') do if not defined GODOT set "GODOT=%%i"

echo.
echo ==========================================================
echo  1/4  Backend tests (pytest)
echo ==========================================================
pushd backend
python -m pytest
if errorlevel 1 set "FAILED=1"
popd

if not defined GODOT (
    echo.
    echo [YEET] Godot executable not found - skipping the Godot test stages.
    echo [YEET] Set GODOT_BIN or copy godot.exe to tools\godot\godot.exe
    echo.
    if "!FAILED!"=="1" exit /b 1
    exit /b 0
)

echo.
echo ==========================================================
echo  2/4  Godot menu smoke test
echo ==========================================================
"%GODOT%" --headless --path "%cd%" --fixed-fps 60 --quit-after 400 "res://tests/godot/menu_smoke.tscn" -- --no-audio | findstr /C:"ALL_MENUS_OK" >nul
if errorlevel 1 (
    echo [FAIL] menu smoke test
    set "FAILED=1"
) else (
    echo [PASS] every menu screen boots cleanly
)

echo.
echo ==========================================================
echo  3/4  Godot full match test (arcade match through to results)
echo ==========================================================
"%GODOT%" --headless --path "%cd%" --fixed-fps 60 --quit-after 6000 "res://tests/godot/match_test.tscn" -- --no-audio | findstr /C:"ALL_MATCH_OK" >nul
if errorlevel 1 (
    echo [FAIL] match test
    set "FAILED=1"
) else (
    echo [PASS] full match plays to the results screen
)

echo.
echo ==========================================================
echo  4/4  Godot to backend API test
echo ==========================================================
rem NOTE: this stage must run in real time (no --fixed-fps): HTTPRequest
rem measures its timeout against the engine clock.
curl -s -o nul --max-time 2 http://127.0.0.1:8000/health >nul 2>nul
if not errorlevel 1 goto backend_ready
set "KILL_BACKEND=1"
echo [YEET] Starting a temporary backend for the API test...
powershell -NoProfile -Command "Start-Process -FilePath python -ArgumentList '-m','uvicorn','app.main:app','--host','127.0.0.1','--port','8000','--app-dir','backend' -WindowStyle Hidden"
for /l %%i in (1,1,15) do (
    ping -n 2 127.0.0.1 >nul
    curl -s -o nul --max-time 1 http://127.0.0.1:8000/health >nul 2>nul
    if not errorlevel 1 goto backend_ready
)
echo [FAIL] the backend did not answer within 15 seconds
set "FAILED=1"
goto suite_end
:backend_ready

"%GODOT%" --headless --path "%cd%" --quit-after 6000 "res://tests/godot/api_test.tscn" -- --no-audio | findstr /C:"ALL_API_OK" >nul
if errorlevel 1 (
    echo [FAIL] API integration test
    set "FAILED=1"
) else (
    echo [PASS] game client talks to the live backend
)

if defined KILL_BACKEND (
    powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Where-Object { $_.CommandLine -like '*uvicorn*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>nul
    echo [YEET] Temporary backend stopped.
)

:suite_end
echo.
if "%FAILED%"=="1" (
    echo ==========================================================
    echo   RESULT: FAILURES ABOVE
    echo ==========================================================
    endlocal
    exit /b 1
)
echo ==========================================================
echo   RESULT: ALL TESTS PASSED
echo ==========================================================
endlocal
exit /b 0
