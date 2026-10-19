;================================================================================;
;	Process Spy Pro (Legacy AHKv1 Edition)                                   ;
;	Lists processes' initial command-line parameters with live search        ;
;	Compatible with Windows XP through Windows 11                            ;
;	Copyright (C) 2026  Fooly Cooly https://github.com/Fooly-Cooly           ;
;	Licensed with GPL v3 https://www.gnu.org/licenses/gpl-3.0.txt            ;
;================================================================================;

#NoEnv
#NoTrayIcon
#SingleInstance Force
SetBatchLines -1
ListLines, Off

; --- Set Window Icon (Titlebar / Alt-Tab) ---
IconPath := FileExist(A_ScriptDir . "\..\assets\Process_Spy_Pro.ico") ? A_ScriptDir . "\..\assets\Process_Spy_Pro.ico"
          : FileExist(A_ScriptDir . "\assets\Process_Spy_Pro.ico") ? A_ScriptDir . "\assets\Process_Spy_Pro.ico"
          : FileExist(A_ScriptDir . "\..\assets\icon.ico") ? A_ScriptDir . "\..\assets\icon.ico"
          : FileExist(A_ScriptDir . "\assets\icon.ico") ? A_ScriptDir . "\assets\icon.ico" : ""

; --- GUI Construction ---
Gui, +Resize +MinSize560x350 +HwndhGui
GroupAdd, ProcessSpyGroup, ahk_id %hGui%
Gui, Margin, 10, 10

; Set window icon via WM_SETICON
if (IconPath != "") {
    hIcon := DllCall("LoadImage", "Ptr", 0, "Str", IconPath, "UInt", 1, "Int", 32, "Int", 32, "UInt", 0x00000010, "Ptr")
    if (hIcon)
        SendMessage, 0x0080, 1, hIcon,, ahk_id %hGui% ; WM_SETICON ICON_BIG
}

; Header Controls
Gui, Font, s9, Segoe UI
Gui, Add, Text, x10 y12, Filter:
Gui, Add, Edit, vFilterText gFilterChange x55 y9 w195, 
Gui, Add, Button, gRefreshProcesses x258 y8 w80 h25, &Refresh (F5)
Gui, Add, Button, gExportLogToFile x344 y8 w85 h25, &Log to File
Gui, Add, Text, vStatusText x438 y13 w350 cGray, Loading processes...

; Process List
Gui, Font, s9, Consolas
Gui, Add, ListView, vProcessLV hwndhListView x10 y40 w780 h490 -Multi +Grid Sort gListViewEvent, Process Name|PID|Command Line (Double-Click to copy)

; Data Cache
global ProcessData := []

Gui, Show, w800 h540, Process Spy Pro (Legacy v1)
Gosub, RefreshProcesses
Return

; --- WMI Query & Process Enumeration ---
RefreshProcesses:
    GuiControl,, StatusText, Querying WMI process table...
    ProcessData := []
    
    ; Micro-optimization: Select only 3 required fields instead of wildcard '*'
    try {
        wmi := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
        for proc in wmi.ExecQuery("Select ProcessId, Name, CommandLine from Win32_Process") {
            cmd := proc.CommandLine
            if (cmd != "") {
                ProcessData.Push({ "name": proc.Name, "pid": proc.ProcessId, "cmd": cmd })
            }
        }
    } catch e {
        GuiControl,, StatusText, WMI query error: %e%
        return
    }
    
    Gosub, ApplyFilter
Return

; --- Instant Search Filter ---
FilterChange:
    Gosub, ApplyFilter
Return

ApplyFilter:
    GuiControlGet, FilterText
    FilterText := Trim(FilterText)
    
    ; Freeze ListView redrawing to eliminate repaint stutter
    GuiControl, -Redraw, %hListView%
    LV_Delete()
    
    MatchCount := 0
    TotalCount := ProcessData.Length()
    
    for idx, item in ProcessData {
        name := item.name
        pid  := item.pid
        cmd  := item.cmd
        
        if (FilterText = "" || InStr(name, FilterText) || InStr(cmd, FilterText) || InStr(pid, FilterText)) {
            LV_Add("", name, pid, cmd)
            MatchCount++
        }
    }
    
    ; Auto-fit column widths
    LV_ModifyCol(1, "AutoHdr")
    LV_ModifyCol(2, "AutoHdr")
    LV_ModifyCol(3, "AutoHdr")
    GuiControl, +Redraw, %hListView%
    
    GuiControl,, StatusText, Showing %MatchCount% of %TotalCount% processes (double-click row to copy)
Return

; --- Event Handlers ---
ListViewEvent:
    if (A_GuiEvent = "DoubleClick") {
        LV_GetText(CopiedCmd, A_EventInfo, 3)
        if (CopiedCmd != "") {
            Clipboard := CopiedCmd
            ToolTip, Copied command line to clipboard!
            SetTimer, RemoveToolTip, -1200
        }
    }
Return

ExportLogToFile:
    if (ProcessData.Length() = 0)
        return
        
    GuiControlGet, FilterText
    FilterText := Trim(FilterText)
    FormatTime, CurrentTime,, HH:mm:ss
    
    out := "======================================================================`r`n"
    out .= "[" . CurrentTime . "] Process Spy Pro - Process Snapshot"
    if (FilterText != "")
        out .= " | Filter: `"" . FilterText . "`""
    out .= "`r`n======================================================================`r`n`r`n"
    
    matchCount := 0
    for idx, item in ProcessData {
        name := item.name
        pid  := item.pid
        cmd  := item.cmd
        
        if (FilterText = "" || InStr(name, FilterText) || InStr(cmd, FilterText) || InStr(pid, FilterText)) {
            out .= name . " (PID: " . pid . ")`r`n  " . cmd . "`r`n`r`n"
            matchCount++
        }
    }
    
    try {
        FileAppend, %out%, process_spy_pro.log, UTF-8
        ToolTip, Saved %matchCount% processes to process_spy_pro.log!
        SetTimer, RemoveToolTip, -1500
    } catch e {
        ToolTip, Failed to write log!
        SetTimer, RemoveToolTip, -2000
    }
Return

RemoveToolTip:
    ToolTip
Return

; --- Window Sizing ---
GuiSize:
    if (A_EventInfo = 1) ; Minimized
        return
    NewWidth := A_GuiWidth - 20
    NewHeight := A_GuiHeight - 50
    GuiControl, Move, %hListView%, w%NewWidth% h%NewHeight%
Return

GuiClose:
    ExitApp
Return

; --- Shortcuts ---
#IfWinActive ahk_group ProcessSpyGroup
F5::Gosub, RefreshProcesses
+Esc::ExitApp
#IfWinActive