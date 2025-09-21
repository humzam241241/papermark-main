@echo off
setlocal ENABLEDELAYEDEXPANSION

REM --- Relaunch self in a persistent console so it never auto-closes ---
if "%~1"=="" (
  start "Papermark Launcher" cmd /k "%~f0" inner
  goto :eof
)
if /I "%~1" NEQ "inner" goto :eof

REM --- Move to the folder where this BAT lives (repo root) ---
cd /d "%~dp0"

set "PORT=3000"

echo [setup] Checking Node and npm...
where node >nul 2>&1 || (echo [error] Node.js not found. Install Node 20+ and retry. & goto :end)
where npm >nul 2>&1 || (echo [error] npm not found on PATH. & goto :end)

REM --- Pick a package manager based on lockfile and availability ---
set "PM=npm"
if exist pnpm-lock.yaml (
  where pnpm >nul 2>&1 && set "PM=pnpm"
) else (
  if exist yarn.lock (
    where yarn >nul 2>&1 && set "PM=yarn"
  ) else (
    if exist package-lock.json (
      set "PM=npm"
    ) else (
      set "PM=npm"
    )
  )
)

echo [setup] Installing dependencies - least restrictive
if /I "%PM%"=="pnpm" (
  echo [setup] Using pnpm install
  call pnpm install
) else (
  if /I "%PM%"=="yarn" (
    echo [setup] Using yarn install
    call yarn install
  ) else (
    if exist package-lock.json (
      echo [setup] Using npm ci - lockfile found
      call npm ci
    ) else (
      echo [setup] Using npm install - no lockfile
      call npm install
    )
  )
)

if errorlevel 1 (
  echo [error] Dependency install failed.
  goto :end
)

REM --- Pre-install TS dev deps so Next.js won't try at runtime (safe if already present) ---
if exist tsconfig.json (
  echo [setup] Ensuring TypeScript dev dependencies are present
  if exist node_modules\typescript\package.json (
    echo [ok] TypeScript already installed
  ) else (
    call npm i -D typescript @types/react @types/node --no-audit --no-fund
    if errorlevel 1 (
      echo [error] Failed installing TypeScript dev dependencies
      goto :end
    )
  )
)

REM --- Ensure local Next binary is installed ---
if not exist node_modules\.bin\next (
  echo [setup] Installing Next locally
  call npm i -E next@14.2.32 --no-audit --no-fund --legacy-peer-deps
)

if not exist node_modules\.bin\next (
  echo [error] Local Next binary still missing after install
  echo        Try running: npm i -E next@14.2.32
  goto :end
)

REM --- If port 3000 is busy, pick the first free port 3001-3010 ---
netstat -ano | findstr ":%PORT% " >nul
if not errorlevel 1 (
  for /l %%p in (3001,1,3010) do (
    netstat -ano | findstr ":%%p " >nul
    if errorlevel 1 (
      set PORT=%%p
      goto port_found
    )
  )
)
:port_found

REM --- Start Next.js dev server in a separate window ---
echo [dev] Starting Next.js on http://localhost:%PORT% ...
set "DEV_CMD=node_modules\\.bin\\next dev"
if "%PORT%"=="3000" (
  start "Papermark Dev Server" cmd /k "%DEV_CMD%"
) else (
  start "Papermark Dev Server" cmd /k "%DEV_CMD% -p %PORT%"
)

REM --- Wait for readiness and open browser ---
echo [wait] Waiting for http://localhost:%PORT% ...
for /l %%I in (1,1,90) do (
  powershell -NoProfile -Command "try{ (Invoke-WebRequest -Uri 'http://localhost:%PORT%' -UseBasicParsing -TimeoutSec 1) | Out-Null; exit 0 }catch{ exit 1 }" >nul 2>&1
  if !errorlevel! EQU 0 (
    echo [ok] Dev server is up
    start "" "http://localhost:%PORT%"
    goto :end
  )
  timeout /t 1 >nul
)
echo [warn] Timed out waiting for the dev server. You can still visit http://localhost:%PORT%

:end
echo.
echo Press any key to close this window...
pause >nul
endlocal