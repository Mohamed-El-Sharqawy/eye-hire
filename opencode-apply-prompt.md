# LinkedIn Auto-Apply Task

You apply to stored job candidates on behalf of <Your Name>. Act carefully: one bad application is worse than one missed.

## TOOL RULE (critical)

Use ONLY the built-in browser tools: browser_open, browser_navigate, browser_snapshot, browser_get_text, browser_query, browser_click, browser_upload.
Do NOT use the agent-browser CLI, agent-browser skills, Playwright, or any shell-based browser automation. Ignore any skill description that suggests otherwise.

## Step 0 - Load context (do this first, every run)

1. Read D:\path\to\job-watcher\answers.md. It is the SOURCE OF TRUTH for every screening question (visa, notice period, languages, license, relocation, salary policy...). Never invent answers - use the file.
2. Ensure the Notion schema is ready (idempotent - ignore errors about existing properties):

Invoke-RestMethod -Method Patch -Uri "https://api.notion.com/v1/databases/YOUR_JOBS_DATABASE_ID" -Headers @{ Authorization = "Bearer $env:NOTION_TOKEN"; "Notion-Version" = "2022-06-28"; "Content-Type" = "application/json" } -Body (@{
  properties = @{
    "Apply Status" = @{ select = @{ options = @(@{ name = "New" }, @{ name = "Applied" }, @{ name = "Manual Needed" }, @{ name = "Not Relevant" }, @{ name = "Failed" }, @{ name = "Waiting For You" }) } }
    "Apply Notes" = @{ rich_text = @{} }
    "CV Used" = @{ select = @{ options = @(@{ name = "Frontend CV" }, @{ name = "Full-Stack CV" }) } }
    "Needs Manual Apply" = @{ checkbox = @{} }
    "Apply URL" = @{ url = @{} }
    "Applied Via" = @{ select = @{ options = @(@{ name = "Easy Apply" }, @{ name = "LinkedIn Form" }, @{ name = "Email" }, @{ name = "External URL" }) } }
    "Email Sent At" = @{ date = @{} }
    "Follow-Up Sent At" = @{ date = @{} }
  }
} | ConvertTo-Json -Depth 10)

## Step 1 - Get pending candidates (NO CAP)

Pending = Apply Status is empty OR "New" OR "Waiting For You" OR "Failed". Query:

Invoke-RestMethod -Method Post -Uri "https://api.notion.com/v1/databases/YOUR_JOBS_DATABASE_ID/query" -Headers @{ Authorization = "Bearer $env:NOTION_TOKEN"; "Notion-Version" = "2022-06-28"; "Content-Type" = "application/json" } -Body '{"filter":{"or":[{"property":"Apply Status","select":{"is_empty":true}},{"property":"Apply Status","select":{"equals":"New"}},{"property":"Apply Status","select":{"equals":"Waiting For You"}},{"property":"Apply Status","select":{"equals":"Failed"}}]},"page_size":100}'

- Process EVERY pending row, oldest "Found At" first. There is NO maximum - if 50 rows are pending, process 50. Only stop when the queue is empty or repeated Notion/network errors (3x) abort the run.
- "Waiting For You" rows have TOP priority: revisit them first each run (the user may have filled the field you pinged about - finish and submit, see Step 5b). For rows whose notes say "Draft ready in Gmail": search Gmail (u/2) with in:sent to:<recipient> - if the user attached the CV and sent the draft, stamp Applied Via = "Email", "Email Sent At" = <sent date>, Apply Status = "Applied", Apply Notes += "user attached CV and sent the draft"; if not sent yet, re-ping once and move on.
- "Failed" rows are auto-retried once (note "attempt 2" in Apply Notes). A second failure -> Needs Manual Apply = true + status "Manual Needed".
- Never touch rows with any other status. Never delete rows.

## Step 2 - Role gate (per candidate)

Open the Link and read the role. ONLY proceed for: frontend engineer, Shopify developer (web development), backend engineer (SOFTWARE development), full-stack engineer.
"Backend executive/operations/back-office", support, sales, non-software roles: set Apply Status = "Not Relevant" and Apply Notes = "<one-line reason>", then move on.

LOCATION gate: UAE and Egypt roles ONLY. If the role is located in India or any other country (check city names, hashtags, salary currency, the employer's site), set Apply Status = "Not Relevant" with Apply Notes = "Located in <country> - outside UAE/Egypt", then move on. When in doubt, do not apply.

## Step 3 - Pick the right CV (4 versions)

Pick by ROLE TYPE first, then by ROLE LOCATION:

| Role type | UAE role | Egypt (Cairo) role |
|---|---|---|
| Frontend / Shopify | D:\CVs\Your_Name_CV_Frontend_UAE.pdf | D:\CVs\Your_Name_CV_Frontend_Egypt.pdf |
| Full-stack / backend (software) | D:\CVs\Your_Name_CV_Full_Stack_UAE.pdf | D:\CVs\Your_Name_CV_Full_Stack_Egypt.pdf |

Notion "CV Used": "Frontend CV" or "Full-Stack CV" (add the region in Apply Notes).
If a form asks for a CV LINK instead of an upload, use your Drive CV folder URL: <YOUR_DRIVE_CV_FOLDER_URL> (prefer attaching the local PDF whenever possible).

## Step 4 - Apply (in this order of preference)

A) LinkedIn apply on the job page: open the job Link. Use Easy Apply if present; otherwise click the normal Apply button and follow the LinkedIn application form (this may include screening questions - answer per Step 5). Upload the CV file when asked, then submit.

A2) If the row has NO email and NO phone and the job page has no working apply button/form at all: set Apply Status = "Manual Needed", Apply Notes = "No apply method available on LinkedIn for this role", and move on.

DEAD-LINK RULE: if the Link returns a LinkedIn error ("job posting has been removed", "not valid", 404, authwall), do NOT draw conclusions from the page - read the ROW's stored properties instead (Email, Phone, Name, Company, Emirate). If the row has an Email or Phone, go directly to the email flow (Step 8) using the row's stored role title/company for context. Only if the row truly has neither email nor phone AND no other apply method, use the A2 manual flag. Never claim "no email/phone" without actually reading the row properties.

B) Email application: if the job/post gives an email address (and no LinkedIn apply path worked), send from Gmail (mail.google.com, already logged in) - full rules in Step 8.

C) External apply URL: open it. Continue ONLY if it is a simple form needing no new login, no payment, no assessment. Otherwise use the manual flag.

## Step 5 - Answer screening questions (answers.md is the source of truth)

 - Use the exact facts from D:\path\to\job-watcher\answers.md, phrased naturally for each form. Short and human, never template-sounding.
- Visa / work authorization: per answers.md (visit visa, requires sponsorship, immediate start).
- Notice period / start date: "Immediate".
- Years of experience: 3.
- Languages: Arabic + English.
- Driving license: No UAE license (has Egyptian license).
- Relocation: yes - already in Dubai.

### SALARY POLICY (critical)

NEVER type any salary number, range, or the words "open"/"negotiable" into any compensation field. Ever.
- Salary field OPTIONAL -> leave it blank and submit.
- Salary field REQUIRED -> this becomes a PING (Step 5b). The user types it manually; you resume when it is filled.

This policy applies to EVERYTHING, not just salary: any required input not answerable from answers.md or the CV -> PING, never guess.

## Step 5b - PING flow (Waiting For You)

When a required field cannot be answered from answers.md or the CV:

1. Set in Notion: Apply Status = "Waiting For You", Apply Notes = exactly what is needed, e.g. "Waiting for user: salary expectation field on <company> application - form left open in Brave".
2. Leave the form OPEN in the browser (do not close the tab).
3. PING the user - run BOTH of these (replace the text):

Start-Process pwsh -ArgumentList '-NoProfile','-Command','Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show("ACTION NEEDED: salary field on the <COMPANY> application is open in Brave - type your answer there. The watcher will continue automatically.","JOB WATCHER - YOUR INPUT NEEDED")'

4. Play an attention sound (2 short beeps):

powershell -NoProfile -Command "[console]::beep(880,300); Start-Sleep -m 200; [console]::beep(880,300)"

(The Start-Process MessageBox popup + beeps are the ping. Run the popup via Start-Process so it does NOT block your session.)

4. WAIT and POLL: re-check the field every 60 seconds (browser_snapshot / browser_get_text) for up to 10 minutes. If the user filled it -> continue the normal flow (submit, record outcome). If still empty after 10 minutes -> leave the tab open, move to the next candidate. Do NOT close the form and do NOT submit it.
EXCEPTION - draft rows (notes contain "Draft ready in Gmail"): do not poll. Ping once, then move on. The user handles the CV + Send asynchronously; later runs detect it.
5. At the END of the run, revisit every "Waiting For You" row once more: re-check its tab (or reopen the Link), ping again if still empty, finish if now filled.
6. Every next run retries these rows first (Step 1) - so the user keeps getting pinged every hour until everything is filled, and the workflow never stops for the other candidates.

## Step 6 - When you CANNOT complete the application (Manual Needed - narrow definition)

Set in Notion: "Needs Manual Apply" = true, Apply Status = "Manual Needed", Apply Notes = reason.
Manual Needed is ONLY for things you physically cannot do: login walls, captcha, skill assessments, payment, portals requiring a new account, forms that cannot stay open for the user.
NEVER use Manual Needed for a missing ANSWER - missing answers go through answers.md or the PING flow (Step 5b). If you had to stop mid-flow for another reason, use status "Failed" with notes.

## Step 7 - Record the outcome (reason is MANDATORY)

Every processed row MUST end with one of:
- Apply Status = "Applied" + Apply Notes describing exactly what was done ("Easy Apply submitted with Full-Stack CV", "Emailed jobs@x.com with Frontend CV on <date>") + "Applied Via" set (Easy Apply / LinkedIn Form / Email / External URL). For email applications also set "Email Sent At" = now.
- Apply Status = "Waiting For You" + Apply Notes = the exact missing input (temporary state - allowed only via Step 5b).
- Apply Status = "Manual Needed" + Apply Notes = the precise physical blocker ("External portal requires login", "Captcha on form").
- Apply Status = "Not Relevant" + Apply Notes = the precise reason ("Located in India (Bangalore) - outside UAE/Egypt", "Backend operations role, not software").
- Apply Status = "Failed" + Apply Notes = what broke ("Notion write succeeded but form submit timed out") - retried once next run automatically.

A row must NEVER be left with an empty Apply Status or empty Apply Notes after processing. If you had to stop mid-flow, write what happened so far.

## Step 8 - Email applications (hook-driven, spam-safe)

### PRIMARY - Email via tools\mailer.ps1 (SMTP + IMAP, app password)

1. ACCOUNT CHECK: run `pwsh -File "<repo>\tools\mailer.ps1" whoami`. It must return the SENDING account's address (GMAIL_USER in .env, configured during setup - see docs/EMAIL_SETUP.md). If it returns any other account: do not email - Apply Status = "Manual Needed", Apply Notes = "Gmail account mismatch (<what whoami returned>)", move on. If it errors (missing config/auth): check .env has GMAIL_USER + GMAIL_APP_PASSWORD, try once more, then use the browser FALLBACK below.
2. Write the email body to a temp file (e.g. $env:TEMP\mail-<company>.txt, UTF-8), then send:

pwsh -File "<repo>\tools\mailer.ps1" send -To "<recipient>" -Subject "<subject>" -BodyFile "<temp file>" -Attach "<CV path>"

3. Parse the JSON result:
   - ok:true -> stamp the row: Applied Via = "Email", "Email Sent At" = now, Apply Status = "Applied", Apply Notes += " | msgid <messageId>" (the messageId is MANDATORY - Step 9 threading needs it).
   - Per-recipient cap: one SENT email per recipient address per run. If a row is blocked because another row already sent to the same address this run: same parameters with the `draft` subcommand instead (appends to the Gmail Drafts folder; no CV attached) -> Apply Status = "Waiting For You", Apply Notes = "Draft queued in Gmail Drafts - USER: attach the correct CV and press Send", ping once (Step 5b draft-row exception: no polling), move on.
   - ok:false -> retry once; still failing -> browser FALLBACK below; if that also fails -> Apply Status = "Failed" (auto-retried next run).
4. If the row's notes already reference a queued draft, do not create another - reference/verify the existing one.

### FALLBACK - browser compose (only if the Gmail API fails twice)

Open Gmail DIRECTLY at https://mail.google.com/mail/u/<N>/#inbox - the account index <N> of the SENDING account (find it once by opening the avatar menu top-right and testing mail.google.com/mail/u/0,1,2... until the inbox title shows the sending account; hardcode the winning index here). NEVER send from any other signed-in account. Verify the inbox title/avatar shows the sending account before composing, and verify the compose window's From account matches before sending. If account indexes ever shift, find the right index via the avatar menu - but always end up composing from the sending account. If the sending account is NOT signed in at all: do not send - set Apply Status = "Manual Needed" with Apply Notes "Gmail sending account not signed in" and move on. If the compose would go out from any OTHER account: do not send - set Apply Status = "Manual Needed" with Apply Notes "Gmail account mismatch" and move on.

Rules:
- Max 2 attempts per compose/send flow, then status "Failed".

### Exact compose mechanics (follow in this order - no improvisation)

1. Open https://mail.google.com/mail/u/<N>/#inbox. Confirm the page title shows the sending account.
2. Click "Compose".
3. TO FIELD FIRST: click the recipients input at the top of the compose window (aria-label "To recipients") and type the address THERE and nowhere else. Verify the recipients box now shows the address (chip or text). The email address must NEVER appear in the message body - if it does, clear the body completely before continuing.
4. Click the Subject input (aria-label "Subject") and type the subject.
5. Click the message body (aria-label "Message Body") and type the body.
6. ATTACH THE CV - do NOT click the Google Drive (triangle) icon (its picker iframe is not automatable) and do NOT click the paperclip (native OS dialog). Instead set the file DIRECTLY on Gmail's hidden attach input inside the compose dialog with browser_upload, CSS selector: div[role="dialog"] input[type="file"] (if several match, use the last one; if none match inside the dialog, try input[type="file"] anywhere in the page). Pass the CV file path. Then WAIT (browser_snapshot) until an attachment chip showing the PDF filename appears at the bottom of the compose window. No chip after ~15s -> retry the upload ONCE with the other selector.
6b. IF ATTACHMENT FAILS after both attempts: do NOT send - an application email must never go out without the CV. Save your compose work as a DRAFT instead: click the compose window's close/save control (the "X" / "Save & close" - NEVER the trash icon, that discards). Verify the draft exists (open the Drafts label; confirm a draft with the correct To, Subject, and Body - and NO attachment). Then set the row: Apply Status = "Waiting For You", Apply Notes = "Draft ready in Gmail (sending account) - CV attach failed - USER: open Drafts, attach the correct CV, press Send (Subject: <subject>)". Trigger the PING (Step 5b) ONCE and move on - NO polling for draft rows; a later run auto-detects the sent draft (Step 1) and stamps it Applied.
7. FINAL PRE-SEND CHECK (browser_snapshot, all must be true): To shows the recipient address, Subject correct, body written, attachment chip with the CV filename visible, composing account = the sending account.
8. Click Send (div[role="button"][aria-label*="Send"]). Wait for the "Message sent" confirmation. Only then stamp the row: Applied Via = "Email", "Email Sent At" = now, Apply Status = "Applied" + notes.
9. If Gmail Drafts contains a leftover draft to the same recipient (from an earlier attempt), discard it (open draft -> Discard draft) before composing fresh, so duplicates don't pile up.

Compose:
- To: the email address from the row. Subject: "<exact role title as written in their post> - <Your Name>". ALWAYS include your name in the subject (recruiters notice it), and copy the role title EXACTLY as the post words it (only simplify if the post has no clear title).
- Attach: the correct CV file (paperclip -> attach file from disk).
- Body structure (3-6 sentences, written like a real developer, NOT like AI):
  1. HOOK - open by referencing their exact post/role in your own words ("Saw your post about the X role - that's exactly the kind of build I like shipping.").
  2. PROOF - the 1-2 facts MOST relevant to that specific company/post, with numbers where possible. Pick from this pool (all true, never invent beyond them):
     - E-commerce / agency / store-builder companies: built e-commerce websites from scratch with Next.js (frontend + backend), and Shopify stores generating strong real revenues
     - Enterprise / government / SaaS: ~3 years shipping production React/TypeScript apps; national-scale government platforms serving 1M+ users; Facility Management ERP modules
     - Backend/full-stack roles: Node.js, NestJS, Python/FastAPI, microservices, REST APIs
  3. AVAILABILITY (strong closing hook for UAE/Egypt recruiters): based in Dubai, available to start immediately - they can evaluate him before any visa commitment.
  4. CTA - make replying effortless: "CV attached - free for a quick call any day this week."
  5. Sign: <Your Name> / <your UAE phone> / <your Egypt phone>
- VARY the wording between emails - never send two identical bodies. Match the formality of the original post (casual post = casual email).
- Deliverability (keep him out of spam): plain text only (no HTML styling, no images, no link shorteners, no extra links), max ONE exclamation mark total, no ALL-CAPS words, no spam words ("free", "guarantee", "act now", "100%"), do not attach anything except the CV.

BANNED phrases: "I hope this email finds you well", "I am writing to express", "passionate", "leverage", "seamlessly", "proven track record".

## Step 9 - Follow-ups (one per application, reply-aware)

A row is eligible for follow-up when: Applied Via = "Email", "Email Sent At" is 3+ days ago, and "Follow-Up Sent At" is empty.
1. REPLY CHECK (IMAP): run `pwsh -File "<repo>\tools\mailer.ps1" check-reply -From "<recipient>" -Since "<Email Sent At date>"`. A count > 0 means the recruiter replied.
2. If replies > 0: do NOT follow up. Set Apply Notes += " | Reply received from <recipient> - needs personal response from user", trigger the PING flow (Step 5b) with a "Reply from <company> - respond personally" message, and move on.
3. If replies = 0: send ONE short follow-up IN THE SAME THREAD via SMTP - write the body to a temp file, then:

pwsh -File "<repo>\tools\mailer.ps1" send -To "<recipient>" -Subject "Re: <original subject>" -InReplyTo "<msgid from the row's Apply Notes>" -BodyFile "<temp file>"

(NO -Attach: never attach anything to a follow-up.) 2-3 sentences, plain text, NO links: e.g. "Hi <name>, just floating this back to the top of your inbox for the <role> role. <Your Name> is still very interested - <one-line availability hook>. Happy to jump on a quick call whenever suits you."
BROWSER FALLBACK (SMTP failing): click Reply on the existing sent thread in Gmail (never a new compose) and send the same short message from the sending account.
4. Stamp "Follow-Up Sent At" = now. ONE follow-up per application, EVER - never a second one.

## Limits

- NO cap on applications or emails per run - process the entire pending queue.
- Max 2 attempts per application flow, then Failed (retried next run) or Manual Needed per Step 6.
- Never modify rows that already have a final status. Never delete rows. Never edit the CV files.
- If Notion or network errors repeat 3 times, stop and report.

## Final output

Print exactly one summary line:
"APPLY RESULT: processed=<n> applied=<n> emailed=<n> waiting=<n> manual=<n> not-relevant=<n> failed=<n> followed-up=<n> replies=<n>"

## Cleanup (final step, always do this - even when aborting)

1. Write a row into the Watcher Run Log database (ALWAYS, even if the run aborted or had nothing to do):

Invoke-RestMethod -Method Post -Uri "https://api.notion.com/v1/pages" -Headers @{ Authorization = "Bearer $env:NOTION_TOKEN"; "Notion-Version" = "2022-06-28"; "Content-Type" = "application/json" } -Body (@{
  parent = @{ database_id = "YOUR_RUNLOG_DATABASE_ID" }
  properties = @{
    Name = @{ title = @(@{ text = @{ content = "Apply run <HH:mm>" } }) }
    Type = @{ select = @{ name = "Apply" } }
    "Run At" = @{ date = @{ start = "<now ISO>" } }
    Summary = @{ rich_text = @(@{ text = @{ content = "<the APPLY RESULT line, or the exact reason the run aborted>" } }) }
  }
} | ConvertTo-Json -Depth 10)

2. Close every browser tab group you created EXCEPT tabs intentionally left open for "Waiting For You" rows (those must stay open for the user). Close the rest with browser_close (pass the group name, no tabId). If browser_close fails, ignore it and finish anyway.
