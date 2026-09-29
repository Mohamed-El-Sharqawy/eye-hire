# LinkedIn Job Watch Task

You are running a scheduled job-watch session. Follow these steps exactly. Be fast and efficient.

## TOOL RULE (critical)

Use ONLY the built-in browser tools: browser_open, browser_navigate, browser_snapshot, browser_get_text, browser_query, browser_get_html, browser_click.
Do NOT use the agent-browser CLI, agent-browser skills, Playwright, or any shell-based browser automation. Ignore any skill description that suggests otherwise.

## Step 1 - Search LinkedIn (7 emirates + Cairo)

For each location below, open this URL pattern in the browser (it is already logged into LinkedIn):

https://www.linkedin.com/jobs/search/?keywords=%22full%20stack%22%20OR%20frontend%20OR%20backend&location=<LOCATION_URL_ENCODED>&f_TPR=r86400&f_E=1%2C2%2C3%2C4&distance=100

f_TPR=r86400 = jobs posted in the LAST 24 HOURS. f_E=1,2,3,4 = Internship, Entry, Associate AND Mid-Senior level. distance=100 removes the 40 km radius cap (candidate accepts remote, on-site, and hybrid anywhere in the emirate/Cairo).

Locations (URL-encode the comma and spaces):
1. Dubai, Dubai, United Arab Emirates
2. Abu Dhabi Emirate, United Arab Emirates
3. Sharjah Emirate, United Arab Emirates
4. Ajman, United Arab Emirates
5. Umm Al Quwain, United Arab Emirates
6. Ras al-Khaimah, United Arab Emirates
7. Fujairah, United Arab Emirates
8. Cairo, Cairo, Egypt

## Step 2 - Collect fresh cards (NO CAP - store everything)

On each search page, collect EVERY job card: title, company, job link (strip everything after "?"), and the posted-time text.
The r86400 parameter already pre-filters to the past 24 hours. As a safety gate, keep a card only if its posted-time shows: "just now", seconds, minutes, hours, or exactly "1 day ago".
Discard: "2 days", "3 days", "week", "month", or empty posted-time.
Read the results header ("N results") and note it.

**There is NO maximum number of jobs.** Page through ALL results (use the pagination buttons / &start=25, &start=50... on the URL) until the result list ends. Open and examine every card that passes the gate. If a run finds 3 jobs, store 3. If it finds a thousand, store a thousand. Never skip or sample cards to save time.

## Step 3 - Extract contact info

For each kept job, open the job link and read the full description. Extract:
- emails matching something@domain.tld (ignore image filenames like @2x.png)
- phone numbers matching +971..., 05X XXX XXXX, or international +<country><9-12 digits>

Contact info is RECORDED but NOT required for storage: store every job that passes the gates, even with no email/phone - the applier will use Easy Apply or the apply button instead.

## Step 3b - Search regular feed posts (hiring posts)

Open these 4 content searches in the browser (logged-in session):

1. https://www.linkedin.com/search/results/content/?keywords=fullstack%20dubai&origin=SWITCH_SEARCH_VERTICAL&datePosted=%5B%22past-24h%22%5D
2. https://www.linkedin.com/search/results/content/?keywords=%22we%20are%20hiring%22%20frontend%20uae&origin=SWITCH_SEARCH_VERTICAL&datePosted=%5B%22past-24h%22%5D
3. https://www.linkedin.com/search/results/content/?keywords=%22we%20are%20hiring%22%20backend%20uae&origin=SWITCH_SEARCH_VERTICAL&datePosted=%5B%22past-24h%22%5D
4. https://www.linkedin.com/search/results/content/?keywords=%22we%20are%20hiring%22%20cairo&origin=SWITCH_SEARCH_VERTICAL&datePosted=%5B%22past-24h%22%5D

The datePosted parameter pre-filters results to the past 24 hours (LinkedIn has no past-hour filter for content search). Your freshness gate still applies: only keep posts showing minutes or "1h".

For each page, collect feed post cards: the author name, the post text, and the post permalink.
The permalink is the card link containing "/posts/" — or if it contains "/feed/update/urn:li:activity:ID", use "https://www.linkedin.com/feed/update/urn:li:activity:ID" as the link.
KEEP ONLY posts posted within the LAST HOUR: timestamp must be "just now", a number of minutes (" Xm"), or exactly "1h"/"1 hour".
SKIP anything older: "2h", "3h", "1d", "1 week", etc. — even if it has contact info. Old posts are never stored.

There is NO maximum number of posts. Examine every candidate post on every page of results, for all 4 searches. A candidate without a resolvable permalink CANNOT be saved (dedupe depends on the link) - but always try the click method before giving up.

From each post's full text extract:
- emails matching something@domain.tld (ignore image filenames like @2x.png)
- phone numbers matching +971..., 05X XXX XXXX, or international +<country><9-12 digits>
- any external apply/careers URL in the text (not linkedin.com links)

If the post has NO email, NO phone, and NO apply URL, skip it.

Permalink resolution (REQUIRED for saving): search result cards often hide the post permalink.
For each candidate, if no /posts/ or /feed/update/ link is visible in the card's DOM:
1. Click the post's relative timestamp (e.g. "1d", "13h", "3h") or the author name/avatar on the card.
2. The browser navigates to the post page - its URL will contain /posts/ or /feed/update/urn:li:activity:ID. Capture that URL as the permalink. The full post text is also visible on that page (use it if the card text was truncated).
3. Navigate back to the content search URL and continue with the next candidate.

## Step 3c - Role relevance gate (CRITICAL)

Only store jobs/posts that are SOFTWARE ENGINEERING roles:
- frontend engineer / React / Next.js developer roles
- Shopify developer / Shopify build roles (web development - relevant)
- backend engineer / backend developer (software development: Node.js, Python, Java, Go, etc.)
- full-stack engineer

EXCLUDE and never store:
- "backend executive", backend operations, back office, operations roles (e.g. bank/finance operations) - these are NOT software
- customer support, sales, marketing, product management, design-only, data entry, HR
- roles where it is unclear from title+text whether it is software development

LOCATION gate: UAE and Egypt ONLY.
- JOBS: exclude jobs located in India (Noida, Bangalore, Mumbai, Delhi, Pune, Hyderabad, Gurgaon, hashtags like #noidajobs) or ANY other country.
- FEED POSTS: check the author's location line and hashtags FIRST, before reading anything else. India (any city - Noida, Bangalore, Delhi...), Pakistan, UK, US, Indonesia, or any non-UAE/Egypt country -> skip the post immediately, do not extract contacts.
- For "remote" posts: keep only if the text indicates UAE/Egypt or shows no other-country signals. If it shows India signals (Indian cities, INR/salary in lakhs, Indian hashtags), skip it.
- If unsure about location, skip it.

If unsure about relevance, skip it. Do not store it and do not apply the gate late - gate BEFORE the Notion dedupe/insert.

## Step 4 - Dedupe against Notion (CRITICAL)

For each candidate, before saving, check if its link already exists in the database:

Invoke-RestMethod -Method Post -Uri "https://api.notion.com/v1/databases/YOUR_JOBS_DATABASE_ID/query" -Headers @{ Authorization = "Bearer $env:NOTION_TOKEN"; "Notion-Version" = "2022-06-28"; "Content-Type" = "application/json" } -Body '{"filter":{"property":"Link","url":{"equals":"JOB_LINK_HERE"}}}'

If results array is non-empty, the job is a DUPLICATE - skip it. Never insert the same link twice.

## Step 5 - Save new jobs to Notion

For a new job, insert one page (ALWAYS set Apply Status = "New" so the applier picks it up):

Invoke-RestMethod -Method Post -Uri "https://api.notion.com/v1/pages" -Headers @{ Authorization = "Bearer $env:NOTION_TOKEN"; "Notion-Version" = "2022-06-28"; "Content-Type" = "application/json" } -Body (@{
  parent = @{ database_id = "YOUR_JOBS_DATABASE_ID" }
  properties = @{
    Name = @{ title = @(@{ text = @{ content = "<job title>" } }) }
    Company = @{ rich_text = @(@{ text = @{ content = "<company>" } }) }
    Emirate = @{ select = @{ name = "<Dubai | Abu Dhabi | Sharjah | Ajman | Umm Al Quwain | Ras Al Khaimah | Fujairah | Cairo - use Cairo ONLY for the Cairo search>" } }
    Link = @{ url = "<job link>" }
    Email = @{ rich_text = @(@{ text = @{ content = "<emails comma-joined, or empty string>" } }) }
    Phone = @{ rich_text = @(@{ text = @{ content = "<phones comma-joined, or empty string>" } }) }
    "Found At" = @{ date = @{ start = "<now ISO 8601>" } }
    "Search URL" = @{ url = "<the search url you found it in>" }
    "Apply Status" = @{ select = @{ name = "New" } }
  }
} | ConvertTo-Json -Depth 10)

For FEED POSTS (Step 3b), use the same insert but:
- Name = "<author>: <first 80 chars of post text>"
- Company = "<author name>"
- Emirate = "Cairo" ONLY if the post is clearly Cairo/Egypt-based, otherwise OMIT the property
- Link = "<post permalink>"
- If an apply URL was found, add: "Apply URL" = @{ url = "<apply url>" }; otherwise omit it
- "Search URL" = the content search URL from Step 3b
- Apply Status = "New"

## Limits

- HARD RULE: never modify, remove, or broaden the search URL parameters. f_TPR=r86400 (past 24 hours) stays exactly as written in every job search. Never run wider-window "control checks" or fallback searches (no r604800, no month filters, no unfiltered searches).
- STORAGE IS UNCAPPED: store every candidate that passes the gates. Never truncate, sample, or cap the number of stored rows.
- Max 2 attempts per page (loading/parsing), then move on - this is an error-retry limit, not a storage limit.
- Do not scroll endlessly on a single page; use real pagination links instead.
- If Notion or network errors repeat 3 times, stop and report.

## Final output

Print exactly one summary line:
"WATCHER RESULT: results-per-emirate=<n,n,n,n,n,n,n,n> job-candidates=<n> post-candidates=<n> saved=<n> duplicates=<n> not-relevant=<n> skipped=<n>"

## Cleanup (final step, always do this - even when aborting)

1. Write a row into the Watcher Run Log database (ALWAYS, even if the run aborted or found nothing):

Invoke-RestMethod -Method Post -Uri "https://api.notion.com/v1/pages" -Headers @{ Authorization = "Bearer $env:NOTION_TOKEN"; "Notion-Version" = "2022-06-28"; "Content-Type" = "application/json" } -Body (@{
  parent = @{ database_id = "YOUR_RUNLOG_DATABASE_ID" }
  properties = @{
    Name = @{ title = @(@{ text = @{ content = "Search run <HH:mm>" } }) }
    Type = @{ select = @{ name = "Search" } }
    "Run At" = @{ date = @{ start = "<now ISO>" } }
    Summary = @{ rich_text = @(@{ text = @{ content = "<the WATCHER RESULT line, or the exact reason the run aborted>" } }) }
  }
} | ConvertTo-Json -Depth 10)

2. Then close every browser tab group you created in this session using browser_close (pass the group name, no tabId). If browser_close fails, ignore it and finish anyway.
