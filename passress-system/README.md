# PASSRESS Business System - code (Phase 2 foundation)

Code only - **no business data, no credentials**. The business folder `PASSRESS_BUSINESS_SYSTEM` is created on the
Windows PC by `scripts\Build-PassressSystem.ps1` and must never be committed.

| Path | Purpose |
|---|---|
| `schemas/tables.json` | Single source of truth for all 61 tables (columns, types, meaning) |
| `src/Passress.Common.psm1` | Config, logging (secret redaction), culture-independent CSV, exceptions, time zone, backups |
| `src/Passress.Engine.psm1` + `src/engine/*.ps1` | Business rules for stages 01-04 (pure, offline-testable) |
| `src/Passress.Shopify.psm1` | Read-only Shopify GraphQL extract, DPAPI credential, retries, pagination |
| `src/Passress.Excel.psm1` | Excel COM: own instance, tables, Power Query, synchronous refresh, validation |
| `scripts/` | Readiness, credential, build, refresh controller, restore, root-folder move, offline tests |
| `tests/` | Saved Shopify sample (#1001-#1009), 18 scenarios, harness |
| `tools/` | Static consistency checks, data-dictionary generator (Python) |
| `docs/` | Architecture & accounting rules, data dictionary, setup/refresh/troubleshooting |

Start with `docs/REFRESH_AND_TROUBLESHOOTING.md`.
