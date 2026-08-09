@echo off
REM VaultX launcher — starts the backend service, then the app window.
REM Backend runs hidden (console window is disabled in the compiled exe).
cd /d "%~dp0"
start "" "backend\vaultx_backend.exe"
timeout /t 2 /nobreak >nul
start "" "vaultx_frontend.exe"