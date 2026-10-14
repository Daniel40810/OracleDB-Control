# ============================================================
# Build-OracleDB-EXE.ps1
# Erstellt aus Start-OracleDB-GUI.ps1 eine standalone EXE.
#
# AUSFUEHREN:
#   Rechtsklick -> "Als Administrator ausfuehren"
#   ODER in einer Admin-PowerShell:
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\Build-OracleDB-EXE.ps1
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  Oracle 21c DB Control Center  -  EXE Builder" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = $PSScriptRoot
$ps1File   = Join-Path $scriptDir "Start-OracleDB-GUI.ps1"
$icoFile   = Join-Path $scriptDir "OracleDB-Control.ico"
$outputExe = Join-Path $scriptDir "OracleDB-Control.exe"

if (-not (Test-Path $ps1File)) {
    Write-Host "FEHLER: Start-OracleDB-GUI.ps1 nicht gefunden in $scriptDir" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $icoFile)) {
    Write-Host "WARNUNG: OracleDB-Control.ico nicht gefunden - EXE wird ohne Icon erstellt." -ForegroundColor Yellow
    $icoFile = $null
}

Write-Host "Pruefe ps2exe..." -ForegroundColor Yellow
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "Installiere ps2exe..." -ForegroundColor Yellow
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
    Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
    Write-Host "ps2exe installiert." -ForegroundColor Green
} else {
    Write-Host "ps2exe bereits vorhanden." -ForegroundColor Green
}

Import-Module ps2exe -Force

Write-Host ""
Write-Host "Erstelle EXE..." -ForegroundColor Yellow
Write-Host "  Quelle : $ps1File"
Write-Host "  Ziel   : $outputExe"
if ($icoFile) { Write-Host "  Icon   : $icoFile" }
Write-Host ""

$ps2exeParams = @{
    "-inputFile"    = $ps1File
    "-outputFile"   = $outputExe
    "-noConsole"    = $true
    "-requireAdmin" = $false
    "-title"        = "Oracle 21c DB Control Center"
    "-description"  = "Oracle 21c Startup / Shutdown / Listener / PDB GUI"
    "-company"      = "Oracle DBA Tools"
    "-version"      = "1.0.0.0"
}
if ($icoFile) { $ps2exeParams["-iconFile"] = $icoFile }


try {
    Invoke-ps2exe @ps2exeParams -verbose
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host "  ERFOLG!" -ForegroundColor Green
    Write-Host "  EXE erstellt: $outputExe" -ForegroundColor Green
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Hinweis: OracleDB-Control.ico muss im selben Ordner" -ForegroundColor Cyan
    Write-Host "         wie OracleDB-Control.exe liegen." -ForegroundColor Cyan
    Write-Host ""
    $launch = Read-Host "OracleDB Control Center jetzt starten? (j/n)"
    if ($launch -eq "j" -or $launch -eq "J") { Start-Process $outputExe }
} catch {
    Write-Host ""
    Write-Host "FEHLER bei der Konvertierung:" -ForegroundColor Red
    Write-Host $_ -ForegroundColor Red
    Write-Host "Loesung: PowerShell als Administrator ausfuehren." -ForegroundColor Yellow
}

Write-Host "Fertig. Druecke Enter zum Beenden..."
Read-Host