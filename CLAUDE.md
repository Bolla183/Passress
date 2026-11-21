# Passress — Project Instructions for Claude

These rules apply to all Passress Shopify development, in every session.
They are standing instructions from the store owner and take precedence over defaults.

## Tools and skills (use automatically)

- Use the Shopify connection (the Shopify AI Toolkit) for all store and theme work.
  - Load the `admin-graphql` skill before any Admin GraphQL query or mutation.
  - Load the `editing-themes` skill before reading, editing or reviewing theme files.
- Apply the relevant Passress skills without being asked:
  - `shopify-developer`: Liquid and Impulse theme development
  - `shopify-performance-engineer`: Core Web Vitals, Liquid/CSS/JS efficiency, images
  - `luxury-ui-design-system`: UI/UX and visual design
  - `passress-brand-guardian-luxury-copywriter`: all customer-facing copy
  - `technical-seo-ai-search-specialist`: SEO, structured data, AI search visibility
  - `shopify-qa-code-review-deployment-guardian`: final review before any change is considered done

## Theme safety

- Work **only** on the designated **unpublished backup theme**.
  - Designated theme: **Passress main layout backup**, ID `gid://shopify/OnlineStoreTheme/194859598188` (role `UNPUBLISHED`, verified 2026-11-21).
  - The live theme is **Passress main layout** (`gid://shopify/OnlineStoreTheme/189593944428`, role `MAIN`). Never edit it.
  - Before every theme edit, confirm via `graphql_query` that the target theme's role is **not** `MAIN` (live). If it is live, or its role is unclear, stop and ask.
- **Never modify the live (published) theme.**
- **Never publish a theme** (`theme_publish`) or deploy anything without the owner's explicit approval, given in the current conversation for that specific change.

## Store safety

- **Never change store settings** (shop configuration, payments, shipping, taxes, domains, policies, apps, staff, etc.).
- Do not create, edit or delete products, collections, discounts, inventory, customers or orders unless the owner explicitly asks for that specific change.
- Read-only queries (GraphQL queries, ShopifyQL analytics, docs search) are fine when the task needs them.

## Change process

1. **Back up first.** Before editing, keep a restorable copy of every file you'll touch (e.g. save the originals into the working directory or the scratchpad, or confirm the theme's version history holds the current state). Copy a whole theme only if the owner asks for a copy.
2. **Review before applying.** Show the owner the planned changes (what files change and a diff or summary) and run the QA/review skill before saving with `theme_commit`.
3. **Ask before anything destructive or irreversible.** That includes deleting files, overwriting content, bulk edits, `theme_commit` (no undo), `theme_publish`, and any `graphql_mutation`. Get approval each time; approval for one change does not extend to the next.

## Preserve what exists

- Keep all existing Shopify functionality working: cart, checkout, product/variant selection, search, filters, apps, analytics and tracking, Shop Pay, and metafields.
- Keep the Passress brand identity: an affordable luxury women's fashion brand with a minimal, refined, mobile-first style. Don't introduce off-brand styles, copy or patterns.
