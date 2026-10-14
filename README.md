# Eye Hire

**Eye Hire** (previously "Job Watcher" - you may still see that name in legacy
script/log labels; it is the same system) is an autonomous, **personalized**
LinkedIn job watcher.
Every hour it searches fresh job posts and "we are hiring" feed posts, filters
them through **your** profile, and stores the hits in a Notion database.

Nothing about you is hardcoded: your roles, markets, keywords, experience cap
and credentials live in two gitignored files created during onboarding
(`profile.json` + `.env`). Anyone can clone this repo and configure their own
watcher in one session.

## Quick start (fresh clone)

````
git clone https://github.com/Mohamed-El-Sharqawy/eye-hire.git
cd eye-hire
opencode        # then just say: setup
````

The **setup interview** (`.opencode/agents/setup.md`) asks you a handful of
questions and configures everything:

1. **Profile** - target role families, stack keywords, seniority, max years of
   experience, leadership roles yes/no, roles to always exclude.
2. **Markets** - which cities/countries to search (e.g. the 7 UAE emirates +
   Cairo, or anywhere else), freshness window, distance.
3. **Feed posts** - optionally watch "we are hiring" posts per market.
4. **Caps** - max new jobs/posts stored per hourly run (defaults: 20 + 10).
5. **Notion credentials** - walks you through creating an integration, creates
   the jobs database (and optional run-log database) with the right schema,
   validates the token live, and writes `.env` for you. The token is never
   printed back.

It finishes by telling you exactly what to do next (log into LinkedIn,
`SELFTEST`, first run, hourly schedule).

Every session you start in the repo checks onboarding state first
(see `AGENTS.md`), so you can never accidentally run an unconfigured watcher.

## Architecture

````
 Scheduled Task "LinkedInJobWatcher" (hourly)
        |
        v
 run-watch.ps1  -->  opencode headless session (your default model)
                     + agent: .opencode/agents/watch.md
                     reads profile.json + .env at every session start
                     drives your logged-in browser via CDP (:9222)
                     => searches LinkedIn, stores fresh jobs in Notion
````

- **Watch** - one job search per location in your profile (past 24 h by default)
  + one content search per feed-post keyword. Gates: freshness, role relevance
  (YOUR role families), location (YOUR markets). Dedupe by link against Notion.
  Caps from your profile - only links not already in Notion count toward them,
  and every stored row gets your configured `Apply Status` (default `New`).
- **Config-driven** - the watch agent derives every search URL, gate and cap
  from `profile.json`. To search differently, update the profile (ask the setup
  agent "update my profile") - never edit tracked files to personalize.

### Standalone watcher (legacy, cross-platform)

`watcher.mjs` - a simple Node + Playwright script (guest LinkedIn access) that
searches hourly, extracts emails/phones from fresh job descriptions and saves
them to Notion. Kept as a lightweight fallback / reference.

````
docker build -t job-watcher .
docker run --env-file .env -p 3000:3000 job-watcher
````

or `npm start` (set the env vars from `.env.example` first).

## Files

| File | Purpose |
|---|---|
| `AGENTS.md` | Session-start rules: onboarding check, secret-safety, quick reference |
| `.opencode/agents/setup.md` | The onboarding interview: profile questions, Notion walkthrough, next-steps briefing |
| `.opencode/agents/watch.md` | The watch agent: config-driven searches/gates/caps, scrape-health watchdog, SELFTEST mode |
| `profile.example.json` | Documented shape of `profile.json` (your copy is gitignored) |
| `.env.example` | Documented shape of `.env` (NOTION_TOKEN, database ids) |
| `run-watch.ps1` | Session runner (portable paths, first-run guard, lock file, browser/CDP check) |
| `start/stop-watcher.ps1` + `START/STOP .bat` | Enable/disable the hourly scheduled task (auto-creates it on a new machine) |
| `run-watch-hidden.vbs` | Windowless launcher (self-locating - works in any clone path) |
| `watcher.mjs` | Legacy standalone Node watcher |
| `Dockerfile` | Container for the legacy watcher |

## Safety design

- Watch gates: freshness, role relevance (your profile only), your markets,
  experience and leadership filters - when in doubt, skip.
- Dedupe by normalized link against Notion - a known link is never re-opened.
- The `STOP` file pauses everything: every run checks it before each search.
- Secrets (`NOTION_TOKEN`) and personal data (`profile.json`) are gitignored and
  are never printed to chat or logs.

## Disclaimer

Automating LinkedIn may violate their Terms of Service and job boards may have
their own rules. This project was built for personal use; share and use it
responsibly and at your own risk.
