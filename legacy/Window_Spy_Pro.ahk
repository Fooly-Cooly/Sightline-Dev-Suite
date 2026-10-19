;================================================================================;
;	Window Spy Pro (Legacy AHKv1 Edition)                                    ;
;	Active window metrics, HWND handles, PID, and visibility auditor         ;
;	Compatible with Windows XP through Windows 11                            ;
;	Copyright (C) 2026  Fooly Cooly https://github.com/Fooly-Cooly           ;
;	Licensed with GPL v3 https://www.gnu.org/licenses/gpl-3.0.txt            ;
;================================================================================;

#NoEnv
#NoTrayIcon
#Persistent
#SingleInstance Force
SetBatchLines -1
ListLines, Off

; --- Set Window Icon (Titlebar / Alt-Tab) ---
IconPath := FileExist(A_ScriptDir . "\..\assets\Window_Spy_Pro.ico") ? A_ScriptDir . "\..\assets\Window_Spy_Pro.ico"
          : FileExist(A_ScriptDir . "\assets\Window_Spy_Pro.ico") ? A_ScriptDir . "\assets\Window_Spy_Pro.ico"
          : FileExist(A_ScriptDir . "\..\assets\icon.ico") ? A_ScriptDir . "\..\assets\icon.ico"
          : FileExist(A_ScriptDir . "\assets\icon.ico") ? A_ScriptDir . "\assets\icon.ico" : ""

; --- GUI Setup ---
Gui, +Resize +MinSize560x350 +HwndhGui
GroupAdd, WindowSpyGroup, ahk_id %hGui%
Gui, Margin, 10, 10

; Set window icon via WM_SETICON
if (IconPath != "") {
    hIcon := DllCall("LoadImage", "Ptr", 0, "Str", IconPath, "UInt", 1, "Int", 32, "Int", 32, "UInt", 0x00000010, "Ptr")
    if (hIcon)
        SendMessage, 0x0080, 1, hIcon,, ahk_id %hGui% ; WM_SETICON ICON_BIG
}

; Top Controls Toolbar
Gui, Font, s9, Segoe UI
Gui, Add, Text, x10 y12, Scope:
Gui, Add, DropDownList, vShowMode x55 y9 w85 gRefreshList Choose1, All|Visible|Hidden
Gui, Add, Text, x150 y12, Search:
Gui, Add, Edit, vSearchFilter gFilterChange x200 y9 w150, 
Gui, Add, Button, x360 y8 w80 h25 gRefreshList vBtnRefresh, &Refresh (F5)
Gui, Add, Button, x448 y8 w85 h25 gExportLogToFile vBtnLog, &Log to File
Gui, Add, Text, x545 y12 w235 vStatusCount cGray Right, Scanning...

; Output Terminal (Monospace)
Gui, Font, s9, Consolas
Gui, Add, Edit, vMsgs hwndEditC x10 y40 w780 h490 +ReadOnly +HScroll -Wrap

Gui, Show, w800 h540, Window Spy Pro (Legacy v1)
Gosub, RefreshList
Return

; --- Fetch & Display Logic (Optimized Scan) ---
FilterChange:
RefreshList:
    Gui, Submit, NoHide
    
    WS_VISIBLE := 0x10000000
    FormatTime, CurrentTime,, HH:mm:ss
    
    ; Pre-allocate buffer to prevent repeated heap allocations
    VarSetCapacity(LogOutput, 65536)
    LogOutput := "======================================================================`r`n"
    LogOutput .= "[" . CurrentTime . "] Window Scan Scope: " . ShowMode
    if (SearchFilter != "")
        LogOutput .= " | Filter: `"" . SearchFilter . "`""
    LogOutput .= "`r`n======================================================================`r`n`r`n"
    
    WinGet, l_array, List
    MatchCount := 0
    
    Loop, %l_array%
    {
        this_id := "ahk_id " . l_array%A_Index%
        
        ; Micro-optimization: Query Title FIRST to skip nameless handles
        WinGetTitle, l_title, %this_id%
        if (l_title = "")
            continue
            
        WinGet, l_style, Style, %this_id%
        is_visible := (l_style & WS_VISIBLE)
        
        if (ShowMode = "Visible" && !is_visible)
            continue
        if (ShowMode = "Hidden" && is_visible)
            continue
            
        WinGet, l_process, ProcessName, %this_id%
        WinGet, l_pid, PID, %this_id%
        pHwnd := Format("0x{:X}", l_array%A_Index%)
        
        ; Search text filter match
        if (SearchFilter != "") {
            if (!InStr(l_title, SearchFilter) && !InStr(l_process, SearchFilter) && !InStr(pHwnd, SearchFilter) && !InStr(l_pid, SearchFilter))
                continue
        }
        
        visibility_str := is_visible ? "[Visible]" : "[Hidden] "
        LogOutput .= visibility_str . " " . l_title . "`r`n  hWnd: " . pHwnd . " | Process: " . l_process . " | PID: " . l_pid . "`r`n`r`n"
        MatchCount++
    }
    
    ; Freeze redrawing during large text replacement to eliminate flicker
    GuiControl, -Redraw, %EditC%
    GuiControl,, Msgs, % LogOutput
    GuiControl, +Redraw, %EditC%
    
    ; Scroll edit block to top view
    ControlSend,, ^{Home}, ahk_id %EditC%
    
    GuiControl,, StatusCount, Windows found: %MatchCount%
Return

ExportLogToFile:
    GuiControlGet, Msgs
    if (Msgs = "")
        return
        
    try {
        FileAppend, %Msgs%, window_spy_pro.log, UTF-8
        ToolTip, Snapshot saved to window_spy_pro.log!
        SetTimer, RemoveToolTip, -1500
    } catch e {
        ToolTip, Failed to write log!
        SetTimer, RemoveToolTip, -2000
    }
Return

RemoveToolTip:
    ToolTip
Return

GuiClose:
    ExitApp
Return

; --- Dynamic UI Resizing ---
GuiSize:
    if (A_EventInfo = 1) ; Minimized
        return
    NewWidth  := A_GuiWidth - 20
    NewHeight := A_GuiHeight - 50
    GuiControl, Move, Msgs, w%NewWidth% h%NewHeight%
    GuiControl, Move, StatusCount, % "x" (A_GuiWidth - 245)
Return

; --- Shortcuts ---
#IfWinActive ahk_group WindowSpyGroup
F5::Gosub, RefreshList
+Esc::ExitApp
#IfWinActive