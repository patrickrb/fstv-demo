@echo off
REM Phase 2 (cyclic variant): play a pre-rendered IQ file on a loop.
REM Streaming mode doesn't survive USB-2.0 jitter on this machine, so we pre-render
REM a short clip and loop it via iio_writedev -c. The Pluto DMA stores the whole
REM buffer in DDR and replays it from local memory - zero USB load during playback.
REM
REM Usage: tx-file.cmd <path-to-iq16> [gain_db]
REM Produce the .iq16 file with scripts\render-iq.cmd first.

setlocal

if "%~1"=="" (
    echo Usage: %~nx0 ^<path-to-iq16^> [gain-dB]
    echo Produce the .iq16 file with: scripts\render-iq.cmd ^<video^> ^<start-s^> ^<dur-s^> ^<out.iq16^>
    exit /b 1
)

set INPUT=%~1

if not exist "%INPUT%" (
    echo Input IQ file not found: %INPUT%
    exit /b 1
)

set LO=471250000
set RATE=7993007
set BW=8000000
set GAIN=0
set URI=ip:192.168.2.1

if not "%~2"=="" set GAIN=%~2

REM Compute sample count from file size: bytes / 4 (complex int16)
for %%F in ("%INPUT%") do set /a SAMPLES=%%~zF / 4

call "%~dp0_config-pluto.cmd" %LO% %RATE% %BW% %GAIN% || exit /b 1

echo Cyclic playback: "%INPUT%"
echo   LO=%LO% Hz  rate=%RATE% sps  gain=%GAIN% dB  samples=%SAMPLES%
echo   Press Ctrl-C to stop.

iio_writedev -u %URI% -c -b %SAMPLES% cf-ad9361-dds-core-lpc voltage0 voltage1 < "%INPUT%"

endlocal
