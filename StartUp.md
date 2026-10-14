# StartUp: Administrations-Tools Framework

Dieses Dokument dient als Design- und Architektur-Vorlage für die Entwicklung weiterer Administrations-Tools innerhalb des Projekts. Es definiert die visuellen Standards, das technische Framework und die Interaktionsmuster.

## 1. Architektur & Tech-Stack

### Basis-Technologie
- **Sprache:** PowerShell (pwsh)
- **UI Framework:** .NET `System.Windows.Forms` und `System.Drawing`
- **Distribution:** Konvertierung des `.ps1` Scripts in eine Standalone-EXE mittels `ps2exe`.

### Strukturmodell
Jedes Tool sollte folgendem Aufbau folgen:
1. **Helper-Funktionen:** Globale Utilities (z.B. Grafik-Pfade, API-Wrapper, SQL-Executors).
2. **Konfiguration:** Definition aller Pfade, Dienstnamen und Credentials am Anfang des Scripts.
3. **Splash-Screen:** Ein kurzer, minimalistischer Ladebildschirm zur Initialisierung.
4. **Hauptfenster:** Definition der Form-Eigenschaften (FixedSingle, CenterScreen, Dark-Theme).
5. **Komponenten-Hierarchie:**
   - `Status-Panel`: Schnelle visuelle Übersicht (Status-Dots).
   - `Log-Fenster`: Konsolen-ähnliche Ausgabe (`Consolas`-Font).
   - `Aktions-Bereich`: Gruppierte Buttons in Panels.
6. **Tray-Integration:** Implementierung eines `NotifyIcon` für Hintergrundbetrieb und Minimieren in das Tray.

---

## 2. Design & Style (Visual Guide)

### Farbschema (Dark Theme)
| Element | Farbe (RGB) | Hex / Beschreibung |
| :--- | :--- | :--- |
| **Haupt-Hintergrund** | `(30, 30, 30)` | Dunkles Grau |
| **Panel-Hintergrund** | `(45, 45, 48)` | Mittleres Grau (Abgrenzung) |
| **Log-Fenster** | `(18, 18, 18)` | Fast Schwarz |
| **Akzent-Farbe (Buttons)** | `(153, 0, 51)` | Deep Red / Burgundy |
| **Primärer Text** | `(255, 255, 255)` | Weiß |
| **Sekundärer Text** | `(192, 192, 192)` | Silver |

### Status-Indikatoren
- **Grün `(60, 200, 80)`**: Aktiv / Gestartet / OK.
- **Grau `(128, 128, 128)`**: Inaktiv / Gestoppt / Unbekannt.
- **Gelb/Orange `(240, 180, 0)`**: Teilweise aktiv / Warnung / Mount-Status.

### Typografie
- **UI-Elemente:** `Segoe UI` (Bold für Header und Buttons).
- **Log-Ausgabe:** `Consolas` (Monospaced für bessere Lesbarkeit von technischen Daten).

---

## 3. Komponenten-Design (Glass-Style)

Buttons folgen dem **"Glass-Design"**-Prinzip, um eine moderne Optik in Windows Forms zu erreichen.

### Visuelle Merkmale
- **Abgerundete Ecken:** Verwendung von `GraphicsPath` statt Standard-Rechtecken.
- **Gradient Shine:** Eine lineare Gradienten-Überlagerung in der oberen Hälfte des Buttons.
- **Zustands-Feedback:**
  - **Normal:** Basis-Farbe + Shine.
  - **Hover:** Zusätzlicher heller Glow-Effekt (weißes Overlay).
  - **Pressed:** Abdunklung des gesamten Buttons durch ein dunkles Overlay.

### Implementierungs-Pattern
Die Logik wird über ein `PSCustomObject` im `.Tag`-Property des Buttons gesteuert und im `Paint`-Event gerendert.

---

## 4. Animationen & Interaktion

### Flow-Animationen
- **Start-Sequenz:** Splash Screen $\rightarrow$ `Start-Sleep (1.5s)` $\rightarrow$ Hauptfenster.
- **Status-Update:** Dynamische Farbänderung der Status-Dots und Aktivierung/Deaktivierung von Buttons basierend auf dem Systemzustand (`Update-Status` Funktion).

### Interaktions-Feedback
- **Visuelles Feedback:** Unmittelbare Reaktion auf Mouse-Events (`MouseEnter`, `MouseLeave`, `MouseDown`, `MouseUp`) via `.Invalidate()`.
- **Asynchrone Benachrichtigungen:** Nutzung von `ShowBalloonTip` im System-Tray, um den Nutzer über den Abschluss von Hintergrundprozessen zu informieren, ohne den Workflow im Hauptfenster zu stören.

---

## 5. Build-Pipeline
1. Icon (`.ico`) erstellen.
2. Script in `Start-ToolName-GUI.ps1` entwickeln.
3. `Build-ToolName-EXE.ps1` nutzen, um mittels `ps2exe` die finale Binary zu erzeugen.
4. Icon und EXE im selben Verzeichnis distribuieren.
