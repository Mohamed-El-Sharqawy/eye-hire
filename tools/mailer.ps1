# mailer.ps1 - Email helper for the apply session (SMTP + IMAP, app password).
# Requires in ../.env:  GMAIL_USER (sending address) and GMAIL_APP_PASSWORD
# (16-char Google App Password - create at myaccount.google.com/apppasswords,
# needs 2-Step Verification enabled; see docs/EMAIL_SETUP.md).
#
# Commands:
#   whoami                              -> the configured sending address
#   send   -To a@b.c -Subject "s" (-Body "..." | -BodyFile f.txt) [-Attach cv.pdf]
#          [-InReplyTo "<message-id@...>"] -> send (threaded follow-up if InReplyTo)
#   draft  (same params as send)        -> append the message to the Gmail Drafts folder (IMAP)
#   check-reply -From a@b.c [-Since yyyy-mm-dd] -> count of messages from that address in INBOX
# Output: a single JSON line: { "ok": true/false, ... }

param(
    [Parameter(Mandatory = $true)][string]$Cmd,
    [string]$To, [string]$Subject, [string]$Body, [string]$BodyFile,
    [string]$Attach, [string]$InReplyTo, [string]$From, [string]$Since
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
$GUser = if ($env:GMAIL_USER) { $env:GMAIL_USER } else { $envMap["GMAIL_USER"] }
$GPass = if ($env:GMAIL_APP_PASSWORD) { $env:GMAIL_APP_PASSWORD } else { $envMap["GMAIL_APP_PASSWORD"] }
if (-not $GUser -or -not $GPass) { Fail "GMAIL_USER / GMAIL_APP_PASSWORD missing in .env (see docs/EMAIL_SETUP.md)" }
$From = if ($From) { $From } else { $GUser }

function Read-MimeText {
    if ($BodyFile) { return (Get-Content $BodyFile -Raw) }
    if ($Body) { return $Body }
    return ""
}
function New-MessageId { return "<jw.$([guid]::NewGuid().ToString('N'))@job-watcher.mail>" }

switch ($Cmd) {

    "whoami" { Out @{ ok = $true; email = $GUser } }

    "send" {
        if (-not $To -or -not $Subject) { Fail "send needs -To and -Subject" }
        try {
            $smtp = [System.Net.Mail.SmtpClient]::new("smtp.gmail.com", 587)
            $smtp.EnableSsl = $true
            $smtp.Credentials = [System.Net.NetworkCredential]::new($GUser, $GPass)
            $msg = [System.Net.Mail.MailMessage]::new()
            $msg.From = [System.Net.Mail.MailAddress]::new($From)
            $msg.To.Add($To)
            $msg.Subject = $Subject
            $msg.SubjectEncoding = [Text.Encoding]::UTF8
            $msg.Body = Read-MimeText
            $msg.BodyEncoding = [Text.Encoding]::UTF8
            $mid = New-MessageId
            $msg.Headers.Add("Message-ID", $mid)
            if ($InReplyTo) { $msg.Headers.Add("In-Reply-To", $InReplyTo); $msg.Headers.Add("References", $InReplyTo) }
            if ($Attach) {
                if (-not (Test-Path $Attach)) { Fail "attachment not found: $Attach" }
                $msg.Attachments.Add([System.Net.Mail.Attachment]::new($Attach, "application/pdf")) | Out-Null
            }
            $smtp.Send($msg)
            $msg.Dispose(); $smtp.Dispose()
            Out @{ ok = $true; messageId = $mid; to = $To }
        } catch { Fail "smtp send failed: $($_.Exception.Message)" }
    }

    "draft" {
        # No SMTP drafts: append the MIME message into the Gmail Drafts folder via IMAP.
        if (-not $To -or -not $Subject) { Fail "draft needs -To and -Subject" }
        $bodyText = Read-MimeText
        $nl = "`r`n"
        $mid = New-MessageId
        $mime = "From: $From$nl" + "To: $To$nl" + "Subject: $Subject$nl" + "MIME-Version: 1.0$nl" +
            "Message-ID: $mid$nl" + "Content-Type: text/plain; charset=""UTF-8""$nl$nl" + $bodyText
        try {
            $r = Invoke-ImapDraft -User $GUser -Pass $GPass -Mime $mime
            Out @{ ok = $true; messageId = $mid; draftFolder = $r }
        } catch { Fail "imap draft failed: $($_.Exception.Message)" }
    }

    "check-reply" {
        if (-not $From -and -not $To) { Fail "check-reply needs -From (the recipient you wrote to)" }
        $addr = if ($From) { $From } else { $To }
        try {
            $count = Invoke-ImapSearchFrom -User $GUser -Pass $GPass -Address $addr -Since $Since
            Out @{ ok = $true; from = $addr; since = $Since; replies = $count }
        } catch { Fail "imap search failed: $($_.Exception.Message)" }
    }

    default { Fail "unknown command: $Cmd (use whoami | send | draft | check-reply)" }
}

# ---------- IMAP helpers (minimal, SSL, no external deps) ----------

function Invoke-ImapSession([string]$user, [string]$pass, [scriptblock]$script) {
    $tcp = [System.Net.Sockets.TcpClient]::new("imap.gmail.com", 993)
    try {
        $ssl = [System.Net.SslStream]::new($tcp.GetStream())
        $ssl.AuthenticateAsClient("imap.gmail.com")
        $rd = [System.IO.StreamReader]::new($ssl, [Text.Encoding]::ASCII)
        $script:tagN = 0
        $null = $rd.ReadLine()   # greeting
        function T([string]$c) {
            $script:tagN++
            $tag = "A$script:tagN"
            $ssl.Write([Text.Encoding]::ASCII.GetBytes("$tag $c`r`n"), 0, ("$tag $c`r`n").Length)
            $lines = @()
            while ($true) {
                $line = $rd.ReadLine()
                $lines += $line
                if ($line -match "^$tag ") { break }
            }
            $status = ($lines | Where-Object { $_ -match "^$tag " } | Select-Object -First 1)
            if ($status -notmatch " OK$") { throw "IMAP error: $status" }
            return $lines
        }
        $null = T "LOGIN ""$user"" ""$pass"""
        $result = & $script $ssl $rd ${function:T}
        $null = T "LOGOUT"
        return $result
    } finally { $tcp.Close() }
}

function Get-DraftFolder($ssl, $rd, $T) {
    $list = T 'LIST "" "*"'
    foreach ($l in $list) { if ($l -match '\\Drafts') { if ($l -match '"([^"]+)"\s*$') { return $Matches[1] } } }
    return '"[Gmail]/Drafts"'
}

function Invoke-ImapDraft([string]$user, [string]$pass, [string]$mime) {
    Invoke-ImapSession $user $pass {
        param($ssl, $rd, $T)
        $folder = Get-DraftFolder $ssl $rd $T
        $bytes = [Text.Encoding]::UTF8.GetBytes($mime)
        $ssl.Write([Text.Encoding]::ASCII.GetBytes("X1 APPEND $folder (\Draft) {$($bytes.Length)}`r`n"), 0, ("X1 APPEND $folder (\Draft) {$($bytes.Length)}`r`n").Length)
        $cont = $rd.ReadLine()
        if ($cont -notmatch '^\+') { throw "expected continuation, got: $cont" }
        $ssl.Write($bytes, 0, $bytes.Length)
        $ssl.Write([Text.Encoding]::ASCII.GetBytes("`r`n"), 0, 2)
        $lines = @()
        while ($true) { $line = $rd.ReadLine(); if ($line -match "^X1 ") { $lines += $line; break } }
        if ($lines[0] -notmatch " OK$") { throw "APPEND failed: $($lines[0])" }
        return $folder
    }
}

function Invoke-ImapSearchFrom([string]$user, [string]$pass, [string]$address, [string]$since) {
    Invoke-ImapSession $user $pass {
        param($ssl, $rd, $T)
        $null = T 'SELECT "INBOX"'
        $crit = "FROM ""$address"""
        if ($since) {
            $d = [datetime]::Parse($since)
            $crit += " SINCE $($d.ToString('dd-MMM-yyyy'))"
        }
        $lines = T "SEARCH $crit"
        $searchLine = ($lines | Where-Object { $_ -match '^\* SEARCH' } | Select-Object -First 1)
        if (-not $searchLine) { return 0 }
        $nums = ($searchLine -replace '^\* SEARCH', '').Trim()
        if (-not $nums) { return 0 }
        return ($nums -split '\s+').Count
    }
}
