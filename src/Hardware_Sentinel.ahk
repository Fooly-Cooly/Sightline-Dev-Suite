;================================================================================;
;   Hardware Sentinel (AHKv2)                                                    ;
;   Real-time hardware abstraction layer debugger & WM_DEVICECHANGE sniffer      ;
;   Supports both Interactive GUI and Headless CLI (--json, --snapshot, --listen);
;   Copyright (C) 2026  Fooly Cooly https://github.com/Fooly-Cooly               ;
;   Licensed with GPL v3 https://www.gnu.org/licenses/gpl-3.0.txt                ;
;================================================================================;

;@Ahk2Exe-ConsoleApp
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()

; --- SetupAPI Library Handle & State Globals ---
global hSetupApi := DllCall("LoadLibrary", "Str", "setupapi.dll", "Ptr")
global cliConfig := {}
global MainGui := ""
global HardwareTree := ""
global LogTree := ""
global InventoryStatus := ""
global EventCountText := ""
global LogCheck := ""
global TotalEvents := 0

OnExit(CleanupHardwareSentinel)
CleanupHardwareSentinel(*) {
    global hSetupApi
    if (hSetupApi) {
        DllCall("FreeLibrary", "Ptr", hSetupApi)
        hSetupApi := 0
    }
    return 0 ; Explicitly return 0 so exit is never aborted
}

; --- Main Entry Point ---
if (A_Args.Length > 0) {
    RunHardwareSentinelCLI(A_Args)
} else {
    RunHardwareSentinelGUI()
}

; ==============================================================================
; Interactive GUI Mode
; ==============================================================================
RunHardwareSentinelGUI() {
    global MainGui, HardwareTree, LogTree, InventoryStatus, EventCountText, LogCheck, LblLive, BtnClearLog
    
    ; Free any attached console in GUI mode so no console window remains
    DllCall("FreeConsole")

    ; Set Tray Icon
    iconPath := FileExist(A_ScriptDir "\..\assets\Hardware_Sentinel.ico") ? A_ScriptDir "\..\assets\Hardware_Sentinel.ico"
              : FileExist(A_ScriptDir "\assets\Hardware_Sentinel.ico") ? A_ScriptDir "\assets\Hardware_Sentinel.ico"
              : FileExist(A_ScriptDir "\..\assets\icon.ico") ? A_ScriptDir "\..\assets\icon.ico"
              : FileExist(A_ScriptDir "\assets\icon.ico") ? A_ScriptDir "\assets\icon.ico" : ""
    if (iconPath != "")
        TraySetIcon(iconPath)

    ; Main GUI Setup
    MainGui := Gui("+Resize +MinSize600x420", "Hardware Sentinel AHKv2")
    MainGui.MarginX := 10
    MainGui.MarginY := 10

    ; Header Row 1: Hardware Inventory
    MainGui.SetFont("s9 Bold", "Segoe UI")
    MainGui.Add("Text", "x10 y10", "Hardware Inventory:")
    MainGui.SetFont("s9 norm", "Segoe UI")
    BtnRefresh := MainGui.Add("Button", "x140 y6 w85 h24", "&Refresh (F5)")
    InventoryStatus := MainGui.Add("Text", "x235 y10 w350 cGray", "Scanning devices...")

    ; Inventory Tree View (Monospace)
    MainGui.SetFont("s9", "Consolas")
    HardwareTree := MainGui.Add("Edit", "vHardwareTree x10 y34 w780 h280 +ReadOnly +HScroll -Wrap")

    ; Header Row 2: Live Notifications & Controls
    MainGui.SetFont("s9 Bold", "Segoe UI")
    LblLive := MainGui.Add("Text", "x10 y325", "Live Hardware Event Stream:")
    MainGui.SetFont("s9 norm", "Segoe UI")
    LogCheck := MainGui.Add("Checkbox", "x230 y325", "Log to file (hardware_sentinel.log)")
    BtnClearLog := MainGui.Add("Button", "x520 y321 w75 h24", "&Clear Log")
    EventCountText := MainGui.Add("Text", "x605 y325 w185 cGray Right", "Events: 0")

    ; Live Event Log Terminal
    MainGui.SetFont("s9", "Consolas")
    LogTree := MainGui.Add("Edit", "vLogTree x10 y350 w780 h180 +ReadOnly +HScroll -Wrap")

    ; Custom Tray Menu (Sentinels minimize to tray)
    A_TrayMenu.Delete()
    A_TrayMenu.Add("&Show", (*) => ShowGui())
    A_TrayMenu.Add("&Refresh Inventory", (*) => ListDevicesGUI())
    A_TrayMenu.Add("&Clear Event Log", (*) => ClearGuiLog())
    A_TrayMenu.Add("E&xit Script", (*) => ExitApp())
    A_TrayMenu.Default := "&Show"
    A_TrayMenu.ClickCount := 1

    ; Event Bindings
    BtnRefresh.OnEvent("Click", (*) => ListDevicesGUI())
    BtnClearLog.OnEvent("Click", (*) => ClearGuiLog())
    MainGui.OnEvent("Size", GuiSizeHandler)
    MainGui.OnEvent("Close", (*) => MainGui.Hide())

    ; Dynamic GUI Keyboard Shortcuts
    HotIfWinActive("ahk_id " MainGui.Hwnd)
    Hotkey("F5", (*) => ListDevicesGUI(), "On")
    Hotkey("+Esc", (*) => ExitApp(), "On")
    HotIf()

    ; Hook Windows Device Broadcast System
    OnMessage(0x219, WM_DEVICECHANGE_GUI_Handler)

    ; Register for all device interface notifications
    DevHdr := Buffer(32, 0)
    NumPut("UInt", 32, DevHdr, 0)
    NumPut("UInt", 5, DevHdr, 4) ; DBT_DEVTYP_DEVICEINTERFACE
    Flags := 0x00000004          ; DEVICE_NOTIFY_ALL_INTERFACE_CLASSES
    DllCall("RegisterDeviceNotification", "Ptr", MainGui.Hwnd, "Ptr", DevHdr.Ptr, "UInt", Flags)

    ListDevicesGUI()
    MainGui.Show("w800 h540")
}

ClearGuiLog() {
    global TotalEvents, LogTree, EventCountText
    if (IsObject(LogTree) && HasProp(LogTree, "Value")) {
        LogTree.Value := ""
        TotalEvents := 0
        if (IsObject(EventCountText))
            EventCountText.Text := "Events: 0"
    }
}

ListDevicesGUI() {
    if (InventoryStatus == "")
        return
        
    InventoryStatus.Text := "Enumerating hardware devices..."
    devices := EnumerateDevices("")
    
    OutputStr := ""
    for dev in devices {
        OutputStr .= "[-] " dev.displayName "`r`n    ID: " dev.instanceId "`r`n`r`n"
    }
    
    HardwareTree.Opt("-Redraw")
    HardwareTree.Value := OutputStr
    HardwareTree.Opt("+Redraw")
    
    InventoryStatus.Text := "Inventory ready (" devices.Length " devices found)"
}

WM_DEVICECHANGE_GUI_Handler(wParam, lParam, *) {
    global TotalEvents, LogTree, EventCountText, LogCheck
    if (!IsObject(LogTree) || !HasProp(LogTree, "Hwnd"))
        return
        
    Timestamp := FormatTime(, "HH:mm:ss")
    
    EventName := "UNKNOWN_EVENT"
    if (wParam = 0x0007)
        EventName := "DBT_DEVNODES_CHANGED (Hardware Config Refreshed)"
    else if (wParam = 0x8000)
        EventName := "DBT_DEVICEARRIVAL (Device Plugged In)"
    else if (wParam = 0x8004)
        EventName := "DBT_DEVICEREMOVECOMPLETE (Device Unplugged)"
        
    LogEntry := "[" Timestamp "] Event: " EventName " (" wParam ")`r`n"
    
    if (lParam != 0) {
        dbch_devicetype := NumGet(lParam, 4, "UInt")
        if (dbch_devicetype = 5) { ; DBT_DEVTYP_DEVICEINTERFACE
            DevicePath := StrGet(lParam + 28, "UTF-16")
            LogEntry .= "    Device Path: " DevicePath "`r`n"
        }
    } else {
        LogEntry .= "    Info: Broad OS Hardware Node Reset.`r`n"
    }
    LogEntry .= "`r`n"
    
    SendMessage(0x00B1, -2, -1,, LogTree.Hwnd)
    SendMessage(0x00C2, 0, StrPtr(LogEntry),, LogTree.Hwnd)
    SendMessage(0x0115, 7, 0,, LogTree.Hwnd)
    
    if (!IsSet(TotalEvents))
        TotalEvents := 0
    TotalEvents++
    EventCountText.Text := "Events: " TotalEvents
    
    if (LogCheck != "" && LogCheck.Value) {
        try FileAppend(LogEntry, "hardware_sentinel.log", "UTF-8")
    }
    
    SetTimer(ListDevicesGUI, -300)
}

ShowGui() {
    if (MainGui != "") {
        MainGui.Show()
        try WinRestore(MainGui.Hwnd)
        try WinActivate(MainGui.Hwnd)
    }
}

GuiSizeHandler(GuiObj, WindowState, Width, Height) {
    global MainGui, HardwareTree, LogTree, LblLive, LogCheck, BtnClearLog, EventCountText
    if (WindowState == -1) {
        MainGui.Hide()
        return
    }
        
    NewWidth  := Width - 20
    TreeHeight := Floor((Height - 85) * 0.58)
    Row2Y      := TreeHeight + 45
    LogTreeY   := Row2Y + 25
    LogHeight  := Height - LogTreeY - 10
    
    if (IsObject(HardwareTree))
        HardwareTree.Move(,, NewWidth, TreeHeight)
    if (IsObject(LblLive))
        LblLive.Move(, Row2Y)
    if (IsObject(LogCheck))
        LogCheck.Move(, Row2Y)
    if (IsObject(BtnClearLog))
        BtnClearLog.Move(Width - 280, Row2Y - 4)
    if (IsObject(EventCountText))
        EventCountText.Move(Width - 195, Row2Y)
    if (IsObject(LogTree))
        LogTree.Move(, LogTreeY, NewWidth, LogHeight)
}

; ==============================================================================
; Core Data Engine: SetupAPI Enumeration
; ==============================================================================
EnumerateDevices(filterText := "") {
    filterLower := StrLower(Trim(filterText))
    results := []
    
    Flags := 0x10 | 0x04 ; DIGCF_DEVICEINTERFACE | DIGCF_ALLCLASSES
    hDev := DllCall("setupapi\SetupDiGetClassDevsW", "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", Flags, "Ptr")
    if (!hDev || hDev = -1)
        return results
        
    cbSize := A_PtrSize == 8 ? 32 : 28
    DevInfoData := Buffer(cbSize, 0)
    NumPut("UInt", cbSize, DevInfoData, 0)
    
    ; Pre-allocated reusable buffers to avoid heap fragmentation during scan
    instanceBuffer := Buffer(2048, 0)
    propBuffer := Buffer(2048, 0)
    
    Loop {
        if (!DllCall("setupapi\SetupDiEnumDeviceInfo", "Ptr", hDev, "UInt", A_Index - 1, "Ptr", DevInfoData.Ptr))
            break
            
        DllCall("setupapi\SetupDiGetDeviceInstanceIdW", "Ptr", hDev, "Ptr", DevInfoData.Ptr, "Ptr", instanceBuffer.Ptr, "UInt", 1024, "Ptr", 0)
        InstanceID := StrGet(instanceBuffer.Ptr, "UTF-16")
        
        FriendlyName := GetDeviceProperty(hDev, DevInfoData, 0x0000000C, propBuffer) ; SPDRP_FRIENDLYNAME
        DeviceDesc   := GetDeviceProperty(hDev, DevInfoData, 0x00000000, propBuffer) ; SPDRP_DEVICEDESC
        
        DisplayName := (FriendlyName != "Unknown") ? FriendlyName : DeviceDesc
        if (DisplayName == "Unknown" && InstanceID != "")
            DisplayName := "Unnamed System Device"
            
        if (filterLower != "") {
            if (!InStr(StrLower(DisplayName), filterLower)
                && !InStr(StrLower(InstanceID), filterLower)
                && !InStr(StrLower(DeviceDesc), filterLower))
                continue
        }
        
        results.Push({
            displayName: DisplayName,
            instanceId: InstanceID,
            description: DeviceDesc
        })
    }
    
    DllCall("setupapi\SetupDiDestroyDeviceInfoList", "Ptr", hDev)
    return results
}

GetDeviceProperty(hDev, DevInfoData, PropId, propBuffer := "") {
    if (!IsObject(propBuffer))
        propBuffer := Buffer(2048, 0)
    if (!DllCall("setupapi\SetupDiGetDeviceRegistryPropertyW", "Ptr", hDev, "Ptr", DevInfoData.Ptr, "UInt", PropId, "Ptr", 0, "Ptr", propBuffer.Ptr, "UInt", 2048, "Ptr", 0))
        return "Unknown"
    return StrGet(propBuffer.Ptr, "UTF-16")
}

; ==============================================================================
; Headless CLI Engine
; ==============================================================================
ConsoleOut(text) => FileAppend(text, "*", "UTF-8")

RunHardwareSentinelCLI(args) {
    useJson := false
    isListenMode := false
    timeoutSec := 0
    maxCount := 0
    filterText := ""
    
    i := 1
    while (i <= args.Length) {
        arg := args[i]
        switch StrLower(arg) {
            case "-h", "--help", "/?":
                PrintHardwareSentinelHelp()
                ExitApp(0)
            case "-j", "--json":
                useJson := true
            case "-s", "--snapshot":
                isListenMode := false
            case "-l", "--listen":
                isListenMode := true
            case "-t", "--timeout":
                if (i + 1 <= args.Length) {
                    i++
                    timeoutSec := Integer(args[i])
                    isListenMode := true
                }
            case "-c", "--count":
                if (i + 1 <= args.Length) {
                    i++
                    maxCount := Integer(args[i])
                    isListenMode := true
                }
            case "-f", "--filter":
                if (i + 1 <= args.Length) {
                    i++
                    filterText := args[i]
                }
            default:
                if (filterText == "" && !InStr(arg, "-")) {
                    filterText := arg
                } else {
                    ConsoleOut("[ERROR] Unrecognized argument: " arg "`nUse --help for usage information.`n")
                    ExitApp(1)
                }
        }
        i++
    }
    
    ; --- Mode 1: Static Snapshot Mode ---
    if (!isListenMode) {
        devices := EnumerateDevices(filterText)
        if (useJson) {
            ConsoleOut(JsonStringify(devices, 2) . "`n")
        } else {
            ConsoleOut("================================================================================`n")
            ConsoleOut("Hardware Sentinel | Device Snapshot | Devices Found: " devices.Length "`n")
            if (filterText != "")
                ConsoleOut("Filter: `"" filterText "`"`n")
            ConsoleOut("================================================================================`n`n")
            
            for dev in devices {
                ConsoleOut(Format("[-] {1}`n    ID: {2}`n`n", dev.displayName, dev.instanceId))
            }
        }
        ExitApp(devices.Length > 0 ? 0 : 2)
    }
    
    ; --- Mode 2: Live Event Listen Mode ---
    cliConfig.useJson := useJson
    cliConfig.timeoutSec := timeoutSec
    cliConfig.maxCount := maxCount
    cliConfig.filterText := StrLower(Trim(filterText))
    cliConfig.capturedCount := 0
    
    ; Register for device broadcast notifications on script window
    OnMessage(0x219, WM_DEVICECHANGE_CLI_Handler)
    DevHdr := Buffer(32, 0)
    NumPut("UInt", 32, DevHdr, 0)
    NumPut("UInt", 5, DevHdr, 4) ; DBT_DEVTYP_DEVICEINTERFACE
    hDevNotify := DllCall("RegisterDeviceNotification", "Ptr", A_ScriptHwnd, "Ptr", DevHdr.Ptr, "UInt", 4, "Ptr")
    
    if (!useJson) {
        ConsoleOut("================================================================================`n")
        ConsoleOut("Hardware Sentinel (CLI Hardware Event Listener Active)`n")
        if (timeoutSec > 0)
            ConsoleOut(Format("Timeout: {1} seconds | ", timeoutSec))
        if (maxCount > 0)
            ConsoleOut(Format("Count Limit: {1} events | ", maxCount))
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
    
    if (hDevNotify)
        DllCall("UnregisterDeviceNotification", "Ptr", hDevNotify)
    ExitApp(0)
}

WM_DEVICECHANGE_CLI_Handler(wParam, lParam, *) {
    eventName := "UNKNOWN_EVENT"
    if (wParam = 0x0007)
        eventName := "DBT_DEVNODES_CHANGED"
    else if (wParam = 0x8000)
        eventName := "DBT_DEVICEARRIVAL"
    else if (wParam = 0x8004)
        eventName := "DBT_DEVICEREMOVECOMPLETE"
        
    devicePath := ""
    if (lParam != 0) {
        dbch_devicetype := NumGet(lParam, 4, "UInt")
        if (dbch_devicetype = 5) { ; DBT_DEVTYP_DEVICEINTERFACE
            devicePath := StrGet(lParam + 28, "UTF-16")
        }
    }
    
    if (cliConfig.filterText != "") {
        ft := cliConfig.filterText
        if (!InStr(StrLower(eventName), ft) && !InStr(StrLower(devicePath), ft))
            return
    }
    
    timeStr := FormatTime(, "yyyy-MM-ddTHH:mm:ss")
    hexCode := Format("0x{:04X}", wParam)
    
    if (cliConfig.useJson) {
        evt := {
            timestamp: timeStr,
            eventCode: hexCode,
            eventName: eventName
        }
        if (devicePath != "")
            evt.devicePath := devicePath
            
        ConsoleOut(JsonStringify(evt, -1) . "`n")
    } else {
        txt := Format("[{1}] {2} ({3})", FormatTime(, "HH:mm:ss"), eventName, hexCode)
        if (devicePath != "")
            txt .= Format(" | Path: {1}", devicePath)
        txt .= "`n"
        ConsoleOut(txt)
    }
    
    cliConfig.capturedCount++
    if (cliConfig.maxCount > 0 && cliConfig.capturedCount >= cliConfig.maxCount) {
        ExitApp(0)
    }
}

PrintHardwareSentinelHelp() {
    ConsoleOut("Sightline DevSuite | Hardware Sentinel (AHKv2)`n")
    ConsoleOut("Usage: Hardware_Sentinel.exe [OPTIONS]`n`n")
    ConsoleOut("Options:`n")
    ConsoleOut("  -j, --json               Output results as structured JSON (or NDJSON in listen mode)`n")
    ConsoleOut("  -s, --snapshot           Dump current hardware device inventory and exit (default)`n")
    ConsoleOut("  -l, --listen             Listen for real-time hardware changes (WM_DEVICECHANGE)`n")
    ConsoleOut("  -t, --timeout <sec>      Listen for N seconds, then exit cleanly`n")
    ConsoleOut("  -c, --count <num>        Exit after capturing N hardware events`n")
    ConsoleOut("  -f, --filter <text>      Filter devices by name, description, or instance ID`n")
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