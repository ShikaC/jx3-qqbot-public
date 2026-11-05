@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo ============================================
echo   JX3 QQ Bot - One-click installer
echo ============================================
echo.
echo This will install Python / AstrBot / NapCat.
echo The first run downloads 1-2 GB, please keep the network on.
echo.
pause

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy\windows-native\setup.ps1"
set "EXITCODE=%ERRORLEVEL%"

echo.
if not "%EXITCODE%"=="0" (
    echo [FAILED] Installation did not finish. Please screenshot the error above.
) else (
    echo [DONE] Installation finished. Press any key to close.
)
pause >nul
exit /b %EXITCODE%
