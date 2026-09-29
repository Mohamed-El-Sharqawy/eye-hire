$task = "LinkedInJobWatcher"

schtasks /Change /TN $task /ENABLE | Out-Null

Write-Host ""
Write-Host "=== JOB WATCHER ENABLED ===" -ForegroundColor Green
Write-Host "Each hour at :00 it runs: JOB SEARCH -> JOB APPLY (chained, one after the other)."
Write-Host "First run at the next hour (:00), NOT immediately."
Write-Host "Search log:  Get-Content D:\UPWORK\job-watcher\opencode-runs.log -Tail 30 -Wait"
Write-Host "Apply log:   Get-Content D:\UPWORK\job-watcher\apply-runs.log -Tail 30 -Wait"
Write-Host ""
$q = schtasks /Query /TN $task /FO LIST | Select-String -Pattern "Next Run|Status"
$q | ForEach-Object { Write-Host $_.Line.Trim() }
Write-Host ""
Write-Host "Press Enter to close this window (the task keeps running)..."
Read-Host
