@echo off
setlocal
title OracleDB-Control - Desktop-Verknuepfung

set "SRC=%~dp0"
if "%SRC:~-1%"=="\" set "SRC=%SRC:~0,-1%"

echo.
echo === Schritt 1: Desktop-Verknuepfung erstellen ===
powershell -NoProfile -ExecutionPolicy Bypass -File "%SRC%\Create-Shortcut.ps1"
if errorlevel 1 (
    echo.
    echo Verknuepfung konnte NICHT erstellt werden. Fehlermeldung oben lesen.
    goto :ende
)

echo.
echo === Schritt 2 (optional): EXE neu bauen, damit das neue Icon in der EXE steckt ===
choice /C JN /M "EXE jetzt neu bauen (J/N)"
if errorlevel 2 goto :ende

tasklist /FI "IMAGENAME eq OracleDB-Control.exe" | find /I "OracleDB-Control.exe" >nul
if not errorlevel 1 (
    echo OracleDB-Control laeuft gerade. Bitte zuerst beenden und die Datei erneut starten.
    goto :ende
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SRC%\Build-OracleDB-EXE.ps1"
echo.
echo Build beendet. Die Desktop-Verknuepfung bleibt bestehen.

:ende
echo.
pause
endlocal
