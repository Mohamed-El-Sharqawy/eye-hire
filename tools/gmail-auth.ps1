# gmail-auth.ps1 - ONE-TIME setup: mint a Gmail API refresh token.
# Prereqs (see docs/GMAIL_SETUP.md):
#   - Google Cloud project with Gmail API enabled
#   - OAuth consent screen configured + published
#   - "Desktop app" OAuth client created
#   - Redirect URI "http://localhost:8899/" added to that client
#   - GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET set in ../.env
# Run:  pwsh -File tools\gmail-auth.ps1
# Consent with the account you want to SEND from. Paste the printed refresh
# token into ../.env as GMAIL_REFRESH_TOKEN.

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

# --- load .env ---
$envMap = @{}
if (Test-Path "$root\.env") {
    Get-Content "$root\.env" | ForEach-Object {
        if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') { $envMap[$Matches[1]] = $Matches[2] }
    }
}
$cid = if ($env:GMAIL_CLIENT_ID) { $env:GMAIL_CLIENT_ID } else { $envMap["GMAIL_CLIENT_ID"] }
$secret = if ($env:GMAIL_CLIENT_SECRET) { $env:GMAIL_CLIENT_SECRET } else { $envMap["GMAIL_CLIENT_SECRET"] }
if (-not $cid -or -not $secret) { Write-Error "GMAIL_CLIENT_ID / GMAIL_CLIENT_SECRET missing in .env"; exit 1 }

$port = 8899
$redirect = "http://localhost:$port/"
$scopes = "https://www.googleapis.com/auth/gmail.send https://www.googleapis.com/auth/gmail.readonly"
$authUrl = "https://accounts.google.com/o/oauth2/v2/auth?client_id=$cid&redirect_uri=$([uri]::EscapeDataString($redirect))&response_type=code&scope=$([uri]::EscapeDataString($scopes))&access_type=offline&prompt=consent"

Write-Host ""
Write-Host "Opening browser for Google consent..." -ForegroundColor Cyan
Write-Host "(if nothing opens, paste this URL manually):" -ForegroundColor Yellow
Write-Host $authUrl
Start-Process $authUrl

# --- raw TCP loopback listener (no admin/URLACL needed) ---
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)
$listener.Start()
Write-Host "Waiting for consent redirect on $redirect ..." -ForegroundColor Cyan
$code = $null
while (-not $code) {
    $client = $listener.AcceptTcpClient()
    $stream = $client.GetStream()
    $reader = [System.IO.StreamReader]::new($stream)
    $requestLine = $reader.ReadLine()
    if ($requestLine -match 'GET\s+(\S+)') {
        $path = $Matches[1]
        if ($path -match '[?&]code=([^&\s]+)') { $code = [uri]::UnescapeDataString($Matches[1]) }
        $html = if ($code) { "<h2>OK - you can close this tab.</h2>" } else { "<h2>No code found - check the console.</h2>" }
        $resp = "HTTP/1.1 200 OK`r`nContent-Type: text/html`r`nContent-Length: $([Text.Encoding]::UTF8.GetByteCount($html))`r`nConnection: close`r`n`r`n$html"
        $bytes = [Text.Encoding]::UTF8.GetBytes($resp)
        $stream.Write($bytes, 0, $bytes.Length)
    }
    $client.Close()
}
$listener.Stop()

# --- exchange code for tokens ---
$resp2 = Invoke-RestMethod -Method Post -Uri "https://oauth2.googleapis.com/token" -Body @{
    client_id = $cid; client_secret = $secret; code = $code
    grant_type = "authorization_code"; redirect_uri = $redirect
}
Write-Host ""
Write-Host "=== SUCCESS ===" -ForegroundColor Green
Write-Host "Add this line to .env (repo root):" -ForegroundColor Green
Write-Host ""
Write-Host "GMAIL_REFRESH_TOKEN=$($resp2.refresh_token)"
Write-Host ""
if (-not $resp2.refresh_token) { Write-Warning "No refresh token returned - re-run with prompt=consent (already included) or remove the app's access at https://myaccount.google.com/permissions and retry." }
