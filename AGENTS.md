# Eye Hire - agent instructions

**Read this at the start of EVERY session in this repo.**

Eye Hire is a personalized LinkedIn job watcher: an hourly session searches fresh
jobs + "we are hiring" posts, filters them through the owner's profile, and stores
hits in a Notion database. It drives the user's own logged-in browser over CDP.

## 1. Onboarding state check (always do this first)

Check in the repo root:

- `profile.json` - the user's search profile (roles, seniority, markets, caps). Personal, gitignored.
- `.env` - secrets (`NOTION_TOKEN`, `NOTION_DATABASE_ID`, optional `NOTION_LOG_DATABASE_ID`). Gitignored.

| State | What to do |
|---|---|
| Either file missing | **Run onboarding**: use the `setup` agent's interview (`.opencode/agents/setup.md`) to ask the user about their profile (role families, keywords, seniority, experience cap, leadership OK, exclusions, markets, feed posts, caps) and their Notion credentials (token + database, validated live). Write `profile.json` + `.env`, then give the user the final briefing (LinkedIn login, SELFTEST, first run, START/STOP). Do NOT launch the watch agent before onboarding completes. |
| Both present | Say onboarding is complete in one line, then answer what the user asked. |

If the user's first message IS the onboarding ask ("setup", "configure", "just cloned
this"), jump straight into the interview.

## 2. Hard rules

- NEVER print, log, or echo `NOTION_TOKEN` or any secret. Writing it to `.env` is the only allowed place.
- NEVER commit `profile.json`, `.env`, or any personal data. They are gitignored - keep it that way.
- The watch agent (`.opencode/agents/watch.md`) derives EVERYTHING from `profile.json` + `.env`. Never hardcode user-specific values back into tracked files.
- To change what the watcher searches for: update `profile.json` (via the `setup` agent or directly). To change how it works: edit `.opencode/agents/watch.md`.
- Windows is the primary platform (scheduled task + `.bat` launchers); everything also runs anywhere pwsh runs via `run-watch.ps1`.

## 3. Quick reference

- Manual run now: start opencode and tell the watch agent "run the hourly LinkedIn watch session now"
- Health check: send `SELFTEST` to the watch agent (one search, no Notion writes)
- Hourly schedule (Windows): `START Job Watcher.bat` / stop with `STOP Job Watcher.bat`
- Logs: `opencode-runs.log`; run summaries also go to the Notion Run Log database when configured
- Pause without killing anything: create a file named `STOP` in the repo root
