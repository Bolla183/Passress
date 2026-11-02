# PASSRESS - Setup, Daily Use, Refresh & Troubleshooting

## One-time setup (Windows PC with Excel 2019 or later)
1. Copy the `passress-system` folder (code) anywhere, e.g. `C:\PASSRESS_CODE`. It contains no business data.
2. Create the business folder and config:
   `mkdir C:\PASSRESS_BUSINESS_SYSTEM\07_CONFIGURATION` then copy `config\passress.config.template.json` to
   `C:\PASSRESS_BUSINESS_SYSTEM\07_CONFIGURATION\passress.config.json` and check `RootFolder`.
3. Allow local scripts for your user (once): `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
   (if Windows blocks the downloaded files: `Get-ChildItem C:\PASSRESS_CODE -Recurse | Unblock-File`).
4. Readiness: `.\scripts\Test-PassressReadiness.ps1 -ConfigPath <config> -OriginalWorkbookPath "<path>\Passress(3).xlsx"`
5. Offline tests: `.\scripts\Invoke-PassressOfflineTests.ps1 -WithExcel` - all results must be PASS.
6. Build: `.\scripts\Build-PassressSystem.ps1 -ConfigPath <config> -OriginalWorkbookPath "<path>\Passress(3).xlsx"`
   - the original is copied to `05_BACKUPS\00_ORIGINAL` (read-only) and verified unchanged.
7. **Security - before any live refresh:** in the Shopify Dev Dashboard (app PASSRESS_DATA) rotate/revoke the old client
   secret (it was exposed in the original workbook). Then run `.\scripts\Set-PassressShopifyCredential.ps1` and paste the
   client id and the NEW secret. The app only needs read scopes: `read_orders`, `read_all_orders` (history older than 60
   days), `read_customers`, `read_products`, `read_inventory`.
8. First live refresh: `.\scripts\Invoke-PassressRefresh.ps1 -ConfigPath <config> -Mode LIVE`

## Daily / weekly use
1. Enter what Shopify cannot know - in the INPUT sheets only:
   * 02: costs (new row per cost change), production receipts, purchases, physical returns + inspections, stock adjustments, opening stock.
   * 03: expenses, production payments, partner deposits / partner-paid costs (choose PaymentSource!), COD remittances and fees, opening balances.
   * 04: marketing spend, budget/forecast.
2. Save and **close all four workbooks**.
3. Run `Invoke-PassressRefresh.ps1 -Mode LIVE` (Excel stays closed; the script runs its own hidden Excel).
4. Open the workbooks: HOME shows run id, status, errors and freshness; CONTROLS must be OK; review exception sheets.

## Which workbook must be open? Does Excel need to run?
* During refresh **none** of the workbooks may be open (the controller refuses locked files). Excel must be **installed**;
  the controller starts and stops its own hidden instance and never touches other Excel windows.
* Opening a workbook and pressing *Refresh All* by hand only reloads the last engine output - it never recalculates
  business logic or pulls Shopify. Always use the controller.

## Moving to another folder or PC
Copy `PASSRESS_BUSINESS_SYSTEM`, then: `.\scripts\Set-PassressRootFolder.ps1 -ConfigPath <new config> -NewRootFolder <new root>`.
On a new PC also re-run `Set-PassressShopifyCredential.ps1` (the encrypted credential only works for the user/PC that created it).

## Troubleshooting
| Symptom | Meaning | Action |
|---|---|---|
| `PREFLIGHT: ... is open` | A workbook is open | Close it (check Task Manager for hidden Excel), re-run |
| `LIVE_BLOCKED` | No credential | Rotate secret, `Set-PassressShopifyCredential.ps1` |
| `SHOPIFY_AUTH_FAILED` | Wrong/revoked secret or missing scope | Re-enter credential; check app scopes |
| `SHOPIFY_RETRIES_EXHAUSTED` / HTTP 5xx | Shopify/network down | Re-run later; nothing downstream was changed |
| `STALE_UPSTREAM` | Upstream stage not OK in this run | Fix the first failed stage (see log), re-run the full refresh |
| `INPUT_TABLE_COLUMNS_CHANGED` | An input column was renamed/deleted | Restore the column name (see DATA_DICTIONARY.md) |
| `POWER_QUERY_REFRESH_FAILED` | A query could not load its CSV | Check `pRootFolder` (Set-PassressRootFolder), file permissions; Data > Queries for details |
| Power Query asks about *privacy levels* / Formula.Firewall | Excel wants a privacy level for the local CSV folder | Data > Get Data > Query Options > Current Workbook > Privacy: choose *Ignore the Privacy Levels* (all sources are local files you own), save, re-run the refresh |
| `VALIDATION_FAILED` | Excel shows a different row count than the engine wrote | Re-run; if it persists restore the backup and report the log |
| HOME shows `STALE` | Upstream was refreshed later than this workbook | Run the full controlled refresh |
| Statements show `INCOMPLETE` | Missing inputs (cost, opening balance, PaymentSource...) | See the exception sheets - each row has a recommended action |
| Timeout | Excel hung | The controller stopped its own Excel; restore with `Restore-PassressBackup.ps1` if needed |

## Recovery after an interrupted refresh
Workbooks are saved only after successful validation, so an interrupted stage keeps its previous file. If any doubt:
`.\scripts\Restore-PassressBackup.ps1 -ConfigPath <config> -BackupFolder "<root>\05_BACKUPS\<time>_pre-refresh_<RunId>"`
(the current files are backed up first), then run the refresh again. Logs: `08_LOGS\refresh_<RunId>.log` and `.json`.
