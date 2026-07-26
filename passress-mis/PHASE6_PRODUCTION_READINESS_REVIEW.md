# PASSRESS MIS — Phase 6 Production Readiness Review & Acceptance Checklist

Covers Phase 6 items 9, 10, and 11. This file plus `PHASE6_DOCUMENTATION.md`
together are the "documentation auto-update" item 9 asked for — every new
table, measure, relationship, dependency, input source, and output consumer
introduced since Phase 5 is listed in one of the two files, not left implicit
in the workbook alone.

---

## 9. Documentation — what covers what

| Phase 6 asked for | Where it lives |
|---|---|
| New tables/sheets, what feeds them, what reads them | `PHASE6_DOCUMENTATION.md` §1-7, per-item source/consumer notes |
| New DAX measures | `dax/PHASE6_MEASURES_ADDENDUM.md` |
| New Power Query columns | `DIM_Date.pq` header comment (Phase 6 addition clearly marked, unchanged columns listed) |
| New named ranges | table below |
| Architectural review, defects found, recommendations | this file, §10 |
| Acceptance checklist | this file, §11 |

**New named ranges this phase** (all registered in `build_workbook.py`,
readable from `15_Settings` › Name Manager or Formulas › Name Manager):

| Name | Refers to | Purpose |
|---|---|---|
| `BusinessHealthScore` | `BI_HealthScore!$C$26` | Read by `RPT_ExecutiveBrief`; future consumer of any dashboard wanting the single master KPI |
| `BusinessHealthStatus` | `BI_HealthScore!$C$27` | RAG text ("GREEN"/"AMBER"/"RED"), same consumers |
| `OverallDataQualityPct` | `14_Data_Quality!$C$40` | Read by `BI_HealthScore` component 9 |

**New tables**: `tbl_HealthScoreWeights`, `tbl_Holidays` (both `15_Settings`),
`tbl_DataQualityChecks` (`14_Data_Quality`). None duplicate an existing
table's grain — `tbl_Holidays` is genuinely new data entry, the other two
are new computed/config tables.

**New sheets**: `BI_HealthScore`, `RPT_ExecutiveBrief`, `RPT_Workflow` (all
hidden, all added to `HIDDEN_ORDER`, all linked from `01_Home`'s "Reports &
Tools" section per your chosen navigation pattern).

---

## 10. Architectural Review

### 10.1 Defects found and fixed this phase

This is the headline finding of Phase 6's review, not a footnote: a
self-audit (`grep` across `build_workbook.py` for every `tbl_RAW_`,
`tbl_DIM_`, `tbl_FACT_`, `tbl_LOG_` reference) surfaced **5 latent broken
references**, all sharing one root cause — a table-naming lifecycle
mismatch between the Phase 1/2 placeholder and the table Power Query
actually produces once wired.

**Root cause**: `build_workbook.py` creates every `RAW_`/`LOG_` table as a
placeholder Excel Table named `tbl_RAW_Variants`, `tbl_LOG_DataQuality`,
etc. (`tbl_` prefix, per Phase 1's placeholder convention).
`power-query/README.md` instructs the user to delete that placeholder and
"Close & Load To Existing Worksheet" from the real query — the resulting
live table takes the **query's name**, with no `tbl_` prefix
(`RAW_Variants`, `LOG_DataQuality`). Every Phase 4 DAX measure was written
against the correct no-prefix name from the start. Five Phase 3/5 worksheet
formulas were not:

| # | Location | Was | Fixed to | Would have broken |
|---|---|---|---|---|
| 1 | `NAMED_LIST_RANGES` (`SKUList`) | `tbl_RAW_Variants[SKU]` | `RAW_Variants[SKU]` | Every SKU dropdown in the workbook (Product Cost Master, PO Lines, Inventory forms) |
| 2 | `NAMED_LIST_RANGES` (`CollectionTitleList`) | `tbl_RAW_Collections[Title]` | `RAW_Collections[Title]` | Collection dropdown, `01_Home` Global Filters |
| 3 | `BI_Alerts` ALT-04 (Products without SKU) | `tbl_RAW_Variants[SKU]` | `RAW_Variants[SKU]` | Alert silently shows 0/blank forever |
| 4 | `BI_Alerts` ALT-10 (Missing Shopify Sync) | `tbl_LOG_DataQuality[Status]` | `LOG_DataQuality[Status]` | Same — alert never fires |
| 5 | `BI_Alerts` ALT-11 (Refresh Errors) | `tbl_LOG_RefreshHistory[Timestamp]` | `LOG_RefreshHistory[Timestamp]` | Same |

**Why this matters more than a typical bug**: all five were syntactically
valid formulas that would compute cleanly against the *placeholder* tables
today, giving zero indication of a problem — they'd only break the moment
the user actually finished wiring Power Query (i.e., exactly when the
workbook starts being used for real). This is the class of defect a
structural review is supposed to catch that a "does it calculate without
error" pass would not. Each fix carries an inline code comment explaining
the lifecycle so the same mistake isn't reintroduced in a future phase.

**Verification**: after the fix, `grep -n "tbl_RAW_\|tbl_DIM_\|tbl_FACT_\|tbl_LOG_" scripts/build_workbook.py`
returns only the placeholder-table *creation* calls themselves (correct —
those really are named `tbl_...` until replaced) and zero remaining
*references* to a data table via its placeholder name.

### 10.2 Unused tables / measures

None found. Every table created has at least one formula, named range, or
documented future-connection consumer (Marketing-Ready Layer tables are
intentionally unconsumed — documented as reserved in Phase 5, not an
oversight). Every DAX measure in `MEASURES.md` / `PHASE5_MEASURES_ADDENDUM.md`
/ `PHASE6_MEASURES_ADDENDUM.md` is referenced by at least one dashboard,
alert, insight, or another measure.

### 10.3 Broken relationships

None introduced this phase. `DIM_Date.pq`'s new columns are plain
`Table.AddColumn` additions to the existing table — they don't touch the
`DateKey` relationship every fact table already uses, and no new
relationship was added or needed (the Holidays join happens *inside* the
Power Query step, before the table loads to the Data Model — `tbl_Holidays`
itself never becomes a Data Model table or relationship).

### 10.4 Duplicate logic

Checked specifically because Phase 6 is exactly the kind of phase that
invites it (a Business Health Score touching 10 other areas, a new
Executive Brief touching almost everything else). None found:
`BI_HealthScore` reads existing measures/named ranges rather than
recomputing them; `RPT_ExecutiveBrief` reuses `BI_Insights`, `BI_Alerts`,
and the Top-N pattern from `02_Partner_Dashboard` rather than rebuilding
any of them; `RPT_Workflow` reuses `[Cash Position]` and
`[Accounts Payable (Proxy)]` by reference, labeled as reuses, not
reintroduced under new names.

### 10.5 Circular dependencies

None possible in the current design: `BI_HealthScore` depends on DAX
measures + `14_Data_Quality` + `BI_Alerts`; nothing in the DAX layer or
`14_Data_Quality`/`BI_Alerts` depends back on `BI_HealthScore`. Verified by
inspection of the dependency direction (worksheet formulas can read the
Data Model; the Data Model has no way to read worksheet cells back), so a
cycle is structurally impossible, not just untested.

### 10.6 Hardcoded references

`RPT_ExecutiveBrief`'s today/yesterday CUBEVALUE filters use
`TODAY()`/`TODAY()-1` (dynamic, correct). No hardcoded dates, SKUs, or
sheet-name string literals were introduced beyond the 5 bugs already fixed
in §10.1. `BI_HealthScore`'s RAG thresholds (75/50) are the one intentional
"hardcoded" values in this phase's work — flagged in
`PHASE6_DOCUMENTATION.md` §3 as a deliberate, easily-adjustable default
rather than a config-table lookup, since a threshold used in exactly one
formula didn't justify a new settings table.

### 10.7 Formula inconsistencies

None found in the new formulas. Existing inconsistency (carried over,
not introduced): `BI_HealthScore`'s weighting uses `INDEX/MATCH` against
`tbl_HealthScoreWeights` rather than `LOOKUPVALUE` (a DAX function) —
intentional, since this table lives outside the Data Model (see
`PHASE6_MEASURES_ADDENDUM.md`), not an inconsistency with Phase 4/5's DAX
`LOOKUPVALUE` pattern.

### 10.8 Performance bottlenecks

- **CUBE function count**: `RPT_ExecutiveBrief` adds roughly 20 CUBEVALUE
  calls and 2 CUBESET/CUBERANKEDMEMBER blocks (Top 5 Products, Top 5
  Collections) — comparable to `02_Partner_Dashboard`'s existing load, not
  materially larger. `RPT_Workflow`'s 12-month trend table is 12 CUBEVALUE
  calls, the same pattern already used by `BI_Forecast` and the CEO
  dashboard's trend chart — no new pattern, no new load class.
- **No duplicate CUBE calls found**: every value computed once, referenced
  by cell/named-range where reused (see §10.4).
- **Known, documented scaling concern (not new this phase, re-flagged)**:
  `FACT_InventoryMovements` (Phase 4) is an append-only snapshot table with
  no archival/rollup strategy — it will grow unbounded with daily refreshes.
  Not a Phase 6 defect (the table's grain hasn't changed), but worth
  carrying into any future phase's scope: a yearly-partition or summarize-
  and-archive step before this becomes a real refresh-time problem.
- **`LOG_RefreshHistory` / `LOG_DataQuality`**: same append-only shape,
  same caveat, smaller row-width — lower urgency but same fix pattern
  applies if/when refresh cadence increases.

### 10.9 Scalability concerns

- Multi-currency: not supported anywhere in the workbook (EGP assumed
  throughout, consistent with brand scope) — flag only, out of scope to fix.
- Multi-location inventory: `DIM_Location` exists (Phase 2) but no Phase
  1-6 dashboard filters by location yet beyond the reserved `FilterLocation`
  cell on `01_Home` (Phase 5) — a real gap if Passress expands beyond one
  warehouse, not urgent at current scale.
- `tbl_Holidays` empty by default is correct behavior, not a defect, but
  worth reiterating in the acceptance checklist below since an empty table
  silently means `IsWorkingDay` = Mon-Fri only until someone populates it.

---

## 11. Final Acceptance Checklist

### Environment compatibility

| Item | Status |
|---|---|
| Excel version | Requires Excel 2016+ (Windows) or Excel 2019+/365 (Mac) for CUBE functions, Power Query, and Power Pivot Data Model. `FORECAST.LINEAR` requires Excel 2016+. |
| Windows compatibility | Full — Power Query, Power Pivot, and CUBE functions are native on Windows Excel 2016+/365. |
| Mac compatibility | Power Query ("Get & Transform") is available in Excel for Mac 16.x+; **Power Pivot / Data Model is NOT available in Excel for Mac** as of this writing. CUBE functions and DAX measures require the Data Model, so a Mac-only user cannot build or refresh the Data Model layer (Phases 4-6's DAX/CUBEVALUE content) — they can still open the file, view Phases 1-3 content, and run Power Query refreshes for `RAW_`/staging tables. Recommend Windows (or a Windows VM/Parallels) for any user who needs to author or maintain the Data Model. |

### Setup sequence (first-time)

1. **Power Query credentials**: per `power-query/README.md`, set the Shopify
   Admin API access token via Data › Get Data › Data Source Settings ›
   Edit Permissions (never hardcoded in any `.pq` file — confirmed absent
   by grep across `power-query/` this phase).
2. **Wire each query**: for every `RAW_*`/`DIM_*`/`FACT_*`/`LOG_*` sheet,
   delete the placeholder `tbl_*` table, paste the corresponding `.pq` file
   into Power Query's Advanced Editor, "Close & Load To" the existing
   worksheet. **This is exactly the step §10.1's bug fix protects** — do
   this for all queries, not a subset, or downstream dropdowns/alerts for
   the un-wired ones will show stale placeholder data (not an error, just
   silently wrong).
3. **Mark `DIM_Date` as the Date Table** (Data Model window › Design ›
   Mark as Date Table › column `Date`) — required for every time-
   intelligence DAX measure across Phases 4-6.
4. **Enter DAX measures**: per `dax/README.md`, `dax/MEASURES.md`,
   `dax/PHASE5_MEASURES_ADDENDUM.md`, `dax/PHASE6_MEASURES_ADDENDUM.md`, in
   that order (Phase 6's 3 measures depend on nothing added after Phase 5).
5. **Populate `tbl_Holidays`** (`15_Settings`) with the business's actual
   closure dates before relying on `IsWorkingDay`/`IsHoliday` for anything
   — it ships empty by design (§10.9).
6. **Set `tbl_HealthScoreWeights`** to the business's actual desired
   weighting if different from the shipped defaults (weights don't need to
   sum to 100; the formula normalizes).
7. **Refresh all** (Data › Refresh All), then verify `14_Data_Quality`'s
   Overall % and `BI_HealthScore`'s score both compute a non-zero,
   plausible value — this is the fastest single check that steps 1-4 all
   succeeded.

### Testing performed this session (structural / static)

- Zip integrity (`zf.testzip()`) — pass.
- XML well-formedness of every workbook part — pass.
- openpyxl reload round-trip — pass.
- Every Excel Table's declared range vs. actual populated rows/columns —
  pass, no bound mismatches.
- Every named range resolves to an existing sheet/cell — pass.
- Formula bracket-balance scan (unmatched `(`/`)`/`[`/`]`) across every
  formula written this phase — pass.
- Row-1 merged-cell violation check (the `title_bar()` gotcha from Phase 5)
  — pass, no violations.
- `HIDDEN_ORDER`/`VISIBLE_ORDER` completeness assertion — pass, 58 sheets
  total (15 visible, 43 hidden) accounted for.
- Table-naming lifecycle grep audit — pass after the 5 fixes in §10.1.

### Testing NOT performed (and cannot be, in this environment)

- **Live calculation testing**: no Excel or Power Pivot engine is available
  in this environment, so no CUBEVALUE, DAX measure, or Power Query step
  has been executed against real data. This has been true and disclosed at
  every phase (Phase 2's M code, Phase 4's DAX, Phase 5's CUBE formulas) —
  Phase 6 adds no new category of untested logic, only more instances of
  the same, already-flagged pattern. First real-data refresh is the actual
  test; recommend doing it against a copy of the file first.
  - **Highest-priority items to spot-check on first live refresh**:
    filtered CUBEVALUE date-member expressions (`RPT_ExecutiveBrief`'s
    Today/Yesterday cards, the trend tables), CUBESET/CUBERANKEDMEMBER
    Top-N lists, and the Holidays join in `DIM_Date.pq` (confirm
    `tbl_Holidays` being empty doesn't throw on the `try...otherwise`
    fallback — logic reviewed, but genuinely untested).
- **Performance/timing testing**: no way to measure actual refresh duration
  or CUBE-formula recalculation time without a live Excel session against
  real (or realistically-sized) data volume. §10.8's assessment is a static
  count-of-calls review, not a timed benchmark.

### Backup / versioning / recovery

- **Versioning strategy**: `15_Settings`' `tbl_VersionLog` (one row per
  phase, Phase 6 = row for "6.0") is the in-workbook version record;
  `01_Home`'s Workbook Version card reads it live. Git (this repository,
  branch `claude/passress-mis-architecture-8hkcr6`) is the source-of-truth
  version history for the *generator script* — `PASSRESS_MIS.xlsx` itself
  is a build artifact, regenerable from `scripts/build_workbook.py` at any
  commit.
- **Backup strategy recommendation**: once the user starts entering real
  data (Purchase Orders, Expenses, Cost history, Holidays, KPI Targets,
  Budget lines) directly into the workbook, that data lives *only* in the
  `.xlsx` file — re-running `build_workbook.py` would overwrite it. Two
  options going forward: (a) keep manual-entry data in the generated file
  only, back it up on a normal cadence (cloud sync, timestamped copies)
  and never re-run the generator against a file with real data without
  first extracting/preserving the manual tables, or (b) migrate manual-
  entry tables to a source the generator can re-import on each build
  (out of scope for this phase, a reasonable Phase 7+ candidate). This
  wasn't a concern through Phase 5 (no real data yet); it becomes real
  the day someone fills in Phase 3's PO/Expense/Cost tables.
- **Recovery procedure**: if the live workbook is lost/corrupted but no
  manual data has been entered yet, `python3 scripts/build_workbook.py`
  from any commit on the branch fully regenerates it. If manual data
  exists, recovery depends on the backup cadence chosen above — there is
  no in-workbook undo/version history beyond Excel's own autosave/AutoRecover.

### Known limitations (consolidated across all 6 phases)

- Data Model / DAX / CUBE functions unavailable on Excel for Mac (see
  compatibility table above).
- No multi-currency support (EGP only).
- No multi-location dashboard filtering yet (dimension exists, UI doesn't).
- CAC, ROAS, Conversion Rate, Marketing Budget Actuals: targets/budgets
  exist and are editable, no Actual measures until Marketing-Ready Layer
  is connected to real ad-platform data.
- Drill-through is link-based navigation between summary sheets, not
  interactive PivotTable "Show Details" — real PivotTables don't exist yet.
- `FACT_InventoryMovements`/`LOG_*` tables have no archival strategy —
  fine at current scale, a future concern at high refresh volume (§10.8).
- Filtered CUBEVALUE and CUBESET/CUBERANKEDMEMBER formulas are
  structurally sound but execution-untested (no Excel engine available
  here) — first live refresh is the real test.
- "Products without Images" data-quality check is N/A — `RAW_Products.pq`
  doesn't fetch image data (outside Phase 2's original scope; Phase 6 was
  told not to modify Phase 2 files).

### Future roadmap (not committed work — candidates for a future phase)

- Real PivotTables/Slicers once authored directly in Excel (by the user,
  or a future phase run with actual Excel available) to unlock true OLAP
  drill-through and native Slicer filtering wired to the existing
  `01_Home` Global Filters cells.
- Connect the Marketing-Ready Layer to real ad-platform APIs, unlocking
  CAC/ROAS/Conversion Rate Actuals and Marketing Budget variance.
- Add `images` field to `RAW_Products.pq`, resolving the one N/A data-
  quality check.
- Archival/summarization strategy for append-only `FACT_`/`LOG_` tables.
- Multi-location dashboard filtering.
- Decide and implement a manual-data-preserving regeneration strategy
  (backup recommendation above) before the workbook accumulates
  significant real business data.
- Replace `BI_Forecast`'s `FORECAST.LINEAR` with an AI/ML-based forecast,
  per the structural hook Phase 5 already built for this.
