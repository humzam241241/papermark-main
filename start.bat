@echo off
setlocal ENABLEDELAYEDEXPANSION

REM Keep this window open when double-clicked
if "%~1"=="" (
    start "Papermark" cmd /k "%~f0" inner
    goto :eof
)

cd /d "%~dp0"

echo Starting Papermark...
echo.

REM Check if node_modules exists, install if not
if not exist node_modules (
    echo [%date% %time%] Installing dependencies...
    set "NPM_CONFIG_LOGLEVEL=verbose"
    set "NPM_CONFIG_PROGRESS=true"
    del ".setup.log" >nul 2>&1
    start "Install logs" powershell -NoProfile -NoExit -Command "Get-Content -Path '.setup.log' -Wait"
    npm install --no-audit --no-fund --legacy-peer-deps --verbose 1>>".setup.log" 2>&1
    if errorlevel 1 (
        echo [%date% %time%] Failed to install dependencies. See .setup.log
        pause
        exit /b 1
    )
)

REM Ensure TypeScript dev dependencies are present (so Next doesn't prompt)
set "NEED_TS=0"
if not exist node_modules\typescript\package.json set "NEED_TS=1"
if not exist node_modules\@types\react\package.json set "NEED_TS=1"
if not exist node_modules\@types\node\package.json set "NEED_TS=1"
if "%NEED_TS%"=="1" (
    echo [%date% %time%] Installing TypeScript dev dependencies...
    if not exist ".setup.log" ( type nul > ".setup.log" )
    npm install -D typescript @types/react @types/node --no-audit --no-fund --verbose 1>>".setup.log" 2>&1
    if errorlevel 1 (
        echo [%date% %time%] Failed installing TypeScript deps. See .setup.log
        pause
        exit /b 1
    )
)

REM Start the development server
echo [%date% %time%] Starting development server...
echo This will take a moment on first run...
echo Logs: .dev.log (live window opened)
echo.
del ".dev.log" >nul 2>&1
start "Dev logs" powershell -NoProfile -NoExit -Command "Get-Content -Path '.dev.log' -Wait"
start "Open Browser" cmd /c "timeout /t 10 >nul && start http://localhost:3000"

REM Auto-answer yes to npx prompts and start server
echo y | npx next@14.2.32 dev --port 3000 1>>".dev.log" 2>&1

REM If we get here, the server stopped
echo.
echo Development server stopped.
pause
