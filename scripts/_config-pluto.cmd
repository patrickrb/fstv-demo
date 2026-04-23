@echo off
REM Configure Pluto TX path via iio_attr. Sets LO, sample rate, RF bandwidth, and gain.
REM Usage: call _config-pluto.cmd <lo_hz> <rate_sps> <bw_hz> <gain_db>
REM gain_db is hardware gain in dB (negative is attenuation; 0 is max, -89.75 is lowest).

setlocal

set LO=%~1
set RATE=%~2
set BW=%~3
set GAIN=%~4
set URI=ip:192.168.2.1

if "%LO%"=="" goto usage
if "%RATE%"=="" goto usage
if "%BW%"=="" goto usage
if "%GAIN%"=="" goto usage

echo [pluto] LO=%LO% Hz  rate=%RATE% sps  bw=%BW% Hz  gain=%GAIN% dB
iio_attr -q -u %URI% -c -o ad9361-phy altvoltage1 frequency %LO% || goto fail
iio_attr -q -u %URI% -c -o ad9361-phy voltage0 sampling_frequency %RATE% || goto fail
iio_attr -q -u %URI% -c -o ad9361-phy voltage0 rf_bandwidth %BW% || goto fail
iio_attr -q -u %URI% -c -o ad9361-phy voltage0 hardwaregain %GAIN% || goto fail

endlocal & exit /b 0

:usage
echo Usage: call _config-pluto.cmd ^<lo_hz^> ^<rate_sps^> ^<bw_hz^> ^<gain_db^>
endlocal & exit /b 1

:fail
echo ERROR: Pluto configuration via iio_attr failed.
endlocal & exit /b 1
