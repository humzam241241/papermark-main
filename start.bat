@echo off
setlocal

echo ===== Papermark Quick Start =====
echo.

rem Change to script directory
cd /d "%~dp0"

set "PORT=3000"

echo Checking Node.js and npm...
where node >nul 2>&1
if errorlevel 1 (
  echo Node.js is not installed or not on PATH. Please install Node.js >= 18.
  pause
  exit /b 1
)
where npm >nul 2>&1
if errorlevel 1 (
  echo npm is not installed or not on PATH.
  pause
  exit /b 1
)

echo Ensuring TypeScript is installed...
call npm install -g typescript --silent
if errorlevel 1 (
  echo TypeScript installation failed but continuing anyway...
)

if not exist "node_modules" (
  echo Installing dependencies with forced flags to bypass peer dependency issues...
  call npm install --legacy-peer-deps --force --no-fund --no-audit
  if errorlevel 1 (
    echo npm install failed. See errors above.
    pause
    exit /b 1
  )
)

echo.
echo Starting Papermark dev server...
echo.
echo A new window will open running the server.
echo The app will open in your browser at http://localhost:%PORT%
echo.

rem Create a temporary script to run the dev server with NODE_OPTIONS
echo @echo off > temp_run.bat
echo set "NODE_OPTIONS=--max-old-space-size=4096 --no-warnings" >> temp_run.bat
echo npm run dev >> temp_run.bat

rem Start the dev server in a new window with a visible title
start "Papermark Dev Server" cmd /k "color 0A && echo Papermark Dev Server Running && echo. && temp_run.bat"

rem Wait for server to start (increased wait time)
echo Waiting for server to start (20 seconds)...
timeout /t 20 /nobreak >nul

rem Open browser
echo Opening browser at http://localhost:%PORT%
start "" "http://localhost:%PORT%"

rem Clean up temporary script
del temp_run.bat

echo.
echo Setup complete! The server is running in a separate window.
echo.
echo If the app doesn't load properly:
echo 1. You may need a .env file with database credentials
echo 2. The database may need to be initialized with "npm run dev:prisma"
echo 3. Try closing all windows and running this script again
echo.
echo Press any key to close this launcher window.
pause >nul
exit /b 0