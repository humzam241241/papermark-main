@echo off
setlocal

REM Keep window open
if "%~1"=="" (
    start "Papermark" cmd /k "%~f0" inner
    goto :eof
)

cd /d "%~dp0"
echo ========================================
echo         PAPERMARK LAUNCHER
echo ========================================
echo.

echo [1/4] Checking Node.js...
where node >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js not found. Install Node.js and retry.
    pause
    exit /b 1
)
echo       Node.js found
echo.

echo [2/4] Installing dependencies if needed...
if not exist node_modules goto INSTALL_DEPS
echo       Dependencies already installed
goto AFTER_INSTALL_DEPS

:INSTALL_DEPS
echo       Installing - first run may take several minutes...
npm install --no-audit --no-fund --legacy-peer-deps
if errorlevel 1 goto INSTALL_FAIL

:AFTER_INSTALL_DEPS
if not exist node_modules\typescript goto INSTALL_TS
goto AFTER_INSTALL_TS

:INSTALL_TS
echo       Installing TypeScript toolchain...
npm install -D typescript @types/react @types/node --no-audit --no-fund
if errorlevel 1 goto INSTALL_FAIL

:AFTER_INSTALL_TS
echo       Dependencies ready
goto DEP_END

:INSTALL_FAIL
echo ERROR: Dependency installation failed. See output above.
pause
exit /b 1

:DEP_END
echo.

echo [3/4] Setting up environment...
if not exist .env.local goto CREATE_ENV
goto AFTER_CREATE_ENV

:CREATE_ENV
echo DATABASE_URL=file:./dev.db> .env.local
echo NEXTAUTH_URL=http://localhost:3000>> .env.local
echo NEXTAUTH_SECRET=dev-secret-key>> .env.local
echo HANKO_API_KEY=dummy-key>> .env.local
echo NEXT_PUBLIC_HANKO_TENANT_ID=dummy-id>> .env.local
echo NEXT_PUBLIC_BASE_URL=http://localhost:3000>> .env.local

:AFTER_CREATE_ENV
if exist node_modules\.prisma\client\index.js goto ENV_READY
echo       Generating Prisma client...

REM Combine all Prisma schema files into one
echo       Merging Prisma schema files...
type prisma\schema\schema.prisma > prisma\schema.prisma 2>nul
type prisma\schema\team.prisma >> prisma\schema.prisma 2>nul
type prisma\schema\document.prisma >> prisma\schema.prisma 2>nul
type prisma\schema\link.prisma >> prisma\schema.prisma 2>nul
type prisma\schema\dataroom.prisma >> prisma\schema.prisma 2>nul
type prisma\schema\conversation.prisma >> prisma\schema.prisma 2>nul
type prisma\schema\annotation.prisma >> prisma\schema.prisma 2>nul
type prisma\schema\integration.prisma >> prisma\schema.prisma 2>nul

npx --yes prisma@6.5.0 generate --schema=prisma/schema.prisma
if errorlevel 1 (
    echo       ERROR: Prisma generate failed
    echo       Try running manually: npx prisma generate --schema=prisma/schema.prisma
    pause
    exit /b 1
)

:ENV_READY
echo       Environment ready
echo.

echo [4/4] Starting Papermark...
echo.
echo ========================================
echo   Opening http://localhost:3000
echo   Press Ctrl+C to stop
echo ========================================
echo.

timeout /t 5 >nul
start http://localhost:3000
npx next@14.2.32 dev

pause
endlocal