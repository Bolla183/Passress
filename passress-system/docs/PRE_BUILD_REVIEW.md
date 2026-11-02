# PASSRESS — Phase 2 Pre-Build Review

**Date:** 2026-11-02 · **Scope:** targeted corrections only; the architecture is unchanged.

Not done in this review: no live Shopify call, the old secret was not used, and no workbook was built or overwritten. One read-only lookup of Shopify's published API schema confirmed the fulfillment and delivery fields; it reads no store data.

---

## 1. Files changed

| File | Change |
|---|---|
| `src/engine/Operations.ps1` | **COGS recognition rewritten**. A configurable trigger, a per-line simulation (dispatch → IN_TRANSIT → recognise), evidence de-duplication with a quantity cap, a `DELIVERY_CONFIRMATIONS` input, return allocation (in-transit units first), `TRANSIT_LOSS`, pending flags, in-transit stock columns, and the sales-vs-stock control now based on recognised quantity. |
| `src/engine/DataSource.ps1` | New `FULFILLMENT_EVENTS` output (dispatch date; delivery date only when Shopify has it). Duplicate fulfillments are de-duplicated and flagged. "DELIVERED" with no date is flagged, not assumed. |
| `src/engine/Finance.ps1` | `TRANSIT_LOSS` posts to 5100. Legacy and pending-review gate. Capital double-count block (shared reference). Duplicate-capital and missing-evidence warnings. Capital sub-ledger columns. New `PARTNER_CAPITAL_RECONCILIATION`. Per-line partner on opening balances. P&L memo line for pending COGS. COGS control excludes transit losses. New stock-ledger-vs-GL-1300 control. |
| `src/Passress.Shopify.psm1` | Extract now includes `fulfillments { status, createdAt, deliveredAt, fulfillmentLineItems }`, with a refetch when the first page is full. Fields verified against the Admin API schema 2026-07. |
| `src/Passress.Engine.psm1` | Operations stage now also reads `FULFILLMENT_EVENTS` and `ORDER_TRANSACTIONS` from 01. |
| `schemas/tables.json` | Version 2.1.0, 64 tables. New: `FULFILLMENT_EVENTS`, `DELIVERY_CONFIRMATIONS`, `PARTNER_CAPITAL_RECONCILIATION`. Recognition columns added to `SALES_COSTED`; in-transit columns to `INVENTORY`; `ReviewStatus` and `ReviewedBy` to `DATA_ENTRY`; `CAPITAL_CONTRIBUTIONS` extended. |
| `scripts/Build-PassressSystem.ps1` | Dropdowns for `ReviewStatus` and delivery `Source`. **Legacy rows seeded `PENDING_REVIEW`.** New CONTROLS rows: pending COGS, partner reconciliation, rows awaiting review. |
| `config/passress.config.template.json` | `"CogsRecognitionTrigger": "DELIVERY"` |
| `tests/TestHelpers.ps1` | Orders carry fulfillments (options: delivered, not delivered, not fulfilled, duplicated). Per-scenario config override. New upstream tables passed to Operations. |
| `tests/scenarios/Scenarios.ps1` | 17 new scenarios / 102 new assertions (now 37 scenarios / 261 assertions). S15 marked not-fulfilled. |
| `docs/ARCHITECTURE.md`, `docs/REFRESH_AND_TROUBLESHOOTING.md`, `docs/DATA_DICTIONARY.md` (regenerated), `docs/PHASE2_REPORT.md` (superseded note), `docs/PRE_BUILD_REVIEW.md` (this report) | Documentation |

## 2. Business rules after correction

### 2.1 COGS recognition

1. **Six separate events are tracked:** order created, payment captured, fulfillment (dispatch), delivery confirmed, physical return, and inspection approval.
2. **One configurable trigger** recognises COGS. Set `CogsRecognitionTrigger` to `DELIVERY` (the default and the proposed Passress rule), `FULFILLMENT`, `PAYMENT_CAPTURED` or `ORDER_CREATED`. An invalid value stops the refresh.
3. **Delivery evidence** is either Shopify's `deliveredAt` on a successful fulfillment, or a `DELIVERY_CONFIRMATIONS` row (with confirmation ID, delivered date and the name of whoever confirmed it). Being fulfilled, paid, or showing a "DELIVERED" status without a date never counts as delivery.
4. **No evidence means no COGS.**
   - A dispatched unit moves from SELLABLE to **IN_TRANSIT**. It is still company stock and still sits in GL 1300.
   - The line shows `PENDING` or `PARTIAL` and raises a `COGS_PENDING_RECOGNITION` warning.
   - The P&L shows a memo line, "COGS pending recognition (memo, not posted)".
5. **COGS is never recognised twice.**
   - Evidence is de-duplicated by ID.
   - Recognised quantity per line is capped at the shipped quantity.
   - Extra evidence (for example Shopify "delivered" plus a courier statement) is ignored and flagged as INFO.
   - The earliest valid evidence date is used.
6. **Cost basis.** COGS uses the approved unit cost valid on the **original sale date**, and reversals use that same cost.
7. **Returns.**
   - A return counts only when it has been physically RECEIVED with a date.
   - An inspection counts only when it is COMPLETE, approved and dated.
   - Units still IN_TRANSIT (refused or undelivered COD) are taken back first:
     - if SELLABLE, they go back to stock with no COGS effect;
     - if DAMAGED or WRITE_OFF, they become a stock loss (`TRANSIT_LOSS`, Dr 5100 / Cr 1300), never COGS.
   - Only units whose COGS was recognised can reverse COGS, and only for the SELLABLE quantity, at the original unit cost.
8. **Refund without a physical return:** COGS is not reversed and stock does not change.
9. **DAMAGED or WRITE_OFF returns** never increase sellable stock. They go to separate DAMAGED or WRITTEN_OFF buckets at zero value, because their COGS is kept.
10. **Controls.**
    - Inventory SALE movements must equal recognised quantity.
    - Stock-ledger value (SELLABLE + IN_TRANSIT) must equal GL 1300 whenever all values and the opening balance are known.
    - P&L COGS must equal Operations COGS (excluding transit losses).

### 2.2 Partner capital

| Transaction | Debit | Credit | Effect on company cash |
|---|---|---|---|
| Cash deposit (`CAPITAL_DEPOSIT`) | Company cash account | 3000 Partner Capital – deposits | Increases once |
| Company cost paid personally (`PARTNER_PERSONAL`) | Expense, 1310 or 1500 | 3010 Partner Capital – paid personally | None |

- **Double counting is blocked.** A `PARTNER_PERSONAL` row whose `CapitalContributionRef` is also used by a cash deposit is **not posted**: it raises `CAPITAL_DOUBLE_COUNT` (ERROR) and marks the month INCOMPLETE.
- **Possible duplicates are flagged.** The same partner and amount within 3 days with no shared reference raises a warning. Identical partner, date, amount and funding type raises `POSSIBLE_DUPLICATE_CAPITAL_ENTRY`.
- **Evidence.** A partner-funded row without a supporting document still posts, but raises `MISSING_SUPPORTING_EVIDENCE`.
- **`CAPITAL_CONTRIBUTIONS`** records, for every row: partner, date, funding type, payment source, signed amount, **cash impact**, related account (code and name), category, reference and evidence.
- **`PARTNER_CAPITAL_RECONCILIATION`** shows per partner: opening capital, deposits, paid personally, withdrawals, sub-ledger balance, GL 3000/3010/3200, GL balance, difference and net cash contributed. A difference raises `PARTNER_CAPITAL_MISMATCH` (ERROR). Capital lines with no partner name raise `CAPITAL_WITHOUT_PARTNER`.

### 2.3 Legacy transactions

- All 37 migrated rows are seeded with `ReviewStatus = PENDING_REVIEW`.
- A row with a `LegacyType` posts only when `ReviewStatus = APPROVED`; otherwise it raises `LEGACY_ROW_PENDING_REVIEW`. Any row marked `PENDING_REVIEW` never posts.
- An approved row with no `PaymentSource` still does not post (`MISSING_PARTNER_FUNDING_CLASSIFICATION`).
- The migrated `TransactionType` is a provisional suggestion and stays editable.
- Legacy "COGS" rows are suggested as `PRODUCTION_PAYMENT`, which posts to 1310 (inventory, materials and WIP), **never to COGS**. Their month shows INCOMPLETE until the rows are reviewed.

### 2.4 Refund reconciliation (re-confirmed; logic unchanged)

- Money refunded is the sum of **successful** REFUND transactions only. Pending, failed, error and void transactions are logged and flagged but never recognised.
- A refund is recognised in the month of its successful transaction.
- Any amount not linked to refund line items stays **UNALLOCATED** (account 4210 plus an exception). It is never assigned to a product by matching amounts.
- **#1008 (EGP 2,250) and #1009 (EGP 3,150) remain unallocated** (assertions S01-06, -07, -08, -10, -11, -12). Both are TEST orders, so they stay out of all reports.

## 3. New test cases and expected results

Each scenario starts with 5 units of SKU-A at EGP 1,000 each and a selling price of EGP 2,500, under the DELIVERY trigger unless stated.

| Scenario | Situation | Expected result |
|---|---|---|
| D01 | Fulfilled, not delivered | Status PENDING, pending qty 1, COGS 0, no COGS event; sellable 4, in transit 1 (value 1,000); P&L COGS 0; memo −1,000; one `COGS_PENDING_RECOGNITION`; GL finished goods 5,000; ledger = GL |
| D02 | Delivered (Shopify `deliveredAt` = 10-07) | Recognised 1, status RECOGNIZED, COGS dated 2026-10-07, P&L COGS −1,000, in transit 0, sellable 4, memo 0 |
| D03 | Duplicate fulfillment and delivery evidence (same fulfillment twice + courier confirmation) | Exactly 1 COGS event of 1,000, dated 2026-10-07; `DUPLICATE_FULFILLMENT_EVENT` = 1; `RECOGNITION_EVIDENCE_EXCEEDS_QUANTITY` = 1; sellable 4 |
| D04 | 2 delivered, 1 refunded, 1 returned SELLABLE | Recognised 2; reversal −1,000; net COGS 1,000; P&L COGS −1,000; sellable 4 |
| D05 | Delivered, refunded, not returned | COGS −1,000 kept; no reversal; sellable 4; net revenue 0; reconciliation REFUND_ONLY |
| D06 | Delivered, returned, pending inspection | No reversal; sellable 4; `RETURN_PENDING_INSPECTION` = 1; COGS −1,000 |
| D07 | Delivered, returned, approved SELLABLE | Reversal −1,000; P&L COGS 0; sellable 5; ledger = GL |
| D08 | Delivered, returned DAMAGED | COGS −1,000 kept; no reversal; sellable 4; damaged 1; no transit loss |
| D09 | COD refused: dispatched, never delivered, cancelled, returned sellable | No COGS, reversal or loss events at all; status RETURNED_UNDELIVERED; nothing pending; sellable 5; in transit 0; net revenue 0; COGS 0 |
| D10 | Never delivered, returned damaged | Transit loss 1,000 posted to write-offs (−1,000); COGS 0; sellable 4; damaged 1; ledger = GL |
| D11 | Trigger = FULFILLMENT | COGS dated at fulfillment (2026-10-06); trigger recorded on the line; in transit 0 |
| D12 | Trigger = PAYMENT_CAPTURED, no fulfillment data | COGS dated at payment (2026-10-05); sellable 4 |
| C01 | Partner cash deposit of 10,000 | Cash 10,000; exactly one cash posting; 3000 = 10,000; Partner A reconciles OK; net cash contributed 10,000; cash impact 10,000; no evidence warning |
| C02 | Partner-paid expense of 1,500 | Cash 0; no cash posting; 3010 = 1,500; Marketing −1,500; cash impact 0; related account 6400; Partner B OK; cash-flow opex 0 |
| C03 | Duplicate capital contribution | `CAPITAL_DOUBLE_COUNT` on TXN-2, which is not posted; `POSSIBLE_DUPLICATE_CAPITAL_ENTRY` = 1; 3010 = 0; cash 4,000; Partner A OK; month INCOMPLETE |
| L01 | Unposted legacy transactions | `LEGACY_ROW_PENDING_REVIEW` = 2; LEG-0001/2/3 not posted (LEG-0003 approved but no PaymentSource); LEG-0004 posted (2 lines); P&L COGS 0; materials/WIP 3,000; month INCOMPLETE |
| R01 | Pending and failed refund transactions | Refunds 0; net revenue 2,500; `REFUND_TRANSACTION_NOT_SUCCESSFUL` = 2; no successful refund transaction; refunded qty 0 |

The earlier scenarios S02–S18 keep their expected values. Their orders now carry a fulfillment delivered on the order date, so COGS still lands where previously expected. S15 is explicitly not fulfilled.

## 4. Static checks executed

| Check | Result |
|---|---|
| `python3 tools/static_checks.py`: 64 schema tables; all engine row keys, formula references and **261** test assertions checked against the schema; bracket balance in 18 PowerShell files; no credential-shaped strings | **PASS** |
| Checker tested against deliberate errors (misspelled `RecognizedQty` in the engine, wrong column in assertion D01-06) | **PASS** (both caught) |
| PowerShell parsing-trap scans: functions mixed with operators without parentheses, assignments to automatic variables | **PASS** (none found) |
| Shopify Admin schema (2026-07): `Order.fulfillments`, `Fulfillment.status/createdAt/deliveredAt/displayStatus/fulfillmentLineItems`, `FulfillmentLineItem.quantity/lineItem`, `FulfillmentStatus` values | **PASS** |

## 5. Tests not executed

PowerShell cannot run in this environment (installing it was blocked by the session's permission policy), and there is no Windows or Excel here. Therefore:

- **All 37 engine scenarios (261 assertions): NOT RUN.** This includes the 17 new scenarios above and the re-run determinism check.
- **File-level protections IO-01 to IO-06, security tests SEC-01 to SEC-06, culture test CSV-01: NOT RUN.**
- **Excel end-to-end tests XL-01 to XL-04 (build, OFFLINE refresh, failure stops the chain, no orphan Excel): NOT RUN.**

**No test is claimed as passed.** Run `scripts\Invoke-PassressOfflineTests.ps1 -WithExcel` on your PC before `Build-PassressSystem.ps1`.

## 6. Unresolved accounting policy decisions

1. **Revenue timing vs COGS timing.** Revenue is still recognised at the order date, while COGS now waits for delivery. For orders in transit at month end, gross margin is overstated by the memo amount. Matching would suggest recognising revenue at the same trigger. **Decision needed:** align revenue to delivery, or keep the order date and rely on the memo line.
2. **Where delivery evidence comes from.** Shopify `deliveredAt` exists only if your courier or its app reports delivery to Shopify. Otherwise, who will enter `DELIVERY_CONFIRMATIONS` from courier statements, and how often?
3. **Undelivered units returned damaged.** These are currently written off immediately (5100). The alternative is to hold them at cost pending a courier claim.
4. **Which returned units count first.** On a line with both in-transit and delivered units, returned units are treated as in-transit first, which is conservative (no COGS reversal). Please confirm.
5. **Damaged delivered returns** are kept at zero value. Is there any salvage, repair or sample-sale policy?
6. **Missing supporting evidence** on partner-funded rows currently posts with a warning. Should it block posting instead?
7. **Legacy "Capital" vs "Paid-Up Capital"** rows are both suggested as `CAPITAL_DEPOSIT` until reviewed. Please confirm what each represented, and whether the partners' personal payments are already included in those amounts.
8. **Still open from Phase 1 and Phase 2:**
   - unit costs, opening stock and opening balances;
   - courier COD remittances and fees;
   - treatment of samples and packaging;
   - the meaning of the EGP 29,400 in the old P&L cell O6.

## 7. Original workbook

**Unchanged.** The uploaded `Passress(3).xlsx` has the same SHA-256 `9944f49026c9e54076ade78fbf3412ce6b0152c95b3b9d810322f4713da43000`, size 782,011 bytes, and the same timestamp as at the start of Phase 1. The read-only working copy has the identical hash. No workbook was built, opened for writing or overwritten in this review.
