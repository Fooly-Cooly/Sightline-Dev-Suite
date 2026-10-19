;================================================================================;
;	Shell Sentinel (Legacy AHKv1 Edition)                                    ;
;	Real-time system shell event monitor & APPCOMMAND macro sniffer          ;
;	Compatible with Windows XP through Windows 11                            ;
;	Copyright (C) 2026  Fooly Cooly https://github.com/Fooly-Cooly           ;
;	Licensed with GPL v3 https://www.gnu.org/licenses/gpl-3.0.txt            ;
;================================================================================;

#NoEnv
#Persistent
#SingleInstance Force
SetBatchLines -1
ListLines, Off

; --- Set Tray Icon ---
IconPath := FileExist(A_ScriptDir . "\..\assets\Shell_Sentinel.ico") ? A_ScriptDir . "\..\assets\Shell_Sentinel.ico"
          : FileExist(A_ScriptDir . "\assets\Shell_Sentinel.ico") ? A_ScriptDir . "\assets\Shell_Sentinel.ico"
          : FileExist(A_ScriptDir . "\..\assets\icon.ico") ? A_ScriptDir . "\..\assets\icon.ico"
          : FileExist(A_ScriptDir . "\assets\icon.ico") ? A_ScriptDir . "\assets\icon.ico" : ""
if (IconPath != "")
    Menu, Tray, Icon, %IconPath%

; --- GUI Setup ---
Gui, +Resize +MinSize520x340 +HwndhGui
GroupAdd, ShellSentinelGroup, ahk_id %hGui%
Gui, Margin, 10, 10

; Top Controls Toolbar
Gui, Font, s9, Segoe UI
Gui, Add, Checkbox, vLogToFile x10 y12 gToggleLogging, Log to file (shell_sentinel.log)
Gui, Add, Checkbox, vPauseCapture x245 y12 gTogglePause, Pause Capture
Gui, Add, Button, x360 y8 w75 h24 gClearLog vBtnClearLog, &Clear Log
Gui, Add, Text, x445 y12 w320 vEventCountText cGray Right, Captured: 0 events

; Terminal Output (Monospace)
Gui, Font, s9, Consolas
Gui, Add, Edit, vMsgs hwndEditC x10 y38 w780 h480 +ReadOnly +HScroll -Wrap

; Tray Menu (Sentinels minimize to tray)
Menu, Tray, NoStandard 
Menu, Tray, Add, &Show, GuiShow
Menu, Tray, Add, &Clear Log, ClearLog
Menu, Tray, Add, E&xit Script, TrayExit
Menu, Tray, Default, &Show
Menu, Tray, Click, 1

Gui, Show, w800 h540, Shell Sentinel (Legacy v1)

; --- Pre-Calculate Lookup Tables for O(1) Speed ---
global ShellEventNames := []
global AppCommandTable := []
global TotalEvents := 0
global PauseLogging := 0

; Pre-populate Shell Event dictionary
RawMsgNames := "HSHELL_WINDOWCREATED|HSHELL_WINDOWDESTROYED|HSHELL_ACTIVATESHELLWINDOW|HSHELL_WINDOWACTIVATED|HSHELL_GETMINRECT|HSHELL_REDRAW|HSHELL_TASKMAN|HSHELL_LANGUAGE|HSHELL_SYSMENU|HSHELL_ENDTASK|HSHELL_ACCESSIBILITYSTATE|HSHELL_APPCOMMAND|HSHELL_WINDOWREPLACED|HSHELL_WINDOWREPLACING"
Loop, Parse, RawMsgNames, |
    ShellEventNames[A_Index] := A_LoopField
ShellEventNames[32772] := "HSHELL_RUDEAPPACTIVATED"
ShellEventNames[32774] := "HSHELL_FLASH"

; Pre-populate AppCommand dictionary
RawCommands := "BROWSER_BACKWARD,BROWSER_FORWARD,BROWSER_REFRESH,BROWSER_STOP,BROWSER_SEARCH,BROWSER_FAVORITES,BROWSER_HOME,VOLUME_MUTE,VOLUME_DOWN,VOLUME_UP,MEDIA_NEXTTRACK,MEDIA_PREVIOUSTRACK,MEDIA_STOP,MEDIA_PLAY_PAUSE,LAUNCH_MAIL,LAUNCH_MEDIA_SELECT,LAUNCH_APP1,LAUNCH_APP2,BASS_DOWN,BASS_BOOST,BASS_UP,TREBLE_DOWN,TREBLE_UP,MICROPHONE_VOLUME_MUTE,MICROPHONE_VOLUME_DOWN,MICROPHONE_VOLUME_UP,HELP,FIND,NEW,OPEN,CLOSE,SAVE,PRINT,UNDO,REDO,COPY,CUT,PASTE,REPLY_TO_MAIL,FORWARD_MAIL,SEND_MAIL,SPELL_CHECK,DICTATE_OR_COMMAND_CONTROL_TOGGLE,MIC_ON_OFF_TOGGLE,CORRECTION_LIST"
Loop, Parse, RawCommands, `,
    AppCommandTable[A_Index] := A_LoopField

; --- Register Shell Hook ---
DllCall("RegisterShellHookWindow", "Ptr", hGui)
MsgNum := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
OnMessage(MsgNum, "ShellMessages")
Return

; --- Event Handler (Optimized O(1) Lookup & Direct Win32 Append) ---
ShellMessages(wP, lP) {
    Global EditC, LogToFile, PauseLogging, ShellEventNames, AppCommandTable, TotalEvents
    
    if (PauseLogging)
        return
        
    ; O(1) Instant array lookup
    Routine := ShellEventNames[wP] ? ShellEventNames[wP] : "UNKNOWN_EVENT"
    
    FormatTime, CurrentTime,, HH:mm:ss
    LogOutput := "[" . CurrentTime . "] Event: " . Routine . " (" . wP . ")"
    
    ; Handle specific shell events
    if (wP = 5) { ; HSHELL_GETMINRECT
        LogOutput .= "`r`n`r`n"
    } 
    else if (wP = 12) { ; HSHELL_APPCOMMAND
        CmdNum := (lP >> 16) & 0xFFFF
        CmdName := AppCommandTable[CmdNum] ? "APPCOMMAND_" . AppCommandTable[CmdNum] : "UNKNOWN_COMMAND"
        LogOutput .= " // Command: " . CmdName . " (" . CmdNum . ")`r`n`r`n"
    } 
    else { ; Window events
        if DllCall("IsWindow", "Ptr", lP) {
            WinGetTitle, WTitle, ahk_id %lP%
            WinGetClass, WClass, ahk_id %lP%
            WinGet, WProcess, ProcessName, ahk_id %lP%
            WinGet, WPID, PID, ahk_id %lP%
            
            LogOutput .= "`r`n  hWnd: " . lP . "`r`n  Title: " . WTitle . "`r`n  Class: " . WClass . "`r`n  Process: " . WProcess . " (PID: " . WPID . ")`r`n`r`n"
        } else {
            LogOutput .= "`r`n  [Target hWnd: " . lP . " no longer exists]`r`n`r`n"
        }
    }
    
    ; Micro-optimization: Append directly via Win32 EM_REPLACESEL (zero memory reallocation or UI flicker)
    SendMessage, 0x00B1, -2, -1,, ahk_id %EditC% ; EM_SETSEL (move caret to end)
    SendMessage, 0x00C2, 0, &LogOutput,, ahk_id %EditC% ; EM_REPLACESEL (CRLF ensures proper Win32 line breaks)
    SendMessage, 0x0115, 7, 0,, ahk_id %EditC%   ; WM_VSCROLL (SB_BOTTOM)
    
    TotalEvents++
    GuiControl,, EventCountText, Captured: %TotalEvents% events
    
    ; Handle File Logging
    if (LogToFile) {
        FileAppend, %LogOutput%, shell_sentinel.log, UTF-8
    }
}

TogglePause:
    GuiControlGet, PauseCapture
    PauseLogging := PauseCapture
Return

ClearLog:
    GuiControl,, Msgs,
    TotalEvents := 0
    GuiControl,, EventCountText, Captured: 0 events
Return

ToggleLogging:
    Gui, Submit, NoHide
Return

GuiShow:
    Gui, Show
    WinRestore, ahk_id %hGui%
    WinActivate, ahk_id %hGui%
Return

GuiClose:
    Gui, Hide
Return

TrayExit:
    ExitApp
Return

; --- Dynamic UI Resizing ---
GuiSize:
    if (A_EventInfo = 1) { ; Minimize button clicked: minimize to tray
        Gui, Hide
        return
    }
    NewWidth  := A_GuiWidth - 20
    NewHeight := A_GuiHeight - 50
    GuiControl, Move, Msgs, w%NewWidth% h%NewHeight%
    GuiControl, Move, EventCountText, % "x" (A_GuiWidth - 330)
Return

; --- Shortcuts ---
#IfWinActive ahk_group ShellSentinelGroup
+Esc::Gosub, TrayExit
^l::Gosub, ClearLog
#IfWinActive