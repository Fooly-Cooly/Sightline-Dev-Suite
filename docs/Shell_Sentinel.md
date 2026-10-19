# Sightline DevSuite | Shell Sentinel

**Shell Sentinel** is a real-time Windows shell event monitoring and logging utility. By registering a system-wide shell hook, this tool intercepts, parses, and displays low-level operating system events—such as window creation, destruction, activation, flashing, and multimedia hardware key presses (`APPCOMMAND` signals). 

This tool is designed specifically for AutoHotkey developers to profile window behaviors, identify elusive window classes, capture process details instantly, and debug hardware macro mappings as they occur.

---

## Key Features

- **Real-Time Shell Hook Monitoring:** Traps system-wide window states and hardware messaging through native Windows API calls (`RegisterShellHookWindow`).
- **Deep Process Profiling:** Captures and displays the Window Handle (`hWnd`), Title, Window Class (`ahk_class`), Process Name (e.g., `chrome.exe`), and Process ID (`PID`) simultaneously.
- **Hardware & Multimedia Macro Sniffer:** Decodes complex `APPCOMMAND` bitmasks into human-readable strings (e.g., volume adjustments, browser navigation, media keys).
- **Streamed Live Logging:** Features a persistent GUI checkbox toggle to stream captured events continuously to a local UTF-8 encoded text file (`shell_sentinel.log`).
- **Responsive Layout:** Includes dynamic GUI resizing logic that stretches and scales the internal tracking terminal seamlessly.
- **Minimize to Tray:** Minimizing or closing the window tucks the utility into the Windows system tray rather than terminating it, ensuring uninterrupted background data capture. Single-click on the tray icon restores the window instantly.

---

## Headless CLI Usage (AHKv2 Flagship)

When invoked with command-line flags, `Shell_Sentinel.exe` runs headlessly without creating a GUI window, outputting captured shell events as text or **Newline-Delimited JSON (NDJSON)** to `stdout`.

### CLI Options

| Option | Shorthand | Description | Default |
| :--- | :--- | :--- | :--- |
| `--json` | `-j` | Output streaming events as Line-Delimited JSON (NDJSON) | Plain text stream |
| `--timeout <sec>` | `-t` | Monitor for $N$ seconds, then exit cleanly | Continuous (`0`) |
| `--count <num>` | `-c` | Exit after capturing $N$ events | Continuous (`0`) |
| `--events <list>` | `-e` | Comma-separated filter: `create,destroy,activate,flash,appcommand` | All events |
| `--filter <text>` | `-f` | Filter by process name, window title, class, or PID | None |
| `--out <path>` | `-o` | Stream events simultaneously to log file | None |
| `--help` | `-h` | Display help and exit | |

### Sample Commands

```powershell
# Listen for 10 seconds and return window creation/destruction events in NDJSON
Shell_Sentinel.exe -j -t 10 -e create,destroy

# Wait until exactly 1 window activation occurs, then exit
Shell_Sentinel.exe --json --count 1 --events activate

# Monitor multimedia macro keys and log to a file
Shell_Sentinel.exe -e appcommand -o macro_keys.log
```

### NDJSON Output Schema

```json
{"timestamp":"2026-10-18T23:30:12","eventCode":1,"eventName":"HSHELL_WINDOWCREATED","hwnd":"0x00040182","title":"Untitled - Notepad","class":"Notepad","process":"notepad.exe","pid":14800}
{"timestamp":"2026-10-18T23:30:15","eventCode":4,"eventName":"HSHELL_WINDOWACTIVATED","hwnd":"0x00040182","title":"Untitled - Notepad","class":"Notepad","process":"notepad.exe","pid":14800}
```

---

## Captured Shell Events

| Event Code | Shell Message Identifier | Description |
| :--- | :--- | :--- |
| **1** | `HSHELL_WINDOWCREATED` | A top-level window has been created. |
| **2** | `HSHELL_WINDOWDESTROYED` | A top-level window is about to be destroyed. |
| **3** | `HSHELL_ACTIVATESHELLWINDOW` | The shell application window should be activated. |
| **4** | `HSHELL_WINDOWACTIVATED` | Activation has switched to a different top-level window. |
| **5** | `HSHELL_GETMINRECT` | A window is minimizing or maximizing (rect coordinates requested). |
| **6** | `HSHELL_REDRAW` | A window has changed its title, icon, or flashing state. |
| **7** | `HSHELL_TASKMAN` | The task list / Task Manager is being invoked. |
| **8** | `HSHELL_LANGUAGE` | The language or keyboard layout input dialect has changed. |
| **9** | `HSHELL_SYSMENU` | The accessibility system menu has been accessed. |
| **10** | `HSHELL_ENDTASK` | The user has requested an application force-close/end task. |
| **11** | `HSHELL_ACCESSIBILITYSTATE` | A state change has occurred in Windows Accessibility features. |
| **12** | `HSHELL_APPCOMMAND` | A multimedia, browser, or specific hardware macro key was triggered. |
| **13** | `HSHELL_WINDOWREPLACED` | A window is replacing an existing window. |
| **14** | `HSHELL_WINDOWREPLACING` | A window is being replaced by another window. |
| **32772** | `HSHELL_RUDEAPPACTIVATED` | An application forced itself to the foreground ("Rude" activation). |
| **32774** | `HSHELL_FLASH` | A background window is flashing on the taskbar to attract attention. |

---

## Intercepted AppCommands (`Event 12`)

When an `HSHELL_APPCOMMAND` event is processed, the script strips the higher word sequence bitmask `(lP >> 16) & 0xFFFF` to log precise hardware keys, including:
- **Audio Interface:** `VOLUME_MUTE`, `VOLUME_DOWN`, `VOLUME_UP`, `MICROPHONE_VOLUME_MUTE`, `BASS_BOOST`.
- **Media Deck:** `MEDIA_PLAY_PAUSE`, `MEDIA_STOP`, `MEDIA_NEXTTRACK`, `MEDIA_PREVIOUSTRACK`.
- **Navigation Controls:** `BROWSER_BACKWARD`, `BROWSER_FORWARD`, `BROWSER_REFRESH`, `BROWSER_STOP`, `BROWSER_SEARCH`, `BROWSER_HOME`.
- **System Actions:** `LAUNCH_MAIL`, `LAUNCH_APP1`, `LAUNCH_APP2`, `HELP`, `FIND`, `NEW`, `OPEN`, `SAVE`, `PRINT`, `COPY`, `PASTE`, `UNDO`.

---

## System Tray & Background Monitoring

As a **Sentinel** utility, Shell Sentinel maintains an active presence in the system tray:
- **Minimize / Close to Tray:** Clicking the minimize button or the window close button hides the window to the system notification area without stopping shell hooks.
- **Single-Click Restore:** Clicking the tray icon immediately brings the utility back to focus.
- **Tray Menu Actions:** Right-click the tray icon to quickly show the GUI, clear the event log, or exit the application completely.

---

## Integration Notes for DevTools Suite Compilation

- **No Cross-Talk Interferences:** This component utilizes a targeted window message registration `DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")`. It safe-hooks directly into its own instance window handle without impacting other modules running in the same thread.
- **Unified Modular Design:** Designed to be easily containerized. If building into a multi-tabbed suite wrapper later, the `ShellMessages` callback function can be detached and redirected to append to a shared custom object or universal logging array.

