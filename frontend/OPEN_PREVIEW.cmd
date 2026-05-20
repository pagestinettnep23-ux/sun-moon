@echo off
cd /d "%~dp0"
start "" "http://127.0.0.1:4173/"
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js was not found. Please install Node.js or use npm.cmd run start.
  pause
  exit /b 1
)
node static-server.mjs
