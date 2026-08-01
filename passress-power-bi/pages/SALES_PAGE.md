# PASSRESS Power BI — Sales Page Build Spec

Follow this top to bottom in Power BI Desktop once `DATA_MODEL.md`'s
tables are loaded and `dax/SALES_MEASURES.md`'s measures are entered.
Canvas: standard 16:9 (1280×720), the Power BI default — no need to change
page size settings.

---

## 1. Page-level setup

1. New page, rename to **Sales**.
2. Format pane → Canvas background: **White** (`#FFFFFF`).
3. Format pane → Page size: **16:9** (default).
4. Turn off **Format → Page background image**, any default template
   styling — start from a blank white canvas, everything below is added
   deliberately.

## 2. Filter bar (top strip, y = 0–50px)

Four slicers in a horizontal row, styled as simple dropdown lists (not
tile/list slicers — dropdowns are the most compact and the least visually
busy, matching the "lots of white space" brief):

| Slicer | Field | x-position |
|---|---|---|
| Date | `DIM_Date[Date]` (between relative dates, or a simple range) | 0–280px |
| Collection | `DIM_Product[Collection]` | 300–520px |
| Category | `DIM_Product[Category]` | 540–760px |
| Channel | `FACT_OrderLines[Channel]` | 780–1000px |

Format each: Slicer settings → style **Dropdown**. Visual → Values: hide
the header background, thin `1px` border in light gray (`#E0E0E0`), 4px
rounded corners, no shadow (shadow is for cards, not filter chrome — keeps
the filter bar visually quiet).

**Sync slicers across pages** (Power BI's native Sync Slicers pane — View
→ Sync Slicers): once the Executive Dashboard and other pages exist, sync
Date/Collection/Category/Channel across all of them so filtering once
filters everywhere — no custom logic, just four checkboxes in a built-in
pane.

## 3. KPI card row (y = 60–180px)

Four Card visuals (the simple, modern "Card" visual — not the older
multi-row card), evenly spaced:

| Card | Measure | x-position | Format |
|---|---|---|---|
| Revenue | `[Revenue]` | 0–300px | `#,##0` currency, EGP |
| Orders | `[Orders]` | 320–580px | `#,##0` |
| Average Order Value | `[Average Order Value]` | 600–860px | `#,##0` currency |
| Units Sold | `[Units Sold]` | 880–1120px | `#,##0` |

**Card styling** (apply to all four, matches the brief's design language):
- Background: light gray `#F7F7F7`.
- Border: `1px` solid `#E5E5E5`, corner radius `8px`.
- Shadow: soft, `Format → Effects → Shadow`, pre-set "Soft" or manually:
  offset 0/2px, blur 8px, transparency 85%.
- Label (measure name) font: Segoe UI, 11pt, `#666666` (muted gray), above
  the value.
- Value font: Segoe UI Semibold, 28pt, `#000000` (black — the brief's
  primary color).
- No category/comparison arrows on this page (that's an Executive
  Dashboard pattern, per the brief's own KPI-card treatment there — Sales
  page cards stay plain and simple).

## 4. Sales Trend (y = 200–420px, full width 0–1280px)

**Line chart.** X-axis: `DIM_Date[Date]`. Y-axis: `[Revenue]`.
- Line color: black (`#000000`), 2px weight, no markers (keeps it clean at
  a glance).
- Gridlines: Y-axis only, very light gray `#F0F0F0`, no X-axis gridlines.
- Title: "Sales Trend" — Segoe UI Semibold 14pt, black, left-aligned, no
  visual border/background (title text only, matching the minimal style).
- Data labels: off (a trend line's shape is the point, not every individual
  value — keep it uncluttered).

This is the one visual on this page that the Field Parameter granularity
switcher (built with the Executive Dashboard) will eventually control —
for now it's fixed at daily/whatever `DIM_Date[Date]`'s natural grain
gives; revisit this visual's X-axis field when the switcher is built
rather than duplicating the chart.

## 5. Breakdown row (y = 440–700px) — four visuals, one Revenue measure each

Split the width into 4 equal columns (0–320, 330–650, 660–980, 990–1280),
each a **horizontal bar chart** (bars read left-to-right better than
columns for ranked category lists — the standard, most legible choice for
"Top N by category"):

| Visual | Axis field | Values | Title |
|---|---|---|---|
| Top Products | `DIM_Product[Title]` | `[Revenue]`, Top N filter = 10, sorted descending | "Top Products" |
| Sales by Collection | `DIM_Product[Collection]` | `[Revenue]`, sorted descending | "Sales by Collection" |
| Sales by Category | `DIM_Product[Category]` | `[Revenue]`, sorted descending | "Sales by Category" |
| Sales by Channel | `FACT_OrderLines[Channel]` | `[Revenue]`, sorted descending | "Sales by Channel" |

**Consistent bar styling across all four:**
- Bar color: warm beige (`#C9A88C`, the brief's secondary color) — Revenue
  bars use the secondary color, reserving black/primary for text and KPI
  card values so the page doesn't feel like it's shouting in one color.
- Data labels: on, outside end, `#,##0` format, 9pt gray.
- Axis title: off (the visual title already says what it is — an axis
  label repeating "Revenue" underneath is redundant clutter).
- Background: white, no border (these sit directly on the page canvas,
  unlike the KPI cards — only the KPI row gets the "card" treatment, to
  keep visual hierarchy: cards = headline numbers, plain charts = detail).

## 6. Sales by Country

Not placed in the 4-column breakdown row above (5 visuals wouldn't fit
cleanly at readable width) — add as a 5th visual below the breakdown row
(y = 720–900px, full width) **only if the page needs to scroll slightly**,
or swap it in for "Sales by Channel" in the row above if Channel turns out
to be less useful once real data is flowing (channel is often just "Online
Store" for a single-storefront brand with no POS, in which case that chart
would show one bar and add nothing — check with real data before deciding
final placement).

Same horizontal bar chart treatment: axis = `FACT_OrderLines
[ShippingCountry]`, values = `[Revenue]`, beige bars, sorted descending,
Top N = 10 (most brands' sales concentrate in 2-3 countries — a long tail
of 1-order countries doesn't need to all be shown).

---

## What's intentionally not on this page

- **Profit/margin** — Finance and Products pages own that, not Sales (see
  `dax/SALES_MEASURES.md`'s "what's deliberately not here yet").
- **Comparison arrows / vs. target** — that's the Executive Dashboard's
  job; Sales page reports what happened, plainly.
- **Drill-through to order-level detail** — a real, valuable Power BI
  feature (unlike the Excel project, which had no way to build interactive
  drill-through at all) but not built in this phase — flagged as a strong
  candidate for a later phase once the base pages exist, not added now
  just because it's technically easy.
