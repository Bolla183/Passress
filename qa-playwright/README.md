# Passress — Live Storefront E2E QA Suite

A Playwright suite that exercises `https://www.passress.com` like a real
customer would: homepage, navigation, collections, product pages (images,
swatches, size, quantity, add-to-cart), cart drawer/page, search, filters &
sorting, wishlist (if present), footer links, contact/track-order/shipping/
returns/FAQ pages, forms, accessibility (axe-core), and site-wide broken
link/image checks — across Desktop, Tablet (iPad), and Mobile (iPhone 13)
viewports.

## Important caveat

This suite was written from this sandboxed session, which has **no outbound
network access to passress.com** (blocked by this environment's egress
policy). Every test uses resilient, role/text-based locators and common
Shopify/e‑commerce UX patterns rather than hard-coded CSS selectors tied to
one theme's markup — but **none of it has been run against the real site
yet**. The first run on your machine is the real verification step.
Expect to:

1. Run it once, headed, and watch what happens (`npm run test:headed`).
2. Open the HTML report for any failures (`npm run report`) — each failure
   includes a screenshot, video, and trace.
3. Tighten a selector or two in `tests/utils/shop-flows.ts` if your theme's
   markup doesn't match what a locator guessed (e.g. a custom swatch
   component). The helpers are centralized there specifically so this is a
   small, one-place edit.

## Setup

Requires Node 18+.

```bash
cd qa-playwright
npm install
npx playwright install --with-deps chromium
cp .env.example .env
```

Edit `.env` if needed — it already defaults to the preview URL you gave me:

```
BASE_URL=https://www.passress.com
PREVIEW_THEME_ID=189593944428
```

If the preview theme gets published or the ID changes, update
`PREVIEW_THEME_ID` (or clear it to test the live published theme). If the
store has Shopify's storefront password screen enabled, set
`STOREFRONT_PASSWORD` too.

## Running

```bash
npm test                # all specs × Desktop/Tablet/Mobile
npm run test:desktop    # just the Desktop project
npm run test:tablet     # just the Tablet project
npm run test:mobile     # just the Mobile project
npm run test:headed     # watch the browser
npm run test:ui         # Playwright's interactive UI mode — best for debugging
npm run report          # open the HTML report from the last run
```

Run a single file: `npx playwright test tests/product.spec.ts`
Run a single project + file: `npx playwright test tests/cart.spec.ts --project=Mobile`

## What each file covers

| File | Covers |
|---|---|
| `homepage.spec.ts` | Load success, console/network errors, hero/header render, image integrity, nav timing budget |
| `navigation.spec.ts` | Desktop/tablet header nav links, mobile hamburger drawer, logo → home |
| `collections.spec.ts` | Product grid renders, card images, pagination/load-more |
| `product.spec.ts` | Gallery, title/price, color swatches, size selector, quantity, add-to-cart, sold-out handling |
| `cart.spec.ts` | Drawer/page shows item, quantity update, remove item, empty state, checkout button |
| `search.spec.ts` | Search returns results, empty-query friendly state |
| `filters-and-sorting.spec.ts` | Sort-by reorders products, facet filters narrow the grid |
| `wishlist.spec.ts` | Wishlist button on cards/PDP and a dedicated wishlist page — **skips cleanly if the store has no wishlist feature** |
| `footer-and-static-pages.spec.ts` | Footer links + newsletter form, Contact/Track Order/Shipping/Returns/FAQ pages reachable and error-free |
| `forms.spec.ts` | Contact + Track Order form validation; a real end-to-end submission is **gated behind `ALLOW_REAL_FORM_SUBMISSION=true`** so test runs don't spam your inbox by default |
| `accessibility.spec.ts` | axe-core scan (WCAG2A/AA + best practice) on homepage/collection/product/cart; fails on critical/serious violations, reports moderate ones |
| `broken-links-and-images.spec.ts` | Crawls links/images across homepage → collection → product → cart and flags any 4xx/5xx or failed image |

Tests that depend on a feature that may not exist (wishlist, filters,
pagination, sold-out variants, password protection) call `test.skip(...)`
with a reason instead of failing, so a green run means "everything present
was checked and passed," not "every listed feature exists."

## Notes

- `tests/global-setup.ts` runs once before the suite: it loads the site
  with `?preview_theme_id=...` (and the password gate if configured), then
  saves cookies to `.auth/storefront-state.json` so every subsequent test
  hits the preview theme without repeating the query param.
- Screenshots, videos, and traces are captured automatically **only on
  failure** (`playwright.config.ts`), keeping the report small on a clean
  run.
- `ALLOW_REAL_FORM_SUBMISSION=true npm test -- tests/forms.spec.ts` to
  additionally verify a full contact-form submission end to end.
