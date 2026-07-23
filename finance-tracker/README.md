# Passress Finance Tracker

A private, single-password expense & revenue tracker for Passress. Log every
EGP in a few taps, and see daily / monthly / trend dashboards. Built with
Next.js 16 + Prisma 7 + Postgres.

## What it does

- **Quick add** (`/add`): pick Income or Expense, tap a category, type an
  amount, save. Optimized for one-handed mobile use.
- **Daily dashboard** (`/dashboard/daily`): today's income, expense, net, and
  a list of today's entries (with delete).
- **Monthly dashboard** (`/dashboard/monthly`): month P&L, expense breakdown
  by category (chart), comparison vs. the prior month.
- **Trends** (`/dashboard/trends`): income / expense / net line chart over
  the last 12 months.
- **Shopify sync**: a "Sync Shopify" button on the daily dashboard pulls your
  store's orders in as Income transactions automatically (no manual entry
  for sales), skipping duplicates on re-sync.
- **Auth**: single shared password (you're the only user), protected by a
  signed session cookie — no user accounts to manage.

Categories are intentionally fixed (not user-editable) to keep entry fast and
the dashboard reports consistent:

- **Income:** Shopify Sales, Wholesale, Other Income
- **Expense:** COGS / Inventory, Marketing & Ads, Shipping & Fulfillment,
  Software & Subscriptions, Salaries & Contractors, Rent & Utilities, Bank &
  Payment Fees, Misc

## Local development

Requirements: Node 20+, a Postgres database.

```bash
npm install
cp .env.example .env   # then fill in the values, see below
npx prisma migrate dev
npm run dev
```

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

## Moving to production

### 1. Get a hosted Postgres database

Any of these have a free tier that's plenty for this use case:

- [Supabase](https://supabase.com) — free Postgres + built-in backups
- [Neon](https://neon.tech) — serverless Postgres, generous free tier
- [Railway](https://railway.app) — simple, pay-as-you-go

Copy the connection string into `DATABASE_URL`, then run:

```bash
npx prisma migrate deploy
```

### 2. Deploy the app

The easiest path is [Vercel](https://vercel.com/new):

1. Push this repo (or just the `finance-tracker/` folder as its own repo) to
   GitHub.
2. Import it in Vercel, set the Root Directory to `finance-tracker` if
   deploying from the monorepo.
3. Add the environment variables above in the Vercel project settings.
4. Deploy. `prisma generate` runs automatically via the `postinstall` script.

### 3. Get a Shopify Admin API token

In your Shopify admin: **Settings → Apps and sales channels → Develop apps →
Create an app**. Configure Admin API scopes to include `read_orders`, install
the app, and copy the Admin API access token into
`SHOPIFY_ADMIN_ACCESS_TOKEN`. Set `SHOPIFY_STORE_DOMAIN` to your
`*.myshopify.com` domain.

## Notes on the numbers

- All amounts are stored and displayed in EGP.
- "Today" and "this month" boundaries are computed in Cairo local time
  (`lib/dates.ts`), not server UTC time, so the daily view resets at Cairo
  midnight regardless of where the app is hosted.
- Shopify sync uses each order's `total_price` (gross) as Income under the
  "Shopify Sales" category and re-runs safely — it updates existing synced
  orders rather than duplicating them.
