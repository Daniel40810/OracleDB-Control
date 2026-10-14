Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

# ============================================================
# HELPER: Rounded Rectangle Path (global scope)
# ============================================================
function Get-RoundedRect([System.Drawing.Rectangle]$rect, [int]$r) {
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $gp.AddArc($rect.X,              $rect.Y,               $r, $r, 180, 90)
    $gp.AddArc($rect.Right - $r,     $rect.Y,               $r, $r, 270, 90)
    $gp.AddArc($rect.Right - $r,     $rect.Bottom - $r,     $r, $r,   0, 90)
    $gp.AddArc($rect.X,              $rect.Bottom - $r,     $r, $r,  90, 90)
    $gp.CloseFigure()
    return $gp
}

# ============================================================
# GLASS BUTTON (Gradient + Shine + Hover + Press + Rounded)
# ============================================================
function Set-GlassButton {
    param(
        [System.Windows.Forms.Button]$btn,
        [System.Drawing.Color]$baseColor,
        [int]$radius = 8
    )

    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 0
    $btn.BackColor = [System.Drawing.Color]::Transparent

    # Store all state and config in the Tag property for access within event blocks
    $btn.Tag = [PSCustomObject]@{
        Hover   = $false
        Pressed = $false
        Radius  = $radius
        Color   = $baseColor
    }

    $paintBlock = {
        param($s, $e)
        $state = $s.Tag
        $r     = $state.Radius
        $col   = $state.Color

        $rect = New-Object System.Drawing.Rectangle(0, 0, $s.Width, $s.Height)
        $path = Get-RoundedRect $rect $r

        $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

        # Base fill
        $brushBase = New-Object System.Drawing.SolidBrush($col)
        $e.Graphics.FillPath($brushBase, $path)
        $brushBase.Dispose()

        # Shine (obere Hälfte)
        $shineRect = New-Object System.Drawing.Rectangle(0, 0, $rect.Width, [int]($rect.Height / 2))
        if ($shineRect.Height -gt 0 -and $shineRect.Width -gt 0) {
            $shineBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                $shineRect,
                [System.Drawing.Color]::FromArgb(110, 255, 255, 255),
                [System.Drawing.Color]::FromArgb(0, 255, 255, 255),
                [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
            )
            $shinePath = Get-RoundedRect $shineRect $r
            $e.Graphics.FillPath($shineBrush, $shinePath)
            $shineBrush.Dispose()
            $shinePath.Dispose()
        }

        # Hover Glow
        if ($state.Hover -and -not $state.Pressed) {
            $glowBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                $rect,
                [System.Drawing.Color]::FromArgb(60, 255, 255, 255),
                [System.Drawing.Color]::FromArgb(0,  255, 255, 255),
                [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
            )
            $e.Graphics.FillPath($glowBrush, $path)
            $glowBrush.Dispose()
        }

        # Pressed Darken
        if ($state.Pressed) {
            $pressBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(80, 0, 0, 0))
            $e.Graphics.FillPath($pressBrush, $path)
            $pressBrush.Dispose()
        }

        # Text
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment     = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
        # Draw centered text using explicit Rectangle overload
        $drawingRect = [System.Drawing.RectangleF]::new(0, 0, $s.Width, $s.Height)
        $e.Graphics.DrawString($s.Text, $s.Font, [System.Drawing.Brushes]::White, $drawingRect, $sf)
        $sf.Dispose()

        $path.Dispose()
    }

    $btn.Add_Paint($paintBlock)

    $btn.Add_MouseEnter({ param($s, $e) $s.Tag.Hover = $true; $s.Invalidate() })
    $btn.Add_MouseLeave({ param($s, $e) $s.Tag.Hover = $false; $s.Tag.Pressed = $false; $s.Invalidate() })
    $btn.Add_MouseDown({  param($s, $e) $s.Tag.Pressed = $true; $s.Invalidate() })
    $btn.Add_MouseUp({    param($s, $e) $s.Tag.Pressed = $false; $s.Invalidate() })
}

# ============================================================
# KONFIGURATION
# ============================================================
$oracleService   = "OracleServiceORCL"
$listenerService = "OracleOraDB21Home1TNSListener"
$oracleHome      = "C:\Oracle\213000_db_home"
$sysdbaUser      = "sys"
# Kein Passwort im Skript. OS-Authentifizierung wird bevorzugt;
# Fallback nur ueber Umgebungsvariable ORACLE_SYSDBA_PASS (siehe Invoke-SqlPlus).
$pdbName         = "PDBORCL"
$cdbName         = "ORCL"

$selfDir  = if ($PSScriptRoot -and $PSScriptRoot -ne "") {
                $PSScriptRoot
            } else {
                Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
            }
$iconPath = Join-Path $selfDir "OracleDB-Control.ico"

# ============================================================
# SQLPLUS WRAPPER
# ============================================================
# Authentifizierung: zuerst OS-Authentifizierung ("sqlplus / as sysdba").
# Nur wenn diese fehlschlaegt (ORA-01031/01017/28009) UND die Umgebungsvariable
# ORACLE_SYSDBA_PASS gesetzt ist, wird ein Passwort-Login versucht.

function Invoke-SqlPlusRaw {
    param(
        [string]$Exe,
        [string]$Login,
        [string]$SqlCommand,
        [int]$TimeoutMs
    )

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName               = $Exe
    $pinfo.Arguments              = "-S `"$Login`""
    $pinfo.UseShellExecute        = $false
    $pinfo.CreateNoWindow         = $true
    $pinfo.RedirectStandardInput  = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError  = $true

    $proc = [System.Diagnostics.Process]::Start($pinfo)
    # stdout und stderr parallel lesen, sonst kann sqlplus blockieren
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    $proc.StandardInput.WriteLine($SqlCommand)
    $proc.StandardInput.WriteLine("EXIT")
    $proc.StandardInput.Close()

    if (-not $proc.WaitForExit($TimeoutMs)) {
        try { $proc.Kill() } catch { }
        throw "sqlplus hat nicht innerhalb von $([int]($TimeoutMs / 1000)) s geantwortet."
    }
    $proc.WaitForExit()
    return ([string]$outTask.Result + [Environment]::NewLine + [string]$errTask.Result)
}

function Invoke-SqlPlus {
    param(
        [string]$SqlCommand,
        [int]$TimeoutMs = 20000
    )

    $sqlplusExe = Join-Path $oracleHome "bin\sqlplus.exe"
    if (-not (Test-Path $sqlplusExe)) { $sqlplusExe = "sqlplus.exe" }

    $out = Invoke-SqlPlusRaw -Exe $sqlplusExe -Login "/ as sysdba" -SqlCommand $SqlCommand -TimeoutMs $TimeoutMs
    if ($out -match "ORA-01031|ORA-01017|ORA-28009" -and $env:ORACLE_SYSDBA_PASS) {
        $login = "$sysdbaUser/$($env:ORACLE_SYSDBA_PASS) as sysdba"
        $out = Invoke-SqlPlusRaw -Exe $sqlplusExe -Login $login -SqlCommand $SqlCommand -TimeoutMs $TimeoutMs
    }
    return [string]$out
}

# Liefert die erste Oracle-Fehlerzeile (ORA-/SP2-) oder $null.
# -Ignore: Codes, die als harmlos gelten (z.B. "ist bereits offen").
function Get-SqlError {
    param(
        [string]$Output,
        [string[]]$Ignore = @()
    )
    foreach ($line in ($Output -split '\r?\n')) {
        if ($line -match '((ORA|SP2)-\d{4,5})') {
            if ($Ignore -contains $matches[1]) { continue }
            return $line.Trim()
        }
    }
    return $null
}

# Oeffnet die PDB und wartet, bis die Instanz nach einem Start bereit ist.
function Open-PdbWithRetry {
    param([int]$Attempts = 6)
    $out = ""
    for ($i = 1; $i -le $Attempts; $i++) {
        Start-Sleep -Milliseconds 2500
        $out = Invoke-SqlPlus "ALTER PLUGGABLE DATABASE $pdbName OPEN;"
        $err = Get-SqlError $out @("ORA-65019")
        if (-not $err) { return $out }
        Write-Log "Versuch $i/$Attempts - Instanz noch nicht bereit: $err"
    }
    $lastErr = Get-SqlError $out @("ORA-65019")
    throw "PDB $pdbName konnte nicht geoeffnet werden: $lastErr"
}

# ============================================================
# ============================================================
# SPLASH SCREEN
# ============================================================
$splash = New-Object System.Windows.Forms.Form
$splash.FormBorderStyle = 'None'
$splash.StartPosition   = 'CenterScreen'
$splash.BackColor       = [System.Drawing.Color]::FromArgb(30, 30, 30)
$splash.Opacity         = 0.95
$splash.Width           = 420
$splash.Height          = 200

if (Test-Path $iconPath) { $splash.Icon = New-Object System.Drawing.Icon($iconPath) }

$splashLogo = New-Object System.Windows.Forms.Label
$splashLogo.Text      = "Oracle 21c"
$splashLogo.ForeColor = [System.Drawing.Color]::FromArgb(240, 100, 30)
$splashLogo.Font      = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
$splashLogo.AutoSize  = $true
$splashLogo.Location  = New-Object System.Drawing.Point(30, 40)
$splash.Controls.Add($splashLogo)

$splashSub = New-Object System.Windows.Forms.Label
$splashSub.Text      = "DB Control Center wird geladen..."
$splashSub.ForeColor = [System.Drawing.Color]::Silver
$splashSub.Font      = New-Object System.Drawing.Font("Segoe UI", 10)
$splashSub.AutoSize  = $true
$splashSub.Location  = New-Object System.Drawing.Point(30, 130)
$splash.Controls.Add($splashSub)

$splash.Show()
$splash.Refresh()
Start-Sleep -Milliseconds 1500
$splash.Close()

# ============================================================
# MAIN WINDOW
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text            = "Oracle 21c DB Control Center"
$form.Size            = New-Object System.Drawing.Size(680, 640)
$form.StartPosition   = "CenterScreen"
$form.BackColor       = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.ForeColor       = [System.Drawing.Color]::White
$form.MinimumSize     = New-Object System.Drawing.Size(680, 640)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.MinimizeBox = $true   # optional


if (Test-Path $iconPath) { $form.Icon = New-Object System.Drawing.Icon($iconPath) }

# ============================================================
# STATUS PANEL
# ============================================================
$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Size      = New-Object System.Drawing.Size(650, 50)
$statusPanel.Location  = New-Object System.Drawing.Point(10, 10)
$statusPanel.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
$form.Controls.Add($statusPanel)

$dbDot = New-Object System.Windows.Forms.Label
$dbDot.Text      = "●"
$dbDot.ForeColor = [System.Drawing.Color]::Gray
$dbDot.Font      = New-Object System.Drawing.Font("Segoe UI", 13)
$dbDot.AutoSize  = $true
$dbDot.Location  = New-Object System.Drawing.Point(10, 14)
$statusPanel.Controls.Add($dbDot)

$dbStatusLabel = New-Object System.Windows.Forms.Label
$dbStatusLabel.Text      = "DB: Unbekannt"
$dbStatusLabel.ForeColor = [System.Drawing.Color]::Silver
$dbStatusLabel.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$dbStatusLabel.AutoSize  = $true
$dbStatusLabel.Location  = New-Object System.Drawing.Point(30, 16)
$statusPanel.Controls.Add($dbStatusLabel)

$lsnDot = New-Object System.Windows.Forms.Label
$lsnDot.Text      = "●"
$lsnDot.ForeColor = [System.Drawing.Color]::Gray
$lsnDot.Font      = New-Object System.Drawing.Font("Segoe UI", 13)
$lsnDot.AutoSize  = $true
$lsnDot.Location  = New-Object System.Drawing.Point(215, 14)
$statusPanel.Controls.Add($lsnDot)

$lsnStatusLabel = New-Object System.Windows.Forms.Label
$lsnStatusLabel.Text      = "Listener: Unbekannt"
$lsnStatusLabel.ForeColor = [System.Drawing.Color]::Silver
$lsnStatusLabel.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lsnStatusLabel.AutoSize  = $true
$lsnStatusLabel.Location  = New-Object System.Drawing.Point(235, 16)
$statusPanel.Controls.Add($lsnStatusLabel)

$pdbDot = New-Object System.Windows.Forms.Label
$pdbDot.Text      = "●"
$pdbDot.ForeColor = [System.Drawing.Color]::Gray
$pdbDot.Font      = New-Object System.Drawing.Font("Segoe UI", 13)
$pdbDot.AutoSize  = $true
$pdbDot.Location  = New-Object System.Drawing.Point(445, 14)
$statusPanel.Controls.Add($pdbDot)

$pdbStatusLabel = New-Object System.Windows.Forms.Label
$pdbStatusLabel.Text      = "PDB: Unbekannt"
$pdbStatusLabel.ForeColor = [System.Drawing.Color]::Silver
$pdbStatusLabel.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$pdbStatusLabel.AutoSize  = $true
$pdbStatusLabel.Location  = New-Object System.Drawing.Point(465, 16)
$statusPanel.Controls.Add($pdbStatusLabel)

# ============================================================
# LOG WINDOW
# ============================================================
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline   = $true
$logBox.ScrollBars  = "Vertical"
$logBox.ReadOnly    = $true
$logBox.BackColor   = [System.Drawing.Color]::FromArgb(18, 18, 18)
$logBox.ForeColor   = [System.Drawing.Color]::FromArgb(204, 204, 204)
$logBox.Font        = New-Object System.Drawing.Font("Consolas", 9)
$logBox.Size        = New-Object System.Drawing.Size(650, 260)
$logBox.Location    = New-Object System.Drawing.Point(10, 70)
$form.Controls.Add($logBox)

function Write-Log {
    param([string]$Message)
    $ts   = Get-Date -Format "HH:mm:ss"
    $line = "[$ts] $Message"
    $logBox.AppendText($line + [Environment]::NewLine)
    $logBox.SelectionStart = $logBox.TextLength
    $logBox.ScrollToCaret()
}

# ============================================================
# STATUS UPDATE
# ============================================================
function Update-Status {
    $dbSvc = Get-Service -Name $oracleService -ErrorAction SilentlyContinue
    if ($dbSvc -and $dbSvc.Status -eq "Running") {
        $dbDot.ForeColor      = [System.Drawing.Color]::FromArgb(60, 200, 80)
        $dbStatusLabel.Text   = "DB: Gestartet"
        $dbStartBtn.Enabled   = $false
        $dbStopBtn.Enabled    = $true
        $dbRestartBtn.Enabled = $true
    } else {
        $dbDot.ForeColor      = [System.Drawing.Color]::Gray
        $dbStatusLabel.Text   = "DB: Gestoppt"
        $dbStartBtn.Enabled   = $true
        $dbStopBtn.Enabled    = $false
        $dbRestartBtn.Enabled = $false
    }

    $lsnSvc = Get-Service -Name $listenerService -ErrorAction SilentlyContinue
    if ($lsnSvc -and $lsnSvc.Status -eq "Running") {
        $lsnDot.ForeColor    = [System.Drawing.Color]::FromArgb(60, 200, 80)
        $lsnStatusLabel.Text = "Listener: Gestartet"
        $lsnStartBtn.Enabled = $false
        $lsnStopBtn.Enabled  = $true
    } else {
        $lsnDot.ForeColor    = [System.Drawing.Color]::Gray
        $lsnStatusLabel.Text = "Listener: Gestoppt"
        $lsnStartBtn.Enabled = $true
        $lsnStopBtn.Enabled  = $false
    }

    $dbSvc2 = Get-Service -Name $oracleService -ErrorAction SilentlyContinue
    if ($dbSvc2 -and $dbSvc2.Status -eq "Running") {
        try {
            $pdbOut = Invoke-SqlPlus "SELECT open_mode FROM v`$pdbs WHERE name = UPPER('$pdbName');"
            if ($pdbOut -match "READ WRITE") {
                $pdbDot.ForeColor    = [System.Drawing.Color]::FromArgb(60, 200, 80)
                $pdbStatusLabel.Text = "PDB: OPEN"
                $pdbOpenBtn.Enabled  = $false
                $pdbCloseBtn.Enabled = $true
            } elseif ($pdbOut -match "MOUNTED") {
                $pdbDot.ForeColor    = [System.Drawing.Color]::FromArgb(240, 180, 0)
                $pdbStatusLabel.Text = "PDB: MOUNTED"
                $pdbOpenBtn.Enabled  = $true
                $pdbCloseBtn.Enabled = $true
            } else {
                $pdbDot.ForeColor    = [System.Drawing.Color]::Gray
                $pdbStatusLabel.Text = "PDB: Geschlossen"
                $pdbOpenBtn.Enabled  = $true
                $pdbCloseBtn.Enabled = $false
            }
        } catch {
            $pdbStatusLabel.Text = "PDB: n/a"
        }
    } else {
        $pdbDot.ForeColor    = [System.Drawing.Color]::Gray
        $pdbStatusLabel.Text = "PDB: n/a"
        $pdbOpenBtn.Enabled  = $false
        $pdbCloseBtn.Enabled = $false
    }
}

# ============================================================
# BUTTONS
# ============================================================

# --- CDB ---
$dbLabel = New-Object System.Windows.Forms.Label
$dbLabel.Text      = "DATENBANK  (CDB: $cdbName)"
$dbLabel.ForeColor = [System.Drawing.Color]::White
$dbLabel.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$dbLabel.AutoSize  = $true
$dbLabel.Location  = New-Object System.Drawing.Point(10, 345)
$form.Controls.Add($dbLabel)

$dbBtnPanel = New-Object System.Windows.Forms.Panel
$dbBtnPanel.Size     = New-Object System.Drawing.Size(650, 42)
$dbBtnPanel.Location = New-Object System.Drawing.Point(10, 365)
$form.Controls.Add($dbBtnPanel)

$dbStartBtn = New-Object System.Windows.Forms.Button
$dbStartBtn.Text      = "▶  DB Starten"
$dbStartBtn.Width     = 200
$dbStartBtn.Height    = 38
$dbStartBtn.Location  = New-Object System.Drawing.Point(0, 0)
$dbStartBtn.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$dbBtnPanel.Controls.Add($dbStartBtn)

$dbStopBtn = New-Object System.Windows.Forms.Button
$dbStopBtn.Text      = "■  DB Stoppen"
$dbStopBtn.Width     = 200
$dbStopBtn.Height    = 38
$dbStopBtn.Location  = New-Object System.Drawing.Point(225, 0)
$dbStopBtn.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$dbBtnPanel.Controls.Add($dbStopBtn)

$dbRestartBtn = New-Object System.Windows.Forms.Button
$dbRestartBtn.Text      = "↺  DB Restart"
$dbRestartBtn.Width     = 200
$dbRestartBtn.Height    = 38
$dbRestartBtn.Location  = New-Object System.Drawing.Point(450, 0)
$dbRestartBtn.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$dbBtnPanel.Controls.Add($dbRestartBtn)

# --- LISTENER ---
$lsnLabel = New-Object System.Windows.Forms.Label
$lsnLabel.Text      = "LISTENER"
$lsnLabel.ForeColor = [System.Drawing.Color]::White
$lsnLabel.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lsnLabel.AutoSize  = $true
$lsnLabel.Location  = New-Object System.Drawing.Point(10, 422)
$form.Controls.Add($lsnLabel)

$lsnBtnPanel = New-Object System.Windows.Forms.Panel
$lsnBtnPanel.Size     = New-Object System.Drawing.Size(650, 42)
$lsnBtnPanel.Location = New-Object System.Drawing.Point(10, 442)
$form.Controls.Add($lsnBtnPanel)

$lsnStartBtn = New-Object System.Windows.Forms.Button
$lsnStartBtn.Text      = "▶  Listener Starten"
$lsnStartBtn.Width     = 315
$lsnStartBtn.Height    = 38
$lsnStartBtn.Location  = New-Object System.Drawing.Point(0, 0)
$lsnStartBtn.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lsnBtnPanel.Controls.Add($lsnStartBtn)

$lsnStopBtn = New-Object System.Windows.Forms.Button
$lsnStopBtn.Text      = "■  Listener Stoppen"
$lsnStopBtn.Width     = 315
$lsnStopBtn.Height    = 38
$lsnStopBtn.Location  = New-Object System.Drawing.Point(335, 0)
$lsnStopBtn.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lsnBtnPanel.Controls.Add($lsnStopBtn)

# --- PDB ---
$pdbLabel = New-Object System.Windows.Forms.Label
$pdbLabel.Text      = "PLUGGABLE DATABASE  (PDB: $pdbName)"
$pdbLabel.ForeColor = [System.Drawing.Color]::White
$pdbLabel.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$pdbLabel.AutoSize  = $true
$pdbLabel.Location  = New-Object System.Drawing.Point(10, 500)
$form.Controls.Add($pdbLabel)

$pdbBtnPanel = New-Object System.Windows.Forms.Panel
$pdbBtnPanel.Size     = New-Object System.Drawing.Size(650, 42)
$pdbBtnPanel.Location = New-Object System.Drawing.Point(10, 520)
$form.Controls.Add($pdbBtnPanel)

$pdbOpenBtn = New-Object System.Windows.Forms.Button
$pdbOpenBtn.Text      = "▶  PDB Öffnen"
$pdbOpenBtn.Width     = 315
$pdbOpenBtn.Height    = 38
$pdbOpenBtn.Location  = New-Object System.Drawing.Point(0, 0)
$pdbOpenBtn.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$pdbBtnPanel.Controls.Add($pdbOpenBtn)

$pdbCloseBtn = New-Object System.Windows.Forms.Button
$pdbCloseBtn.Text      = "■  PDB Schließen"
$pdbCloseBtn.Width     = 315
$pdbCloseBtn.Height    = 38
$pdbCloseBtn.Location  = New-Object System.Drawing.Point(335, 0)
$pdbCloseBtn.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$pdbBtnPanel.Controls.Add($pdbCloseBtn)

# ============================================================
# GLASS STYLES ANWENDEN
# ============================================================
Set-GlassButton $dbStartBtn   ([System.Drawing.Color]::FromArgb(153,0,51))
Set-GlassButton $dbStopBtn    ([System.Drawing.Color]::FromArgb(153,0,51))
Set-GlassButton $dbRestartBtn ([System.Drawing.Color]::FromArgb(153,0,51))

Set-GlassButton $lsnStartBtn  ([System.Drawing.Color]::FromArgb(153,0,51))
Set-GlassButton $lsnStopBtn   ([System.Drawing.Color]::FromArgb(153,0,51))

Set-GlassButton $pdbOpenBtn   ([System.Drawing.Color]::FromArgb(153,0,51))
Set-GlassButton $pdbCloseBtn  ([System.Drawing.Color]::FromArgb(153,0,51))

# ============================================================
# TRAY ICON
# ============================================================
$tray = New-Object System.Windows.Forms.NotifyIcon
if (Test-Path $iconPath) {
    $tray.Icon = New-Object System.Drawing.Icon($iconPath)
} else {
    $tray.Icon = [System.Drawing.SystemIcons]::Information
}
$tray.Visible = $true
$tray.Text    = "Oracle 21c DB Control Center"

$menu         = New-Object System.Windows.Forms.ContextMenuStrip
$menuDbStart  = $menu.Items.Add("DB starten")
$menuDbStop   = $menu.Items.Add("DB stoppen")
$menu.Items.Add("-") | Out-Null
$menuLsnStart = $menu.Items.Add("Listener starten")
$menuLsnStop  = $menu.Items.Add("Listener stoppen")
$menu.Items.Add("-") | Out-Null
$menuPdbOpen  = $menu.Items.Add("PDB öffnen")
$menuPdbClose = $menu.Items.Add("PDB schließen")
$menu.Items.Add("-") | Out-Null
$menuStatus   = $menu.Items.Add("Status aktualisieren")
$menuExit     = $menu.Items.Add("Beenden")

$menuDbStart.Add_Click({  $dbStartBtn.PerformClick()  })
$menuDbStop.Add_Click({   $dbStopBtn.PerformClick()   })
$menuLsnStart.Add_Click({ $lsnStartBtn.PerformClick() })
$menuLsnStop.Add_Click({  $lsnStopBtn.PerformClick()  })
$menuPdbOpen.Add_Click({  $pdbOpenBtn.PerformClick()  })
$menuPdbClose.Add_Click({ $pdbCloseBtn.PerformClick() })
$menuStatus.Add_Click({   Update-Status               })
$menuExit.Add_Click({     $tray.Visible = $false; [System.Windows.Forms.Application]::Exit() })

$tray.ContextMenuStrip = $menu

# ============================================================
# BUTTON LOGIK
# ============================================================
$dbStartBtn.Add_Click({
    Write-Log "Starte Oracle DB-Dienst ($oracleService)..."
    try {
        Start-Service -Name $oracleService -ErrorAction Stop
        Write-Log "DB-Dienst gestartet, warte auf Instanz..."
        $out = Open-PdbWithRetry
        Write-Log $out.Trim()
        Write-Log "PDB $pdbName geoeffnet."
        $tray.ShowBalloonTip(3000, "Oracle DB", "Datenbank gestartet & PDB geoeffnet.", [System.Windows.Forms.ToolTipIcon]::Info)
    } catch {
        Write-Log "FEHLER beim DB-Start: $_"
        $tray.ShowBalloonTip(4000, "Oracle DB", "Start fehlgeschlagen - siehe Log.", [System.Windows.Forms.ToolTipIcon]::Error)
    }
    Update-Status
})

$dbStopBtn.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Oracle DB jetzt stoppen (SHUTDOWN IMMEDIATE)?",
        "DB stoppen",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($result -eq "No") { return }

    Write-Log "Fahre DB herunter (SHUTDOWN IMMEDIATE)..."
    try {
        $out = Invoke-SqlPlus "SHUTDOWN IMMEDIATE;"
        Write-Log $out.Trim()
        # ORA-01034 = Instanz lief ohnehin nicht -> kein Fehler
        $err = Get-SqlError $out @("ORA-01034")
        if ($err) { throw "SHUTDOWN fehlgeschlagen: $err" }
        Stop-Service -Name $oracleService -Force -ErrorAction SilentlyContinue
        Write-Log "DB-Dienst gestoppt."
        $tray.ShowBalloonTip(2000, "Oracle DB", "Datenbank gestoppt.", [System.Windows.Forms.ToolTipIcon]::Warning)
    } catch {
        Write-Log "FEHLER beim DB-Stop: $_"
        $tray.ShowBalloonTip(4000, "Oracle DB", "Stop fehlgeschlagen - siehe Log.", [System.Windows.Forms.ToolTipIcon]::Error)
    }
    Update-Status
})

$dbRestartBtn.Add_Click({
    Write-Log "Restart: Fahre DB herunter..."
    try {
        $out = Invoke-SqlPlus "SHUTDOWN IMMEDIATE;"
        Write-Log $out.Trim()
        $err = Get-SqlError $out @("ORA-01034")
        if ($err) { throw "SHUTDOWN fehlgeschlagen: $err" }
        Restart-Service -Name $oracleService -Force
        Write-Log "DB-Dienst neu gestartet, warte auf Instanz..."
        $out2 = Open-PdbWithRetry
        Write-Log $out2.Trim()
        Write-Log "PDB $pdbName wieder geoeffnet."
        $tray.ShowBalloonTip(3000, "Oracle DB", "Neustart abgeschlossen.", [System.Windows.Forms.ToolTipIcon]::Info)
    } catch {
        Write-Log "FEHLER beim Restart: $_"
        $tray.ShowBalloonTip(4000, "Oracle DB", "Restart fehlgeschlagen - siehe Log.", [System.Windows.Forms.ToolTipIcon]::Error)
    }
    Update-Status
})

$lsnStartBtn.Add_Click({
    Write-Log "Starte Listener ($listenerService)..."
    try {
        Start-Service -Name $listenerService -ErrorAction Stop
        Write-Log "Listener gestartet."
        $tray.ShowBalloonTip(2000, "Listener", "Listener gestartet.", [System.Windows.Forms.ToolTipIcon]::Info)
    } catch {
        Write-Log "FEHLER: $_"
        Write-Log "Hinweis: Dienstname prüfen - evtl. abweichend von '$listenerService'"
        $tray.ShowBalloonTip(4000, "Listener", "Start fehlgeschlagen - siehe Log.", [System.Windows.Forms.ToolTipIcon]::Error)
    }
    Update-Status
})

$lsnStopBtn.Add_Click({
    Write-Log "Stoppe Listener..."
    try {
        Stop-Service -Name $listenerService -Force -ErrorAction Stop
        Write-Log "Listener gestoppt."
        $tray.ShowBalloonTip(2000, "Listener", "Listener gestoppt.", [System.Windows.Forms.ToolTipIcon]::Warning)
    } catch {
        Write-Log "FEHLER: $_"
        $tray.ShowBalloonTip(4000, "Listener", "Stop fehlgeschlagen - siehe Log.", [System.Windows.Forms.ToolTipIcon]::Error)
    }
    Update-Status
})

$pdbOpenBtn.Add_Click({
    Write-Log "Öffne PDB $pdbName..."
    try {
        $out = Invoke-SqlPlus "ALTER PLUGGABLE DATABASE $pdbName OPEN;"
        Write-Log $out.Trim()
        # ORA-65019 = PDB ist bereits offen -> kein Fehler
        $err = Get-SqlError $out @("ORA-65019")
        if ($err) { throw $err }
        $tray.ShowBalloonTip(2000, "PDB", "$pdbName geöffnet.", [System.Windows.Forms.ToolTipIcon]::Info)
    } catch {
        Write-Log "FEHLER: $_"
        $tray.ShowBalloonTip(4000, "PDB", "Öffnen fehlgeschlagen - siehe Log.", [System.Windows.Forms.ToolTipIcon]::Error)
    }
    Update-Status
})

$pdbCloseBtn.Add_Click({
    Write-Log "Schließe PDB $pdbName..."
    try {
        $out = Invoke-SqlPlus "ALTER PLUGGABLE DATABASE $pdbName CLOSE IMMEDIATE;"
        Write-Log $out.Trim()
        # ORA-65020 = PDB ist bereits geschlossen -> kein Fehler
        $err = Get-SqlError $out @("ORA-65020")
        if ($err) { throw $err }
        $tray.ShowBalloonTip(2000, "PDB", "$pdbName geschlossen.", [System.Windows.Forms.ToolTipIcon]::Warning)
    } catch {
        Write-Log "FEHLER: $_"
        $tray.ShowBalloonTip(4000, "PDB", "Schließen fehlgeschlagen - siehe Log.", [System.Windows.Forms.ToolTipIcon]::Error)
    }
    Update-Status
})

# ============================================================
# ============================================================
# MINIMIZE TO TRAY
# ============================================================
$form.Add_Resize({
    if ($form.WindowState -eq "Minimized") {
        $form.Hide()
        $tray.ShowBalloonTip(1000, "Oracle DB Control Center", "Läuft im Tray weiter.", [System.Windows.Forms.ToolTipIcon]::Info)
    }
})

$tray.Add_DoubleClick({
    $form.Show()
    $form.WindowState = "Normal"
    $form.Activate()
})

$form.Add_FormClosing({
    $tray.Visible = $false
    $statusTimer.Stop()
})

# ============================================================
# AUTO-REFRESH (Status alle 15 s aktualisieren)
# ============================================================
$statusTimer = New-Object System.Windows.Forms.Timer
$statusTimer.Interval = 15000
$statusTimer.Add_Tick({ Update-Status })
$statusTimer.Start()

# ============================================================
# STARTUP
# ============================================================
Write-Log "Oracle 21c DB Control Center gestartet."
Write-Log "CDB: $cdbName  |  PDB: $pdbName  |  Port: 1521"
Write-Log "Lese aktuellen Status..."

try {
    Update-Status
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Fehler beim Start:`n`n$($_.Exception.Message)",
        "Startfehler",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
}

Write-Log "Bereit."

[System.Windows.Forms.Application]::Run($form)
