;================================================================================;
;	Hardware Sentinel (Legacy AHKv1 Edition)                                 ;
;	Real-time hardware abstraction layer debugger & WM_DEVICECHANGE sniffer  ;
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
IconPath := FileExist(A_ScriptDir . "\..\assets\Hardware_Sentinel.ico") ? A_ScriptDir . "\..\assets\Hardware_Sentinel.ico"
          : FileExist(A_ScriptDir . "\assets\Hardware_Sentinel.ico") ? A_ScriptDir . "\assets\Hardware_Sentinel.ico"
          : FileExist(A_ScriptDir . "\..\assets\icon.ico") ? A_ScriptDir . "\..\assets\icon.ico"
          : FileExist(A_ScriptDir . "\assets\icon.ico") ? A_ScriptDir . "\assets\icon.ico" : ""
if (IconPath != "")
    Menu, Tray, Icon, %IconPath%

; --- GUI Setup ---
Gui, +Resize +MinSize600x420 +HwndhGui
GroupAdd, HardwareSentinelGroup, ahk_id %hGui%
Gui, Margin, 10, 10

; Header Row 1: Hardware Inventory
Gui, Font, s9 Bold, Segoe UI
Gui, Add, Text, x10 y10 vLblInventory, Hardware Inventory:
Gui, Font, s9 norm, Segoe UI
Gui, Add, Button, x140 y6 w85 h24 gManualRefresh vBtnRefresh, &Refresh (F5)
Gui, Add, Text, x235 y10 w350 vInventoryStatus cGray, Scanning devices...

; Inventory Tree View (Monospace)
Gui, Font, s9, Consolas
Gui, Add, Edit, vHardwareTree hwndTreeHwnd x10 y34 w780 h280 +ReadOnly +HScroll -Wrap

; Header Row 2: Live Notifications & Controls
Gui, Font, s9 Bold, Segoe UI
Gui, Add, Text, x10 y325 vLblLive, Live Hardware Event Stream:
Gui, Font, s9 norm, Segoe UI
Gui, Add, Checkbox, vLogToFile x230 y325 gToggleLogging, Log to file (hardware_sentinel.log)
Gui, Add, Button, x520 y321 w75 h24 gClearLog vBtnClearLog, &Clear Log
Gui, Add, Text, x605 y325 w185 vEventCountText cGray Right, Events: 0

; Live Notifications Edit Box
Gui, Font, s9, Consolas
Gui, Add, Edit, vLogTree hwndLogHwnd x10 y350 w780 h180 +ReadOnly +HScroll -Wrap

; Custom Tray Menu (Sentinels minimize to tray)
Menu, Tray, NoStandard
Menu, Tray, Add, &Show, GuiShow
Menu, Tray, Add, &Refresh Inventory, ManualRefresh
Menu, Tray, Add, &Clear Event Log, ClearLog
Menu, Tray, Add, E&xit Script, TrayExit
Menu, Tray, Default, &Show
Menu, Tray, Click, 1

Gui, Show, w800 h540, Hardware Sentinel (Legacy v1)

; --- Persistent DLL & Device Notification Hooking ---
global hSetupApi := DllCall("LoadLibrary", "Str", "setupapi.dll", "Ptr")
global TotalEvents := 0

OnMessage(0x219, "WM_DEVICECHANGE_Handler")

; Register for device interface broadcasts
; Flags = 0x00000004 (DEVICE_NOTIFY_ALL_INTERFACE_CLASSES on Vista+)
; If on Windows XP, fallback to Flags = 0 for full backward compatibility
VarSetCapacity(DevHdr, 32, 0)
NumPut(32, DevHdr, 0, "UInt")
NumPut(5, DevHdr, 4, "UInt") ; DBT_DEVTYP_DEVICEINTERFACE
hDevNotify := DllCall("RegisterDeviceNotification", "Ptr", hGui, "Ptr", &DevHdr, "UInt", 0x00000004, "Ptr")
if (!hDevNotify) {
    ; Fallback for Windows XP/2000
    hDevNotify := DllCall("RegisterDeviceNotification", "Ptr", hGui, "Ptr", &DevHdr, "UInt", 0, "Ptr")
}

; Initial hardware inventory scan
Gosub, ManualRefresh
Return

; --- Core Enumerate Logic (Optimized) ---
ManualRefresh:
    GuiControl,, InventoryStatus, Enumerating hardware devices...
    ListDevices()
Return

ListDevices() {
    global TreeHwnd, hSetupApi
    
    Flags := 0x10 | 0x04 ; DIGCF_DEVICEINTERFACE | DIGCF_ALLCLASSES
    hDev := DllCall("setupapi\SetupDiGetClassDevsW", "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", Flags, "Ptr")
    if (!hDev || hDev = -1) {
        GuiControl,, InventoryStatus, Failed to acquire SetupAPI handle.
        return
    }
    
    cbSize := A_PtrSize == 8 ? 32 : 28
    VarSetCapacity(DevInfoData, cbSize, 0)
    NumPut(cbSize, DevInfoData, 0, "UInt")
    
    ; Pre-allocate buffer for string assembly to minimize re-allocations
    VarSetCapacity(OutputStr, 65536)
    VarSetCapacity(InstanceID, 2048, 0)
    DeviceCount := 0
    
    Loop {
        if (!DllCall("setupapi\SetupDiEnumDeviceInfo", "Ptr", hDev, "UInt", A_Index - 1, "Ptr", &DevInfoData))
            break
            
        DllCall("setupapi\SetupDiGetDeviceInstanceIdW", "Ptr", hDev, "Ptr", &DevInfoData, "Str", InstanceID, "UInt", 1024, "Ptr", 0)
        
        FriendlyName := GetDeviceProperty(hDev, DevInfoData, 0x0000000C) ; SPDRP_FRIENDLYNAME
        DeviceDesc   := GetDeviceProperty(hDev, DevInfoData, 0x00000000) ; SPDRP_DEVICEDESC
        
        DisplayName := (FriendlyName != "Unknown") ? FriendlyName : DeviceDesc
        if (DisplayName == "Unknown" && InstanceID != "")
            DisplayName := "Unnamed System Device"
            
        OutputStr .= "[-] " . DisplayName . "`n    ID: " . InstanceID . "`n`n"
        DeviceCount++
    }
    
    DllCall("setupapi\SetupDiDestroyDeviceInfoList", "Ptr", hDev)
    
    ; Freeze redrawing during bulk update
    GuiControl, -Redraw, %TreeHwnd%
    GuiControl,, HardwareTree, % OutputStr
    GuiControl, +Redraw, %TreeHwnd%
    
    GuiControl,, InventoryStatus, % "Inventory ready (" . DeviceCount . " devices found)"
}

GetDeviceProperty(hDev, ByRef DevInfoData, PropId) {
    VarSetCapacity(Buffer, 2048, 0)
    if (!DllCall("setupapi\SetupDiGetDeviceRegistryPropertyW", "Ptr", hDev, "Ptr", &DevInfoData, "UInt", PropId, "Ptr", 0, "Str", Buffer, "UInt", 2048, "Ptr", 0))
        Return "Unknown"
    Return Buffer
}

; --- Event Callback Listener (Debounced & Fast Append) ---
WM_DEVICECHANGE_Handler(wP, lP) {
    global LogHwnd, LogToFile, TotalEvents
    FormatTime, Timestamp,, HH:mm:ss
    
    EventName := "UNKNOWN_EVENT"
    if (wP = 0x0007)
        EventName := "DBT_DEVNODES_CHANGED (Hardware Config Refreshed)"
    else if (wP = 0x8000)
        EventName := "DBT_DEVICEARRIVAL (Device Plugged In)"
    else if (wP = 0x8004)
        EventName := "DBT_DEVICEREMOVECOMPLETE (Device Unplugged)"
    
    LogEntry := "[" . Timestamp . "] Event: " . EventName . " (" . wP . ")`r`n"
    
    if (lP != 0) {
        dbch_devicetype := NumGet(lP+0, 4, "UInt")
        if (dbch_devicetype = 5) { ; DBT_DEVTYP_DEVICEINTERFACE
            DevicePath := StrGet(lP + 28, "UTF-16")
            LogEntry .= "    Device Path: " . DevicePath . "`r`n"
        }
    } else {
        LogEntry .= "    Info: Broad OS Hardware Node Reset.`r`n"
    }
    LogEntry .= "`r`n"
    
    ; Micro-optimization: Instant text append via Win32 EM_REPLACESEL without reading full log
    SendMessage, 0x00B1, -2, -1,, ahk_id %LogHwnd% ; EM_SETSEL (move to end)
    SendMessage, 0x00C2, 0, &LogEntry,, ahk_id %LogHwnd% ; EM_REPLACESEL (CRLF ensures proper Win32 line breaks)
    SendMessage, 0x0115, 7, 0,, ahk_id %LogHwnd%   ; WM_VSCROLL (SB_BOTTOM)
    
    TotalEvents++
    GuiControl,, EventCountText, Events: %TotalEvents%
    
    if (LogToFile) {
        FileAppend, %LogEntry%, hardware_sentinel.log, UTF-8
    }
    
    ; Debounce inventory refresh by 300ms to collapse rapid USB insertion storms into a single scan
    SetTimer, DebouncedScan, -300
}

DebouncedScan:
    ListDevices()
Return

ClearLog:
    GuiControl,, LogTree, 
    TotalEvents := 0
    GuiControl,, EventCountText, Events: 0
Return

ToggleLogging:
    Gui, Submit, NoHide
Return

GuiClose:
    Gui, Hide
Return

TrayExit:
    if (hSetupApi)
        DllCall("FreeLibrary", "Ptr", hSetupApi)
    ExitApp
Return

GuiShow:
    Gui, Show
    WinRestore, ahk_id %hGui%
    WinActivate, ahk_id %hGui%
Return

; --- Dynamic UI Resizing ---
GuiSize:
    if (A_EventInfo = 1) { ; Minimize button clicked: minimize to tray
        Gui, Hide
        return
    }
    NewWidth := A_GuiWidth - 20
    
    ; Allocate 58% height to inventory tree, remainder to live log
    TreeHeight := Floor((A_GuiHeight - 85) * 0.58)
    LogHeight  := A_GuiHeight - TreeHeight - 85
    Row2Y      := TreeHeight + 45
    LogTreeY   := Row2Y + 25
    
    GuiControl, Move, HardwareTree, w%NewWidth% h%TreeHeight%
    GuiControl, Move, LblLive, y%Row2Y%
    GuiControl, Move, LogToFile, y%Row2Y%
    GuiControl, Move, BtnClearLog, % "x" (A_GuiWidth - 180) . " y" (Row2Y - 4)
    GuiControl, Move, EventCountText, % "x" (A_GuiWidth - 100) . " y" Row2Y
    GuiControl, Move, LogTree, % "w" NewWidth " h" LogHeight " y" LogTreeY
Return

; --- Shortcuts ---
#IfWinActive ahk_group HardwareSentinelGroup
F5::Gosub, ManualRefresh
+Esc::Gosub, GuiClose
#IfWinActive