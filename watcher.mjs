import http from "node:http";
import { chromium } from "playwright";

const NOTION_TOKEN = process.env.NOTION_TOKEN;
const DATABASE_ID = process.env.NOTION_DATABASE_ID;
const PORT = Number(process.env.PORT || 3000);
const RUN_ON_START = process.env.RUN_ON_START !== "false";
const INTERVAL_MS = Number(process.env.INTERVAL_MS || 60 * 60 * 1000);

const KEYWORDS = encodeURIComponent('"full stack" OR frontend OR backend');
const EMIRATES = [
  ["Dubai", "Dubai, Dubai, United Arab Emirates"],
  ["Abu Dhabi", "Abu Dhabi Emirate, United Arab Emirates"],
  ["Sharjah", "Sharjah Emirate, United Arab Emirates"],
  ["Ajman", "Ajman, United Arab Emirates"],
  ["Umm Al Quwain", "Umm Al Quwain, United Arab Emirates"],
  ["Ras Al Khaimah", "Ras al-Khaimah, United Arab Emirates"],
  ["Fujairah", "Fujairah, United Arab Emirates"],
];

const EMAIL_RE = /[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/gi;
const PHONE_RE = /(\+?971[\d\s-]{7,12}|\b0\s?5\d[\d\s-]{7,8}\b|\+\d{1,3}[\s-]?\d{8,12})/g;
const BAD_FILE_RE = /\.(png|jpe?g|gif|webp|svg|css|js)$/i;
const FRESH_RE = /(second|minute|hour)s?\s+ago|just now/i;

const log = (...a) => console.log(new Date().toISOString(), ...a);

function notionFetch(path, options = {}) {
  return fetch(`https://api.notion.com/v1${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${NOTION_TOKEN}`,
      "Notion-Version": "2022-06-28",
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });
}

async function ensureSchema() {
  const properties = {
    Company: { rich_text: {} },
    Emirate: { select: { options: EMIRATES.map(([name]) => ({ name })) } },
    Link: { url: {} },
    Email: { rich_text: {} },
    Phone: { rich_text: {} },
    "Found At": { date: {} },
    "Search URL": { url: {} },
  };
  const res = await notionFetch(`/databases/${DATABASE_ID}`, {
    method: "PATCH",
    body: JSON.stringify({ properties }),
  });
  if (!res.ok && res.status !== 400) {
    throw new Error(`ensureSchema failed: ${res.status} ${await res.text()}`);
  }
  log("schema ready");
}

async function alreadySaved(link) {
  const res = await notionFetch(`/databases/${DATABASE_ID}/query`, {
    method: "POST",
    body: JSON.stringify({
      filter: { property: "Link", url: { equals: link } },
      page_size: 1,
    }),
  });
  if (!res.ok) throw new Error(`query failed: ${res.status} ${await res.text()}`);
  const data = await res.json();
  return data.results.length > 0;
}

async function saveJob({ emirate, title, company, link, emails, phones, searchUrl }) {
  const res = await notionFetch("/pages", {
    method: "POST",
    body: JSON.stringify({
      parent: { database_id: DATABASE_ID },
      properties: {
        Name: { title: [{ text: { content: title } }] },
        Company: { rich_text: [{ text: { content: company || "" } }] },
        Emirate: { select: { name: emirate } },
        Link: { url: link },
        Email: { rich_text: [{ text: { content: emails.join(", ") } }] },
        Phone: { rich_text: [{ text: { content: phones.join(", ") } }] },
        "Found At": { date: { start: new Date().toISOString() } },
        "Search URL": { url: searchUrl },
      },
    }),
  });
  if (!res.ok) throw new Error(`save failed: ${res.status} ${await res.text()}`);
}

function extractContacts(text) {
  const emails = [...new Set((text.match(EMAIL_RE) || []).filter((e) => !BAD_FILE_RE.test(e)))];
  const phones = [
    ...new Set(
      (text.match(PHONE_RE) || [])
        .map((p) => p.replace(/\s+/g, " ").trim())
        .filter((p) => p.replace(/\D/g, "").length >= 9)
    ),
  ];
  return { emails, phones };
}

async function runOnce() {
  const browser = await chromium.launch({ args: ["--no-sandbox"] });
  const context = await browser.newContext({
    userAgent:
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    viewport: { width: 1366, height: 900 },
    locale: "en-US",
  });
  const page = await context.newPage();
  let added = 0;

  for (const [emirate, location] of EMIRATES) {
    const searchUrl = `https://www.linkedin.com/jobs/search/?keywords=${KEYWORDS}&location=${encodeURIComponent(
      location
    )}&f_TPR=r3600&f_E=1%2C2%2C3`;
    try {
      await page.goto(searchUrl, { waitUntil: "domcontentloaded", timeout: 45000 });
      await page.waitForTimeout(2500);

      if (page.url().includes("authwall") || (await page.locator("form.login-sign-form").count())) {
        log(`guest blocked on ${emirate}, skipping`);
        continue;
      }

      const cards = await page.evaluate(() => {
        const out = [];
        document.querySelectorAll("div.base-card, div.job-search-card").forEach((card) => {
          const a = card.querySelector("a.base-card__full-link, a.job-search-card__link");
          const title = card.querySelector(".base-search-card__title, .job-search-card__title");
          const company = card.querySelector(".base-search-card__subtitle, .job-search-card__subtitle");
          const meta = card.querySelector(
            ".job-search-card__listdate, .job-search-card__listdate--new, .job-search-card__listed-time, time"
          );
          if (a && title) {
            out.push({
              link: a.href ? a.href.split("?")[0] : "",
              title: title.textContent.trim(),
              company: company ? company.textContent.trim() : "",
              meta: meta ? meta.textContent.trim() : "",
            });
          }
        });
        return out;
      });

      const fresh = cards.filter((c) => c.link && FRESH_RE.test(c.meta));
      log(`${emirate}: ${cards.length} cards, ${fresh.length} fresh (<24h signals)`);

      for (const job of fresh) {
        try {
          await page.goto(job.link, { waitUntil: "domcontentloaded", timeout: 45000 });
          await page.waitForTimeout(2000);
          if (page.url().includes("authwall")) continue;

          const description = await page
            .locator(".show-more-less-html__markup, .description__text")
            .first()
            .innerText({ timeout: 10000 })
            .catch(() => "");

          if (!description) continue;
          const { emails, phones } = extractContacts(description);
          if (emails.length === 0 && phones.length === 0) continue;

          if (await alreadySaved(job.link)) continue;
          await saveJob({ ...job, emirate, emails, phones, searchUrl });
          added++;
          log(`saved: ${job.title} @ ${job.company} (${emirate})`);
        } catch (e) {
          log(`job error: ${e.message}`);
        }
        await page.waitForTimeout(3000 + Math.floor(Math.random() * 4000));
      }
    } catch (e) {
      log(`emirate error (${emirate}): ${e.message}`);
    }
    await page.waitForTimeout(4000 + Math.floor(Math.random() * 4000));
  }

  await browser.close();
  log(`run complete, ${added} new job(s) saved`);
}

http
  .createServer((req, res) => {
    res.writeHead(200);
    res.end("ok");
  })
  .listen(PORT, () => log(`health server on :${PORT}`));

async function main() {
  if (!NOTION_TOKEN || !DATABASE_ID) {
    console.error("NOTION_TOKEN and NOTION_DATABASE_ID are required");
    process.exit(1);
  }
  await ensureSchema();
  if (RUN_ON_START) await runOnce();
  setInterval(() => runOnce().catch((e) => log(`run error: ${e.message}`)), INTERVAL_MS);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
