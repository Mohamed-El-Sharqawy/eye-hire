# gmail.ps1 - Gmail API helper used by the apply session (and humans).
# Requires GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REFRESH_TOKEN in ../.env
# (run tools\gmail-auth.ps1 once to create the refresh token - see docs/GMAIL_SETUP.md)
#
# Commands:
#   whoami                                  -> which account this token sends as
#   send   -To a@b.c -Subject "s" (-Body "..." | -BodyFile f.txt) [-Attach cv.pdf]
#          [-InReplyTo "<message-id@...>"]  -> send (threaded follow-up if InReplyTo)
#   draft  (same params as send)            -> save as draft instead of sending
#   find-sent -To a@b.c -Subject "s"        -> newest sent message matching (id, threadId, messageId header)
#   check-reply -ThreadId <threadId>        -> how many replies, and from whom
# Output: a single JSON line: { "ok": true/false, ... }

param(
    [Parameter(Mandatory = $true)][string]$Cmd,
    [string]$To, [string]$Subject, [string]$Body, [string]$BodyFile,
    [string]$Attach, [string]$InReplyTo, [string]$ThreadId
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

function Out([hashtable]$h, [int]$code = 0) {
    Write-Output ($h | ConvertTo-Json -Compress)
    exit $code
}
function Fail([string]$msg) { Out @{ ok = $false; error = $msg } 1 }

# --- load .env ---
$envMap = @{}
if (Test-Path "$root\.env") {
    Get-Content "$root\.env" | ForEach-Object {
        if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') { $envMap[$Matches[1]] = $Matches[2] }
    }
}
$cid = if ($env:GMAIL_CLIENT_ID) { $env:GMAIL_CLIENT_ID } else { $envMap["GMAIL_CLIENT_ID"] }
$secret = if ($env:GMAIL_CLIENT_SECRET) { $env:GMAIL_CLIENT_SECRET } else { $envMap["GMAIL_CLIENT_SECRET"] }
$rt = if ($env:GMAIL_REFRESH_TOKEN) { $env:GMAIL_REFRESH_TOKEN } else { $envMap["GMAIL_REFRESH_TOKEN"] }
if (-not $cid -or -not $secret -or -not $rt) { Fail "GMAIL_CLIENT_ID / GMAIL_CLIENT_SECRET / GMAIL_REFRESH_TOKEN missing in .env (run tools\gmail-auth.ps1 first)" }

try { $tok = Invoke-RestMethod -Method Post -Uri "https://oauth2.googleapis.com/token" -Body @{ client_id = $cid; client_secret = $secret; refresh_token = $rt; grant_type = "refresh_token" } }
catch { Fail "token refresh failed: $($_.Exception.Message)" }
$H = @{ Authorization = "Bearer $($tok.access_token)" }

function B64Url([byte[]]$b) { [Convert]::ToBase64String($b).TrimEnd('=').Replace('+', '-').Replace('/', '_') }

switch ($Cmd) {
    "whoami" {
        try { $p = Invoke-RestMethod -Uri "https://gmail.googleapis.com/gmail/v1/users/me/profile" -Headers $H }
        catch { Fail "profile failed: $($_.Exception.Message)" }
        Out @{ ok = $true; email = $p.emailAddress; messagesTotal = $p.messagesTotal }
    }
    "send" {
        if (-not $To -or -not $Subject) { Fail "send needs -To and -Subject" }
        $bodyText = if ($BodyFile) { (Get-Content $BodyFile -Raw) } elseif ($Body) { $Body } else { "" }
        $nl = "`r`n"
        $headers = "From: me$nl" + "To: $To$nl" + "Subject: $Subject$nl" + "MIME-Version: 1.0$nl"
        if ($InReplyTo) { $headers += "In-Reply-To: $InReplyTo$nl" + "References: $InReplyTo$nl" }
        if ($Attach) {
            if (-not (Test-Path $Attach)) { Fail "attachment not found: $Attach" }
            $fname = [IO.Path]::GetFileName($Attach)
            $mimeType = switch ([IO.Path]::GetExtension($Attach).ToLower()) {
                ".pdf" { "application/pdf" } ".doc" { "application/msword" }
                ".docx" { "application/vnd.openxmlformats-officedocument.wordprocessingml.document" }
                default { "application/octet-stream" }
            }
            $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Attach))
            $chunked = ($b64 -split '(.{76})' | Where-Object { $_ }) -join $nl
            $mime = $headers + "Content-Type: multipart/mixed; boundary=""JWBOUND""$nl$nl" +
                "--JWBOUND$nl" +
                "Content-Type: text/plain; charset=""UTF-8""$nl" +
                "Content-Transfer-Encoding: 8bit$nl$nl" +
                "$bodyText$nl" +
                "--JWBOUND$nl" +
                "Content-Type: $mimeType; name=""$fname""$nl" +
                "Content-Disposition: attachment; filename=""$fname""$nl" +
                "Content-Transfer-Encoding: base64$nl$nl" +
                "$chunked$nl" +
                "--JWBOUND--"
        } else {
            $mime = $headers + "Content-Type: text/plain; charset=""UTF-8""$nl" +
                "Content-Transfer-Encoding: 8bit$nl$nl" + $bodyText
        }
        try {
            $resp = Invoke-RestMethod -Method Post -Uri "https://gmail.googleapis.com/upload/gmail/v1/users/me/messages/send?uploadType=media" -Headers $H -ContentType "message/rfc822" -Body ([Text.Encoding]::UTF8.GetBytes($mime))
            Out @{ ok = $true; id = $resp.id; threadId = $resp.threadId; labelIds = $resp.labelIds }
        } catch { Fail "send failed: $($_.Exception.Message)" }
    }
    "draft" {
        if (-not $To -or -not $Subject) { Fail "draft needs -To and -Subject" }
        $bodyText = if ($BodyFile) { (Get-Content $BodyFile -Raw) } elseif ($Body) { $Body } else { "" }
        $nl = "`r`n"
        $mime = "From: me$nlTo: $To$nlSubject: $Subject$nlMIME-Version: 1.0$nlContent-Type: text/plain; charset=""UTF-8""$nl$nl$bodyText"
        $json = @{ message = @{ raw = (B64Url ([Text.Encoding]::UTF8.GetBytes($mime))) } } | ConvertTo-Json -Compress
        try {
            $resp = Invoke-RestMethod -Method Post -Uri "https://gmail.googleapis.com/gmail/v1/users/me/drafts" -Headers $H -ContentType "application/json" -Body $json
            Out @{ ok = $true; draftId = $resp.id; id = $resp.message.id; threadId = $resp.message.threadId }
        } catch { Fail "draft failed: $($_.Exception.Message)" }
    }
    "find-sent" {
        if (-not $To -or -not $Subject) { Fail "find-sent needs -To and -Subject" }
        $q = "in:sent to:$To subject:""$Subject"""
        try { $list = Invoke-RestMethod -Uri "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=$([uri]::EscapeDataString($q))&maxResults=1" -Headers $H }
        catch { Fail "search failed: $($_.Exception.Message)" }
        if (-not $list.messages) { Out @{ ok = $true; found = $false } }
        else {
            $m = Invoke-RestMethod -Uri "https://gmail.googleapis.com/gmail/v1/users/me/messages/$($list.messages[0].id)?format=metadata&metadataHeaders=Message-ID&metadataHeaders=Date&metadataHeaders=To&metadataHeaders=Subject" -Headers $H
            $mid = ($m.payload.headers | Where-Object name -eq "Message-ID").value
            Out @{ ok = $true; found = $true; id = $m.id; threadId = $m.threadId; messageIdHeader = $mid; date = $m.internalDate }
        }
    }
    "check-reply" {
        if (-not $ThreadId) { Fail "check-reply needs -ThreadId" }
        try {
            $me = (Invoke-RestMethod -Uri "https://gmail.googleapis.com/gmail/v1/users/me/profile" -Headers $H).emailAddress
            $t = Invoke-RestMethod -Uri "https://gmail.googleapis.com/gmail/v1/users/me/threads/$ThreadId?format=metadata&metadataHeaders=From" -Headers $H }
        catch { Fail "thread fetch failed: $($_.Exception.Message)" }
        $replies = @($t.messages | Where-Object {
                $from = ($_.payload.headers | Where-Object name -eq "From").value
                $from -and ($from -notmatch [regex]::Escape($me))
            })
        $lastFrom = if ($replies.Count -gt 0) { ($replies[-1].payload.headers | Where-Object name -eq "From").value } else { $null }
        Out @{ ok = $true; threadId = $ThreadId; total = $t.messages.Count; replies = $replies.Count; lastFrom = $lastFrom }
    }
    default { Fail "unknown command: $Cmd (use whoami | send | draft | find-sent | check-reply)" }
}
