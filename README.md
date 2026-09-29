# Job Watcher

An autonomous LinkedIn job watcher **and auto-applier** for the UAE + Egypt market.
Every hour it searches fresh job posts and "we are hiring" feed posts, filters for
relevant software-engineering roles, stores them in a Notion database, then applies
on your behalf - LinkedIn Easy Apply, application forms, or hook-driven emails sent
from your own Gmail - and tracks every outcome in Notion.

## Architecture

The project has two components:

### 1. Agentic pipeline (primary, Windows)

```
 Scheduled Task "LinkedInJobWatcher" (hourly)
        |
        v
 run-all.ps1
   |-- run-watch.ps1  -->  opencode headless session (glm-5.3-flash)
   |                         + agent: .opencode/agents/watch.md
   |                         drives logged-in Brave via CDP (:9222)
   |                         => searches LinkedIn, stores fresh jobs in Notion
   |-- run-apply.ps1  -->  opencode headless session
                            + agent: .opencode/agents/apply.md
                            + answers.md (screening question bank)
                            => applies to every pending row, records outcome
```

- **Watch** - 8 job searches (7 UAE emirates + Cairo, past 24 h) + 4 "we are hiring"
  content searches (past hour). Gates: freshness, role relevance (software eng only),
  location (UAE/Egypt only). Dedupe by link against Notion. Storage is uncapped:
  everything that passes the gates gets a row with `Apply Status = New`.
- **Apply** - processes the whole pending queue. Picks 1 of 4 CVs
  (Frontend / Full-Stack x UAE / Egypt), answers screening questions from
  `answers.md`, applies via Easy Apply -> Gmail email -> external URL.
  Any required field it cannot answer (salary by policy, or anything missing from
  the answer bank) is never guessed: it saves state, pops a Windows notification
  (MessageBox + beeps), marks the row `Waiting For You`, and resumes automatically
  once you fill it in. Emails that cannot be auto-sent are left as ready-to-send
  Gmail drafts. Failed rows auto-retry once. Applied-by-email rows get one
  spam-safe follow-up after 3 days (same thread, only if no reply).

### 2. Standalone watcher (legacy, cross-platform)

`watcher.mjs` - a simple Node + Playwright script (guest LinkedIn access) that
searches 7 emirates hourly, extracts emails/phones from fresh job descriptions and
saves them to Notion. Kept as a lightweight fallback / reference; it does not apply.

```
docker build -t job-watcher .
docker run --env-file .env -p 3000:3000 job-watcher
```

or `npm start` (set the env vars from `.env.example` first).

## Setup

1. **Notion** - create an integration, get a token, and create (or pick) a database.
   Share the database with the integration. The database uses these properties
   (the apply session auto-creates the missing ones):
   `Name` (title), `Company`, `Emirate` (select), `Link` (url), `Email`, `Phone`,
   `Found At` (date), `Search URL` (url), `Apply Status` (select: New / Applied /
   Manual Needed / Not Relevant / Failed / Waiting For You), `Apply Notes`,
   `CV Used`, `Needs Manual Apply` (checkbox), `Apply URL`, `Applied Via`,
   `Email Sent At` (date), `Follow-Up Sent At` (date).
   A second database (optional) is used as the run log.
   Put both IDs in `.env` / prompts.
2. **Config** - copy `.env.example` to `.env` and fill in `NOTION_TOKEN` and
   `NOTION_DATABASE_ID`. Never hardcode the token anywhere else.
3. **opencode** - install opencode and make sure it is on PATH
   (the wrappers call it headless: `opencode run --dir <repo> --agent <agent> <goal>`).
4. **Brave + CDP** - the pipeline drives your logged-in Brave over CDP on port
   9222. `run-watch.ps1` / `run-apply.ps1` start or restart Brave with the debug
   flag automatically. Log into LinkedIn and Gmail in that browser profile.
5. **Personalize** - edit `answers.md` (screening answers + Open Questions), the
   CV matrix, contact details and Gmail sender account in
   `.opencode/agents/apply.md`, and the search keywords/locations in
   `.opencode/agents/watch.md`. Replace before use.
6. **Gmail sending** - follow `docs/EMAIL_SETUP.md`: enable 2-Step Verification,
   create a Google App Password, put `GMAIL_USER` + `GMAIL_APP_PASSWORD` in `.env`.
   Email sending runs over SMTP with IMAP for reply detection - deterministic
   sends with CV attachments and thread-aware follow-ups. Browser Gmail stays as
   a fallback.
7. **Schedule** - `START Job Watcher.bat` enables the hourly Windows task
   (`LinkedInJobWatcher`), `STOP Job Watcher.bat` disables it and kills any
   running session. Logs: `opencode-runs.log` (search) and `apply-runs.log` (apply).
   Health checks: `opencode run --agent watch "SELFTEST"` (scraper health) and
   `opencode run --agent apply "SELFCHECK"` (Notion schema + mailer identity).

## Files

| File | Purpose |
|---|---|
| `.opencode/agents/watch.md` | The watch agent: hourly searches, gates, scrape-health watchdog + SELFTEST, uncapped storage |
| `.opencode/agents/apply.md` | The apply agent: queue drain (newest first), Easy Apply / external ATS forms / email via `tools\mailer.ps1`, ping flow, follow-ups + SELFCHECK |
| `answers.md` | Screening question bank + self-growing Open Questions - source of truth for form answers |
| `tools/mailer.ps1` | SMTP send / IMAP draft / IMAP reply-check helper (Google App Password) |
| `run-all.ps1` / `run-watch.ps1` / `run-apply.ps1` | Session runners (lock files, Brave/CDP check, `opencode run --agent ...`) |
| `start/stop-watcher.ps1` + `START/STOP .bat` | Enable/disable the hourly scheduled task |
| `watcher.mjs` | Legacy standalone Node watcher |
| `Dockerfile` | Container for the legacy watcher |

## Safety design

- Apply guard rails: role + location gates, "one bad application is worse than one
  missed", mandatory outcome status + notes on every processed row, never touch
  rows that already have a final status.
- `Manual Needed` is reserved for physical blockers only (captcha, login walls,
  assessments). Missing *answers* go through the answer bank or the ping flow.
- Salary is never auto-entered. Ever.
- Email deliverability: plain text, no link spam, varied wording, one sent email
  per recipient per run, at most one follow-up ever, sent in the same thread.

## Disclaimer

Automating LinkedIn may violate their Terms of Service and job boards may have
their own rules. This project was built for personal use; share and use it
responsibly and at your own risk. Don't spam recruiters - the world has enough
of that already.

