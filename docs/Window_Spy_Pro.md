# Sightline DevSuite | Window Spy Pro

An essential utility for script developers, system debuggers, and AI coding agents to capture, filter, and audit active window metrics. `Window Spy Pro` allows you to instantly scan open applications, exposing hidden hooks, process names, window classes, titles, PIDs, hex HWND handles, and bounding coordinates.

It offers **Dual-Mode Execution**: launch normally for the interactive desktop GUI, or invoke via command-line arguments for headless automation and structured JSON dumps.

---

## Features

* **Dual GUI & Headless CLI:** Operates as a native desktop GUI by default, or runs headlessly with zero UI flicker when passed CLI flags.
* **Visibility Filtering:** Dynamically toggle between viewing **Visible** windows only, background **Hidden** windows, or **All** windows.
* **Instant Filtering:** Filter on the fly by window title, executable name, PID, Window Class, or Hex HWND.
* **Structured JSON Dumps:** Flagship edition exports machine-readable JSON with exact spatial coordinates (`x`, `y`, `w`, `h`), cloaked state, and minimized state.
* **On-Demand Snapshot Logging:** In GUI mode, click **Log to File** to export the current snapshot directly to `window_spy_pro.log`.
* **Standard Desktop Window:** Operates as a clean desktop utility with taskbar presence and titlebar icon, leaving the system tray uncluttered.

---

## Headless CLI Usage (AHKv2 Flagship)

When invoked with command-line flags, `Window_Spy_Pro.exe` attaches directly to the calling console, prints results to `stdout`, and exits cleanly.

### CLI Options

| Option | Shorthand | Description | Default |
| :--- | :--- | :--- | :--- |
| `--json` | `-j` | Output results as formatted JSON | Text table |
| `--scope <mode>` | `-s` | Filter scope: `visible`, `hidden`, `all` | `visible` |
| `--filter <text>`| `-f` | Filter by title, class, process name, or hex HWND | None |
| `--pid <pid>` | `-p` | Filter by specific Process ID | None |
| `--include-cloaked` | | Include Windows 10/11 cloaked windows | `false` |
| `--help` | `-h` | Display help and exit | |

### Sample Commands

```powershell
# Get all visible windows in structured JSON
Window_Spy_Pro.exe -j -s visible

# Find all windows belonging to Chrome or VS Code
Window_Spy_Pro.exe --json --filter "Chrome"

# Inspect all windows (including hidden) owned by PID 14208
Window_Spy_Pro.exe -j -s all -p 14208
```

### JSON Schema

```json
[
  {
    "hwnd": "0x000502BE",
    "title": "Sightline DevSuite - Visual Studio Code",
    "class": "Chrome_WidgetWin_1",
    "process": "Code.exe",
    "pid": 14208,
    "visible": true,
    "minimized": false,
    "cloaked": false,
    "rect": {
      "x": 100,
      "y": 80,
      "w": 1400,
      "h": 900
    }
  }
]
```

---

## GUI Usage

1. Launch `Window_Spy_Pro.exe` or `src/Window_Spy_Pro.ahk`.
2. Select your desired visibility scope using the **Scope** dropdown (`Visible`, `Hidden`, `All`).
3. Type into the **Search** box to isolate a specific app, class, or PID.
4. Press `F5` or click **Refresh** at any time to re-scan.
5. Click **Log to File** to export the current snapshot to `window_spy_pro.log`.