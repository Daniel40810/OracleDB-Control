# ============================================================
# Create-Shortcut.ps1
# Legt eine Desktop-Verknuepfung zu OracleDB-Control.exe an
# (Icon: OracleDB-Control.ico aus demselben Ordner).
# ============================================================
$ErrorActionPreference = "Stop"

try {
    $base = $PSScriptRoot
    $exe  = Join-Path $base "OracleDB-Control.exe"
    $ico  = Join-Path $base "OracleDB-Control.ico"

    if (-not (Test-Path $exe)) {
        throw "OracleDB-Control.exe nicht gefunden in: $base  (erst bauen oder Build-OracleDB-EXE.ps1 ausfuehren)"
    }

    $desk    = [Environment]::GetFolderPath("Desktop")
    $lnkPath = Join-Path $desk "Oracle DB Control Center.lnk"
    Write-Host "Desktop-Ordner: $desk"

    $ws  = New-Object -ComObject WScript.Shell
    $lnk = $ws.CreateShortcut($lnkPath)
    $lnk.TargetPath       = $exe
    $lnk.WorkingDirectory = $base
    if (Test-Path $ico) { $lnk.IconLocation = "$ico,0" }
    $lnk.Description      = "Oracle 21c DB Control Center"
    $lnk.Save()

    if (-not (Test-Path $lnkPath)) { throw "Verknuepfung wurde nicht gespeichert: $lnkPath" }
    Write-Host "OK: Verknuepfung erstellt: $lnkPath" -ForegroundColor Green
    exit 0
} catch {
    Write-Host "FEHLER: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
