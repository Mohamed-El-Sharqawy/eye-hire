$ErrorActionPreference = "Continue"
$dir = $PSScriptRoot
$log = "$dir\opencode-runs.log"
$lock = "$dir\run.lock"

function Log($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Add-Content $log }

# STOP file: create <repo>\STOP to pause; delete it to resume
if (Test-Path "$dir\STOP") { Log "STOP file present - skipping this run"; exit 0 }

# First-run guard: the watcher is config-driven. No profile.json / .env = no run.
$missing = @()
if (-not (Test-Path "$dir\profile.json")) { $missing += "profile.json" }
if (-not (Test-Path "$dir\.env")) { $missing += ".env" }
if ($missing.Count -gt 0) {
    Log "NOT CONFIGURED - missing $($missing -join ', ')"
    Write-Host "Eye Hire is not configured yet (missing: $($missing -join ', '))." -ForegroundColor Yellow
    Write-Host "Run the onboarding interview once:"
    Write-Host "  1. open a terminal in this folder"
    Write-Host "  2. run: opencode"
    Write-Host "  3. say: setup"
    Write-Host "It asks about your profile (roles, markets, caps), creates your Notion"
    Write-Host "database, validates the token, and writes profile.json + .env for you."
    exit 1
}

if (Test-Path $lock) {
    $age = (Get-Date) - (Get-Item $lock).LastWriteTime
    if ($age.TotalMinutes -lt 70) { Log "previous run still active (lock age $([int]$age.TotalMinutes) min), skipping"; exit 0 }
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
    if (-not (Test-Path $brave)) { $brave = "C:\Program Files\Google\Chrome\Application\chrome.exe" }
    if (-not (Test-Path $brave)) { $brave = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe" }
    if (Test-Path $brave) {
        Log "starting browser with CDP"
        Start-Process $brave -ArgumentList "--remote-debugging-port=9222", "--restore-last-session"
        Start-Sleep -Seconds 10
    } else {
        Log "Brave/Chrome not found, aborting"
        exit 1
    }
}

$cdpUp = (Test-NetConnection 127.0.0.1 -Port 9222 -InformationLevel Quiet -WarningAction SilentlyContinue)
if (-not $cdpUp) { Log "CDP still down after browser start, aborting"; exit 1 }

# Locate opencode: prefer the known bun install, then any PATH .exe, then anything on PATH.
# (Resolving a wrong shim prints CLI help and exits 1 - the 2026-10-14 10:20 failure.)
$oc = $null
if (Test-Path "$env:USERPROFILE\.bun\bin\opencode.exe") { $oc = "$env:USERPROFILE\.bun\bin\opencode.exe" }
if (-not $oc) {
    foreach ($cmd in (Get-Command opencode -All -ErrorAction SilentlyContinue)) {
        if ($cmd.Source -like "*.exe") { $oc = $cmd.Source; break }
    }
}
if (-not $oc) { $c = Get-Command opencode -ErrorAction SilentlyContinue; if ($c) { $oc = $c.Source } }
if (-not $oc) { Log "opencode.exe not found (looked in ~/.bun/bin and PATH) - install opencode first"; exit 1 }

Log "=== starting watch agent ==="
Set-Location $dir
$modelArgs = @()
if ($env:WATCH_MODEL) { $modelArgs = @("-m", $env:WATCH_MODEL) }
& $oc run --agent watch @modelArgs "Run the hourly LinkedIn watch session now." *>> $log
Log "=== watch agent finished (exit $LASTEXITCODE) ==="

} finally {
    Remove-Item $lock -Force -ErrorAction SilentlyContinue
}
