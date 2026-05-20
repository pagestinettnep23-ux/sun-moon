@echo off
cd /d "%~dp0"
echo SUN/MOON preview server
echo.
echo Open this URL in your browser:
echo http://127.0.0.1:4173
echo.
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js was not found. Please install Node.js or use npm.cmd run start.
  pause
  exit /b 1
)
node static-server.mjs
