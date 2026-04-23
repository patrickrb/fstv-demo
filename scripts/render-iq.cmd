@echo off
REM Trim + render an MP4 to an NTSC-M complex int16 IQ file.
REM Usage: render-iq.cmd <input> <start-secs> <duration-secs> <output.iq16>
REM Example: render-iq.cmd media\bbb-trailer.mp4 10 2 media\bbb-clip.iq16

setlocal

if "%~4"=="" (
    echo Usage: %~nx0 ^<input^> ^<start-secs^> ^<duration-secs^> ^<output.iq16^>
    exit /b 1
)

call "%~dp0_find-hacktv.cmd" || exit /b 1

set INPUT=%~1
set START=%~2
set DUR=%~3
set OUT=%~4
set TRIMMED=%TEMP%\_hacktv_trim.mp4

echo [1/2] Trimming %INPUT%  [%START%s +%DUR%s] -^> %TRIMMED%
if exist "%TRIMMED%" del "%TRIMMED%"
ffmpeg -hide_banner -loglevel warning -y -ss %START% -t %DUR% -i "%INPUT%" -c copy "%TRIMMED%" || exit /b 1

echo [2/2] Rendering NTSC-M IQ @ 7993007 sps -^> %OUT%
if exist "%OUT%" del "%OUT%"
"%HACKTV%" -o "file:%OUT%" -t int16 -m m -s 7993007 "%TRIMMED%"

if exist "%OUT%" (
    for %%F in ("%OUT%") do echo     file size: %%~zF bytes
) else (
    echo     ERROR: output file not created
    exit /b 1
)

endlocal
