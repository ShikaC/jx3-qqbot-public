@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy\windows-native\stop.ps1"
echo.
pause
exit /b %ERRORLEVEL%
