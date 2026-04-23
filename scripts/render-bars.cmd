@echo off
REM Render NTSC-M colour-bars test pattern to an IQ file for cyclic playback.
REM Usage: render-bars.cmd <output.iq16> [duration_seconds]

setlocal

if "%~1"=="" (
    echo Usage: %~nx0 ^<output.iq16^> [duration_seconds]
    echo Example: %~nx0 media\bars.iq16 2
    exit /b 1
)

call "%~dp0_find-hacktv.cmd" || exit /b 1

set OUT=%~1
set DUR=%~2
if "%DUR%"=="" set DUR=2

REM hacktv runs until killed when fed test:colourbars. Let it run slightly longer than
REM DUR of wall-clock (hacktv writes faster than real time) then truncate to exact length.
REM At 7993007 sps complex int16, DUR seconds = DUR * 7993007 * 4 bytes.

if exist "%OUT%" del "%OUT%"
echo Rendering ~%DUR%s of colour bars @ 7993007 sps -^> %OUT%
powershell -NoProfile -Command "$p = Start-Process -FilePath '%HACKTV%' -ArgumentList '-o','file:%OUT%','-t','int16','-m','m','-s','7993007','test:colourbars' -NoNewWindow -PassThru; Start-Sleep -Seconds ([int]%DUR% + 3); if (!$p.HasExited) { $p.Kill() }; $p.WaitForExit()"

if not exist "%OUT%" (
    echo ERROR: render produced no output
    exit /b 1
)

REM Truncate to exactly DUR seconds.
powershell -NoProfile -Command "$target = [int]%DUR% * 7993007 * 4; $fs = [System.IO.File]::OpenWrite('%OUT%'); if ($fs.Length -ge $target) { $fs.SetLength($target) } else { Write-Host ('WARN: only ' + $fs.Length + ' bytes, wanted ' + $target) }; $fs.Close()"

for %%F in ("%OUT%") do echo     file size: %%~zF bytes

endlocal
