# PASSRESS MIS — Deployment Guide

Phase 7 deliverable. Everything needed to take `PASSRESS_MIS.xlsx` from a
generated file to a live, refreshing, daily-use business system. Written for
whoever sets the workbook up the first time — not necessarily the person who
uses it day to day (see `OPERATIONS_MANUAL.md` for that audience).

---

## 1. System requirements

| Requirement | Minimum | Notes |
|---|---|---|
| Excel version | Excel 2016 (Windows), or Microsoft 365 | Needs Power Query ("Get & Transform"), Power Pivot (Data Model), and CUBE functions. Excel 2013 and earlier lack native Power Query. |
| Operating system | Windows 10/11 | See §1.1 — Mac is not fully supported. |
| Microsoft 365 license tier | Any tier that includes desktop Excel with Power Pivot | Power Pivot is included in every desktop Excel install from 2016 onward; it does not require a specific 365 plan, but it must be enabled once (§4). |
| Internet access | Required at refresh time | Outbound HTTPS to `<store>.myshopify.com` on port 443. |
| Disk space | ~50 MB per copy, more as historical data grows | The Data Model compresses well; RAW_ staging tables are the main growth driver. |

### 1.1 Windows vs. Mac

**Excel for Mac cannot host a Power Pivot Data Model as of this writing.**
Power Query ("Get & Transform") exists on Mac (16.x+) and can refresh the
`RAW_`/`DIM_`/`FACT_`/`LOG_` staging tables, but every DAX measure and every
CUBEVALUE/CUBESET dashboard formula (Phases 4-6, i.e. almost every visible
number outside the raw staging tables) needs the Data Model, which simply
isn't available on Mac. **Deploy on Windows.** If the primary maintainer
only has a Mac, use a Windows VM (Parallels/VMware) or a Windows machine for
setup and DAX maintenance; day-to-day viewing of already-refreshed dashboards
works fine on Mac since the CUBEVALUE results are just cached numbers in
cells once calculated on Windows.

---

## 2. First-time setup order

Do these in order — later steps depend on earlier ones being in place.

1. **Get the file.** Copy `PASSRESS_MIS.xlsx` to the machine that will own
   scheduled refreshes (or wherever it will be opened for daily use).
2. **Enable Power Pivot** (§4) if it isn't already.
3. **Set the Shopify connection settings** (§3) — Store Domain on
   `15_Settings`, access token via Excel's credential UI (never typed into
   any cell).
4. **Wire every Power Query** (§5) — this is the step most likely to be
   done partially; do it for every `RAW_`/`DIM_`/`FACT_`/`LOG_` sheet, not a
   subset (see the warning in §5.3).
5. **Build the Data Model relationships and DAX measures** (§6).
6. **Refresh All**, then run the validation checks in §7 before trusting any
   number on a dashboard.
7. **Set up the backup routine** (§8) before anyone starts entering real
   Purchase Orders, Expenses, Costs, Capital transactions, or Budget lines —
   once that data exists only in the workbook, losing the file loses it.

---

## 3. Credential setup

The Shopify Admin API access token is **never stored in the workbook, in
any `.pq` file, or in this repository** — every query authenticates via
`Extension.CurrentCredential()`, which Excel resolves from its own OS-level
credential store at refresh time.

1. Create a **custom app** in the Shopify Admin (Settings → Apps and sales
   channels → Develop apps) scoped to read-only permissions:
   `read_products`, `read_orders`, `read_customers`, `read_inventory`,
   `read_discounts`. Do not grant write scopes — this workbook only ever
   sends GraphQL `query` operations, never `mutation`, and a read-only token
   is a second line of defense if that ever changed by accident.
2. Install the app, generate the **Admin API access token**, and copy it
   somewhere secure (a password manager, not a text file).
3. On `15_Settings`, set **Shopify Store Domain** to the real
   `*.myshopify.com` domain (replacing the placeholder
   `your-store.myshopify.com`).
4. In Excel: **Data → Get Data → Data Source Settings → find the Shopify
   Web source → Edit Permissions → Credentials → Edit... → Web API → paste
   the access token into the Key field → OK.**
5. Excel stores the token in the Windows Credential Manager, not the
   workbook — copying the `.xlsx` file to another machine does **not**
   carry the credential with it; step 4 must be repeated on each machine
   that refreshes the file.
6. Rotating the token later: revoke the old one in Shopify Admin, generate a
   new one, repeat step 4 with the new value. No formula or `.pq` file
   changes needed.

---

## 4. Enabling Power Pivot (Windows Excel)

Power Pivot ships with Excel 2016+ but its ribbon tab is off by default.

1. File → Options → Add-ins.
2. At the bottom, set "Manage" to **COM Add-ins** → Go...
3. Check **Microsoft Power Pivot for Excel** → OK.
4. A "Power Pivot" tab appears in the ribbon. Use **Power Pivot → Manage**
   to open the Data Model window for §6.

---

## 5. Power Query setup

### 5.1 Order

Wire queries in this order — later ones depend on earlier ones existing as
named queries Excel can reference:

1. **Parameters** (`power-query/parameters/*.pq`) — six small queries, no
   dependencies. Create each as its own Blank Query, paste the `.pq`
   contents, name it exactly as the file (e.g. `Param_ShopifyStoreDomain`),
   and set its **value** to match `15_Settings` (or better: point it at
   `15_Settings` directly so the two never drift — see the comment in each
   parameter file).
2. **Shared functions** (`power-query/shared/*.pq`) — five queries, each a
   Blank Query named exactly as the file. These reference the parameter
   queries from step 1.
3. **Staging** (`power-query/staging/*.pq`) — one query per `RAW_`/`LOG_`
   sheet, plus `Orders_Source` (shared, connection-only — do not load it to
   a worksheet; see its own header comment). Each references the shared
   functions from step 2.
4. **Star schema** (`power-query/star-schema/*.pq`) — one query per
   `DIM_`/`FACT_` sheet. These reference the staging queries from step 3.

### 5.2 Per-sheet steps

For each `RAW_`/`DIM_`/`FACT_`/`LOG_` sheet in the workbook:

1. Right-click tab (unhide first via any visible sheet tab → right-click →
   Unhide, if needed) → select the existing placeholder table
   (`tbl_RAW_Variants`, etc.) → **delete the table** (Table Design →
   Convert to Range won't do — actually delete the rows/table so Power
   Query has a clean target).
2. Data → Get Data → Launch Power Query Editor → New Query → Blank Query.
3. Open the **Advanced Editor**, paste the matching `.pq` file's full
   contents, rename the query to match the sheet's code exactly (e.g.
   `RAW_Variants`, not `tbl_RAW_Variants` — no prefix).
4. **Close & Load To... → Existing Worksheet** → point it at the same
   hidden sheet, same top-left cell the placeholder table occupied (row 11,
   column B in every technical sheet — see `TECHNICAL_DOCUMENTATION.md`).
5. Confirm the resulting table is named after the query (no `tbl_` prefix)
   — every DAX measure already assumes this no-prefix convention. Every
   worksheet FORMULA and named range in the workbook, by contrast,
   deliberately still points at the `tbl_`-prefixed placeholder name (see
   §5.4 — this is not an oversight).

### 5.3 Wire every query, not a subset

**Do this for all 25 `RAW_`/`DIM_`/`FACT_`/`LOG_` queries before relying on
any dashboard number.** A partially wired workbook is worse than an unwired
one: an unwired table shows an obvious broken reference, while a table left
on its Phase 1 placeholder silently continues showing stale/example data
that downstream dropdowns and alerts will happily consume as if it were
real. `LOG_RefreshHistory`/`LOG_DataQuality` should be wired last — they
depend on the `RAW_` queries existing so Excel can compute the
"refresh-after" dependency Power Query needs (see that file's own header
comment on why this ordering works).

### 5.4 Required manual step after wiring RAW_Variants / RAW_Collections

**Two named ranges must be manually repointed once you wire these two
specific queries — this is not optional cleanup, the SKU/Collection
dropdowns across the workbook silently keep reading stale placeholder data
until you do it:**

1. Formulas tab → **Name Manager**.
2. Find **`SKUList`** — its "Refers to" currently reads
   `=tbl_RAW_Variants[SKU]`. Edit it to `=RAW_Variants[SKU]` (drop the
   `tbl_` prefix) — but **only after** `RAW_Variants` is actually wired
   (§5.2); editing this before the real table exists reintroduces the exact
   bug this section exists to prevent (see the note below).
3. Find **`CollectionTitleList`** — same edit:
   `=tbl_RAW_Collections[Title]` → `=RAW_Collections[Title]`, only after
   `RAW_Collections` is wired.
4. Close Name Manager, then **Data → Refresh All** to confirm every SKU/
   Collection dropdown (Product Cost Master, Manual Expenses, PO Lines,
   Goods Receipt) still offers real choices.

**Why this manual step exists at all** (the short version — full technical
finding in `PHASE8_DOCUMENTATION.md`): every workbook-scoped named range and
worksheet formula in this file that reads a `RAW_`/`DIM_`/`FACT_`/`LOG_`
table intentionally points at the `tbl_`-prefixed **placeholder** table name
(which always exists), not the post-wiring name Power Query eventually
creates. A real-world test caught that pointing a defined name at a table
that doesn't exist ANYWHERE in the file yet doesn't just show a formula
error — Excel's loader treats it as structurally invalid and strips the
name (and every Data Validation dropdown depending on it), forcing a
"we found a problem with some content" repair just to open the file. Every
other `RAW_`/`DIM_`/`FACT_`/`LOG_`-reading formula in the workbook (in
`BI_Alerts`, `14_Data_Quality`, `RPT_Workflow`, `01_Home`) has the same
`tbl_`-prefix-until-wired design and is safe to leave exactly as generated
— **`SKUList`/`CollectionTitleList` are the only two names you need to
touch by hand**, because Data Validation is the one place in this workbook
that reads a named range's formula directly rather than a cell formula
that can independently show `#REF!` without corrupting the file structure.

---

## 6. Data Model setup

1. Power Pivot → Manage opens the Data Model window.
2. **Add every `DIM_`/`FACT_` table to the Data Model** (Power Pivot →
   Add to Data Model, from each sheet, or drag from Power Query's queries
   pane with "Add to Data Model" checked at load time — cleaner to set this
   at Close & Load time in §5.2 step 4 by checking "Add this data to the
   Data Model").
3. **Mark `DIM_Date` as the Date Table**: Data Model window → Design →
   Mark as Date Table → column `Date`. Every time-intelligence DAX measure
   (`TOTALMTD`, `SAMEPERIODLASTYEAR`, etc.) requires this.
4. **Build relationships** — see `TECHNICAL_DOCUMENTATION.md`'s
   relationship table for the full list (every `FACT_` table's key columns
   to their matching `DIM_` table, one-to-many, single direction unless
   documented otherwise). `DIM_ProductCostHistory` deliberately has **no**
   Data Model relationship — see `dax/README.md` for why (date-range joins
   aren't expressible as a Power Pivot relationship; `fn_GetEffectiveCost`
   in Power Query resolves it instead).
5. **Enter every DAX measure**, in this order: `dax/MEASURES.md` →
   `dax/PHASE5_MEASURES_ADDENDUM.md` → `dax/PHASE6_MEASURES_ADDENDUM.md`.
   Later files reference measures from earlier ones by name — entering out
   of order will show a "measure not found" error until the referenced one
   exists too (harmless, just enter the missing one and it resolves).
6. `tbl_KPITargets` and `tbl_Budget` must also be added to the Data Model
   (step 2) before Phase 5's Target/Budget measures resolve.

---

## 7. Refresh procedure & first-refresh validation

### 7.1 Routine refresh

**Data → Refresh All** (or Ctrl+Alt+F5). This refreshes every Power Query
in dependency order, then recalculates the Data Model and every CUBEVALUE
formula. On a large dataset this can take several minutes — see
`OPERATIONS_MANUAL.md` for expected timing and what to do if it stalls.

### 7.2 First-refresh checklist

Run through this once, right after finishing §5-§6, before telling anyone
the workbook is live:

- [ ] Refresh All completes without an error dialog.
- [ ] `14_Data_Quality`'s **Overall Data Quality %** shows a real percentage
      (not 0%, not an error) — see `OPERATIONS_MANUAL.md`'s troubleshooting
      section if it doesn't.
- [ ] `BI_HealthScore`'s Total Business Health Score shows a number between
      0 and 100.
- [ ] `01_Home`'s **Last Refresh** and **Data Quality** cards show real
      values, not "—".
- [ ] Spot-check one dashboard's KPI cards (`02_Partner_Dashboard`) against
      the equivalent number in Shopify Admin's own analytics for the same
      period, as a sanity check.
- [ ] Run every check in `dax/MEASURES.md` §9 (Reconciliation) — Balance
      Sheet Check and Cash Variance should both be near 0.
- [ ] Confirm every SKU/Collection/Supplier dropdown (05_Products,
      10_Expenses, 12_Suppliers) actually offers choices, not a blank list
      — a blank list means a `RAW_` query wasn't wired (§5.3).

---

## 8. Backup procedure

The workbook is a single `.xlsx` file with **two very different kinds of
content**: everything generated by `python3 build_workbook.py` (structure,
formulas, DAX definitions once entered) is reproducible from this
repository at any commit; everything typed in by hand (Purchase Orders,
Expenses, Capital transactions, Product Cost Master rows, KPI Targets,
Budget lines, Holidays, Health Score weights) exists **only** in that file.

1. **Before the first real data entry**, put the file under a backup
   routine that keeps versioned snapshots, not just a single overwritten
   copy — OneDrive/SharePoint version history, a nightly copy to another
   drive with a date-stamped filename, or both.
2. **Recommended cadence**: daily, automatically, for a system used for
   daily business decisions. A version-history-enabled cloud folder
   (OneDrive/SharePoint) satisfies this with no extra scripting — every
   save is a recoverable version.
3. **Before any risky operation** (re-running `build_workbook.py` against a
   file that has real manual data in it, changing DAX measures, re-wiring a
   query) — take an explicit manual copy first, named with the date and a
   short reason (`PASSRESS_MIS_2026-08-01_pre-DAX-change.xlsx`).
4. **Retention**: keep at least 30 daily versions and 12 monthly snapshots
   (month-end copies) so a problem discovered weeks later is still
   recoverable to a point before it started.

---

## 9. Recovery procedure

**Scenario A — file lost or corrupted, no manual data entered yet:**
`python3 scripts/build_workbook.py` from any commit on
`claude/passress-mis-architecture-8hkcr6` (or whichever branch/tag is
current) regenerates the full structure from scratch. Re-run §5-§6 to
rewire.

**Scenario B — file lost or corrupted, manual data exists:** restore the
most recent backup (§8). If using OneDrive/SharePoint version history:
right-click the file → Version History → restore the last known-good
version. If using dated manual copies: copy the most recent one back to the
working location and rename it to the standard filename.

**Scenario C — a refresh corrupted/blanked live data (e.g. a bad Power
Query edit wiped a table):** do not re-refresh. Close without saving if the
bad state hasn't been saved yet; otherwise restore from the most recent
pre-refresh backup and re-apply only the intended change.

**Scenario D — workbook password lost:** the sheet-protection and
workbook-structure password is `Passress2026` (set in
`scripts/build_workbook.py`'s `PROTECT_PASSWORD` constant) — change this
constant and regenerate if the business wants a different password;
treat this document itself as sensitive once that's done, or store the
real password in a password manager instead of here.

---

## 10. Version upgrade procedure

When a future phase (or any change to `scripts/build_workbook.py`) needs to
reach a workbook that already has real business data in it:

1. **Back up first** (§8, step 3) — non-negotiable.
2. **Extract the manual-entry tables** you need to preserve: copy
   `tbl_ProductCostMaster`, `tbl_ManualExpenses`, `tbl_CapitalTransactions`,
   `tbl_SupplierMaster`, `tbl_POHeader`, `tbl_POLines`, `tbl_GoodsReceipt`,
   `tbl_Budget`, `tbl_KPITargets` (if customized), `tbl_HealthScoreWeights`
   (if customized), and `tbl_Holidays` to a scratch workbook.
3. **Regenerate** the workbook from the updated script
   (`python3 build_workbook.py`) — this produces a fresh file with the new
   structure and the same empty/example manual tables Phase 1-6 always
   ship with.
4. **Re-wire Power Query and the Data Model** (§5-§6) in the new file.
5. **Paste the preserved manual data back in** (step 2) — into the same
   table ranges, respecting each table's column order (unchanged across
   phases so far; verify against `TECHNICAL_DOCUMENTATION.md` if a future
   phase adds/reorders columns).
6. **Re-run the first-refresh checklist** (§7.2) on the upgraded file before
   retiring the old one.
7. **Update the Version Log**: `15_Settings`' `tbl_VersionLog` — a new
   phase's build script appends its own row automatically; nothing manual
   needed here beyond confirming `01_Home`'s Workbook Version card shows
   the new number after refresh.

This is the same procedure any future phase (8, 9, ...) should follow —
there is no different "one-time" migration path; every version upgrade
looks like this.
