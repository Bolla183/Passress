# Passress Business Companion

A double-entry accounting engine for Passress, with a mobile-first quick-entry
UX on top so day-to-day use still feels like a simple tracker. Built with
Next.js 16 + Prisma 7 + Postgres.

## Architecture

- **Ledger core** (`lib/accounting/`): a hierarchical Chart of Accounts, and
  `postJournalEntry()` — the single function anywhere in the app allowed to
  write ledger data. It enforces debits = credits on every entry. Every
  feature (quick-add, Shopify sync, and future modules) posts through it, so
  the ledger can never go out of balance.
- **Reports** (`lib/accounting/reports.ts`): Trial Balance, General Ledger,
  Profit & Loss, Balance Sheet, and Cash Flow Statement, all computed
  directly from journal lines with hierarchical rollup (a leaf account's
  balance rolls up through every ancestor).
- **Master data** (`lib/masterdata/`): Suppliers, Bank Accounts, Employees,
  Customers, Products, and 13 other entities each have a company-scoped
  service (list/get/create/update/remove) behind a single generic CRUD
  factory, so adding a new entity's screen is mechanical, not bespoke.
- **Quick entry** (`lib/accounting/quickEntry.ts`): the simple "type +
  category + amount" view the founder actually uses day to day, implemented
  as a thin layer that posts two-line journal entries (against Cash) and
  reconstructs that simple view back out of the ledger for the dashboards.
- **Multi-company ready**: every table carries a `companyId`. Only one
  company (Passress) exists today — there's no signup/billing/company
  switcher UI — but adding a second company later is a data row, not a
  schema migration.

See `/root/.claude/plans/scalable-plotting-sparrow.md` (or ask Claude to
regenerate it) for the full phased roadmap — this build is "Phase A": the
complete foundation, with two master-data screens (Suppliers, Bank Accounts)
fully wired as the reusable pattern the remaining 16 follow.

## What it does today

Product direction is now driven by a PRD (`Passress Business Companion`,
approved as the baseline) rebuilding the UX in milestones, on top of the
unchanged accounting engine. **Milestone 2 (Dashboard)** is complete; Timeline
(Milestone 3) and the Reports redesign (Milestone 4) are next.

The bottom nav is **Dashboard, Reports, More**, with a floating **+** button
(visible on every screen except Add itself) for quick entry — Timeline joins
the bar as a fourth tab once Milestone 3 ships. Everything from earlier
phases still exists, tucked under **More** instead of competing for
attention on every screen.

- **Dashboard** (`/dashboard`): the app's landing page (login goes straight
  here). In priority order: a **Cash Available** hero (the founder's own
  first question, "how much money do I have"), a **Today** card (Revenue/
  Expenses/Profit so far, resets at midnight Cairo time), Net Profit/Capital
  Invested/Owner Equity, a **Business Health Score** (0–100, a reproducible
  weighted formula across Cash Position/Profitability/Revenue Growth/Expense
  Control/Liquidity — never a guess — with a plain-language "why";
  `lib/accounting/healthScore.ts`), Revenue/Expenses as secondary cards, a
  gradient revenue-vs-expense trend chart, a recent-activity preview
  (`lib/accounting/activityFeed.ts`, reads the ledger directly so nothing
  posted through any workflow is invisible), and **Dashboard Insights** —
  plain-language statements (`lib/accounting/insights.ts`) generated from
  the same numbers, not hardcoded.
- **Add** (`/add`): tuned for repeat use in under 10 seconds — the last
  category you used per Income/Expense is remembered (`localStorage`) and
  pre-selected, Date/Note are collapsed behind an optional toggle, and the
  amount field refocuses after each save. A third toggle, **Capital**, records
  money the owner puts into the business personally (Debit Cash / Credit
  Owner's Equity — `lib/modules/capital.ts`), the only way Capital Invested
  and Owner Equity have to grow. Revenue syncs from Shopify automatically
  once a day via Vercel Cron (`vercel.json` → `/api/cron/shopify-sync`); the
  **Sync Shopify** button here is still there for an on-demand sync in
  between. Installable to a phone home screen for a chrome-less, one-tap
  launch straight into Dashboard.
- **Payroll** (`/payroll`, under More): type a name and an amount, hit Pay —
  no employee record to set up first. Shows this month's total, a by-person
  breakdown, and a running list, with month navigation.
- **Reports** (`/reports`): Trial Balance, General Ledger, Profit & Loss,
  Balance Sheet, Cash Flow Statement — unchanged pending Milestone 4's
  chart-first redesign.
- **More** (`/more`): Payroll, older dashboards (Daily/Monthly/Trends),
  business workflows (Bills/Invoices/Loans/Inventory), and master data
  (Suppliers, Bank Accounts, etc.) — all still fully working, just out of
  the primary flow.
- **Auth**: unchanged — single shared password, signed session cookie.

## Local development

Requirements: Node 20+, a Postgres database.

```bash
npm install
cp .env.example .env   # then fill in the values, see below
npm run build           # applies migrations + seeds the chart of accounts
npm run dev
```

`npm run build` runs `prisma migrate deploy`, then `prisma/bootstrap.ts`
(idempotent: seeds the Company + Chart of Accounts, and migrates any rows
still sitting in the legacy `Transaction` table into journal entries), then
builds Next.js. This is also exactly what runs on every Vercel deploy, so
production sets itself up the same way — no manual migration step.

### Environment variables

| Variable | Description |
| --- | --- |
| `DATABASE_URL` | Postgres connection string, e.g. `postgresql://user:pass@host:5432/db` |
| `APP_PASSWORD` | The password you'll type in to log in |
| `SESSION_SECRET` | Any long random string, used to sign the session cookie |
| `SHOPIFY_STORE_DOMAIN` | e.g. `your-store.myshopify.com` (for sales sync) |
| `SHOPIFY_ADMIN_ACCESS_TOKEN` | A Shopify Admin API access token with `read_orders` scope |
| `CRON_SECRET` | Any long random string. Required for the daily automatic Shopify sync and the daily digest email — Vercel sends it as `Authorization: Bearer $CRON_SECRET` on the scheduled request, and the two `/api/cron/*` routes check it before running. Generate one with `openssl rand -hex 32` and add it in Vercel's project Environment Variables (same manual step as the other secrets below) |
| `RESEND_API_KEY` | API key from [resend.com](https://resend.com) (for the daily digest email) |
| `DAILY_DIGEST_RECIPIENTS` | Comma-separated email addresses to send the daily digest to, e.g. `partner1@example.com,partner2@example.com` |
| `DAILY_DIGEST_FROM` | Optional. The "from" address for the digest, e.g. `Passress <reports@yourdomain.com>` once a sending domain is verified on Resend. Defaults to Resend's shared `onboarding@resend.dev` sandbox sender, which can only deliver to the email address on the Resend account until a custom domain is verified |

The Shopify and daily-digest variables are optional — the app works fully
for manual entry without them. "Sync Shopify" will show an error until the
Shopify variables are set, and the digest cron will fail (visibly, in its
own logs) until `RESEND_API_KEY` and `DAILY_DIGEST_RECIPIENTS` are set.

**On the Hobby plan, Vercel Cron only allows once-per-day schedules** —
`vercel.json` runs the Shopify sync at `0 3 * * *` and the daily digest at
`0 5 * * *` (both UTC; Vercel may fire anytime within the scheduled hour).
If the Vercel project is on the Pro plan, either schedule can be tightened
for closer to real-time timing.

## Notes on the numbers

- All amounts are stored and displayed in EGP.
- "Today" and "this month" boundaries are computed in Cairo local time
  (`lib/dates.ts`), not server UTC time.
- The legacy `Transaction` table is kept, untouched, as an audit trail of
  the original flat entries — nothing writes to it anymore, and it isn't
  read by anything except the one-time migration script.
