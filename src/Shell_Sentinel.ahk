;================================================================================;
;   Shell Sentinel (AHKv2)                                                       ;
;   Real-time system shell event monitor & APPCOMMAND macro sniffer              ;
;   Supports both Interactive GUI and Headless CLI (--json, --timeout, --count)  ;
;   Copyright (C) 2026  Fooly Cooly https://github.com/Fooly-Cooly               ;
;   Licensed with GPL v3 https://www.gnu.org/licenses/gpl-3.0.txt                ;
;================================================================================;

;@Ahk2Exe-ConsoleApp
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()

; --- Pre-allocated Maps & State Globals ---
global cliConfig := {}
global staticMsgNames := Map(
    1, "HSHELL_WINDOWCREATED",
    2, "HSHELL_WINDOWDESTROYED",
    3, "HSHELL_ACTIVATESHELLWINDOW",
    4, "HSHELL_WINDOWACTIVATED",
    5, "HSHELL_GETMINRECT",
    6, "HSHELL_REDRAW",
    7, "HSHELL_TASKMAN",
    8, "HSHELL_LANGUAGE",
    9, "HSHELL_SYSMENU",
    10, "HSHELL_ENDTASK",
    11, "HSHELL_ACCESSIBILITYSTATE",
    12, "HSHELL_APPCOMMAND",
    13, "HSHELL_WINDOWREPLACED",
    14, "HSHELL_WINDOWREPLACING",
    32772, "HSHELL_RUDEAPPACTIVATED", ; 0x8004
    32774, "HSHELL_FLASH"              ; 0x8006
)

global staticAppCommands := Map(
    1, "APPCOMMAND_BROWSER_BACKWARD", 2, "APPCOMMAND_BROWSER_FORWARD", 3, "APPCOMMAND_BROWSER_REFRESH",
    4, "APPCOMMAND_BROWSER_STOP", 5, "APPCOMMAND_BROWSER_SEARCH", 6, "APPCOMMAND_BROWSER_FAVORITES",
    7, "APPCOMMAND_BROWSER_HOME", 8, "APPCOMMAND_VOLUME_MUTE", 9, "APPCOMMAND_VOLUME_DOWN",
    10, "APPCOMMAND_VOLUME_UP", 11, "APPCOMMAND_MEDIA_NEXTTRACK", 12, "APPCOMMAND_MEDIA_PREVIOUSTRACK",
    13, "APPCOMMAND_MEDIA_STOP", 14, "APPCOMMAND_MEDIA_PLAY_PAUSE", 15, "APPCOMMAND_LAUNCH_MAIL",
    16, "APPCOMMAND_LAUNCH_MEDIA_SELECT", 17, "APPCOMMAND_LAUNCH_APP1", 18, "APPCOMMAND_LAUNCH_APP2",
    19, "APPCOMMAND_BASS_DOWN", 20, "APPCOMMAND_BASS_BOOST", 21, "APPCOMMAND_BASS_UP",
    22, "APPCOMMAND_TREBLE_DOWN", 23, "APPCOMMAND_TREBLE_UP", 24, "APPCOMMAND_MICROPHONE_VOLUME_MUTE",
    25, "APPCOMMAND_MICROPHONE_VOLUME_DOWN", 26, "APPCOMMAND_MICROPHONE_VOLUME_UP", 27, "APPCOMMAND_HELP",
    28, "APPCOMMAND_FIND", 29, "APPCOMMAND_NEW", 30, "APPCOMMAND_OPEN", 31, "APPCOMMAND_CLOSE",
    32, "APPCOMMAND_SAVE", 33, "APPCOMMAND_PRINT", 34, "APPCOMMAND_UNDO", 35, "APPCOMMAND_REDO",
    36, "APPCOMMAND_COPY", 37, "APPCOMMAND_CUT", 38, "APPCOMMAND_PASTE", 39, "APPCOMMAND_REPLY_TO_MAIL",
    40, "APPCOMMAND_FORWARD_MAIL", 41, "APPCOMMAND_SEND_MAIL", 42, "APPCOMMAND_SPELL_CHECK",
    43, "APPCOMMAND_DICTATE_OR_COMMAND_CONTROL_TOGGLE", 44, "APPCOMMAND_MIC_ON_OFF_TOGGLE",
    45, "APPCOMMAND_CORRECTION_LIST"
)

; --- Pre-allocated State Globals ---
global MainGui := ""
global LogCheckbox := ""
global PauseCheckbox := ""
global MsgEdit := ""
global EventCountText := ""
global TotalEvents := 0

; --- Main Entry Point ---
if (A_Args.Length > 0) {
    RunShellSentinelCLI(A_Args)
} else {
    RunShellSentinelGUI()
}

; ==============================================================================
; Interactive GUI Mode
; ==============================================================================
RunShellSentinelGUI() {
    global MainGui, LogCheckbox, PauseCheckbox, MsgEdit, EventCountText, TotalEvents
    
    ; Free any attached console in GUI mode so no console window remains
    DllCall("FreeConsole")

    ; Set Tray Icon
    iconPath := FileExist(A_ScriptDir "\..\assets\Shell_Sentinel.ico") ? A_ScriptDir "\..\assets\Shell_Sentinel.ico"
              : FileExist(A_ScriptDir "\assets\Shell_Sentinel.ico") ? A_ScriptDir "\assets\Shell_Sentinel.ico"
              : FileExist(A_ScriptDir "\..\assets\icon.ico") ? A_ScriptDir "\..\assets\icon.ico"
              : FileExist(A_ScriptDir "\assets\icon.ico") ? A_ScriptDir "\assets\icon.ico" : ""
    if (iconPath != "")
        TraySetIcon(iconPath)

    ; GUI Setup
    MainGui := Gui("+Resize +MinSize520x340", "Shell Sentinel AHKv2")
    MainGui.MarginX := 10
    MainGui.MarginY := 10

    ; Top Controls Toolbar
    MainGui.SetFont("s9", "Segoe UI")
    LogCheckbox := MainGui.Add("Checkbox", "vLogToFile x10 y12", "Log to file (shell_sentinel.log)")
    PauseCheckbox := MainGui.Add("Checkbox", "x245 y12", "Pause Capture")
    BtnClearLog := MainGui.Add("Button", "x360 y8 w75 h24", "&Clear Log")
    EventCountText := MainGui.Add("Text", "x445 y12 w320 cGray Right", "Captured: 0 events")

    ; Terminal Output (Monospace)
    MainGui.SetFont("s9", "Consolas")
    MsgEdit := MainGui.Add("Edit", "vMsgs x10 y38 w780 h490 +ReadOnly +HScroll -Wrap")

    ; Tray Menu Setup (Sentinels minimize to tray)
    A_TrayMenu.Delete()
    A_TrayMenu.Add("&Show", (*) => ShowGui())
    A_TrayMenu.Add("&Clear Log", (*) => ClearGuiLog())
    A_TrayMenu.Add("E&xit Script", (*) => ExitApp())
    A_TrayMenu.Default := "&Show"
    A_TrayMenu.ClickCount := 1

    ; Event Bindings
    BtnClearLog.OnEvent("Click", (*) => ClearGuiLog())
    MainGui.OnEvent("Close", (*) => MainGui.Hide())
    MainGui.OnEvent("Size", GuiSizeHandler)

    ; Register Shell Hook for GUI
    DllCall("RegisterShellHookWindow", "Ptr", MainGui.Hwnd)
    MsgNum := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
    OnMessage(MsgNum, GUIShellMessages)

    ; Dynamic GUI Keyboard Shortcuts
    HotIfWinActive("ahk_id " MainGui.Hwnd)
    Hotkey("^l", (*) => ClearGuiLog(), "On")
    Hotkey("+Esc", (*) => ExitApp(), "On")
    HotIf()

    MainGui.Show("w800 h540")
}

ClearGuiLog() {
    global TotalEvents, MsgEdit, EventCountText
    if (IsObject(MsgEdit) && HasProp(MsgEdit, "Value")) {
        MsgEdit.Value := ""
        TotalEvents := 0
        if (IsObject(EventCountText))
            EventCountText.Text := "Captured: 0 events"
    }
}

GUIShellMessages(wP, lP, *) {
    global TotalEvents, MsgEdit, PauseCheckbox, LogCheckbox, EventCountText
    if (!IsObject(MsgEdit) || !HasProp(MsgEdit, "Hwnd"))
        return
        
    if (PauseCheckbox != "" && PauseCheckbox.Value)
        return
        
    Routine := staticMsgNames.Get(wP, "UNKNOWN_EVENT")
    LogOutput := Format("[{1}] Event: {2} ({3})", FormatTime(, "HH:mm:ss"), Routine, wP)
    
    switch wP {
        case 5: ; HSHELL_GETMINRECT
            LogOutput .= "`r`n`r`n"
            
        case 12: ; HSHELL_APPCOMMAND
            CmdNum := (lP >> 16) & 0xFFFF
            CmdName := staticAppCommands.Get(CmdNum, "UNKNOWN_COMMAND")
            LogOutput .= Format(" // Command: {1} ({2})`r`n`r`n", CmdName, CmdNum)
            
        default: ; Window events
            if DllCall("IsWindow", "Ptr", lP) {
                try {
                    WTitle := WinGetTitle("ahk_id " lP)
                    WClass := WinGetClass("ahk_id " lP)
                    WProcess := WinGetProcessName("ahk_id " lP)
                    WPID := WinGetPID("ahk_id " lP)
                    
                    LogOutput .= Format("`r`n  hWnd: {1}`r`n  Title: {2}`r`n  Class: {3}`r`n  Process: {4} (PID: {5})`r`n`r`n", lP, WTitle, WClass, WProcess, WPID)
                } catch {
                    LogOutput .= "`r`n  [Window target lost or restricted]`r`n`r`n"
                }
            } else {
                LogOutput .= "`r`n  [Target hWnd: " lP " no longer exists]`r`n`r`n"
            }
    }
    
    SendMessage(0x00B1, -2, -1,, MsgEdit.Hwnd)
    SendMessage(0x00C2, 0, StrPtr(LogOutput),, MsgEdit.Hwnd)
    SendMessage(0x0115, 7, 0,, MsgEdit.Hwnd)
    
    if (!IsSet(TotalEvents))
        TotalEvents := 0
    TotalEvents++
    EventCountText.Text := "Captured: " TotalEvents " events"
    
    if (LogCheckbox != "" && LogCheckbox.Value) {
        try FileAppend(LogOutput, "shell_sentinel.log", "UTF-8")
    }
}

ShowGui() {
    if (MainGui != "") {
        MainGui.Show()
        try WinRestore(MainGui.Hwnd)
        try WinActivate(MainGui.Hwnd)
    }
}

GuiSizeHandler(GuiObj, MinMax, Width, Height) {
    global MainGui, MsgEdit, EventCountText
    if (MinMax == -1) {
        MainGui.Hide()
        return
    }
        
    NewWidth  := Width - 20
    NewHeight := Height - 50
    if (IsObject(MsgEdit))
        MsgEdit.Move(,, NewWidth, NewHeight)
    if (IsObject(EventCountText))
        EventCountText.Move(Width - 330)
}

; ==============================================================================
; Headless CLI Engine
; ==============================================================================
ConsoleOut(text) => FileAppend(text, "*", "UTF-8")

RunShellSentinelCLI(args) {
    useJson := false
    timeoutSec := 0
    maxCount := 0
    eventFilter := ""
    filterText := ""
    outFile := ""
    
    i := 1
    while (i <= args.Length) {
        arg := args[i]
        switch StrLower(arg) {
            case "-h", "--help", "/?":
                PrintShellSentinelHelp()
                ExitApp(0)
            case "-j", "--json":
                useJson := true
            case "-t", "--timeout":
                if (i + 1 <= args.Length) {
                    i++
                    timeoutSec := Integer(args[i])
                }
            case "-c", "--count":
                if (i + 1 <= args.Length) {
                    i++
                    maxCount := Integer(args[i])
                }
            case "-e", "--events":
                if (i + 1 <= args.Length) {
                    i++
                    eventFilter := StrLower(args[i])
                }
            case "-f", "--filter":
                if (i + 1 <= args.Length) {
                    i++
                    filterText := StrLower(args[i])
                }
            case "-o", "--out":
                if (i + 1 <= args.Length) {
                    i++
                    outFile := args[i]
                }
            default:
                ConsoleOut("[ERROR] Unrecognized argument: " arg "`nUse --help for usage information.`n")
                ExitApp(1)
        }
        i++
    }
    
    cliConfig.useJson := useJson
    cliConfig.timeoutSec := timeoutSec
    cliConfig.maxCount := maxCount
    cliConfig.eventFilter := eventFilter
    cliConfig.filterText := filterText
    cliConfig.outFile := outFile
    cliConfig.capturedCount := 0
    
    ; Register shell hook directly on script message window
    DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)
    hookMsg := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
    OnMessage(hookMsg, CLIShellHookHandler)
    OnExit((*) => (DllCall("DeregisterShellHookWindow", "Ptr", A_ScriptHwnd), 0))
    
    if (!useJson) {
        ConsoleOut("================================================================================`n")
        ConsoleOut("Shell Sentinel (CLI Listener Active)`n")
        if (timeoutSec > 0)
            ConsoleOut(Format("Timeout: {1} seconds | ", timeoutSec))
        if (maxCount > 0)
            ConsoleOut(Format("Count Limit: {1} events | ", maxCount))
        if (eventFilter != "")
            ConsoleOut(Format("Events: {1} | ", eventFilter))
        if (filterText != "")
            ConsoleOut(Format("Filter: {1} | ", filterText))
        ConsoleOut("Press Ctrl+C to terminate`n")
        ConsoleOut("================================================================================`n`n")
    }
    
    startTime := A_TickCount
    durationMs := timeoutSec * 1000
    while (true) {
        Sleep(50)
        if (timeoutSec > 0 && (A_TickCount - startTime >= durationMs))
            break
        if (cliConfig.maxCount > 0 && cliConfig.capturedCount >= cliConfig.maxCount)
            break
    }
    ExitApp(0)
}

CLIShellHookHandler(wP, lP, *) {
    routineName := staticMsgNames.Get(wP, "UNKNOWN_EVENT")
    
    ; Event category filter check (create, destroy, activate, flash, appcommand)
    if (cliConfig.eventFilter != "") {
        matchedFilter := false
        f := cliConfig.eventFilter
        if (InStr(f, "create") && wP == 1)
            matchedFilter := true
        else if (InStr(f, "destroy") && wP == 2)
            matchedFilter := true
        else if (InStr(f, "activate") && (wP == 4 || wP == 32772))
            matchedFilter := true
        else if (InStr(f, "flash") && wP == 32774)
            matchedFilter := true
        else if (InStr(f, "appcommand") && wP == 12)
            matchedFilter := true
        else if (InStr(f, "redraw") && wP == 6)
            matchedFilter := true
            
        if (!matchedFilter)
            return
    }
    
    cmdName := ""
    cmdNum := 0
    wTitle := ""
    wClass := ""
    wProcess := ""
    wPID := 0
    hexHwnd := Format("0x{:08X}", lP)
    
    if (wP == 12) {
        cmdNum := (lP >> 16) & 0xFFFF
        cmdName := staticAppCommands.Get(cmdNum, "UNKNOWN_COMMAND")
    } else if (lP != 0 && DllCall("IsWindow", "Ptr", lP)) {
        try wTitle := WinGetTitle("ahk_id " lP)
        try wClass := WinGetClass("ahk_id " lP)
        try wProcess := WinGetProcessName("ahk_id " lP)
        try wPID := WinGetPID("ahk_id " lP)
    }
    
    ; Content substring filter check
    if (cliConfig.filterText != "") {
        ft := cliConfig.filterText
        if (!InStr(StrLower(wTitle), ft)
            && !InStr(StrLower(wClass), ft)
            && !InStr(StrLower(wProcess), ft)
            && !InStr(StrLower(cmdName), ft)
            && !InStr(String(wPID), ft)
            && !InStr(StrLower(hexHwnd), ft))
            return
    }
    
    timeStr := FormatTime(, "yyyy-MM-ddTHH:mm:ss")
    
    if (cliConfig.useJson) {
        evt := {
            timestamp: timeStr,
            eventCode: wP,
            eventName: routineName,
            hwnd: hexHwnd
        }
        if (wP == 12) {
            evt.commandNum := cmdNum
            evt.commandName := cmdName
        } else {
            evt.title := wTitle
            evt.class := wClass
            evt.process := wProcess
            evt.pid := wPID
        }
        
        jsonLine := JsonStringify(evt, -1) . "`n"
        ConsoleOut(jsonLine)
        if (cliConfig.outFile != "")
            try FileAppend(jsonLine, cliConfig.outFile, "UTF-8")
    } else {
        txt := Format("[{1}] {2} ({3}) | hWnd: {4}", FormatTime(, "HH:mm:ss"), routineName, wP, hexHwnd)
        if (wP == 12) {
            txt .= Format(" | Command: {1} ({2})", cmdName, cmdNum)
        } else if (wProcess != "" || wTitle != "") {
            txt .= Format(" | {1} (PID: {2}) | `"{3}`"", wProcess, wPID, wTitle)
        }
        txt .= "`n"
        ConsoleOut(txt)
        if (cliConfig.outFile != "")
            try FileAppend(txt, cliConfig.outFile, "UTF-8")
    }
    
    cliConfig.capturedCount++
    if (cliConfig.maxCount > 0 && cliConfig.capturedCount >= cliConfig.maxCount) {
        ExitApp(0)
    }
}

PrintShellSentinelHelp() {
    ConsoleOut("Sightline DevSuite | Shell Sentinel (AHKv2)`n")
    ConsoleOut("Usage: Shell_Sentinel.exe [OPTIONS]`n`n")
    ConsoleOut("Options:`n")
    ConsoleOut("  -j, --json               Output streaming events as Line-Delimited JSON (NDJSON)`n")
    ConsoleOut("  -t, --timeout <sec>      Monitor for N seconds, then exit cleanly`n")
    ConsoleOut("  -c, --count <num>        Exit after capturing N events`n")
    ConsoleOut("  -e, --events <list>      Filter by event type (create, destroy, activate, flash, appcommand)`n")
    ConsoleOut("  -f, --filter <text>      Filter by process name, title, class, or PID`n")
    ConsoleOut("  -o, --out <path>         Stream events simultaneously to log file`n")
    ConsoleOut("  -h, --help               Show this help message`n")
}

; ==============================================================================
; Lightweight JSON Engine
; ==============================================================================
class JBool {
    static True := { __isJsonBool: true, val: "true" }
    static False := { __isJsonBool: true, val: "false" }
}

JsonEscape(str) {
    str := StrReplace(str, "\", "\\")
    str := StrReplace(str, '"', '\"')
    str := StrReplace(str, "`n", "\n")
    str := StrReplace(str, "`r", "\r")
    str := StrReplace(str, "`t", "\t")
    return str
}

JsonStringify(val, indent := 0) {
    if IsObject(val) {
        if HasProp(val, "__isJsonBool")
            return val.val
            
        isArr := (val is Array)
        isMap := (val is Map)
        pad := ""
        Loop indent
            pad .= "  "
        nextPad := pad . "  "
        
        if isArr {
            if (val.Length == 0)
                return "[]"
            out := "["
            for idx, item in val {
                out .= (idx > 1 ? "," : "") . (indent >= 0 ? "`n" . nextPad : " ")
                out .= JsonStringify(item, indent >= 0 ? indent + 1 : -1)
            }
            out .= (indent >= 0 ? "`n" . pad : " ") . "]"
            return out
        } else {
            out := "{"
            first := true
            enumObj := isMap ? val : val.OwnProps()
            for k, v in enumObj {
                if (k == "__isJsonBool")
                    continue
                out .= (!first ? "," : "") . (indent >= 0 ? "`n" . nextPad : " ")
                out .= '"' . JsonEscape(String(k)) . '": ' . JsonStringify(v, indent >= 0 ? indent + 1 : -1)
                first := false
            }
            if first
                return "{}"
            out .= (indent >= 0 ? "`n" . pad : " ") . "}"
            return out
        }
    } else if (val is Number) {
        return String(val)
    } else if (val == "") {
        return '""'
    } else {
        return '"' . JsonEscape(String(val)) . '"'
    }
}