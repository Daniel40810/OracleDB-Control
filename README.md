<div align="center">

<img src="OracleDB-Control.png" width="150" alt="Oracle DB Control Center Icon">

# 🛢️ Oracle 21c DB Control Center

**Kleines Windows-Tool zum Starten, Stoppen und Überwachen von Oracle 21c – mit Tray-Icon und 🏅 Goldkante**

![Windows](https://img.shields.io/badge/Windows-0078D4?style=for-the-badge&logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell_5.1-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![Oracle](https://img.shields.io/badge/Oracle_21c-F80000?style=for-the-badge&logo=oracle&logoColor=white)
![Akzent](https://img.shields.io/badge/Akzent-990033?style=for-the-badge)
![Gold](https://img.shields.io/badge/Gold_Edge-FFC95C?style=for-the-badge)

</div>

---

## ✨ Funktionen

| | Funktion | Beschreibung |
|:-:|:--|:--|
| 📊 | **Statusanzeige** | DB, Listener und PDB auf einen Blick, aktualisiert sich alle 15 s |
| ▶️ | **DB starten** | Startet den Dienst und öffnet die PDB, wiederholt bis die Instanz bereit ist |
| ⏹️ | **DB stoppen** | `SHUTDOWN IMMEDIATE`, mit Sicherheitsabfrage |
| 🔄 | **DB Restart** | Herunterfahren, Dienst neu starten, PDB wieder öffnen |
| 📡 | **Listener** | Starten und Stoppen des TNS-Listeners |
| 🧩 | **PDB öffnen / schließen** | `ALTER PLUGGABLE DATABASE` |
| 🔔 | **Tray-Integration** | Minimieren ins Tray, Benachrichtigungen bei Erfolg und Fehler |

## 🚦 Status-Farben

| Farbe | Bedeutung |
|:-:|:--|
| 🟢 | gestartet / PDB `READ WRITE` |
| 🟡 | PDB `MOUNTED` |
| ⚪ | gestoppt / geschlossen / unbekannt |

## 📁 Dateien

| Datei | Zweck |
|:--|:--|
| `Start-OracleDB-GUI.ps1` | 🧠 Hauptskript (GUI) |
| `Build-OracleDB-EXE.ps1` | 🏗️ Erstellt `OracleDB-Control.exe` mit ps2exe |
| `OracleDB-Control.ico` | 🎨 Icon, Größen 16 bis 256 px |
| `OracleDB-Control.png` | 🖼️ Vorschaubild für dieses README |
| `Create-Shortcut.ps1` | 🔗 Legt die Desktop-Verknüpfung an |
| `Desktop-Verknuepfung.bat` | 🖱️ Doppelklick: Verknüpfung, optional EXE-Build |
| `21C.ico` | 🗂️ altes Icon, wird nicht mehr genutzt |
| `.gitattributes` / `.gitignore` | 🧹 Git-Einstellungen |

## 🚀 Schnellstart

1. **`Desktop-Verknuepfung.bat`** doppelklicken, dann entsteht die Verknüpfung auf dem Desktop.
2. Optional mit **J** die EXE neu bauen, damit das neue Icon auch in der Datei steckt. Die App muss dafür geschlossen sein.
3. Über die Verknüpfung starten.

> 💡 Dienste steuern braucht in der Regel Administratorrechte. Die EXE daher „Als Administrator ausführen“ starten.

## ⚙️ Konfiguration

Die Einstellungen stehen oben in `Start-OracleDB-GUI.ps1`:

| Variable | Standardwert | Bedeutung |
|:--|:--|:--|
| `$oracleService` | `OracleServiceORCL` | Oracle-Datenbankdienst |
| `$listenerService` | `OracleOraDB21Home1TNSListener` | TNS-Listener-Dienst |
| `$oracleHome` | `C:\Oracle\213000_db_home` | Oracle-Installation (für `sqlplus.exe`) |
| `$cdbName` | `ORCL` | Container-Datenbank |
| `$pdbName` | `PDBORCL` | Pluggable Database |

## 🔐 Anmeldung

- **Standard:** OS-Authentifizierung über `sqlplus / as sysdba`. Der Windows-Benutzer muss in der Gruppe `ORA_DBA` sein.
- **Fallback:** Falls das nicht klappt, wird die Umgebungsvariable `ORACLE_SYSDBA_PASS` genutzt:

```powershell
setx ORACLE_SYSDBA_PASS "dein-passwort"
```

> 🔒 Passwörter gehören nicht ins Repository. Das Skript enthält keines.

## 🏗️ EXE bauen

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\Build-OracleDB-EXE.ps1
```

Das Skript installiert bei Bedarf das Modul `ps2exe` und bettet `OracleDB-Control.ico` in die EXE ein.

## 📋 Voraussetzungen

- 🪟 Windows
- 🛢️ Oracle 21c mit den Diensten `OracleServiceORCL` und dem TNS-Listener
- 💻 PowerShell 5.1 (Windows-Standard)
- 📦 Internetzugang für den ersten Build (ps2exe)

---

<div align="center">

💛 *Goldkante für alle Fälle* 💛

</div>
