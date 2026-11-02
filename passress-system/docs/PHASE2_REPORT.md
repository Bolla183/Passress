# PASSRESS — Phase 2 Report (Implementation Foundation)

> **Superseded in part by `PRE_BUILD_REVIEW.md` (2026-11-02):** COGS is no longer recognised "at sale"; it follows a configurable trigger (default: confirmed delivery). Partner-capital and legacy-row rules were tightened. Read that report for the current rules.

**Date:** 2026-11-01 · **Status:** code written and statically verified. Workbooks **not yet built** and PowerShell tests **not yet run**: both need a Windows PC with Excel (details in §1 and §7).

---

## 1. Step 1 — Implementation readiness (findings)

| Item | Result |
|---|---|
| Original workbook | Accessible (uploaded `Passress(3).xlsx`, 782,011 bytes, SHA-256 `9944f490…3000`). The original is never modified. The build copies it to `05_BACKUPS\00_ORIGINAL` (read-only) and re-checks the hash after reading. |
| GitHub branch `passress-mis-architecture` | Accessible. Reused the design ideas behind `fn_ShopifyGraphQL` (retry/throttle), `fn_ShopifyPagedConnection` (cursor paging) and `fn_GetEffectiveCost` (effective-dated cost), rewritten in PowerShell. Its login method, 20/50 refund caps and "incremental" window were not reused (Phase 1 findings). |
| **Excel version / COM** | **Not available in this environment** (Linux cloud container: no Windows, no Excel, no COM). `Test-PassressReadiness.ps1` performs these checks on your PC. |
| **PowerShell** | Not installed here. Installing PowerShell 7 was **blocked by this session's permission policy** (downloading and running external code), so no PowerShell code has executed yet. |
| Remote Control to your PC | Not possible: no computer is connected, and Remote Control supports Mac/Linux folders only, not Windows. |
| Shopify schema | All GraphQL fields used were verified against the Admin API schema (version 2026-07) with Shopify's schema tool. This is metadata only: no store data was read in Phase 2, and nothing was written. |
| Working directory | Code: `passress-system/` in the repository (not committed). Business data folder: created on your PC by the build script. |

## 2. Workbooks and folder structure

| Workbook | Exact path (created by `Build-PassressSystem.ps1`) |
|---|---|
| 01 Data Source | `C:\PASSRESS_BUSINESS_SYSTEM\01_DATA_SOURCE\01_DATA_SOURCE.xlsx` |
| 02 Operations | `C:\PASSRESS_BUSINESS_SYSTEM\02_OPERATIONS\02_OPERATIONS.xlsx` |
| 03 Finance | `C:\PASSRESS_BUSINESS_SYSTEM\03_FINANCE\03_FINANCE.xlsx` |
| 04 Management | `C:\PASSRESS_BUSINESS_SYSTEM\04_MANAGEMENT\04_MANAGEMENT.xlsx` |

The root folder is configurable (`RootFolder` in the config file).

```
PASSRESS_BUSINESS_SYSTEM\
  01_DATA_SOURCE\   01_DATA_SOURCE.xlsx, outputs\ (engine CSVs), inputs_snapshot\, state\, staging\<RunId>\ (Shopify extract)
  02_OPERATIONS\    02_OPERATIONS.xlsx, outputs\, inputs_snapshot\, state\cost_master_state.json
  03_FINANCE\       03_FINANCE.xlsx, outputs\, inputs_snapshot\, state\month_close_snapshots.json
  04_MANAGEMENT\    04_MANAGEMENT.xlsx, outputs\, inputs_snapshot\
  05_BACKUPS\       00_ORIGINAL\Passress(3).xlsx (read-only) + timestamped pre-refresh / pre-rebuild backups
  06_DOCUMENTATION\ architecture, data dictionary, setup/refresh/troubleshooting, this report
  07_CONFIGURATION\ passress.config.json (no secrets)
  08_LOGS\          build / readiness / refresh logs (.log + .json)
```

The Shopify credential lives outside this folder, in `%LOCALAPPDATA%\Passress\shopify_credential.xml` (encrypted with Windows DPAPI for your user only).

## 3. PowerShell scripts and modules

| File | Purpose |
|---|---|
| `scripts/Test-PassressReadiness.ps1` | Step 1 on your PC: PowerShell/OS version, Excel COM + version, Power Query object model, config, root folder writable, time zone, original workbook fingerprint, credential present. Read-only. |
| `scripts/Set-PassressShopifyCredential.ps1` | Stores the **new** client ID and secret. Asks you to confirm the old secret was rotated first. |
| `scripts/Build-PassressSystem.ps1` | Creates the folders, preserves the original, migrates legacy data (read-only), and builds the four workbooks via COM. Never overwrites a workbook without `-Rebuild` and a prior backup. |
| `scripts/Invoke-PassressRefresh.ps1` | Sequential controller: 01 → 02 → 03 → 04, LIVE or OFFLINE, with backup, a timeout watchdog, validation, and stop-on-failure. |
| `scripts/Restore-PassressBackup.ps1` | Restores workbooks, outputs and state from a backup (backs up the current files first). |
| `scripts/Set-PassressRootFolder.ps1` | Moves the system to a new folder with one command (config + `pRootFolder` in all four workbooks). |
| `scripts/Invoke-PassressOfflineTests.ps1` | Offline test suite with evidence files (JSON + Markdown). `-WithExcel` adds the Excel end-to-end tests. |
| `src/Passress.Common.psm1` | Config, logging with secret redaction, culture-independent CSV, schema projection, exceptions, Cairo time zone, backups, fingerprints. |
| `src/Passress.Engine.psm1` + `src/engine/*.ps1` | The business rules for stages 01–04 (no Excel, no network). Also handles stage file I/O, stale-upstream refusal, `_RUN.json` and `LOG_REFRESH`. |
| `src/Passress.Shopify.psm1` | Read-only GraphQL client. Refuses any mutation before sending. Token via client-credentials grant; retry and backoff on 429/5xx/THROTTLED; full pagination including nested line items, refund lines, refunds and transactions. |
| `src/Passress.Excel.psm1` | COM helpers: dedicated Excel instance (only its own process ID is ever stopped), locked-file refusal, typed and validated input tables, Power Query table loads, synchronous refresh, row-count validation, brand formatting. |
| `tools/static_checks.py`, `tools/generate_data_dictionary.py` | Static consistency checks (run here) and the data dictionary generator. |

In total: 3,369 lines of PowerShell, plus 61 table definitions in `schemas/tables.json` (the single source of truth for columns and types).

## 4. Excel COM implementation details

- **Instance safety.** `New-Object -ComObject Excel.Application` is created hidden, with alerts and events off, and macros force-disabled (`AutomationSecurity = 3`). The process ID is read from the window handle. On exit: Quit, release COM, and only if that same process ID is still alive, stop it. The timeout watchdog also targets only that process ID. Other Excel sessions are never touched.
- **Locked files.** Workbooks open in Excel are refused (`WORKBOOK_LOCKED` / `PREFLIGHT`).
- **Input tables.** Created as typed `ListObject`s with olive headers and light input cells. Each column gets a validation (dropdown lists, date ≥ 2020-01-01, numbers) and a header comment explaining it.
- **Reports.** Each is a Power Query query added with `Workbook.Queries.Add`, loaded through `Microsoft.Mashup.OleDb.1` into a `ListObject` (Excel 2016/2019 compatible). M code: `Csv.Document(File.Contents(pRootFolder & "\…\outputs\<TABLE>.csv"))`, typed with the `en-US` culture, blank cells converted to null.
- **Freshness.** `UPSTREAM_STATUS` in each downstream workbook reads the upstream `LOG_REFRESH` from the **saved** upstream file using `Excel.Workbook(File.Contents(...))`. HOME then shows `CURRENT` or `STALE`.
- **Refresh.** Every connection's `BackgroundQuery = False`. Each connection is refreshed individually with error capture, then `CalculateUntilAsyncQueriesDone`, then pivot refresh (quarterly/annual pivots hide percentage rows), then `CalculateFull`.
- **Validation before save.** Each output table's row count in Excel must equal the engine's count, and `LOG_REFRESH`'s last run ID must equal the current run. Otherwise the workbook is closed **without saving** and later stages are skipped.
- **Formats.** No macros; files saved as `.xlsx` (format 51). Formulas use only SUMIFS, COUNTIFS, INDEX, IF and IFERROR (Excel 2019 safe).

## 5. Tables, queries and connections

| Workbook | INPUT tables (you type) | REPORT tables (Power Query) | Other |
|---|---|---|---|
| 01 | ORDER_CLASSIFICATION (seeded: #1001–#1009 = TEST) | RAW_ORDERS, ORDER_LINE_ITEMS, ORDER_TRANSACTIONS, RAW_REFUNDS, REFUND_LINE_ITEMS, REFUND_TRANSACTIONS, RAW_CUSTOMERS, RAW_PRODUCTS, RAW_VARIANTS, SALES_FACT, REVENUE_EVENTS, REFUND_RECONCILIATION, EXCEPTIONS, LOG_REFRESH | HOME, CONFIG, CONTROLS |
| 02 | HEIRARCHY, COST_MASTER, OPENING_INVENTORY, PRODUCTION, SUPPLIERS, PURCHASES, RETURNS, RETURN_INSPECTIONS, INVENTORY_ADJUSTMENTS | SALES, CUSTOMER_BASE, SALES_COSTED, COGS_EVENTS, INVENTORY_MOVEMENTS, INVENTORY, REFUND_RETURN_RECONCILIATION, COST_EXCEPTIONS, INVENTORY_EXCEPTIONS, LOG_REFRESH | UPSTREAM_STATUS, CONTROLS |
| 03 | CHART_OF_ACCOUNTS (seeded, 36 accounts), EXPENSE_CATEGORY_MAP (seeded), DATA_ENTRY (37 legacy rows migrated unposted), OPENING_BALANCES, MONTH_CLOSE | JOURNAL_ENTRIES, TRIAL_BALANCE, PROFIT_AND_LOSS, BALANCE_SHEET, CASH_FLOW, ORDER_PROFITABILITY, PRODUCT_PL, CAPITAL_CONTRIBUTIONS, MONTH_CLOSE_STATUS, FINANCE_EXCEPTIONS, LOG_REFRESH | Pivots PL_MONTHLY / PL_QUARTERLY / PL_ANNUAL / BS_VIEW / CF_VIEW; UPSTREAM_STATUS; CONTROLS |
| 04 | MARKETING_INPUT, BUDGET_INPUT | EXECUTIVE_DASHBOARD (+ trend chart), KPI_MONTHLY, PRODUCT_PERFORMANCE, CUSTOMER_ANALYTICS, MARKETING_PERFORMANCE, INVENTORY_OVERVIEW, BUDGET_VS_ACTUAL, MANAGEMENT_EXCEPTIONS, LOG_REFRESH | UPSTREAM_STATUS, CONTROLS |

Every workbook also has the `pRootFolder` parameter query and a protected HOME sheet (status and guide). Full column definitions are in `docs/DATA_DICTIONARY.md`.

## 6. Logic implemented

### Order classification

- Classification is resolved in this order: a manual row in ORDER_CLASSIFICATION, then Shopify's `test` flag, then a `TEST` tag, otherwise **REAL by default**.
- An invalid or conflicting manual row makes the order UNCLASSIFIED: it is excluded and an ERROR is raised.
- Every TEST order gets an INFO exception, so exclusions stay visible.
- Raw tables keep everything. Every report, statement and KPI filters on `IsReportable`.

### Financial refunds

- The amount refunded is the sum of **successful REFUND transactions** only.
- It is recognised in the month of that transaction (Cairo time, daylight-saving aware).
- Each refund is reconciled: line allocations + refunded shipping + adjustments against the successful amount. Any difference is kept **UNALLOCATED** (account 4210) and raises an exception.
- A refund is never assigned to a product because the amounts happen to match. #1008's EGP 2,250 and #1009's EGP 3,150 stay unallocated.
- Refund-line subtotals on voids are treated as quantities only, never as cash.

### Physical returns and inspections

- These are separate tables. Shopify's `restockType` is stored for information only and proves nothing.
- A return counts only when its status is RECEIVED, INSPECTION_PENDING or CLOSED **and** it has a ReceivedDate.
- An inspection counts only when it is COMPLETE, approved, and dated.

### COGS and inventory

- COGS is recognised at sale for shipped quantity, at the unit cost valid on the sale date.
- COGS is reversed **only** for quantity received, inspected and approved as SELLABLE, at the **original** unit cost.
- DAMAGED and WRITE_OFF returns keep their COGS and go to separate stock buckets.
- Duplicate returns and inspections are ignored after the first and flagged. Event IDs are deterministic, so a repeated refresh produces identical output.
- The inventory ledger is movement-based: opening stock, production, purchases, sales, returns by bucket, and adjustments. Shopify's stock figure is used only as a check.
- Costs are append-only. An edited or deleted approved cost row raises an ERROR. A missing cost is never treated as zero.

### Partner capital

| Transaction | Debit | Credit |
|---|---|---|
| Partner deposits cash (`CAPITAL_DEPOSIT`) | Cash account | 3000 Partner Capital – deposits |
| Partner pays a company cost personally (`PARTNER_PERSONAL`) | Expense or asset | 3010 Partner Capital – paid personally |

- A partner-paid cost never reduces company cash.
- Production and inventory payments are posted to 1310 (an asset), never expensed as COGS when paid.
- A row with no PaymentSource is not posted, is flagged, and marks its month INCOMPLETE.
- A possible double count (same partner, same amount, recorded as both deposit and personal payment within 3 days) raises a warning.

### Statements

- The P&L, Balance Sheet and Cash Flow are built from the double-entry journal.
- Each month is labelled PRELIMINARY or INCOMPLETE; nothing is labelled final.
- The Balance Sheet stays INCOMPLETE until opening balances are entered.
- Engine controls, and Excel formula controls, re-check: journal balanced, Balance Sheet balanced, Cash Flow equals Balance Sheet cash, P&L equals the revenue ledger, Product P&L equals the P&L, P&L COGS equals Operations COGS, and no TEST order reaches Finance or Management.
- Month close takes a snapshot and flags any later change to a closed month.

## 7. Tests: what was actually executed

| Test | Where | Result | Evidence |
|---|---|---|---|
| Static consistency checks: 738 engine row keys, 29 formula references, 159 test-assertion columns, all checked against the schema; bracket balance in 18 PowerShell files; no credential-shaped strings | Here (Python) | **PASS** | `python3 tools/static_checks.py` |
| Static checker validated against deliberate errors (misspelled column, missing brace, wrong assertion column) | Here | **PASS** (all 3 caught) | Session log |
| Test fixture #1001–#1009 totals match the Phase 1 Shopify evidence (all 9 orders) | Here | **PASS** | `build_test_order_fixture.py` output |
| Shopify GraphQL fields exist in the API schema (Refund, RefundLineItem, RefundShippingLine, OrderAdjustment, Order.transactions/refunds, Customer, CustomerEmailAddress, ProductVariant, InventoryItem.unitCost, LineItem) | Here (Shopify schema tool) | **PASS** | Session log |
| 20 engine scenarios, 159 assertions: test orders, new order defaults to REAL, **Cases A/B/C**, pending and unapproved inspections, partial refund, partial return, duplicates and idempotent re-run, refund month, partner capital, double-count warning, missing cost/SKU, missing funding classification, effective-dated cost and append-only, unallocated refund on a REAL order, cancelled unpaid order, Cairo month boundary, no test-order leakage, multiple refunds | Needs PowerShell | **NOT RUN** | Run `Invoke-PassressOfflineTests.ps1` |
| File-level refresh protections (IO-01 to IO-06): full offline chain, every output has a CSV, append-only log, stale upstream refused, failed upstream refused, corrupt extract refused | Needs PowerShell | **NOT RUN** | Same script |
| Security and culture tests (SEC-01 to SEC-06, CSV-01): read-only guard, secret redaction in logs, German decimal comma | Needs PowerShell | **NOT RUN** | Same script |
| Excel end-to-end (XL-01 to XL-04): build via COM, controlled OFFLINE refresh, failure at 02 skips 03/04, no orphan Excel process | Needs Windows and Excel | **NOT RUN** | `-WithExcel` |

**No PowerShell test is claimed as passed.** Expected values in the scenarios were written by hand from the approved rules, not taken from engine output.

## 8. Known issues and missing business inputs

### Known issues and risks

- **No PowerShell has executed yet.** The first run on your PC may surface runtime errors that static checks cannot catch. Run the offline tests before building.
- **Power Query privacy settings.** If Excel shows a privacy-level prompt on first refresh, set the privacy level for the CSV folder (see the troubleshooting guide).
- **Accounts Payable** is not modelled from supplier bills yet.
- **Per-order costs** (shipping, COD fees, packaging) are not available from any source, so order contribution excludes them and is labelled accordingly.

### Legacy data

- The 37 DATA ENTRY rows are migrated **unposted** with PaymentSource blank. For each row you must say whether it was paid by the company or personally by a partner.
- Legacy COGS rows are reclassified to PRODUCTION_PAYMENT (inventory, not COGS), as the rules require.
- The legacy Cowboy Pants costs are migrated as **unapproved** (labels unconfirmed, no effective date), so they are not used yet.

### Missing inputs (all have input tables and are flagged until entered)

1. Unit costs for Napoleon Blazer, Offbeat Brown Blazer, Hideout Laptop Sleeve (-13 and -15), Stone Cropped Blazer and passBlazer.
2. SKUs for Stone Cropped Blazer and passBlazer, to be set in Shopify.
3. Opening and current stock per SKU.
4. Opening bank, InstaPay and cash balances.
5. Opening capital and a breakdown per partner.
6. COD courier remittances and fees.
7. Shipping costs.
8. What the EGP 29,400 in the old P&L cell O6 represents.
9. How to treat samples, packaging and the legacy "EXPENSES / PRODUCTION" rows. These are currently posted provisionally and flagged.

## 9. Security status

- The old client secret is treated as **compromised**. It does not appear anywhere in the new code, M queries, workbooks, config, logs or docs; the static check confirms this.
- **Live API testing remains blocked.** The controller refuses LIVE mode until a credential has been stored with `Set-PassressShopifyCredential.ps1`, and that script first asks you to confirm the old secret was rotated.
- All Shopify access is read-only and enforced in code.
- Nothing was published or deployed, and no Shopify data was changed.

## 10. Next actions for you

1. In the Shopify Dev Dashboard (app **PASSRESS_DATA**), **rotate or revoke the old client secret**.
2. On your Windows PC: copy `passress-system`, create `C:\PASSRESS_BUSINESS_SYSTEM\07_CONFIGURATION\passress.config.json` from the template, then run:
   1. `Test-PassressReadiness.ps1`
   2. `Invoke-PassressOfflineTests.ps1 -WithExcel`
   
   Send me the `TEST_REPORT_*.md` and readiness JSON, or any error output.
3. If everything passes, run `Build-PassressSystem.ps1 -OriginalWorkbookPath "…\Passress(3).xlsx"`.
4. Store the new credential with `Set-PassressShopifyCredential.ps1`, then run `Invoke-PassressRefresh.ps1 -Mode LIVE`.
5. Fill in: PaymentSource on the 37 migrated rows, approved unit costs, opening stock, and opening balances.
6. Optional: allow this session to install PowerShell 7, so I can run the 159-assertion offline suite here before you test on Windows.
