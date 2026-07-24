# Passress Financial Operating System

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

The bottom nav is deliberately short — **Add, Payroll, Performance, Reports,
More** — so day-to-day use only ever touches the first four. Everything from
Phase B/C still exists, it's just tucked under **More** instead of competing
for attention on every screen.

- **Add** (`/add`): the app's landing page (login goes straight here) and
  tuned for repeat use in under 10 seconds — the last category you used per
  Income/Expense is remembered (`localStorage`) and pre-selected, Date/Note
  are collapsed behind an optional toggle (today's date is used unless you
  expand it), and the amount field refocuses after each save so logging
  several expenses in a row needs no extra taps. A small "Today / This
  month" strip at the top (`/api/performance/snapshot`, ledger-accurate)
  gives an at-a-glance performance check without leaving the screen.
  Revenue syncs from Shopify automatically once a day via Vercel Cron
  (`vercel.json` → `/api/cron/shopify-sync`); the **Sync Shopify** button
  on the same page is still there for an on-demand sync in between. Both
  paths share one function (`lib/modules/shopifySync.ts`) and only ask
  Shopify for orders updated since the last successful sync
  (`Company.lastShopifySyncAt`), so repeat syncs stay cheap regardless of
  order history. Installable to a phone home screen (`app/manifest.ts` +
  generated icons) for a chrome-less, one-tap launch straight into Add.
- **Payroll** (`/payroll`): type a name and an amount, hit Pay — no employee
  record to set up first. The name is matched (or silently created) against
  the Employee master table behind the scenes, so per-person totals still
  work, but there's nothing to configure up front. Shows this month's total,
  a by-person breakdown, and a running list, with month navigation.
- **Performance** (`/dashboard/performance`): a BI-style glance, not a table —
  a hero Net Profit figure with a growth delta against the previous
  comparable period, Revenue/Expenses/Margin on elevated cards, a
  gradient-filled area chart for the 12-month revenue-vs-expense trend
  (`components/PerformanceAreaChart.tsx`), and revenue/expense by category,
  with a This Month/Last Month/This Quarter/This Year switch. Deliberately
  excludes Cash Balance/AR/AP — those depend on Bank Accounts and Customers,
  which aren't part of the day-to-day flow. Computed directly from the
  ledger (`getExecutiveSummary`/`getMonthlyTrend` in
  `lib/accounting/reports.ts`), not from the quick-add "simple entries"
  reconstruction, so it's always complete regardless of which workflow
  posted the activity.
- **Reports** (`/reports`): Trial Balance, General Ledger (drill into any
  account), Profit & Loss, Balance Sheet, Cash Flow Statement — the actual
  financial statements, unchanged.
- **More** (`/more`): everything else, still fully working —
  - **Older dashboards**: Daily / Monthly / Trends, reading from journal
    lines. Kept for reference; Performance supersedes them for day-to-day use.
  - **Business workflows** (`/workflows`): Bills (AP) and Invoices (AR) with
    partial-payment tracking; Loans (disbursement + repayment, split into
    principal/interest); Inventory (Purchase/Sale/Manufacture, with COGS
    posted at cost and stock-level validation).
  - **Master data** (`/data`): full Add/Edit/Delete/Search/Active-filter/Audit
    screens for Suppliers and Bank Accounts today; the other 16 entities exist
    in the database with a service layer, screens to follow as needed.
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
| `CRON_SECRET` | Any long random string. Required for the daily automatic Shopify sync — Vercel sends it as `Authorization: Bearer $CRON_SECRET` on the scheduled request, and `/api/cron/shopify-sync` checks it before running. Generate one with `openssl rand -hex 32` and add it in Vercel's project Environment Variables (same manual step as the other secrets below) |

The Shopify variables are optional — the app works fully for manual entry
without them. "Sync Shopify" will show an error until they're set.

**On the Hobby plan, Vercel Cron only allows once-per-day schedules** —
`vercel.json` is set to `0 3 * * *` (around 3am UTC daily; Vercel may fire it
anytime in that hour). If the Vercel project is on the Pro plan, the
schedule can be tightened to hourly (`0 * * * *`) or more often for closer
to real-time revenue.

## Notes on the numbers

- All amounts are stored and displayed in EGP.
- "Today" and "this month" boundaries are computed in Cairo local time
  (`lib/dates.ts`), not server UTC time.
- The legacy `Transaction` table is kept, untouched, as an audit trail of
  the original flat entries — nothing writes to it anymore, and it isn't
  read by anything except the one-time migration script.
