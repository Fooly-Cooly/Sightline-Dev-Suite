# Sightline DevSuite | Process Spy Pro

A streamlined process exploration and command-line audit utility for human developers and autonomous AI agents. `Process Spy Pro` queries the Windows Management Instrumentation (WMI) engine to extract launch parameters, execution arguments, binary paths, UAC elevation status, and memory metrics for active processes.

It offers **Dual-Mode Execution**: run interactively as a desktop GUI with search and copy tools, or invoke via command-line flags for instant, headless JSON process audits.

---

## Features

* **Dual GUI & Headless CLI:** Works as a responsive desktop utility or executes headlessly via terminal flags with clean `stdout` exit codes.
* **WMI Command-Line Extraction:** Interrogates `Win32_Process` to retrieve exact command-line arguments and parameters that Task Manager obscures.
* **UAC Elevation Detection:** Checks process token privileges to determine whether a process is running elevated (useful for diagnosing UIPI automation blocks).
* **PSAPI Memory Metrics:** Optional `--memory` flag queries working set RAM and pagefile metrics directly from kernel tables via PSAPI.
* **Instant Filtering:** Real-time search filtering matching process names, PIDs, executable paths, or command-line parameters.
* **On-Demand Snapshot Logging:** Click **Log to File** in GUI mode to export a point-in-time snapshot to `process_spy_pro.log`.

---

## Headless CLI Usage (AHKv2 Flagship)

When invoked with command-line flags, `Process_Spy_Pro.exe` attaches directly to the calling console, prints results to `stdout`, and exits cleanly.

### CLI Options

| Option | Shorthand | Description | Default |
| :--- | :--- | :--- | :--- |
| `--json` | `-j` | Output results as structured JSON | Text table |
| `--filter <text>` | `-f` | Filter by process name, command line, path, or PID | None |
| `--pid <pid>` | `-p` | Target a single specific Process ID | None |
| `--memory` | `-m` | Include working set and pagefile RAM metrics (MB) | `false` |
| `--help` | `-h` | Display help and exit | |

### Sample Commands

```powershell
# Get all running Python or Node processes in JSON format
Process_Spy_Pro.exe --json --filter "python"

# Inspect exact launch arguments and RAM footprint of PID 12260
Process_Spy_Pro.exe -j -m -p 12260

# Search for processes launched with a specific parameter
Process_Spy_Pro.exe --filter "--port"
```

### JSON Schema

```json
[
  {
    "name": "pwsh.exe",
    "pid": 12260,
    "commandLine": "\"C:\\Program Files\\PowerShell\\7\\pwsh.exe\" -NoExit",
    "path": "C:\\Program Files\\PowerShell\\7\\pwsh.exe",
    "elevated": false,
    "memory": {
      "workingSetMB": 68.73,
      "pagefileMB": 56.64
    }
  }
]
```

---

## GUI Usage

1. Launch `Process_Spy_Pro.exe` or `src/Process_Spy_Pro.ahk`.
2. The table displays running processes with accessible command-line strings.
3. Type into the **Filter** box to narrow down executables, PIDs, or argument keywords.
4. Double-click any row to copy its command line to your clipboard (or right-click for the context menu).
5. Click **Log to File** to export the filtered snapshot to `process_spy_pro.log`.
6. Press `F5` to re-query the WMI process table.
