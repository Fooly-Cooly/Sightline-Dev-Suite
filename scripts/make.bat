@ECHO OFF
SETLOCAL EnableDelayedExpansion

:: Resolve project root directory
PUSHD "%~dp0.."
SET "ROOT_DIR=%CD%"
POPD

SET "AHK_DIR="
FOR /F "tokens=2*" %%A IN ('REG QUERY "HKEY_LOCAL_MACHINE\SOFTWARE\AutoHotkey" /v InstallDir 2^>NUL') DO (
    SET "AHK_DIR=%%B"
)
IF "%AHK_DIR%"=="" IF EXIST "%ProgramFiles%\AutoHotkey" SET "AHK_DIR=%ProgramFiles%\AutoHotkey"

SET "AHK_COMPILER=%AHK_DIR%\Compiler\Ahk2Exe.exe"
IF NOT EXIST "%AHK_COMPILER%" (
    ECHO [ERROR] Ahk2Exe.exe not found at "%AHK_COMPILER%"! Please ensure AutoHotkey compiler is installed.
    PAUSE
    EXIT /B 1
)

:: Detect AHKv2 Base Binary
SET "BASE_V2="
IF EXIST "%AHK_DIR%\v2\AutoHotkey64.exe" (
    SET "BASE_V2=%AHK_DIR%\v2\AutoHotkey64.exe"
) ELSE IF EXIST "%AHK_DIR%\v2\AutoHotkey32.exe" (
    SET "BASE_V2=%AHK_DIR%\v2\AutoHotkey32.exe"
)

:: Detect AHKv1 Legacy Base Binary
SET "BASE_V1="
IF EXIST "%AHK_DIR%\v1.1.37.02\AutoHotkeyU64.exe" (
    SET "BASE_V1=%AHK_DIR%\v1.1.37.02\AutoHotkeyU64.exe"
) ELSE IF EXIST "%AHK_DIR%\v1.1.37.02\AutoHotkeyU32.exe" (
    SET "BASE_V1=%AHK_DIR%\v1.1.37.02\AutoHotkeyU32.exe"
) ELSE IF EXIST "%AHK_DIR%\Compiler\Unicode 64-bit.bin" (
    SET "BASE_V1=%AHK_DIR%\Compiler\Unicode 64-bit.bin"
) ELSE IF EXIST "%AHK_DIR%\Compiler\Unicode 32-bit.bin" (
    SET "BASE_V1=%AHK_DIR%\Compiler\Unicode 32-bit.bin"
)

SET "ICON_PARAM="
IF EXIST "%ROOT_DIR%\assets\icon.ico" (
    SET "ICON_PARAM=/icon "%ROOT_DIR%\assets\icon.ico""
)

SET "BASE_V2_PARAM="
IF NOT "%BASE_V2%"=="" SET "BASE_V2_PARAM=/base "%BASE_V2%""

SET "BASE_V1_PARAM="
IF NOT "%BASE_V1%"=="" SET "BASE_V1_PARAM=/base "%BASE_V1%""

:: Direct CLI argument handling
SET "IS_CLI=0"
IF NOT "%~1"=="" (
    SET "IS_CLI=1"
    SET "CHOICE=%~1"
    IF /I "%~1"=="v2" SET "CHOICE=1"
    IF /I "%~1"=="v1" SET "CHOICE=2"
    IF /I "%~1"=="all" SET "CHOICE=3"
    IF /I "!CHOICE!"=="1" GOTO DO_BUILD_V2
    IF /I "!CHOICE!"=="2" GOTO DO_BUILD_V1
    IF /I "!CHOICE!"=="3" GOTO DO_BUILD_ALL
    IF /I "!CHOICE!"=="4" GOTO LAUNCH_GUI
    IF /I "!CHOICE!"=="Q" EXIT /B 0
    ECHO Unknown command-line option: %~1
    EXIT /B 1
)

:MENU
CLS
ECHO ===============================================================================
ECHO   Sightline DevSuite - Build / Compiler Tool
ECHO ===============================================================================
ECHO   Root Dir   : %ROOT_DIR%
ECHO   Ahk2Exe    : %AHK_COMPILER%
ECHO   v2 Base    : %BASE_V2%
ECHO   v1 Base    : %BASE_V1%
ECHO.
ECHO   [1] Build All AHKv2 Utilities (src/ -^> bin/v2/)
ECHO   [2] Build All AHKv1 Legacy Utilities (legacy_v1/ -^> bin/v1/)
ECHO   [3] Build Everything (v2 and v1)
ECHO   [4] Launch Ahk2Exe GUI
ECHO   [Q] Quit
ECHO.
SET /P "CHOICE=Enter selection (1-4, Q): "

IF /I "%CHOICE%"=="1" GOTO DO_BUILD_V2
IF /I "%CHOICE%"=="2" GOTO DO_BUILD_V1
IF /I "%CHOICE%"=="3" GOTO DO_BUILD_ALL
IF /I "%CHOICE%"=="4" GOTO LAUNCH_GUI
IF /I "%CHOICE%"=="Q" EXIT /B 0
GOTO MENU

:DO_BUILD_V2
ECHO.
ECHO Compiling AHKv2 Utilities to bin\v2 ...
IF NOT EXIST "%ROOT_DIR%\bin\v2" MKDIR "%ROOT_DIR%\bin\v2"
FOR %%F IN ("%ROOT_DIR%\src\*.ahk") DO (
    ECHO   -^> Compiling %%~nxF ...
    SET "TOOL_ICON=%ROOT_DIR%\assets\%%~nF.ico"
    IF NOT EXIST "!TOOL_ICON!" SET "TOOL_ICON=%ROOT_DIR%\assets\icon.ico"
    SET "TOOL_ICON_PARAM="
    IF EXIST "!TOOL_ICON!" SET "TOOL_ICON_PARAM=/icon "!TOOL_ICON!""
    "%AHK_COMPILER%" /in "%%F" /out "%ROOT_DIR%\bin\v2\%%~nF.exe" !TOOL_ICON_PARAM! %BASE_V2_PARAM% /silent
)
ECHO [DONE] AHKv2 builds complete in bin\v2\
IF "%IS_CLI%"=="1" EXIT /B 0
PAUSE
GOTO MENU

:DO_BUILD_V1
ECHO.
ECHO Compiling AHKv1 Legacy Utilities to bin\v1 ...
IF NOT EXIST "%ROOT_DIR%\bin\v1" MKDIR "%ROOT_DIR%\bin\v1"
FOR %%F IN ("%ROOT_DIR%\legacy_v1\*.ahk") DO (
    ECHO   -^> Compiling %%~nxF ...
    SET "TOOL_ICON=%ROOT_DIR%\assets\%%~nF.ico"
    IF NOT EXIST "!TOOL_ICON!" SET "TOOL_ICON=%ROOT_DIR%\assets\icon.ico"
    SET "TOOL_ICON_PARAM="
    IF EXIST "!TOOL_ICON!" SET "TOOL_ICON_PARAM=/icon "!TOOL_ICON!""
    "%AHK_COMPILER%" /in "%%F" /out "%ROOT_DIR%\bin\v1\%%~nF.exe" !TOOL_ICON_PARAM! %BASE_V1_PARAM% /silent
)
ECHO [DONE] AHKv1 builds complete in bin\v1\
IF "%IS_CLI%"=="1" EXIT /B 0
PAUSE
GOTO MENU

:DO_BUILD_ALL
ECHO.
ECHO Compiling AHKv2 Utilities to bin\v2 ...
IF NOT EXIST "%ROOT_DIR%\bin\v2" MKDIR "%ROOT_DIR%\bin\v2"
FOR %%F IN ("%ROOT_DIR%\src\*.ahk") DO (
    ECHO   -^> Compiling %%~nxF ...
    SET "TOOL_ICON=%ROOT_DIR%\assets\%%~nF.ico"
    IF NOT EXIST "!TOOL_ICON!" SET "TOOL_ICON=%ROOT_DIR%\assets\icon.ico"
    SET "TOOL_ICON_PARAM="
    IF EXIST "!TOOL_ICON!" SET "TOOL_ICON_PARAM=/icon "!TOOL_ICON!""
    "%AHK_COMPILER%" /in "%%F" /out "%ROOT_DIR%\bin\v2\%%~nF.exe" !TOOL_ICON_PARAM! %BASE_V2_PARAM% /silent
)
ECHO.
ECHO Compiling AHKv1 Legacy Utilities to bin\v1 ...
IF NOT EXIST "%ROOT_DIR%\bin\v1" MKDIR "%ROOT_DIR%\bin\v1"
FOR %%F IN ("%ROOT_DIR%\legacy_v1\*.ahk") DO (
    ECHO   -^> Compiling %%~nxF ...
    SET "TOOL_ICON=%ROOT_DIR%\assets\%%~nF.ico"
    IF NOT EXIST "!TOOL_ICON!" SET "TOOL_ICON=%ROOT_DIR%\assets\icon.ico"
    SET "TOOL_ICON_PARAM="
    IF EXIST "!TOOL_ICON!" SET "TOOL_ICON_PARAM=/icon "!TOOL_ICON!""
    "%AHK_COMPILER%" /in "%%F" /out "%ROOT_DIR%\bin\v1\%%~nF.exe" !TOOL_ICON_PARAM! %BASE_V1_PARAM% /silent
)
ECHO [DONE] All builds complete!
IF "%IS_CLI%"=="1" EXIT /B 0
PAUSE
GOTO MENU

:LAUNCH_GUI
START "" "%AHK_COMPILER%"
GOTO MENU