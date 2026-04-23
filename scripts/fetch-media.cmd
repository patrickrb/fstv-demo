@echo off
REM Download the demo video(s) into media\. Content licensed CC-BY by Blender Foundation.

setlocal

set ROOT=%~dp0..
set DEST=%ROOT%\media
if not exist "%DEST%" mkdir "%DEST%"

set TRAILER=%DEST%\bbb-trailer.mp4
if exist "%TRAILER%" (
    echo already present: %TRAILER%
) else (
    echo downloading Big Buck Bunny trailer [480p, ~10 MB, CC-BY Blender Foundation]...
    powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://download.blender.org/peach/trailer/trailer_480p.mov' -OutFile '%TRAILER%' -UseBasicParsing" || exit /b 1
    for %%F in ("%TRAILER%") do echo     saved: %%~fF  (%%~zF bytes^)
)

endlocal
