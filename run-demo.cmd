@echo off
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js is not installed. Download Node.js LTS and try again.
  pause
  exit /b 1
)
echo Running dashboard with simulated traffic (no VPN needed).
echo Open http://127.0.0.1:3000 in your browser.
echo Press Ctrl+C to stop.
type "samples\sample-traffic.txt" | node dashboard\server.js
