$task = "LinkedInJobWatcher"
$dir = $PSScriptRoot

# Resume: remove the STOP file, re-enable (or create) the schedule
Remove-Item "$dir\STOP" -Force -ErrorAction SilentlyContinue

$exists = schtasks /Query /TN $task 2>$null
if ($LASTEXITCODE -ne 0) {
    # First run on this machine: create the hourly task pointing at THIS clone
    $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $pwsh) { $pwsh = "powershell" }
    schtasks /Create /TN $task /TR "`"$pwsh`" -NoProfile -ExecutionPolicy Bypass -File `"$dir\run-watch.ps1`"" /SC HOURLY /MO 1 /F | Out-Null
    Write-Host "Created hourly scheduled task '$task' -> $dir\run-watch.ps1"
} else {
    schtasks /Change /TN $task /ENABLE | Out-Null
}

# Caps shown below come from YOUR profile.json
$caps = "20 new jobs/run, 10 new posts/run"
if (Test-Path "$dir\profile.json") {
    try { $p = Get-Content "$dir\profile.json" -Raw | ConvertFrom-Json; $caps = "$($p.caps.newJobsPerRun) new jobs/run, $($p.caps.newPostsPerRun) new posts/run" } catch {}
}

Write-Host ""
Write-Host "=== JOB WATCHER RUNNING ===" -ForegroundColor Green
Write-Host "STOP file removed. Schedule active: every hour, watch only"
Write-Host "(search jobs -> Notion; hourly at :00; caps: $caps; known jobs never re-analyzed; no scoring, no applying)."
Write-Host "First run at the next hour slot, NOT immediately."
Write-Host "Manual run now:  Start-ScheduledTask -TaskName '$task'"
Write-Host "Search log:      Get-Content $dir\opencode-runs.log -Tail 30 -Wait"
Write-Host "Stop again:      double-click 'STOP Job Watcher.bat' (or create $dir\STOP)"
Write-Host ""
$q = schtasks /Query /TN $task /FO LIST | Select-String -Pattern "Next Run|Status"
$q | ForEach-Object { Write-Host $_.Line.Trim() }
Write-Host ""
Write-Host "Press Enter to close this window (the task keeps running)..."
Read-Host
