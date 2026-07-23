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

- **Quick add** (`/add`): same simple form as before — pick Income/Expense,
  tap a category, amount, date, note — now posting through the ledger.
- **Daily / Monthly / Trends** (`/dashboard/*`): unchanged behavior, now
  reading from journal lines instead of a flat table.
- **Reports** (`/reports`): Trial Balance, General Ledger (drill into any
  account), Profit & Loss, Balance Sheet, Cash Flow Statement.
- **Master data** (`/data`): full Add/Edit/Delete/Search/Active-filter/Audit
  screens for Suppliers and Bank Accounts today; the other 16 entities exist
  in the database and have a service layer, with their screens next in line.
- **Shopify sync**: same "Sync Shopify" button, now posting a journal entry
  (Debit Cash, Credit Shopify Sales) per order instead of a flat row.
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

The Shopify variables are optional — the app works fully for manual entry
without them. "Sync Shopify" will show an error until they're set.

## Notes on the numbers

- All amounts are stored and displayed in EGP.
- "Today" and "this month" boundaries are computed in Cairo local time
  (`lib/dates.ts`), not server UTC time.
- The legacy `Transaction` table is kept, untouched, as an audit trail of
  the original flat entries — nothing writes to it anymore, and it isn't
  read by anything except the one-time migration script.
