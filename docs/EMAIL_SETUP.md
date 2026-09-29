# Email Setup (one-time, ~2 minutes, no Google Cloud needed)

The apply session sends email over SMTP and checks replies over IMAP using a
**Google App Password** - Google's equivalent of a personal access token. It
lives until you revoke it. No OAuth, no cloud project, no verification.

You NEVER share your actual Google password. The app password only works for
mail, and only because 2-Step Verification protects the account.

## 1. Requirements

- The sending Gmail account must have **2-Step Verification** enabled:
  https://myaccount.google.com/security

## 2. Create the app password

1. Go to https://myaccount.google.com/apppasswords
2. Name it (e.g. "job-watcher") -> Create.
3. Google shows a 16-character password (spaces are cosmetic) - copy it.

## 3. Configure

Add to `.env` in the repo root (gitignored - never commit it):

```
GMAIL_USER=the.sending.account@gmail.com
GMAIL_APP_PASSWORD=abcd efgh ijkl mnop
```

## 4. Verify

```
pwsh -File tools\mailer.ps1 whoami          # returns the sending address
pwsh -File tools\mailer.ps1 send -To someone@example.com -Subject "test" -Body "hello"
pwsh -File tools\mailer.ps1 check-reply -From someone@example.com
```

## What each command does

| Command | Transport | Used by the apply session for |
|---|---|---|
| `send` | SMTP (attachments + threading headers supported) | Applications with CV, follow-up replies in the same thread |
| `draft` | IMAP APPEND into the Gmail Drafts folder | Queued emails for the per-recipient send cap |
| `check-reply` | IMAP SEARCH in INBOX | Detecting recruiter replies before following up |

The apply session (`opencode-apply-prompt.md`) calls these automatically.
Browser-based Gmail remains only as a fallback if SMTP/IMAP error out.

## Revoking

Remove the app password at https://myaccount.google.com/apppasswords and the
token stops working instantly. Nothing else to clean up.
