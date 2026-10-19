;================================================================================;
;   Process Spy Pro (AHKv2)                                                      ;
;   Audits active processes, PIDs, and initial command-line parameters           ;
;   Supports both Interactive GUI and Headless CLI (--json, --filter, --pid)     ;
;   Copyright (C) 2026  Fooly Cooly https://github.com/Fooly-Cooly               ;
;   Licensed with GPL v3 https://www.gnu.org/licenses/gpl-3.0.txt                ;
;================================================================================;

;@Ahk2Exe-ConsoleApp
#Requires AutoHotkey v2.0
#SingleInstance Force

; --- CLI Headless Dispatcher ---
if (A_Args.Length > 0) {
    ExitApp(RunProcessSpyCLI(A_Args))
}

; Free attached console in GUI mode so no console window remains
DllCall("FreeConsole")

; Set window icon for taskbar & titlebar, then hide tray icon (Spies have no tray icon)
iconPath := FileExist(A_ScriptDir "\..\assets\Process_Spy_Pro.ico") ? A_ScriptDir "\..\assets\Process_Spy_Pro.ico"
          : FileExist(A_ScriptDir "\assets\Process_Spy_Pro.ico") ? A_ScriptDir "\assets\Process_Spy_Pro.ico"
          : FileExist(A_ScriptDir "\..\assets\icon.ico") ? A_ScriptDir "\..\assets\icon.ico"
          : FileExist(A_ScriptDir "\assets\icon.ico") ? A_ScriptDir "\assets\icon.ico" : ""
if (iconPath != "")
    TraySetIcon(iconPath)
A_IconHidden := true

; --- Main GUI Setup ---
MainGui := Gui("+Resize +MinSize560x350", "Process Spy Pro AHKv2")
MainGui.MarginX := 10
MainGui.MarginY := 10

; Header Controls
MainGui.SetFont("s9", "Segoe UI")
MainGui.Add("Text", "x10 y12", "Filter:")
FilterEdit := MainGui.Add("Edit", "x55 y9 w195", "")
RefreshBtn := MainGui.Add("Button", "x258 y8 w80 h25", "&Refresh (F5)")
LogBtn := MainGui.Add("Button", "x344 y8 w85 h25", "&Log to File")
StatusText := MainGui.Add("Text", "x438 y12 w350 cGray", "Loading processes...")

; Process ListView (Monospace font for technical clarity)
MainGui.SetFont("s9", "Consolas")
LV := MainGui.Add("ListView", "x10 y40 w780 h490 -Multi +Grid Sort", ["Process Name", "PID", "Command Line (Double-Click to copy)"])

; Context Menu for ListView Rows
RowMenu := Menu()
RowMenu.Add("Copy &Command Line", (*) => CopySelectedField(3, "Command Line"))
RowMenu.Add("Copy &Process Name", (*) => CopySelectedField(1, "Process Name"))
RowMenu.Add("Copy &PID", (*) => CopySelectedField(2, "PID"))
RowMenu.Add()
RowMenu.Add("&Open File Location", (*) => OpenSelectedLocation())
RowMenu.Add("&Log Snapshot to File", (*) => ExportLogToFile())
RowMenu.Add("&Refresh List", (*) => PopulateProcessList())

; Event Bindings
LV.OnEvent("DoubleClick", ListView_DoubleClick)
LV.OnEvent("ContextMenu", ListView_ContextMenu)
FilterEdit.OnEvent("Change", (*) => ApplyFilter())
RefreshBtn.OnEvent("Click", (*) => PopulateProcessList())
LogBtn.OnEvent("Click", (*) => ExportLogToFile())
MainGui.OnEvent("Size", GuiSizeHandler)
MainGui.OnEvent("Close", (*) => ExitApp())

; Global storage for cached process objects
global AllProcesses := []

PopulateProcessList()
MainGui.Show("w800 h540")

; --- Keyboard Shortcuts ---
#HotIf WinActive("ahk_id " MainGui.Hwnd)
F5::PopulateProcessList()
+Esc::ExitApp()
Esc::ClearFilter()
#HotIf

ClearFilter() {
    if (FilterEdit.Value != "") {
        FilterEdit.Value := ""
        ApplyFilter()
    }
}

PopulateProcessList() {
    global AllProcesses, StatusText
    if (!IsSet(AllProcesses))
        AllProcesses := []
    StatusText.Text := "Querying WMI process table..."
    
    try {
        AllProcesses := CollectProcesses("", 0, false)
    } catch as err {
        StatusText.Text := "WMI Error: " err.Message
        return
    }
    
    ApplyFilter()
}

ApplyFilter() {
    global AllProcesses, LV, FilterEdit, StatusText
    LV.Opt("-Redraw")
    LV.Delete()
    filter := StrLower(Trim(FilterEdit.Text))
    
    count := 0
    for item in AllProcesses {
        if (filter == "" 
            || InStr(StrLower(item.Name), filter) 
            || InStr(StrLower(item.CommandLine), filter) 
            || InStr(String(item.PID), filter)) {
            LV.Add("", item.Name, item.PID, item.CommandLine)
            count++
        }
    }
    
    LV.ModifyCol(1, "AutoHdr")
    LV.ModifyCol(2, "AutoHdr")
    LV.ModifyCol(3, "AutoHdr")
    LV.Opt("+Redraw")
    
    StatusText.Text := "Showing " count " of " AllProcesses.Length " processes (double-click row to copy)"
}

ListView_DoubleClick(LV, RowNumber) {
    if (RowNumber == 0)
        return
    CopySelectedField(3, "Command Line")
}

ListView_ContextMenu(LV, Item, IsRightClick, X, Y) {
    if (Item == 0)
        return
    RowMenu.Show(X, Y)
}

CopySelectedField(ColIndex, FieldName) {
    row := LV.GetNext()
    if (row == 0)
        return
    val := LV.GetText(row, ColIndex)
    if (val != "") {
        A_Clipboard := val
        ToolTip("Copied " FieldName " to clipboard!")
        SetTimer(() => ToolTip(), -1200)
    }
}

OpenSelectedLocation() {
    global AllProcesses, LV
    row := LV.GetNext()
    if (row == 0)
        return
    pid := Integer(LV.GetText(row, 2))
    
    for proc in AllProcesses {
        if (proc.PID == pid && proc.Path != "") {
            try Run(Format('explorer.exe /select,"{1}"', proc.Path))
            return
        }
    }
    ToolTip("Path not accessible for PID " pid)
    SetTimer(() => ToolTip(), -1500)
}

ExportLogToFile(*) {
    global AllProcesses, FilterEdit
    filter := Trim(FilterEdit.Text)
    CurrentTime := FormatTime(, "HH:mm:ss")
    LogOutput := "======================================================================`r`n"
    LogOutput .= "[" CurrentTime "] Process Spy Pro Snapshot"
    if (filter != "")
        LogOutput .= " | Filter: `"" filter "`""
    LogOutput .= "`r`n======================================================================`r`n`r`n"
    
    exportedCount := 0
    filterLower := StrLower(filter)
    for item in AllProcesses {
        if (filterLower == "" 
            || InStr(StrLower(item.Name), filterLower) 
            || InStr(StrLower(item.CommandLine), filterLower) 
            || InStr(String(item.PID), filterLower)) {
            LogOutput .= item.Name " (PID: " item.PID ")`r`n  " item.CommandLine "`r`n`r`n"
            exportedCount++
        }
    }
    
    if (exportedCount == 0) {
        ToolTip("No processes matching filter to log!")
        SetTimer(() => ToolTip(), -1500)
        return
    }
    
    try {
        FileAppend(LogOutput, "process_spy_pro.log", "UTF-8")
        ToolTip("Exported " exportedCount " processes to process_spy_pro.log!")
        SetTimer(() => ToolTip(), -1500)
    } catch as err {
        ToolTip("Failed to write log: " err.Message)
        SetTimer(() => ToolTip(), -2000)
    }
}

GuiSizeHandler(GuiObj, WindowState, Width, Height) {
    global LV
    if (WindowState == -1)
        return
        
    NewWidth  := Width - 20
    NewHeight := Height - 50
    if (IsObject(LV)) {
        LV.Move(,, NewWidth, NewHeight)
        LV.ModifyCol(3, NewWidth - 220)
    }
}

; ==============================================================================
; Core Data Engine: CollectProcesses
; ==============================================================================
CollectProcesses(filterText := "", targetPid := 0, includeMemory := false, checkElevation := false) {
    filterLower := StrLower(Trim(filterText))
    results := []
    
    wmi := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
    query := "Select ProcessId, Name, CommandLine, ExecutablePath from Win32_Process"
    if (targetPid > 0)
        query .= " where ProcessId = " targetPid
        
    for proc in wmi.ExecQuery(query) {
        try {
            cmd := proc.CommandLine
            if (cmd == "")
                continue
                
            pid := proc.ProcessId
            name := proc.Name
            execPath := ""
            try execPath := proc.ExecutablePath
            
            if (filterLower != "") {
                if (!InStr(StrLower(name), filterLower)
                    && !InStr(StrLower(cmd), filterLower)
                    && !InStr(StrLower(execPath), filterLower)
                    && !InStr(String(pid), filterLower))
                    continue
            }
            
            isElevated := checkElevation ? CheckProcessElevated(pid) : false
            item := {
                name: name,
                pid: pid,
                commandLine: cmd,
                path: execPath,
                elevated: isElevated ? JBool.True : JBool.False
            }
            
            if (includeMemory) {
                mem := GetProcessMemoryMB(pid)
                item.memory := {
                    workingSetMB: mem.workingSetMB,
                    pagefileMB: mem.pagefileMB
                }
            }
            
            results.Push(item)
        }
    }
    return results
}

CheckProcessElevated(pid) {
    hProc := DllCall("Kernel32\OpenProcess", "UInt", 0x0400, "Int", 0, "UInt", pid, "Ptr") ; PROCESS_QUERY_INFORMATION
    if !hProc
        return false
    hToken := 0
    isElevated := false
    if DllCall("Advapi32\OpenProcessToken", "Ptr", hProc, "UInt", 0x0008, "Ptr*", &hToken) {
        tokenInfo := Buffer(4, 0)
        retLen := 0
        if DllCall("Advapi32\GetTokenInformation", "Ptr", hToken, "Int", 20, "Ptr", tokenInfo.Ptr, "UInt", 4, "UInt*", &retLen) {
            isElevated := NumGet(tokenInfo, 0, "UInt") != 0
        }
        DllCall("Kernel32\CloseHandle", "Ptr", hToken)
    }
    DllCall("Kernel32\CloseHandle", "Ptr", hProc)
    return isElevated
}

GetProcessMemoryMB(pid) {
    hProc := DllCall("Kernel32\OpenProcess", "UInt", 0x0410, "Int", 0, "UInt", pid, "Ptr")
    if !hProc
        return { workingSetMB: 0.0, pagefileMB: 0.0 }
        
    cbSize := 8 + (A_PtrSize * 9)
    pmc := Buffer(cbSize, 0)
    NumPut("UInt", cbSize, pmc, 0)
    
    ws := 0.0
    pf := 0.0
    if DllCall("Kernel32\K32GetProcessMemoryInfo", "Ptr", hProc, "Ptr", pmc.Ptr, "UInt", cbSize) {
        ws := Round(NumGet(pmc, 8 + A_PtrSize, "UPtr") / (1024 * 1024), 2)
        pf := Round(NumGet(pmc, 8 + (A_PtrSize * 7), "UPtr") / (1024 * 1024), 2)
    }
    DllCall("Kernel32\CloseHandle", "Ptr", hProc)
    return { workingSetMB: ws, pagefileMB: pf }
}

; ==============================================================================
; Headless CLI Engine
; ==============================================================================
ConsoleOut(text) => FileAppend(text, "*", "UTF-8")

RunProcessSpyCLI(args) {
    useJson := false
    filterText := ""
    targetPid := 0
    includeMemory := false
    
    i := 1
    while (i <= args.Length) {
        arg := args[i]
        switch StrLower(arg) {
            case "-h", "--help", "/?":
                PrintProcessSpyHelp()
                return 0
            case "-j", "--json":
                useJson := true
            case "-m", "--memory":
                includeMemory := true
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
    
    processes := CollectProcesses(filterText, targetPid, includeMemory, true)
    
    if (useJson) {
        ConsoleOut(JsonStringify(processes, 2) . "`n")
    } else {
        ConsoleOut("================================================================================`n")
        ConsoleOut("Process Spy Pro | Processes Found: " processes.Length "`n")
        if (filterText != "")
            ConsoleOut("Filter: `"" filterText "`"`n")
        if (targetPid > 0)
            ConsoleOut("Target PID: " targetPid "`n")
        ConsoleOut("================================================================================`n`n")
        
        for proc in processes {
            elev := proc.elevated.val == "true" ? "[Elevated]" : "[Standard]"
            memStr := ""
            if (includeMemory && HasProp(proc, "memory"))
                memStr := Format(" | RAM: {1} MB", proc.memory.workingSetMB)
            ConsoleOut(Format("{1} {2} (PID: {3}){4}`n", elev, proc.name, proc.pid, memStr))
            ConsoleOut(Format("  Cmd: {1}`n`n", proc.commandLine))
        }
    }
    
    return processes.Length > 0 ? 0 : 2
}

PrintProcessSpyHelp() {
    ConsoleOut("Sightline DevSuite | Process Spy Pro (AHKv2)`n")
    ConsoleOut("Usage: Process_Spy_Pro.exe [OPTIONS]`n`n")
    ConsoleOut("Options:`n")
    ConsoleOut("  -j, --json               Output results as structured JSON`n")
    ConsoleOut("  -f, --filter <text>      Filter by process name, command-line, or path`n")
    ConsoleOut("  -p, --pid <pid>          Filter by specific Process ID`n")
    ConsoleOut("  -m, --memory             Include working set memory metrics (MB)`n")
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
