# Sightline DevSuite | Hardware Sentinel

**Hardware Sentinel** is a real-time hardware abstraction layer debugger and peripheral monitor. Utilizing the Windows `WM_DEVICECHANGE` message hook and kernel device registration APIs (`RegisterDeviceNotification`), it detects, inspects, and logs physical and virtual hardware events—including USB plug/unplug cycles, audio device changes, and display adapter shifts.

Coupled with a deep `setupapi.dll` enumerator, it provides both an instant static snapshot of all connected motherboard devices and a live streaming log of peripheral state changes.

---

## Key Features

- **Real-Time Live Device Monitoring:** Seamlessly hooks into `RegisterDeviceNotification` to track physical peripheral updates as they occur on the kernel device tree.
- **Dual Output Layout:** Combines a full hardware inventory snapshot (upper pane) with an active event trigger terminal (lower pane).
- **Deep SetupAPI Inspection:** Interrogates Windows `setupapi.dll` to read Class GUIDs, Friendly Descriptions, Device Instance IDs, and OEM Service Drivers.
- **Streamed Live Logging:** Features a persistent GUI checkbox toggle to stream captured events continuously to a local UTF-8 encoded text file (`hardware_sentinel.log`).
- **Debounced Rescan:** Automatically collapses rapid peripheral insertion storms (e.g. multi-endpoint composite USB devices) into a single clean inventory refresh.
- **Minimize to Tray:** Minimizing or closing the window tucks the utility into the Windows system tray rather than terminating it, ensuring background hardware tracking is uninterrupted. Single-click or double-click restores the GUI instantly.

---

## Headless CLI Usage (AHKv2 Flagship)

When invoked with command-line flags, `Hardware_Sentinel.exe` executes headlessly in either **Snapshot Mode** (dumping current hardware inventory) or **Listen Mode** (monitoring real-time `WM_DEVICECHANGE` events).

### CLI Options

| Option | Shorthand | Description | Default |
| :--- | :--- | :--- | :--- |
| `--json` | `-j` | Output results as structured JSON (or NDJSON in listen mode) | Text table |
| `--snapshot` | `-s` | Dump current hardware device inventory and exit immediately | Enabled by default |
| `--listen` | `-l` | Listen for real-time hardware changes (`WM_DEVICECHANGE`) | Snapshot only |
| `--timeout <sec>` | `-t` | Listen for $N$ seconds, then exit cleanly | Continuous (`0`) |
| `--count <num>` | `-c` | Exit after capturing $N$ hardware events | Continuous (`0`) |
| `--filter <text>` | `-f` | Filter devices by name, description, or instance ID | None |
| `--help` | `-h` | Display help and exit | |

### Sample Commands

```powershell
# Dump all connected USB devices in structured JSON
Hardware_Sentinel.exe --snapshot --json --filter "USB"

# Query Realtek audio controllers and endpoints
Hardware_Sentinel.exe -s -j -f "Realtek"

# Listen for 15 seconds to see if any peripherals are plugged in or unplugged
Hardware_Sentinel.exe --listen --timeout 15 --json
```

### Snapshot JSON Schema

```json
[
  {
    "description": "Realtek PCIe GbE Family Controller",
    "displayName": "Realtek PCIe GbE Family Controller",
    "instanceId": "PCI\\VEN_10EC&DEV_8168&SUBSYS_E0001458&REV_15\\1F77FFD35ED8000000"
  }
]
```

### Live Event NDJSON Schema

```json
{"timestamp":"2026-10-18T23:35:10","eventCode":"0x8000","eventName":"DBT_DEVICEARRIVAL","devicePath":"\\\\?\\USB#VID_0781&PID_5583#4C531001#{a5dcbf10-6530-11d2-901f-00c04fb951ed}"}
```

---

## Intercepted Hardware Events

| Event Code | Event Identifier | Description |
| :--- | :--- | :--- |
| **0x0007** | `DBT_DEVNODES_CHANGED` | The OS refreshed hardware device nodes. |
| **0x8000** | `DBT_DEVICEARRIVAL` | A device or peripheral has been plugged in and initialized. |
| **0x8004** | `DBT_DEVICEREMOVECOMPLETE` | A device or peripheral was unplugged or removed. |

---

## System Tray & Background Monitoring

As a **Sentinel** utility, Hardware Sentinel maintains an active presence in the system tray:
- **Minimize / Close to Tray:** Clicking the minimize button or the window close button hides the window to the system notification area without stopping device hooks.
- **Single-Click Restore:** Clicking the tray icon immediately brings the utility back to focus.
- **Tray Menu Actions:** Right-click the tray icon to quickly show the GUI, trigger an inventory refresh, clear the event log, or exit the application completely.