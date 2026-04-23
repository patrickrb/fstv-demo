@echo off
REM Phase 3: live screen/webcam -> hacktv -> Pluto, NTSC-M on UHF ch 14.
REM
REM NOTE: This streaming pipeline is NOT reliable on native Windows + WinUSB for the
REM Pluto. The host/USB stack cannot sustain 32 MB/s complex-int16 IQ without
REM micro-gaps that break NTSC horizontal sync. Cyclic playback (see tx-file.cmd) is
REM the only working mode on this host. For a live pipeline, run this under WSL2
REM with usbipd-win attaching the Pluto. This script is retained for that future path.
REM
REM See memory/project_pluto_streaming_broken.md for the details of what was tried.

setlocal

call "%~dp0_find-hacktv.cmd" || exit /b 1

set LO=471250000
set RATE=7993007
set BW=8000000
set MODE=m
set GAIN=0
set URI=ip:192.168.2.1

if not "%~1"=="" set GAIN=%~1

if not defined VIDEO_IN set VIDEO_IN=-f gdigrab -framerate 30 -i desktop
if not defined AUDIO_IN set AUDIO_IN=-f dshow -i audio="Stereo Mix"

call "%~dp0_config-pluto.cmd" %LO% %RATE% %BW% %GAIN% || exit /b 1

echo WARNING: streaming is known-broken on native Windows. Expect static on the Watchman.
echo          Use tx-file.cmd for reliable playback, or run this pipeline from WSL2.

ffmpeg -hide_banner -loglevel warning %VIDEO_IN% %AUDIO_IN% ^
       -f yuv4mpegpipe -pix_fmt yuv420p -r 30 - ^
 | "%HACKTV%" -o - -t int16 -m %MODE% -s %RATE% - ^
 | iio_writedev -u %URI% -b 4000000 cf-ad9361-dds-core-lpc voltage0 voltage1

endlocal
