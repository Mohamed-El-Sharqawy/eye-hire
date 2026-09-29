$task = "LinkedInJobWatcher"
$dir = "D:\UPWORK\job-watcher"

schtasks /Change /TN $task /DISABLE | Out-Null

Get-CimInstance Win32_Process -Filter "Name='opencode.exe'" |
    Where-Object { $_.CommandLine -match ' run ' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Get-CimInstance Win32_Process -Filter "Name='pwsh.exe'" |
    Where-Object { $_.CommandLine -match 'run-(watch|apply|all)\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Remove-Item "$dir\run.lock"   -Force -ErrorAction SilentlyContinue
Remove-Item "$dir\apply.lock" -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== JOB WATCHER STOPPED ===" -ForegroundColor Yellow
Write-Host "Hourly schedule disabled, any running session killed, locks cleared."
Write-Host "Your own OpenCode/TUI session was not touched."
Write-Host ""
Write-Host "Press Enter to close this window..."
Read-Host
