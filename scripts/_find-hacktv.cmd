@echo off
REM Locate hacktv.exe. Sets HACKTV to the full path, or exits 1.
REM Source via: call "%~dp0_find-hacktv.cmd" || exit /b 1

set "HACKTV="

for %%P in (hacktv.exe) do if not defined HACKTV if not "%%~$PATH:P"=="" set "HACKTV=%%~$PATH:P"

if not defined HACKTV if exist "%~dp0bin\hacktv.exe" set "HACKTV=%~dp0bin\hacktv.exe"

if not defined HACKTV for %%D in (
    "%APPDATA%\hacktv-gui\bin\hacktv.exe"
    "%LOCALAPPDATA%\Programs\hacktv-gui\hacktv.exe"
    "%LOCALAPPDATA%\hacktv-gui\bin\hacktv.exe"
    "%ProgramFiles%\hacktv-gui\hacktv.exe"
    "%ProgramFiles(x86)%\hacktv-gui\hacktv.exe"
) do if not defined HACKTV if exist %%~D set "HACKTV=%%~D"

if not defined HACKTV (
    echo ERROR: hacktv.exe not found.
    echo   Install via https://github.com/steeviebops/hacktv-gui-installer/releases
    echo   or place hacktv.exe in scripts\bin\ or anywhere on PATH.
    exit /b 1
)

exit /b 0
