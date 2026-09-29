$ErrorActionPreference = "Continue"
$dir = $PSScriptRoot
$log = "$dir\opencode-runs.log"
$lock = "$dir\run.lock"

function Log($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Add-Content $log }

if (Test-Path $lock) {
    $age = (Get-Date) - (Get-Item $lock).LastWriteTime
    if ($age.TotalMinutes -lt 120) { Log "previous run still active (lock age $([int]$age.TotalMinutes) min), skipping"; exit 0 }
}
New-Item $lock -Force | Out-Null
try {

# Load secrets from .env (never hardcode tokens in scripts)
if (-not $env:NOTION_TOKEN) {
    $envFile = Join-Path $dir ".env"
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^\s*([^#=\s]+)\s*=\s*(.*)\s*$') { [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], "Process") }
        }
    }
}
if (-not $env:NOTION_TOKEN) { Log "NOTION_TOKEN missing - set it in .env (see .env.example), aborting"; exit 1 }

$cdpUp = (Test-NetConnection 127.0.0.1 -Port 9222 -InformationLevel Quiet -WarningAction SilentlyContinue)
if (-not $cdpUp) {
    $braveRunning = [bool](Get-Process brave -ErrorAction SilentlyContinue)
    if ($braveRunning) {
        Log "Brave running without CDP - restarting Brave with debug port"
        Get-Process brave -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 3
    }
    $brave = "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe"
    if (-not (Test-Path $brave)) { $brave = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe" }
    if (Test-Path $brave) {
        Log "starting Brave with CDP"
        Start-Process $brave -ArgumentList "--remote-debugging-port=9222", "--restore-last-session"
        Start-Sleep -Seconds 10
    } else {
        Log "Brave not found, aborting"
        exit 1
    }
}

$cdpUp = (Test-NetConnection 127.0.0.1 -Port 9222 -InformationLevel Quiet -WarningAction SilentlyContinue)
if (-not $cdpUp) { Log "CDP still down after Brave start, aborting"; exit 1 }

$prompt = Get-Content "$dir\opencode-prompt.md" -Raw
Log "=== starting opencode session ==="
& "opencode" run --model "glm-5.3-flash" $prompt *>> $log
Log "=== session finished (exit $LASTEXITCODE) ==="

} finally {
    Remove-Item $lock -Force -ErrorAction SilentlyContinue
}
