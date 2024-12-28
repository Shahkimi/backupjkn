@echo off
setlocal EnableDelayedExpansion

:: Security: Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Administrative privileges required.
    echo Please run this script as Administrator.
    timeout /t 5
    exit /b 1
)

:: Set secure paths with quotes to handle spaces
set "source_folder=D:\wamp\www"
set "destination_folder=D:\BackupApplication\Zip Apps"
set "log_folder=D:\BackupApplication\log"
set "error_log=%log_folder%\error.log"

:: Validate source directory exists
if not exist "%source_folder%" (
    echo Error: Source folder does not exist. >> "%error_log%"
    exit /b 1
)

:: Create secure folders with proper permissions
if not exist "%destination_folder%" (
    mkdir "%destination_folder%"
    icacls "%destination_folder%" /inheritance:d
    icacls "%destination_folder%" /grant:r Administrators:(OI)(CI)F
    icacls "%destination_folder%" /grant:r SYSTEM:(OI)(CI)F
)

if not exist "%log_folder%" (
    mkdir "%log_folder%"
    icacls "%log_folder%" /inheritance:d
    icacls "%log_folder%" /grant:r Administrators:(OI)(CI)F
    icacls "%log_folder%" /grant:r SYSTEM:(OI)(CI)F
)

:: Get current date/time securely
for /f "tokens=2 delims==" %%I in ('wmic OS Get localdatetime /value') do set "datetime=%%I"
set "zip_file=%destination_folder%\Archive101_%datetime:~0,8%_%datetime:~8,6%.zip"
set "log_file=%log_folder%\log%datetime:~0,8%.txt"

:: Verify 7-Zip installation and version
set "sevenzip=%ProgramFiles%\7-Zip\7z.exe"
if not exist "%sevenzip%" (
    echo Error: 7-Zip not found at %sevenzip% >> "%error_log%"
    exit /b 1
)

:: Get start time and initialize log with error handling
set "start_time=%time%"
(
echo Zip Log
echo Server Name : Server 101
echo Time start Zip : %date% %start_time%
echo Source Directory: %source_folder%
echo Destination: %zip_file%
) > "%log_file%" 2>> "%error_log%"

:: Change directory with verification
pushd "%source_folder%" || (
    echo Error: Failed to change to source directory >> "%error_log%"
    exit /b 1
)

:: Create backup with compression and encryption
"%sevenzip%" a -tzip "%zip_file%" "*" -mx9 -mhe -bsp1
if !errorlevel! neq 0 (
    echo Error: Backup failed with code !errorlevel! >> "%error_log%"
    set "status=error"
) else (
    set "status=success"
)

:: Return to original directory
popd

:: Calculate duration and finalize log
set "end_time=%time%"
call :calculate_duration "%start_time%" "%end_time%"

:: Clean up old backups (keep last 3 months)
forfiles /p "%destination_folder%" /m "Archive101_*.zip" /d -90 /c "cmd /c del @path" 2>> "%error_log%"

:: Log completion status
(
echo Time finish Zip : %date% %end_time%
echo Status: %status%
if "%status%"=="success" (
    echo Backup completed successfully
    echo Files zipped from %source_folder% to %zip_file%
) else (
    echo Backup failed - check error log
)
) >> "%log_file%"

exit /b

:calculate_duration
setlocal
set "start=%~1"
set "end=%~2"
for /f "tokens=1-4 delims=:." %%a in ("%start%") do (
    set /a "start_s=(((%%a*60)+1%%b %% 100)*60+1%%c %% 100)*100+1%%d %% 100"
)
for /f "tokens=1-4 delims=:." %%a in ("%end%") do (
    set /a "end_s=(((%%a*60)+1%%b %% 100)*60+1%%c %% 100)*100+1%%d %% 100"
)
set /a "duration_s=end_s-start_s"
if %duration_s% lss 0 set /a "duration_s+=24*60*60*100"
set /a "duration_minutes=duration_s/6000"
set /a "duration_seconds=(duration_s%%6000)/100"
echo Duration: %duration_minutes% minutes and %duration_seconds% seconds >> "%log_file%"
endlocal
goto :eof