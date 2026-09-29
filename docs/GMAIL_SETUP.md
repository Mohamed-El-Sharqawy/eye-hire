# Gmail API Setup (one-time, ~5 minutes)

The apply session sends emails through the Gmail API instead of browser
automation - deterministic sends, native CV attachments, exact thread replies.

You NEVER share your Google password. You create an OAuth token that can only
send mail (gmail.send) and read thread metadata (gmail.readonly), and it lives
in the gitignored `.env`.

## 1. Google Cloud project

1. Go to https://console.cloud.google.com/ and create a project (any name, e.g. `job-watcher`).
2. APIs & Services -> Library -> search "Gmail API" -> **Enable**.

## 2. OAuth consent screen

1. APIs & Services -> OAuth consent screen -> choose **External** -> Create.
2. Fill only the required fields (app name, your email).
3. Scopes: add `https://www.googleapis.com/auth/gmail.send` and
   `https://www.googleapis.com/auth/gmail.readonly`.
4. Test users: add the Gmail account you will send from (required while the app
   is in Testing).
5. **Publish the app** (Publishing status -> In Production). For personal use
   Google shows an "unverified app" warning you can bypass once - but publishing
   matters: refresh tokens issued under "Testing" expire every 7 days, published
   ones do not.

## 3. OAuth client

1. APIs & Services -> Credentials -> Create credentials -> OAuth client ID.
2. Application type: **Desktop app**.
3. After creation, click the client -> "Authorized redirect URIs" -> add exactly:
   `http://localhost:8899/`
4. Copy the **Client ID** and **Client Secret**.

## 4. Configure and mint the token

1. Add to `.env` in the repo root (never commit it):

   ```
   GMAIL_CLIENT_ID=xxxxx.apps.googleusercontent.com
   GMAIL_CLIENT_SECRET=GOCSPX-xxxxx
   ```

2. Run:

   ```
   pwsh -File tools\gmail-auth.ps1
   ```

   A browser opens -> sign in with the SENDING Gmail account -> Allow
   (bypass the unverified-app warning via Advanced -> Go to project if shown).
   The script prints a `GMAIL_REFRESH_TOKEN=...` line - paste it into `.env`.

3. Verify:

   ```
   pwsh -File tools\gmail.ps1 whoami
   ```

   Should return the sending account's address.

## 5. Test

```
pwsh -File tools\gmail.ps1 send -To someone@example.com -Subject "test" -Body "hello"
```

The apply session (`opencode-apply-prompt.md`) now uses this helper
(`send` / `draft` / `find-sent` / `check-reply`) automatically. Browser-based
Gmail remains only as a fallback if the API errors.
