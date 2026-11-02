# PASSRESS Business System - Architecture & Accounting Rules (Phase 2)

## 1. Design in one paragraph
Four Excel workbooks, one direction of data flow, one engine. A PowerShell **controller** opens each workbook in its
own Excel instance (COM), snapshots the operator's **input tables** to CSV, runs the **engine** stage (pure PowerShell,
tested offline), writes every **output table** to CSV, then refreshes the workbook's **Power Query** connections
(which load those CSVs), validates that Excel shows exactly what the engine wrote, saves, closes, and only then moves
to the next workbook. Excel is the user interface and the system of record for manual inputs; the engine guarantees
that the accounting rules are applied identically every time.

```
Shopify Admin GraphQL (read-only, rotated credential, DPAPI-encrypted)
        |  Invoke-PassressShopifyExtract  -> 01_DATA_SOURCE\staging\<RunId>\orders.json ...
        v
01_DATA_SOURCE.xlsx   inputs: ORDER_CLASSIFICATION
                      outputs: RAW_*, ORDER_LINE_ITEMS, REFUND_*, SALES_FACT, REVENUE_EVENTS, REFUND_RECONCILIATION, EXCEPTIONS
        v   (engine reads 01 outputs of THIS run only - stale/failed upstream is refused)
02_OPERATIONS.xlsx    inputs: COST_MASTER, OPENING_INVENTORY, PRODUCTION, PURCHASES, SUPPLIERS, RETURNS, RETURN_INSPECTIONS, INVENTORY_ADJUSTMENTS, HEIRARCHY
                      outputs: SALES, CUSTOMER_BASE, SALES_COSTED, COGS_EVENTS, INVENTORY_MOVEMENTS, INVENTORY, REFUND_RETURN_RECONCILIATION, *_EXCEPTIONS
        v
03_FINANCE.xlsx       inputs: DATA_ENTRY, CHART_OF_ACCOUNTS, EXPENSE_CATEGORY_MAP, OPENING_BALANCES, MONTH_CLOSE
                      outputs: JOURNAL_ENTRIES, TRIAL_BALANCE, PROFIT_AND_LOSS, BALANCE_SHEET, CASH_FLOW, ORDER_PROFITABILITY, PRODUCT_PL, CAPITAL_CONTRIBUTIONS, MONTH_CLOSE_STATUS, FINANCE_EXCEPTIONS
                      views:   PL_MONTHLY / PL_QUARTERLY / PL_ANNUAL / BS_VIEW / CF_VIEW pivots, CONTROLS
        v
04_MANAGEMENT.xlsx    inputs: MARKETING_INPUT, BUDGET_INPUT
                      outputs: EXECUTIVE_DASHBOARD, KPI_MONTHLY, PRODUCT_PERFORMANCE, CUSTOMER_ANALYTICS, MARKETING_PERFORMANCE, INVENTORY_OVERVIEW, BUDGET_VS_ACTUAL, MANAGEMENT_EXCEPTIONS
```
No workbook ever reads a downstream workbook - there are no circular dependencies. Cost lives in 02, so SALES_FACT (01)
carries no cost (approved decision A from Phase 1).

## 2. Why the engine is PowerShell (and not M formulas)
* The rules (line-level refund allocation, refund/return/inspection separation, effective-dated costing, double entry)
  must be **testable offline** before any live data is touched. Power Query M cannot be executed outside Excel.
* The controller already runs PowerShell (approved method). Keeping the logic there means one runtime, one test suite.
* Excel keeps everything that should be visible to the operator: Power Query loads (Excel 2019 compatible:
  `Csv.Document`, `Excel.Workbook(File.Contents(...))`), structured tables, pivots, and independent formula **CONTROLS**
  (SUMIFS/COUNTIFS over the loaded tables) that re-check the engine.

## 3. Keys, freshness, configuration
| Concept | Rule |
|---|---|
| Primary keys | Shopify GIDs (Order, LineItem, Refund, RefundLineItem, OrderTransaction, Customer, Variant). Manual: TransactionID, CostRecordID, ReturnID, InspectionID, ProductionID, PurchaseID, AdjustmentID. |
| Event ids | Deterministic (`REV-S-<line>`, `REV-RL-<refundLine>`, `COGS-<line>`, `COGSREV-<inspection>`, `MOV-...`, `JE-<event>`). Re-running never duplicates. |
| Run id | Every refresh has one RunId. Each stage writes `outputs\_RUN.json`; a stage only consumes upstream outputs with **the same RunId and Status OK**. |
| Freshness in Excel | HOME shows the last run, status, error count, upstream run consumed, and (from the saved upstream workbook, via `Excel.Workbook(File.Contents())`) the upstream's latest run -> `CURRENT` or `STALE`. |
| Root folder | One Power Query parameter `pRootFolder` per workbook + `RootFolder` in the config file. Moving the system = `Set-PassressRootFolder.ps1` (one command updates all four). |
| Credentials | Never in workbooks, M, config, logs or git. `%LOCALAPPDATA%\Passress\shopify_credential.xml` (DPAPI, current Windows user, file ACL restricted). |

## 4. Accounting rules implemented

### 4.1 Order classification
* `ORDER_CLASSIFICATION` (01): OrderGID / OrderName, Classification TEST|REAL, Reason, EffectiveDate, UpdatedAt.
* Seeded: #1001-#1009 = TEST (approved). Resolution order: manual row -> Shopify `test` flag -> tag `TEST` (config) -> **REAL by default**.
* Invalid or conflicting manual rows -> `UNCLASSIFIED`, excluded, ERROR exception. Every TEST order appears as an INFO exception (visible audit trail).
* `IsReportable = (Classification = REAL)` - every operational, financial and management output filters on it. Raw tables keep everything.

### 4.2 Revenue and refunds (01)
* SALE events in the order month (shop time zone Africa/Cairo, DST-aware).
* **Money refunded = successful REFUND transactions only.** Pending/failed transactions are logged, not recognised.
* Refund recognised in the month of the successful refund transaction (approved). The original sale month is never rewritten.
* Per refund: `success total - (line allocations + refunded shipping + order adjustments)`. Zero -> ALLOCATED. Otherwise the
  difference is an **UNALLOCATED** event (account 4210) and an exception. **Nothing is ever assigned to a product by matching amounts.**
* Refund line subtotals with no money (voids/cancellations) are quantities only - never treated as cash.
* Cancellation: no-money quantities on a cancelled order (or `CANCEL` restock lines) reverse revenue in the cancel month.
  `restockType = CANCEL` means the item never shipped -> no COGS.
* `restockType` / `restocked` are stored for information only and are **not** proof of a physical return.

### 4.3 Physical return, inspection, COGS, inventory (02)
| Financial refund | Physical return | Inspection | Revenue | COGS | Sellable stock |
|---|---|---|---|---|---|
| Yes | No | - | reduced (refund month) | kept | unchanged |
| Yes | Yes | pending / unapproved | reduced | kept | unchanged |
| Yes | Yes | SELLABLE (approved) | reduced | reversed for accepted qty at ORIGINAL unit cost | +qty at original cost |
| Yes | Yes | DAMAGED | reduced | kept | unchanged; DAMAGED bucket +qty (value 0) |
| Yes | Yes | WRITE_OFF | reduced | kept | unchanged; WRITTEN_OFF bucket +qty (value 0) |
| No | Yes | SELLABLE | unchanged | reversed for accepted qty | +qty |
* A return counts only when status is RECEIVED / INSPECTION_PENDING / CLOSED **and** ReceivedDate is filled.
* An inspection counts only when COMPLETE **and** ApprovedBy and InspectionDate are filled.
* Over-returns (more than shipped) and over-inspections (more than returned) are refused and flagged.
* Duplicate ReturnID / InspectionID are ignored after the first and flagged -> no double reversal.
* Write-offs of on-hand stock (not returns) go through INVENTORY_ADJUSTMENTS and post Dr 5100 / Cr 1300.

### 4.4 Costing (02)
* `COST_MASTER` is append-only: CostRecordID, SKU, components, UnitCost, EffectiveFrom/To, Source, ApprovedBy, CreatedAt.
* A row is used only when complete **and approved**. The cost valid on the **original sale date** is used (latest EffectiveFrom <= date).
* Approved rows are fingerprinted in `02_OPERATIONS\state\cost_master_state.json`; an edited or deleted approved row raises
  COST_RECORD_MODIFIED / COST_RECORD_DELETED_OR_UNAPPROVED (ERROR) - historical COGS cannot change silently.
* Missing SKU or cost: line stays visible, COGS blank (never 0), COST_EXCEPTIONS row, month INCOMPLETE, coverage % shown.

### 4.5 Journal (03) - double entry, REAL orders only
| Event | Debit | Credit |
|---|---|---|
| Sale (line) | 1200 AR (net+tax), 4100 Discounts | 4000 Gross Sales, 2200 Tax |
| Shipping charged | 1200 | 4010 |
| Payment marked received in Shopify | 1210 COD/Payment clearing | 1200 |
| Refund - allocated line | 4200 Refunds, 2200 | 1210 |
| Refund - unallocated | 4210 Refunds - Unallocated | 1210 |
| Cancellation (no money) | 4300, 2200 | 1200 |
| COGS | 5000 | 1300 Inventory FG |
| COGS reversal (approved SELLABLE return) | 1300 | 5000 |
| Production / purchase receipt into stock | 1300 | 1310 Materials/WIP/advances |
| Expense paid by COMPANY | 6xxx (EXPENSE_CATEGORY_MAP) | cash account (1000-1030) |
| Expense paid PARTNER_PERSONAL | 6xxx | **3010 Partner capital - paid personally** (no company cash) |
| Production / inventory payment | **1310** (asset - never COGS when paid) | cash or 3010 |
| Partner cash deposit (CAPITAL_DEPOSIT) | cash account | **3000 Partner capital - cash deposits** |
| Partner withdrawal | 3200 | cash |
| COD remittance / COD fee | cash / 6800 | 1210 |
| Opening balances (OPENING_BALANCES) | as entered (must balance) | as entered |
* DATA_ENTRY rows without PaymentSource (COMPANY / PARTNER_PERSONAL), without a cash account where needed, or with an
  unmapped category are **not posted** and flagged; their month is INCOMPLETE.
* Possible double counting (same partner, same amount, deposit + paid-personally within 3 days) -> warning.

### 4.6 Statements and controls (03)
* P&L (monthly; quarterly/annual pivots hide the RATIO rows), preliminary management Balance Sheet, direct Cash Flow,
  order profitability (contribution before fulfilment costs - those inputs do not exist yet), product P&L with
  `UNALLOCATED_REFUNDS` and `SHIPPING_INCOME` rows so it reconciles to the P&L.
* Status per month: `INCOMPLETE` when a blocking exception affects it; otherwise `PRELIMINARY`. Nothing is labelled final.
  Balance Sheet / Cash Flow are `INCOMPLETE` until opening balances are entered.
* Engine controls: P&L revenue = revenue ledger; product P&L = P&L; P&L COGS = 02 COGS events; journal balanced;
  BS balances; cash flow = BS cash; no TEST order in the journal; opening inventory (02) = 1300 opening (03); COD clearing ageing.
* Excel CONTROLS sheet re-checks the same equalities with SUMIFS/COUNTIFS formulas.
* Month close: mark a month CLOSED in MONTH_CLOSE -> a snapshot is saved; any later change to that month raises CLOSED_PERIOD_CHANGED.

## 5. Refresh sequence (Invoke-PassressRefresh.ps1)
1. Preflight: all four workbooks exist and are closed. 2. Backup workbooks + outputs + state to `05_BACKUPS\<time>_pre-refresh_<RunId>`.
3. Extract Shopify (LIVE) or copy a saved extract (OFFLINE). 4. Start a dedicated Excel instance; start a watchdog that can stop
**only that process** after the timeout. 5. For 01 -> 02 -> 03 -> 04: open, snapshot inputs, engine stage, refresh each
connection synchronously (background refresh off), validate row counts + LOG_REFRESH run id, save, close.
6. First failure: the workbook is closed **without saving**, the stage is marked FAILED, downstream stages are SKIPPED.
7. Close Excel, write `08_LOGS\refresh_<RunId>.log/.json`, exit code 0/1.

## 6. Limits of this design (honest list)
* Excel must be installed on the PC that runs the controller (Windows only); the operator does not need programming.
* Inputs typed while a refresh runs are not seen (workbooks must be closed during refresh - enforced).
* Accounts Payable is not modelled from supplier bills yet; receipts in excess of payments show as a negative 1310 balance.
* Shipping cost, COD fees and packaging per order are not available from any source; order contribution excludes them (labelled).
