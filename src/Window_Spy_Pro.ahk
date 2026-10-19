;================================================================================;
;   Window Spy Pro (AHKv2)                                                       ;
;   Active window metrics, HWND handles, PID, and visibility auditor             ;
;   Supports both Interactive GUI and Headless CLI (--json, --scope, --filter)   ;
;   Copyright (C) 2026  Fooly Cooly https://github.com/Fooly-Cooly               ;
;   Licensed with GPL v3 https://www.gnu.org/licenses/gpl-3.0.txt                ;
;================================================================================;

;@Ahk2Exe-ConsoleApp
#Requires AutoHotkey v2.0
#SingleInstance Force

; --- CLI Headless Dispatcher ---
if (A_Args.Length > 0) {
    ExitApp(RunWindowSpyCLI(A_Args))
}

; Free any attached console in GUI mode so no console window remains
DllCall("FreeConsole")

; Set window icon for taskbar & titlebar, then hide tray icon (Spies have no tray icon)
iconPath := FileExist(A_ScriptDir "\..\assets\Window_Spy_Pro.ico") ? A_ScriptDir "\..\assets\Window_Spy_Pro.ico"
          : FileExist(A_ScriptDir "\assets\Window_Spy_Pro.ico") ? A_ScriptDir "\assets\Window_Spy_Pro.ico"
          : FileExist(A_ScriptDir "\..\assets\icon.ico") ? A_ScriptDir "\..\assets\icon.ico"
          : FileExist(A_ScriptDir "\assets\icon.ico") ? A_ScriptDir "\assets\icon.ico" : ""
if (iconPath != "")
    TraySetIcon(iconPath)
A_IconHidden := true

; --- Main GUI Setup ---
MainGui := Gui("+Resize +MinSize560x350", "Window Spy Pro AHKv2")
MainGui.MarginX := 10
MainGui.MarginY := 10

; Header Controls Toolbar
MainGui.SetFont("s9", "Segoe UI")
MainGui.Add("Text", "x10 y12", "Scope:")
FilterCombo := MainGui.Add("DropDownList", "x55 y9 w85 Choose1", ["All", "Visible", "Hidden"])
MainGui.Add("Text", "x150 y12", "Search:")
SearchEdit := MainGui.Add("Edit", "x200 y9 w150", "")
RefreshBtn := MainGui.Add("Button", "x360 y8 w80 h25", "&Refresh (F5)")
LogBtn := MainGui.Add("Button", "x448 y8 w85 h25", "&Log to File")
StatusCount := MainGui.Add("Text", "x545 y12 w235 cGray Right", "Scanning...")

; Terminal Output (Monospace)
MainGui.SetFont("s9", "Consolas")
LogEdit := MainGui.Add("Edit", "vMsgs x10 y40 w780 h490 +ReadOnly +HScroll -Wrap")

; Event Bindings
FilterCombo.OnEvent("Change", RefreshWindowList)
SearchEdit.OnEvent("Change", RefreshWindowList)
RefreshBtn.OnEvent("Click", RefreshWindowList)
LogBtn.OnEvent("Click", ExportLogToFile)
MainGui.OnEvent("Size", GuiSizeHandler)
MainGui.OnEvent("Close", (*) => ExitApp())

; Initial population
RefreshWindowList()
MainGui.Show("w800 h540")

; --- Keyboard Shortcuts ---
#HotIf WinActive("ahk_id " MainGui.Hwnd)
F5::RefreshWindowList()
+Esc::ExitApp()
Esc::ClearSearch()
#HotIf

ClearSearch() {
    if (SearchEdit.Value != "") {
        SearchEdit.Value := ""
        RefreshWindowList()
    }
}

RefreshWindowList(*) {
    ShowMode := StrLower(FilterCombo.Text)
    SearchText := Trim(SearchEdit.Text)
    
    CurrentTime := FormatTime(, "HH:mm:ss")
    LogOutput := "======================================================================`r`n"
    LogOutput .= "[" CurrentTime "] Window Scan Scope: " FilterCombo.Text
    if (SearchText != "")
        LogOutput .= " | Filter: `"" SearchText "`""
    LogOutput .= "`r`n======================================================================`r`n`r`n"
    
    windows := CollectWindows(ShowMode, SearchText, 0, true)
    
    for win in windows {
        visStr := win.visible.val == "true" ? "[Visible]" : "[Hidden] "
        LogOutput .= visStr " " win.title "`r`n  hWnd: " win.hwnd " | Class: " win.class " | Process: " win.process " | PID: " win.pid "`r`n`r`n"
    }
    
    LogEdit.Opt("-Redraw")
    LogEdit.Value := LogOutput
    LogEdit.Opt("+Redraw")
    
    ControlSend("^{Home}", LogEdit.Hwnd)
    StatusCount.Text := "Windows found: " windows.Length
}

ExportLogToFile(*) {
    content := LogEdit.Value
    if (content == "")
        return
        
    try {
        FileAppend(content, "window_spy_pro.log", "UTF-8")
        ToolTip("Snapshot saved to window_spy_pro.log!")
        SetTimer(() => ToolTip(), -1500)
    } catch as err {
        ToolTip("Failed to write log: " err.Message)
        SetTimer(() => ToolTip(), -2000)
    }
}

GuiSizeHandler(GuiObj, WindowState, Width, Height) {
    if (WindowState == -1)
        return
        
    NewWidth  := Width - 20
    NewHeight := Height - 50
    if (IsObject(LogEdit))
        LogEdit.Move(,, NewWidth, NewHeight)
    if (IsObject(StatusCount))
        StatusCount.Move(Width - 245)
}

; ==============================================================================
; Core Data Engine: CollectWindows
; ==============================================================================
CollectWindows(scope := "visible", filterText := "", targetPid := 0, includeCloaked := false) {
    DetectHiddenWindows(true)
    WS_VISIBLE := 0x10000000
    scope := StrLower(scope)
    filterLower := StrLower(Trim(filterText))
    results := []
    
    ; Pre-allocated RECT buffer for GetWindowRect
    rectBuf := Buffer(16, 0)
    
    windowIds := WinGetList()
    for hwnd in windowIds {
        try {
            title := WinGetTitle(hwnd)
            if (title == "") {
                if (scope == "visible")
                    continue
                title := "[Untitled]"
            }
                
            style := WinGetStyle(hwnd)
            isVisible := (style & WS_VISIBLE) != 0
            
            if (scope == "visible" && !isVisible)
                continue
            if (scope == "hidden" && isVisible)
                continue
                
            process := WinGetProcessName(hwnd)
            pid := WinGetPID(hwnd)
            
            if (targetPid > 0 && pid != targetPid)
                continue
                
            hexHwnd := Format("0x{:08X}", hwnd)
            wClass := WinGetClass(hwnd)
            
            ; Live Search Filter check before expensive DWM calls
            if (filterLower != "") {
                if (!InStr(StrLower(title), filterLower)
                    && !InStr(StrLower(process), filterLower)
                    && !InStr(StrLower(hexHwnd), filterLower)
                    && !InStr(StrLower(wClass), filterLower)
                    && !InStr(String(pid), filterLower))
                    continue
            }
            
            isCloaked := CheckWindowCloaked(hwnd)
            if (!includeCloaked && isCloaked && isVisible)
                continue
                
            minMax := WinGetMinMax(hwnd)
            isMinimized := (minMax == -1)
            
            DllCall("User32\GetWindowRect", "Ptr", hwnd, "Ptr", rectBuf)
            rcLeft   := NumGet(rectBuf, 0, "Int")
            rcTop    := NumGet(rectBuf, 4, "Int")
            rcRight  := NumGet(rectBuf, 8, "Int")
            rcBottom := NumGet(rectBuf, 12, "Int")
            
            results.Push({
                hwnd: hexHwnd,
                title: title,
                class: wClass,
                process: process,
                pid: pid,
                visible: isVisible ? JBool.True : JBool.False,
                minimized: isMinimized ? JBool.True : JBool.False,
                cloaked: isCloaked ? JBool.True : JBool.False,
                rect: {
                    x: rcLeft,
                    y: rcTop,
                    w: rcRight - rcLeft,
                    h: rcBottom - rcTop
                }
            })
        }
    }
    return results
}

CheckWindowCloaked(hwnd) {
    cloaked := 0
    if (DllCall("Dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 14, "UInt*", &cloaked, "UInt", 4) == 0)
        return cloaked != 0
    return false
}

; ==============================================================================
; Headless CLI Engine
; ==============================================================================
ConsoleOut(text) => FileAppend(text, "*", "UTF-8")

RunWindowSpyCLI(args) {
    useJson := false
    scope := "visible"
    filterText := ""
    targetPid := 0
    includeCloaked := false
    
    i := 1
    while (i <= args.Length) {
        arg := args[i]
        switch StrLower(arg) {
            case "-h", "--help", "/?":
                PrintWindowSpyHelp()
                return 0
            case "-j", "--json":
                useJson := true
            case "-s", "--scope":
                if (i + 1 <= args.Length) {
                    i++
                    scope := StrLower(args[i])
                    if (scope != "all" && scope != "visible" && scope != "hidden") {
                        ConsoleOut("[ERROR] Invalid scope '" scope "'. Valid options: all, visible, hidden`n")
                        return 1
                    }
                }
            case "-f", "--filter":
                if (i + 1 <= args.Length) {
                    i++
                    filterText := args[i]
                }
            case "-p", "--pid":
                if (i + 1 <= args.Length) {
                    i++
                    targetPid := Integer(args[i])
                }
            case "--include-cloaked":
                includeCloaked := true
            default:
                if (filterText == "" && !InStr(arg, "-")) {
                    filterText := arg
                } else {
                    ConsoleOut("[ERROR] Unrecognized argument: " arg "`nUse --help for usage information.`n")
                    return 1
                }
        }
        i++
    }
    
    windows := CollectWindows(scope, filterText, targetPid, includeCloaked)
    
    if (useJson) {
        ConsoleOut(JsonStringify(windows, 2) . "`n")
    } else {
        ConsoleOut("================================================================================`n")
        ConsoleOut("Window Spy Pro | Scope: " scope " | Windows Found: " windows.Length "`n")
        if (filterText != "")
            ConsoleOut("Filter: `"" filterText "`"`n")
        if (targetPid > 0)
            ConsoleOut("Target PID: " targetPid "`n")
        ConsoleOut("================================================================================`n`n")
        
        for win in windows {
            vis := win.visible.val == "true" ? "[Visible]" : "[Hidden] "
            ConsoleOut(Format("{1} [{2}] {3} (PID: {4})`n", vis, win.hwnd, win.process, win.pid))
            ConsoleOut(Format("  Title: {1}`n", win.title))
            ConsoleOut(Format("  Class: {1} | Rect: {2},{3} ({4}x{5})`n`n", win.class, win.rect.x, win.rect.y, win.rect.w, win.rect.h))
        }
    }
    
    return windows.Length > 0 ? 0 : 2
}

PrintWindowSpyHelp() {
    ConsoleOut("Sightline DevSuite | Window Spy Pro (AHKv2)`n")
    ConsoleOut("Usage: Window_Spy_Pro.exe [OPTIONS]`n`n")
    ConsoleOut("Options:`n")
    ConsoleOut("  -j, --json               Output results as structured JSON`n")
    ConsoleOut("  -s, --scope <mode>       Filter scope: visible (default), hidden, all`n")
    ConsoleOut("  -f, --filter <text>      Filter by title, class, process name, or hex HWND`n")
    ConsoleOut("  -p, --pid <pid>          Filter by specific Process ID`n")
    ConsoleOut("      --include-cloaked    Include Windows 10/11 cloaked windows`n")
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