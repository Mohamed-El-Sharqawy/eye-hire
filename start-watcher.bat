@echo off
rem One click = one watch run NOW + the hourly schedule ON.
rem Watch only: searches jobs and adds them to Notion. Never applies to anything.

set "DIR=%~dp0"

rem 1. Resume: remove the STOP file, enable (or create) the schedule
if exist "%DIR%STOP" del "%DIR%STOP"
schtasks /Change /TN "LinkedInJobWatcher" /ENABLE >nul 2>&1
if errorlevel 1 (
    rem First run on this machine: the ps1 script creates the task
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%DIR%start-watcher.ps1"
    exit /b
)

rem 2. One watch run right now (minimized window; safe to close this bat)
start "Eye Hire watcher" /min pwsh -NoProfile -ExecutionPolicy Bypass -File "%DIR%run-watch.ps1"

echo.
echo Watcher started (see taskbar: "Eye Hire watcher").
echo Schedule ON: hourly at :00, search + Notion only. Known jobs never re-analyzed.
echo A run that is already active skips itself - no duplicates.
echo.
rem 4-second window delay (works without console input, unlike timeout)
ping -n 5 127.0.0.1 >nul
