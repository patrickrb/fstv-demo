@echo off
REM Phase 1: NTSC-M colour bars, cyclic loop on US UHF channel 14 via Pluto TX DMA.
REM Auto-renders media\bars.iq16 on first run (small, ~24 MB for 0.75s loop).
REM Usage: tx-testpattern.cmd [gain_db]   (default 0, which is max Pluto TX power)

setlocal

set LO=471250000
set RATE=7993007
set BW=8000000
set GAIN=0
set URI=ip:192.168.2.1

if not "%~1"=="" set GAIN=%~1

REM Resolve repo root one level up from this script.
set ROOT=%~dp0..
set IQ=%ROOT%\media\bars.iq16

if not exist "%IQ%" (
    if not exist "%ROOT%\media" mkdir "%ROOT%\media"
    call "%~dp0render-bars.cmd" "%IQ%" 1 || exit /b 1
)

call "%~dp0_config-pluto.cmd" %LO% %RATE% %BW% %GAIN% || exit /b 1

for %%F in ("%IQ%") do set /a SAMPLES=%%~zF / 4

echo Cyclic playback: "%IQ%"
echo   LO=%LO% Hz  rate=%RATE% sps  gain=%GAIN% dB  samples=%SAMPLES%
echo   Tune the Watchman to channel 14. Press Ctrl-C to stop.

iio_writedev -u %URI% -c -b %SAMPLES% cf-ad9361-dds-core-lpc voltage0 voltage1 < "%IQ%"

endlocal
