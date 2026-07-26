"""
PASSRESS MIS - Phase 1: Workbook Foundation
Builds the complete workbook skeleton (structure, tables, named ranges,
documentation, color coding, protection) with NO calculations and NO
live data connections. Those are Phase 2+.

Run: python3 build_workbook.py
Output: ../PASSRESS_MIS.xlsx
"""

import openpyxl
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.worksheet.table import Table, TableStyleInfo
from openpyxl.utils import get_column_letter
from openpyxl.workbook.protection import WorkbookProtection
from openpyxl.worksheet.properties import WorksheetProperties, PageSetupProperties, Outline
from openpyxl.worksheet.protection import SheetProtection
from openpyxl.styles.protection import Protection
from openpyxl.worksheet.dimensions import RowDimension
from openpyxl.formatting.rule import FormulaRule

FONT_NAME = "Segoe UI"
PROTECT_PASSWORD = "Passress2026"

# ---------------------------------------------------------------- palette --
C = {
    "black": "000000",
    "white": "FFFFFF",
    "light_gray": "F2F2F2",
    "med_gray": "D9D9D9",
    "border_gray": "BFBFBF",
    "dark_gray": "404040",
    "text_gray": "595959",
    # input-standard categories
    "input_header": "375623",   # dark green
    "input_body": "008000",
    "input_fill": "EAF3EA",
    "shopify_header": "1F4E78", # dark blue
    "shopify_body": "0070C0",
    "shopify_fill": "EAF1F8",
    "calc_header": "595959",    # dark gray
    "calc_body": "7F7F7F",
    "calc_fill": "F2F2F2",
    "settings_header": "C55A11",# dark orange
    "settings_body": "C55A11",
    "settings_fill": "FCEEE3",
    "kpi_fill": "404040",
}

THIN = Side(style="thin", color=C["border_gray"])
BORDER_ALL = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)

CATEGORY_STYLE = {
    "input":   dict(header_fill=C["input_header"],   body_font=C["input_body"],   body_fill=C["input_fill"]),
    "shopify": dict(header_fill=C["shopify_header"],  body_font=C["shopify_body"], body_fill=C["shopify_fill"]),
    "calc":    dict(header_fill=C["calc_header"],     body_font=C["calc_body"],    body_fill=C["calc_fill"]),
    "settings":dict(header_fill=C["settings_header"], body_font=C["settings_body"],body_fill=C["settings_fill"]),
}

TAB_COLOR = {
    "nav": "000000",
    "dashboard": "1F4E78",
    "report": "404040",
    "input": "375623",
    "raw": "0070C0",
    "dim": "7F7F7F",
    "fact": "595959",
    "log": "C55A11",
}

wb = Workbook()
wb.remove(wb.active)

# ------------------------------------------------------------- utilities --

def f(size=10, bold=False, italic=False, color=C["black"], name=FONT_NAME):
    return Font(name=name, size=size, bold=bold, italic=italic, color=color)


def fill(hex_color):
    return PatternFill("solid", fgColor=hex_color)


def set_col_widths(ws, widths):
    for i, w in enumerate(widths, start=1):
        ws.column_dimensions[get_column_letter(i)].width = w


def title_bar(ws, text, last_col=10):
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=last_col)
    c = ws.cell(row=1, column=1, value=text)
    c.font = f(size=18, bold=True, color=C["white"])
    c.fill = fill(C["black"])
    c.alignment = Alignment(vertical="center", horizontal="left", indent=1)
    ws.row_dimensions[1].height = 34

    ws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=last_col)
    b = ws.cell(row=2, column=1, value="PASSRESS MIS   |   Home ▸ " + text)
    b.font = f(size=9, italic=True, color=C["text_gray"])
    b.fill = fill(C["light_gray"])
    b.alignment = Alignment(vertical="center", horizontal="left", indent=1)
    ws.row_dimensions[2].height = 16


def doc_block(ws, purpose, inputs, outputs, relationships, future_source, last_col=10):
    """Rows 3-9: collapsible documentation strip. Row 3 = summary label (visible),
    rows 4-9 = detail rows (collapsed via outline group)."""
    ws.merge_cells(start_row=3, start_column=1, end_row=3, end_column=last_col)
    s = ws.cell(row=3, column=1, value="Sheet Documentation  (use the  +  outline control at left to expand)")
    s.font = f(size=8, italic=True, bold=True, color=C["text_gray"])
    s.fill = fill(C["white"])
    ws.row_dimensions[3].height = 14

    fields = [
        ("Purpose", purpose),
        ("Input tables", inputs),
        ("Output tables", outputs),
        ("Relationships", relationships),
        ("Future data source", future_source),
    ]
    r = 4
    for label, value in fields:
        lc = ws.cell(row=r, column=1, value=label)
        lc.font = f(size=8, bold=True, color=C["text_gray"])
        lc.alignment = Alignment(vertical="top")
        ws.merge_cells(start_row=r, start_column=2, end_row=r, end_column=last_col)
        vc = ws.cell(row=r, column=2, value=value)
        vc.font = f(size=8, italic=True, color=C["text_gray"])
        vc.alignment = Alignment(vertical="top", wrap_text=True)
        ws.row_dimensions[r].height = 13
        ws.row_dimensions[r].outline_level = 1
        ws.row_dimensions[r].hidden = True
        r += 1
    # one spare hidden row to close the group cleanly
    ws.row_dimensions[9].outline_level = 1
    ws.row_dimensions[9].hidden = True

    ws.sheet_properties.outlinePr.summaryBelow = False
    ws.sheet_properties.outlinePr.applyStyles = True

    ws.row_dimensions[10].height = 6  # spacer
    return 11  # first free content row


def add_kpi_row(ws, row, labels, col_start=1, card_width=2, height_rows=3, gap=0):
    """Dark-gray KPI cards. Value cells are left as em-dash placeholders (Phase 3 wires DAX)."""
    col = col_start
    top = row
    bottom = row + height_rows - 1
    for label in labels:
        left, right = col, col + card_width - 1
        ws.merge_cells(start_row=top, start_column=left, end_row=top, end_column=right)
        lab = ws.cell(row=top, column=left, value=label.upper())
        lab.font = f(size=8, bold=True, color=C["med_gray"])
        lab.fill = fill(C["kpi_fill"])
        lab.alignment = Alignment(vertical="bottom", horizontal="left", indent=1)

        ws.merge_cells(start_row=top + 1, start_column=left, end_row=bottom, end_column=right)
        val = ws.cell(row=top + 1, column=left, value="—")
        val.font = f(size=20, bold=True, color=C["white"])
        val.fill = fill(C["kpi_fill"])
        val.alignment = Alignment(vertical="center", horizontal="left", indent=1)
        val.protection = Protection(locked=True)

        for rr in range(top, bottom + 1):
            for cc in range(left, right + 1):
                cell = ws.cell(row=rr, column=cc)
                cell.fill = fill(C["kpi_fill"])
        col += card_width + gap
    for rr in range(top, bottom + 1):
        ws.row_dimensions[rr].height = 15 if rr == top else 22
    return bottom + 2, col  # next free row, next free col


def add_placeholder_box(ws, row, col, width, height, label, phase="Phase 3"):
    r2, c2 = row + height - 1, col + width - 1
    ws.merge_cells(start_row=row, start_column=col, end_row=r2, end_column=c2)
    cell = ws.cell(row=row, column=col, value=f"[ {label}  —  Placeholder, built in {phase} ]")
    cell.font = f(size=9, italic=True, color=C["text_gray"])
    cell.fill = fill(C["light_gray"])
    cell.alignment = Alignment(vertical="center", horizontal="center", wrap_text=True)
    dashed = Side(style="dashed", color=C["border_gray"])
    box_border = Border(left=dashed, right=dashed, top=dashed, bottom=dashed)
    for rr in range(row, r2 + 1):
        for cc in range(col, c2 + 1):
            ws.cell(row=rr, column=cc).border = box_border
            if ws.cell(row=rr, column=cc).fill.fgColor.rgb in (None, "00000000"):
                ws.cell(row=rr, column=cc).fill = fill(C["light_gray"])
    return r2 + 2  # next free row


def add_table(ws, table_name, top_row, top_col, headers, category, example_row=None, n_placeholder_rows=1, data_rows=None):
    """Creates a real Excel Table with color-coded header + body per input-standard category.
    data_rows: list of row-value-lists for permanent (non-"EXAMPLE") data, e.g. an append-only log."""
    style = CATEGORY_STYLE[category]
    ncols = len(headers)
    # header
    for i, h in enumerate(headers):
        cell = ws.cell(row=top_row, column=top_col + i, value=h)
        cell.font = f(size=9, bold=True, color=C["white"])
        cell.fill = fill(style["header_fill"])
        cell.border = BORDER_ALL
        cell.alignment = Alignment(vertical="center", horizontal="left", wrap_text=True)
        cell.protection = Protection(locked=True)
    ws.row_dimensions[top_row].height = 18

    if data_rows:
        n_rows = len(data_rows)
    else:
        n_rows = 1 if example_row else n_placeholder_rows
    for rr in range(1, n_rows + 1):
        row_idx = top_row + rr
        if data_rows:
            values = data_rows[rr - 1]
        else:
            values = example_row if (example_row and rr == 1) else ["" for _ in headers]
        for i, val in enumerate(values):
            cell = ws.cell(row=row_idx, column=top_col + i, value=val if val != "" else None)
            unlocked = category == "input"
            cell.font = f(size=9, color=style["body_font"], italic=(example_row is not None and rr == 1 and not data_rows))
            cell.fill = fill(style["body_fill"])
            cell.border = BORDER_ALL
            cell.protection = Protection(locked=not unlocked)

    end_row = top_row + n_rows
    end_col = top_col + ncols - 1
    ref = f"{get_column_letter(top_col)}{top_row}:{get_column_letter(end_col)}{end_row}"
    tbl = Table(displayName=table_name, ref=ref)
    tbl.tableStyleInfo = TableStyleInfo(
        name="TableStyleLight1", showFirstColumn=False, showLastColumn=False,
        showRowStripes=False, showColumnStripes=False,
    )
    ws.add_table(tbl)
    return end_row + 2  # next free row


def protect_ws(ws, hide_technical=False):
    ws.protection = SheetProtection(
        password=PROTECT_PASSWORD, sheet=True,
        formatCells=False, formatColumns=False, formatRows=False,
        insertRows=False, insertColumns=False, deleteRows=False, deleteColumns=False,
        sort=True, autoFilter=True, pivotTables=False, selectLockedCells=False,
        selectUnlockedCells=False,
    )


def freeze_below_header(ws, row=11):
    ws.freeze_panes = ws.cell(row=row, column=1)


# ============================================================================
# 01_Home
# ============================================================================
ws = wb.create_sheet("01_Home")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3] + [14] * 11)
title_bar(ws, "PASSRESS MIS — Home", last_col=12)
row = doc_block(
    ws,
    "Landing page and navigation hub for the entire workbook.",
    "None — display only.",
    "None.",
    "Links to all 14 other visible sheets. Reads workbook status from LOG_RefreshHistory and LOG_DataQuality.",
    "LOG_RefreshHistory (last refresh timestamp), LOG_DataQuality (overall status) — wired in Phase 2/4.",
    last_col=12,
)

home_kpi_top = row
row, _ = add_kpi_row(ws, row, ["Last Refresh", "Data Quality", "Workbook Version", "Phase Completed"], col_start=2, card_width=2)

# "Workbook Version" / "Phase Completed" are live-linked to 15_Settings' Version
# Log: every future phase appends a row there (see VERSION_LOG_ROWS) and these
# two cards automatically show the latest one — no manual editing of Home needed.
version_cell = ws.cell(row=home_kpi_top + 1, column=6, value="=INDEX(tbl_VersionLog[Version],COUNTA(tbl_VersionLog[Version]))")
version_cell.font = f(size=20, bold=True, color=C["white"])
version_cell.fill = fill(C["kpi_fill"])
version_cell.alignment = Alignment(vertical="center", horizontal="left", indent=1)
version_cell.protection = Protection(locked=True)

phase_cell = ws.cell(row=home_kpi_top + 1, column=8, value="=INDEX(tbl_VersionLog[Phase],COUNTA(tbl_VersionLog[Phase]))")
phase_cell.font = f(size=13, bold=True, color=C["white"])
phase_cell.fill = fill(C["kpi_fill"])
phase_cell.alignment = Alignment(vertical="center", horizontal="left", indent=1, wrap_text=True)
phase_cell.protection = Protection(locked=True)

nav = [
    ("02", "Partner Dashboard"), ("03", "CEO Dashboard"), ("04", "Sales"),
    ("05", "Products"), ("06", "Customers"), ("07", "Inventory"),
    ("08", "Finance"), ("09", "Profitability"), ("10", "Expenses"),
    ("11", "Capital"), ("12", "Suppliers"), ("13", "Marketing"),
    ("14", "Data Quality"), ("15", "Settings"),
]
ws.cell(row=row, column=2, value="NAVIGATION").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
start_row = row
col = 2
per_row = 4
for i, (code, name) in enumerate(nav):
    r = start_row + (i // per_row) * 3
    c = col + (i % per_row) * 2
    sheet_code = f"{code}_{name.replace(' ', '_')}"
    ws.merge_cells(start_row=r, start_column=c, end_row=r + 1, end_column=c + 1)
    cell = ws.cell(row=r, column=c, value=f"{code}\n{name}")
    cell.font = f(size=11, bold=True, color=C["white"])
    cell.fill = fill(C["dark_gray"])
    cell.alignment = Alignment(vertical="center", horizontal="center", wrap_text=True)
    cell.hyperlink = f"#'{sheet_code}'!A1"
    for rr in range(r, r + 2):
        for cc in range(c, c + 2):
            ws.cell(row=rr, column=cc).fill = fill(C["dark_gray"])
    ws.row_dimensions[r].height = 18
    ws.row_dimensions[r + 1].height = 18
row = start_row + ((len(nav) - 1) // per_row + 1) * 3 + 1
ws.cell(row=row, column=2, value=(
    "Phase 1 build — structure only. No live Shopify data, no calculations, "
    "no DAX measures yet. See 15_Settings for workbook version and roadmap."
)).font = f(size=9, italic=True, color=C["text_gray"])
freeze_below_header(ws)
protect_ws(ws)
ws.sheet_properties.tabColor = TAB_COLOR["nav"]


# ============================================================================
# Generic dashboard / report sheet builder (02-09, 13)
# ============================================================================
DASHBOARD_SHEETS = [
    dict(
        code="02_Partner_Dashboard", title="Partner Dashboard",
        purpose="Consolidated, high-level view for business partners — financial and operational health at a glance, no drill-down detail.",
        inputs="FACT_OrderLines, FACT_Refunds, FACT_ManualExpenses, FACT_Payments (via Data Model, Phase 3).",
        outputs="KPI summary, trend chart, expense breakdown chart.",
        relationships="Data Model star schema (DIM_Date, DIM_Product) — Phase 3.",
        future_source="Power Pivot Data Model measures — Phase 3/4.",
        kpis=["Net Sales", "Gross Margin %", "Net Profit", "Cash Position", "Inventory Value", "Capital Invested"],
        charts=["Revenue Trend (Chart)", "Expense Breakdown (Chart)"],
        pivots=["Financial Summary (PivotTable)"],
    ),
    dict(
        code="03_CEO_Dashboard", title="CEO Dashboard",
        purpose="Executive operational + strategic overview — broader KPI set and more granularity than the Partner view.",
        inputs="FACT_OrderLines, FACT_Refunds, DIM_Product, DIM_Collection, DIM_Customer (via Data Model, Phase 3).",
        outputs="KPI summary, sales trend, product/collection breakdown, channel/geography chart.",
        relationships="Data Model star schema — Phase 3.",
        future_source="Power Pivot Data Model measures — Phase 3/4.",
        kpis=["Net Sales", "Orders", "AOV", "Gross Margin %", "Return Rate", "Inventory Turns", "Customers", "New vs Returning %"],
        charts=["Sales Trend (Chart)", "Sales by Collection (Chart)", "Top Products (Chart)", "Geography (Chart)"],
        pivots=["Executive Summary (PivotTable)"],
    ),
    dict(
        code="04_Sales", title="Sales",
        purpose="Sales performance detail — orders, revenue, discounts, and returns by period, product, and channel.",
        inputs="FACT_OrderLines, FACT_Refunds, DIM_Date, DIM_Product, DIM_Collection.",
        outputs="Sales KPI row, Sales-by-Date / Sales-by-Product / Sales-by-Collection pivots, order list.",
        relationships="FACT_OrderLines links to DIM_Date/DIM_Product/DIM_Collection; FACT_Refunds links to FACT_OrderLines.",
        future_source="RAW_Orders / RAW_OrderLines via Power Query — Phase 2.",
        kpis=["Gross Sales", "Discounts", "Returns", "Net Sales"],
        charts=["Sales Trend (Chart)"],
        pivots=["Sales by Date (PivotTable)", "Sales by Product (PivotTable)", "Sales by Collection (PivotTable)", "Order List (Table)"],
    ),
    dict(
        code="05_Products", title="Products",
        purpose="Product-level performance — best sellers, margin by SKU, and variant performance.",
        inputs="DIM_Product, FACT_OrderLines.",
        outputs="Product KPI row, Top Products table, Product Margin table, Variant Detail table.",
        relationships="DIM_Product links to FACT_OrderLines on ProductKey.",
        future_source="RAW_Products / RAW_Variants via Power Query — Phase 2.",
        kpis=["Active SKUs", "Best Seller", "Avg Margin %", "Slow Movers"],
        charts=["Top 10 Products (Chart)"],
        pivots=["Product Margin (PivotTable)", "Variant Detail (PivotTable)"],
    ),
    dict(
        code="06_Customers", title="Customers",
        purpose="Customer analytics — cohorts, lifetime value, repeat-purchase rate, and geography.",
        inputs="DIM_Customer, FACT_OrderLines.",
        outputs="Customer KPI row, Cohort table, Top Customers table, Geography breakdown.",
        relationships="DIM_Customer links to FACT_OrderLines on CustomerKey.",
        future_source="RAW_Customers via Power Query — Phase 2.",
        kpis=["Total Customers", "New Customers", "Repeat Rate %", "Avg LTV"],
        charts=["Cohort Trend (Chart)"],
        pivots=["Cohort Table (PivotTable)", "Top Customers (PivotTable)", "Geography (PivotTable)"],
    ),
    dict(
        code="07_Inventory", title="Inventory",
        purpose="Stock levels, valuation, turnover, and reorder risk.",
        inputs="FACT_InventoryMovements, DIM_Product, DIM_Location.",
        outputs="Inventory KPI row, Stock-by-Location table, Low Stock list, Valuation table.",
        relationships="FACT_InventoryMovements links to DIM_Product and DIM_Location.",
        future_source="RAW_InventoryLevels via Power Query — Phase 2.",
        kpis=["Inventory Value", "Units on Hand", "Inventory Turns", "Stockout Risk"],
        charts=["Stock Trend (Chart)"],
        pivots=["Stock by Location (PivotTable)", "Low Stock List (Table)", "Inventory Valuation (PivotTable)"],
    ),
    dict(
        code="08_Finance", title="Finance",
        purpose="Core management-basis financial statements — Profit & Loss and Cash Flow summary (not audited books).",
        inputs="FACT_OrderLines, FACT_ManualExpenses, FACT_Payments, Chart of Accounts mapping (15_Settings).",
        outputs="Finance KPI row, P&L Statement, Cash Flow Statement.",
        relationships="Combines Shopify-sourced facts with manually entered FACT_ManualExpenses, categorized via the Chart of Accounts mapping table.",
        future_source="Data Model measures, built on top of RAW_Orders + FACT_ManualExpenses — Phase 3/4.",
        kpis=["Net Sales", "Total Expenses", "Net Profit", "Cash Balance"],
        charts=["P&L Trend (Chart)"],
        pivots=["P&L Statement (PivotTable)", "Cash Flow Statement (PivotTable)"],
    ),
    dict(
        code="09_Profitability", title="Profitability",
        purpose="Margin analysis — gross margin, contribution margin, and profitability by product, collection, and channel.",
        inputs="FACT_OrderLines, DIM_Product, DIM_Collection.",
        outputs="Profitability KPI row, Margin-by-Product / Margin-by-Collection tables, Margin Trend chart.",
        relationships="FACT_OrderLines carries both revenue and COGS at line grain, enabling margin by any dimension.",
        future_source="Data Model measures — Phase 3/4.",
        kpis=["Gross Margin %", "Contribution Margin %", "Best Margin Category", "Worst Margin Category"],
        charts=["Margin Trend (Chart)"],
        pivots=["Margin by Product (PivotTable)", "Margin by Collection (PivotTable)"],
    ),
    dict(
        code="13_Marketing", title="Marketing",
        purpose="Campaign and discount-code performance tracking; future home for ad-spend ROAS once integrated.",
        inputs="DIM_Collection, FACT_OrderLines (discount amounts). Future: FACT_AdSpend.",
        outputs="Marketing KPI row, Campaign Performance table, Discount Code Usage table.",
        relationships="FACT_OrderLines[DiscountAmount] rolls up by campaign/discount code.",
        future_source="RAW_Orders discount fields via Power Query — Phase 2. Meta/TikTok Ads API — future integration.",
        kpis=["Total Discount Given", "Active Campaigns", "Discount Rate %", "ROAS (future)"],
        charts=["Discount Trend (Chart)"],
        pivots=["Campaign Performance (PivotTable)", "Discount Code Usage (PivotTable)"],
    ),
]

for spec in DASHBOARD_SHEETS:
    ws = wb.create_sheet(spec["code"])
    ws.sheet_view.showGridLines = False
    set_col_widths(ws, [3] + [13] * 11)
    title_bar(ws, spec["title"], last_col=12)
    row = doc_block(ws, spec["purpose"], spec["inputs"], spec["outputs"], spec["relationships"], spec["future_source"], last_col=12)
    row, _ = add_kpi_row(ws, row, spec["kpis"], col_start=2, card_width=2)
    row += 1
    ws.cell(row=row, column=2, value="TRENDS & BREAKDOWNS").font = f(size=10, bold=True, color=C["text_gray"])
    row += 1
    chart_row = row
    for ch in spec["charts"]:
        row = add_placeholder_box(ws, chart_row, 2, 10, 8, ch, phase="Phase 3")
        chart_row = row
    row += 1
    ws.cell(row=row, column=2, value="DETAIL (PIVOTTABLES)").font = f(size=10, bold=True, color=C["text_gray"])
    row += 1
    piv_col = 2
    for pv in spec["pivots"]:
        row2 = add_placeholder_box(ws, row, piv_col, 5, 10, pv, phase="Phase 3")
        piv_col += 5
        if piv_col > 10:
            piv_col = 2
            row = row2
    freeze_below_header(ws)
    protect_ws(ws)
    ws.sheet_properties.tabColor = TAB_COLOR["dashboard"] if "Dashboard" in spec["title"] else TAB_COLOR["report"]


# ============================================================================
# 10_Expenses  — manual-entry sheet (green)
# ============================================================================
ws = wb.create_sheet("10_Expenses")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3, 12, 16, 16, 30, 12, 14, 12])
title_bar(ws, "Expenses", last_col=8)
row = doc_block(
    ws,
    "Operating expense tracking — the manual-entry source for costs that do not come from Shopify (rent, salaries, ad spend, shipping, etc.).",
    "None — this sheet is the input. Category list validated against 15_Settings Chart of Accounts.",
    "FACT_ManualExpenses (Data Model fact table).",
    "Feeds the Data Model as its own fact table, kept structurally separate from Shopify-sourced facts so system-of-record vs. hand-entered data is always distinguishable. Categories map to 15_Settings!ChartOfAccounts.",
    "This IS the source — no external system. Manual entry only.",
    last_col=8,
)
row, _ = add_kpi_row(ws, row, ["Expenses MTD", "Expenses YTD", "Largest Category", "Budget Variance"], col_start=2, card_width=2)
row += 1
ws.cell(row=row, column=2, value="MANUAL EXPENSE ENTRY  (green cells = type here)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_table(
    ws, "tbl_ManualExpenses", row, 2,
    ["Date", "Category", "Cost Center", "Description", "Amount (EGP)", "Payment Method", "Entered By"],
    "input",
    example_row=["2026-01-15", "Rent", "Head Office", "EXAMPLE — January office rent", 15000, "Bank Transfer", "Founder"],
)
freeze_below_header(ws)
protect_ws(ws)
ws.sheet_properties.tabColor = TAB_COLOR["input"]

# ============================================================================
# 11_Capital — manual-entry sheet (green)
# ============================================================================
ws = wb.create_sheet("11_Capital")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3, 12, 16, 30, 14, 14])
title_bar(ws, "Capital", last_col=6)
row = doc_block(
    ws,
    "Tracks owner capital contributions and withdrawals, and the resulting owner-equity position.",
    "None — this sheet is the input.",
    "FACT_ManualExpenses-style capital ledger (own table) feeding the Data Model owner-equity measures.",
    "The only source that grows/shrinks Capital Invested and Owner Equity on the dashboards.",
    "This IS the source — no external system. Manual entry only.",
    last_col=6,
)
row, _ = add_kpi_row(ws, row, ["Capital Invested", "Owner Withdrawals", "Net Owner Equity", "YTD Movement"], col_start=2, card_width=2)
row += 1
ws.cell(row=row, column=2, value="CAPITAL TRANSACTIONS  (green cells = type here)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_table(
    ws, "tbl_CapitalTransactions", row, 2,
    ["Date", "Type (Contribution/Withdrawal)", "Description", "Amount (EGP)", "Entered By"],
    "input",
    example_row=["2026-01-01", "Contribution", "EXAMPLE — founder capital injection", 50000, "Founder"],
)
freeze_below_header(ws)
protect_ws(ws)
ws.sheet_properties.tabColor = TAB_COLOR["input"]


# ============================================================================
# 14_Data_Quality
# ============================================================================
ws = wb.create_sheet("14_Data_Quality")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3, 16, 30, 14, 30])
title_bar(ws, "Data Quality", last_col=5)
row = doc_block(
    ws,
    "Monitors refresh health, row counts, and validation checks so data problems surface immediately instead of silently propagating into dashboards.",
    "LOG_RefreshHistory, LOG_DataQuality.",
    "Refresh Status Summary, Validation Rules.",
    "Reads directly from the two hidden LOG_ sheets — this is their human-facing display, not a separate data source.",
    "LOG_RefreshHistory / LOG_DataQuality, populated by Power Query refresh events — Phase 2.",
    last_col=5,
)
row, _ = add_kpi_row(ws, row, ["Last Refresh", "Rows Loaded", "Errors Found", "Data Freshness"], col_start=2, card_width=2)
row += 1
ws.cell(row=row, column=2, value="VALIDATION RULES  (orange cells = configurable)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_table(
    ws, "tbl_ValidationRules", row, 2,
    ["Rule ID", "Check Name", "Applies To", "Threshold"],
    "settings",
    example_row=["DQ-001", "No orders older than lookback window missing", "RAW_Orders", "0 gaps"],
)
row += 1
ws.cell(row=row, column=2, value="REFRESH STATUS SUMMARY  (calculated — Phase 2)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_table(
    ws, "tbl_RefreshStatusSummary", row, 2,
    ["Table", "Last Refreshed", "Row Count", "Status"],
    "calc",
)
freeze_below_header(ws)
protect_ws(ws)
ws.sheet_properties.tabColor = TAB_COLOR["report"]


# ============================================================================
# 15_Settings — control panel (orange) + named ranges
# ============================================================================
ws = wb.create_sheet("15_Settings")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3, 24, 22, 44])
title_bar(ws, "Settings", last_col=4)
row = doc_block(
    ws,
    "Central control panel — every configurable parameter the rest of the workbook depends on. The single place non-technical changes should be made.",
    "None — this sheet is the input.",
    "DIM_Parameters (disconnected DAX table mirrors these values), Power Query parameters (Phase 2), Chart of Accounts mapping used by 08_Finance/09_Profitability.",
    "Every Power Query parameter and every DAX measure that needs a configurable constant reads from here — never hardcoded elsewhere.",
    "This IS the source. No external system.",
    last_col=4,
)

NAMED_RANGES = []  # (name, sheet, cell)

def settings_table(ws, start_row, title, rows, name_prefix=None):
    ws.cell(row=start_row, column=2, value=title).font = f(size=10, bold=True, color=C["text_gray"])
    r = start_row + 1
    headers = ["Parameter", "Value", "Description"]
    for i, h in enumerate(headers):
        cell = ws.cell(row=r, column=2 + i, value=h)
        cell.font = f(size=9, bold=True, color=C["white"])
        cell.fill = fill(C["settings_header"])
        cell.border = BORDER_ALL
    ws.row_dimensions[r].height = 16
    r += 1
    for param, value, desc in rows:
        pcell = ws.cell(row=r, column=2, value=param)
        pcell.font = f(size=9, color=C["text_gray"])
        pcell.fill = fill(C["light_gray"])
        pcell.border = BORDER_ALL
        pcell.protection = Protection(locked=True)

        vcell = ws.cell(row=r, column=3, value=value)
        vcell.font = f(size=9, bold=True, color=C["settings_body"])
        vcell.fill = fill(C["settings_fill"])
        vcell.border = BORDER_ALL
        vcell.protection = Protection(locked=False)

        dcell = ws.cell(row=r, column=4, value=desc)
        dcell.font = f(size=8, italic=True, color=C["text_gray"])
        dcell.fill = fill(C["light_gray"])
        dcell.border = BORDER_ALL
        dcell.protection = Protection(locked=True)

        if name_prefix:
            nr_name = name_prefix + "".join(ch for ch in param if ch.isalnum())
            NAMED_RANGES.append((nr_name, "15_Settings", f"$C${r}"))
        r += 1
    return r + 2

row = settings_table(
    ws, row, "GENERAL SETTINGS  (orange cells = configurable)",
    [
        ("Company Name", "Passress", "Legal/trading name shown across dashboards."),
        ("Base Currency", "EGP", "Currency all imported Shopify data is stored in."),
        ("Reporting Currency", "EGP", "Currency used for dashboard display. Phase 1: same as base."),
        ("Fiscal Year Start Month", "January", "First month of fiscal year, used for YTD/FY calculations."),
        ("Default VAT Rate", "14%", "Egypt standard VAT — used for tax reconciliation."),
        ("Target Gross Margin %", "55%", "Benchmark used for profitability flags (Phase 3)."),
    ],
    name_prefix="Set",
)

row = settings_table(
    ws, row, "SHOPIFY CONNECTION SETTINGS  (fill in Store Domain to go live; token is never stored here)",
    [
        ("Shopify Store Domain", "your-store.myshopify.com", "Set this to your real *.myshopify.com domain to go live. The access token itself is never stored in this workbook — see power-query/README.md."),
        ("Shopify API Version", "2025-01", "Admin GraphQL API version pinned for Power Query — reviewed twice a year."),
        ("Lookback Days (Incremental Refresh)", "7", "Rolling re-check window: days of history re-pulled on every refresh so late-updated records are never missed."),
        ("Historical Backfill Start Date", "2024-01-01", "Earliest date fetched on a first-ever run (empty staging table). Ignored once a table has data — Lookback Days takes over."),
        ("Max Pages Per Refresh (Safety Cap)", "500", "Hard stop on pagination per query per refresh (500 pages x 250 records ≈ 125,000 rows), so a misconfigured filter can't run away."),
    ],
    name_prefix="Set",
)

# Chart of Accounts mapping table (real Excel Table)
ws.cell(row=row, column=2, value="CHART OF ACCOUNTS MAPPING  (orange cells = configurable)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_table(
    ws, "tbl_ChartOfAccounts", row, 2,
    ["Account Code", "Account Name", "Statement", "P&L / BS Line", "Source"],
    "settings",
    example_row=["4000", "EXAMPLE — Net Sales", "P&L", "Revenue", "FACT_OrderLines"],
)
row += 1

# Workbook version log (calculated/system — light gray)
# Every phase appends one row here — see VERSION_LOG_ROWS below. 01_Home's
# "Workbook Version" / "Phase Completed" KPI cards read the LAST row of this
# table live via formula, so this table is the single place that drives both.
ws.cell(row=row, column=2, value="WORKBOOK VERSION LOG  (system-maintained — every phase appends a row here)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
VERSION_LOG_ROWS = [
    ["1.0", "2026-07-26", "Phase 1 — Workbook Foundation",
     "Structure, tables, named ranges, documentation. No live data, no calculations."],
    ["1.1", "2026-07-26", "Phase 1 Finalization",
     "01_Home's Workbook Version / Phase Completed KPI cards now read this table's last row live via formula — every future phase appends a row here and Home updates automatically."],
    ["2.0", "2026-07-26", "Phase 2 — Shopify GraphQL Ingestion Layer",
     "Complete Power Query M layer: authentication (Extension.CurrentCredential, no hardcoded tokens), automatic cursor pagination, incremental refresh, HTTP/GraphQL error handling with backoff. Covers Products, Variants, Orders, Order Lines, Customers, Collections, Inventory Levels, Transactions, Refunds, Discounts — read-only (GraphQL query operations only). Added RAW_Transactions and RAW_Discounts staging sheets; revised RAW_Refunds and RAW_InventoryLevels to match verified Shopify Admin API schema. See /passress-mis/power-query/README.md and DOCUMENTATION.md. No dashboards yet."],
]
tbl_version_log_top_row = row
row = add_table(
    ws, "tbl_VersionLog", row, 2,
    ["Version", "Date", "Phase", "Summary"],
    "calc",
    data_rows=VERSION_LOG_ROWS,
)

freeze_below_header(ws)
protect_ws(ws)
ws.sheet_properties.tabColor = TAB_COLOR["report"]


# ============================================================================
# 12_Suppliers — manual-entry sheet (green)
# ============================================================================
ws = wb.create_sheet("12_Suppliers")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3, 14, 20, 16, 16, 12, 14])
title_bar(ws, "Suppliers", last_col=7)
row = doc_block(
    ws,
    "Supplier master data and purchase order tracking.",
    "None — this sheet is the input.",
    "Supplier master table, Purchase Order log — future Data Model facts (FACT_Purchases).",
    "Purchase Order log will link to DIM_Product once SKU-level purchasing is tracked (Phase 3+).",
    "This IS the source today. Candidate for supplier-portal or accounting-system integration later (see Future Integrations).",
    last_col=7,
)
row, _ = add_kpi_row(ws, row, ["Active Suppliers", "Purchases YTD", "Avg Lead Time", "Outstanding Payables"], col_start=2, card_width=2)
row += 1
ws.cell(row=row, column=2, value="SUPPLIER MASTER  (green cells = type here)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_table(
    ws, "tbl_SupplierMaster", row, 2,
    ["Supplier ID", "Supplier Name", "Contact", "Category", "Lead Time (Days)", "Status"],
    "input",
    example_row=["SUP-001", "EXAMPLE — ABC Textiles", "contact@example.com", "Fabric", 14, "Active"],
)
row += 1
ws.cell(row=row, column=2, value="PURCHASE ORDER LOG  (green cells = type here)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_table(
    ws, "tbl_PurchaseOrders", row, 2,
    ["PO Number", "Supplier ID", "Date", "Amount (EGP)", "Status", "Expected Delivery"],
    "input",
    example_row=["PO-2026-001", "SUP-001", "2026-01-10", 20000, "Ordered", "2026-01-24"],
)
freeze_below_header(ws)
protect_ws(ws)
ws.sheet_properties.tabColor = TAB_COLOR["input"]


# ============================================================================
# Hidden technical sheets: RAW_ / DIM_ / FACT_ / LOG_
# ============================================================================

def build_hidden_sheet(code, category, purpose, inputs, outputs, relationships, future_source, headers, example_row=None):
    ws = wb.create_sheet(code)
    ws.sheet_view.showGridLines = False
    set_col_widths(ws, [3] + [16] * len(headers))
    title_bar(ws, code, last_col=len(headers) + 1)
    row = doc_block(ws, purpose, inputs, outputs, relationships, future_source, last_col=len(headers) + 1)
    table_category = {"raw": "shopify", "dim": "calc", "fact": "calc", "log": "calc"}[category]
    add_table(ws, "tbl_" + code, row, 2, headers, table_category, example_row=example_row)
    freeze_below_header(ws)
    protect_ws(ws)
    ws.sheet_properties.tabColor = TAB_COLOR[category]
    ws.sheet_state = "hidden"
    return ws


RAW_SHEETS = [
    dict(code="RAW_Orders", pq="staging/RAW_Orders.pq",
         headers=["OrderID", "OrderNumber", "CreatedAt", "UpdatedAt", "FinancialStatus",
                   "FulfillmentStatus", "Currency", "TotalPrice", "SubtotalPrice",
                   "TotalDiscounts", "TotalTax", "CustomerID", "LocationID"]),
    dict(code="RAW_OrderLines", pq="staging/RAW_OrderLines.pq",
         headers=["LineItemID", "OrderID", "ProductID", "VariantID", "SKU", "Title",
                   "Quantity", "UnitPrice", "DiscountAllocated", "TaxAllocated"]),
    dict(code="RAW_Transactions", pq="staging/RAW_Transactions.pq",
         headers=["TransactionID", "OrderID", "Kind", "Status", "Gateway", "AmountShop",
                   "CurrencyShop", "CreatedAt", "ProcessedAt", "Test"]),
    dict(code="RAW_Refunds", pq="staging/RAW_Refunds.pq",
         headers=["RefundLineItemID", "RefundID", "OrderID", "LineItemID", "Quantity",
                   "SubtotalAmount", "TaxAmount", "RefundCreatedAt", "RefundProcessedAt", "Note"]),
    dict(code="RAW_Products", pq="staging/RAW_Products.pq",
         headers=["ProductID", "Title", "ProductType", "Vendor", "CollectionIDs",
                   "CreatedAt", "UpdatedAt", "Status"]),
    dict(code="RAW_Variants", pq="staging/RAW_Variants.pq",
         headers=["VariantID", "ProductID", "SKU", "Title", "Price", "CompareAtPrice",
                   "InventoryItemID", "UnitCost", "CreatedAt", "UpdatedAt"]),
    dict(code="RAW_InventoryLevels", pq="staging/RAW_InventoryLevels.pq",
         headers=["InventoryItemID", "SKU", "LocationID", "Available", "UpdatedAt"]),
    dict(code="RAW_Customers", pq="staging/RAW_Customers.pq",
         headers=["CustomerID", "FirstName", "LastName", "Email", "CreatedAt", "UpdatedAt",
                   "OrdersCount", "TotalSpent", "DefaultAddressCountry"]),
    dict(code="RAW_Collections", pq="staging/RAW_Collections.pq",
         headers=["CollectionID", "Title", "Handle"]),
    dict(code="RAW_Discounts", pq="staging/RAW_Discounts.pq",
         headers=["DiscountNodeID", "Typename", "Title", "Status", "Summary", "Code",
                   "StartsAt", "EndsAt", "UsageLimit", "AsyncUsageCount", "CreatedAt", "UpdatedAt"]),
]
for s in RAW_SHEETS:
    build_hidden_sheet(
        s["code"], "raw",
        purpose=f"Power Query staging landing zone for the Shopify {s['code'].replace('RAW_', '')} resource. Shape-only transforms (type casting, flattening) happen here — no business logic.",
        inputs="Shopify Admin GraphQL API, via the fn_ShopifyGraphQL / fn_ShopifyPagedConnection shared functions.",
        outputs="Feeds the Data Model fact/dimension tables built from this resource (Phase 3).",
        relationships="Connection-only in Excel; loaded to the Data Model, not to a worksheet grid, once wired in Excel.",
        future_source=(
            f"Live now: paste passress-mis/power-query/{s['pq']} into this query in Excel's Power Query "
            "Advanced Editor (Data > Get Data > Launch Power Query Editor > New Query > Blank Query). "
            "See passress-mis/power-query/README.md for full setup and passress-mis/power-query/DOCUMENTATION.md "
            "for the field-by-field mapping."
        ),
        headers=s["headers"],
    )

DIM_SHEETS = [
    dict(code="DIM_Date", headers=["DateKey", "Date", "Year", "FiscalYear", "Quarter", "Month", "MonthName",
                                    "Week", "Day", "DayName", "IsWeekend"]),
    dict(code="DIM_Product", headers=["ProductKey", "ProductID", "SKU", "Title", "ProductType", "Vendor",
                                       "Collection", "UnitCost", "Status"]),
    dict(code="DIM_Customer", headers=["CustomerKey", "CustomerID", "Name", "Email", "Country",
                                        "FirstOrderDate", "CustomerSegment"]),
    dict(code="DIM_Location", headers=["LocationKey", "LocationID", "LocationName", "City", "Country"]),
    dict(code="DIM_Collection", headers=["CollectionKey", "CollectionID", "Title", "Handle"]),
    dict(code="DIM_Parameters", headers=["ParameterName", "ParameterValue"]),
]
for s in DIM_SHEETS:
    is_params = s["code"] == "DIM_Parameters"
    build_hidden_sheet(
        s["code"], "dim",
        purpose=(
            "Disconnected mirror of 15_Settings, used so DAX measures can reference configurable "
            "constants without creating a relationship into the star schema."
            if is_params else
            f"Dimension table for the star schema — describes the '{s['code'].replace('DIM_', '')}' entity that FACT_ tables relate to."
        ),
        inputs="15_Settings (linked manually / via Power Query, Phase 2)." if is_params else "Derived from the matching RAW_ staging table(s).",
        outputs="Referenced by DAX measures across all dashboards." if is_params else "Related to FACT_ tables in the Data Model (one-to-many).",
        relationships="N/A — disconnected table by design." if is_params else "One-to-many into the relevant FACT_ table(s) on this dimension's key column.",
        future_source="Manual link to 15_Settings — Phase 3." if is_params else "Built from RAW_ staging data in Power Query — Phase 2/3.",
        headers=s["headers"],
    )

FACT_SHEETS = [
    dict(code="FACT_OrderLines", category="calc",
         headers=["OrderLineKey", "OrderID", "DateKey", "ProductKey", "CustomerKey", "LocationKey",
                   "Quantity", "UnitPrice", "GrossAmount", "DiscountAmount", "TaxAmount", "NetAmount",
                   "UnitCost", "COGS"]),
    dict(code="FACT_Refunds", category="calc",
         headers=["RefundKey", "OrderLineKey", "DateKey", "Quantity", "RefundAmount"]),
    dict(code="FACT_InventoryMovements", category="calc",
         headers=["MovementKey", "DateKey", "ProductKey", "LocationKey", "MovementType", "QuantityChange",
                   "ResultingOnHand"]),
    dict(code="FACT_Payments", category="calc",
         headers=["PaymentKey", "OrderID", "DateKey", "PaymentMethod", "Currency", "Amount",
                   "PresentmentAmount"]),
    dict(code="FACT_ManualExpenses", category="input",
         headers=["ExpenseKey", "Date", "Category", "CostCenter", "Description", "Amount", "PaymentMethod",
                   "EnteredBy"]),
]
for s in FACT_SHEETS:
    manual = s["category"] == "input"
    ws = wb.create_sheet(s["code"])
    ws.sheet_view.showGridLines = False
    set_col_widths(ws, [3] + [16] * len(s["headers"]))
    title_bar(ws, s["code"], last_col=len(s["headers"]) + 1)
    row = doc_block(
        ws,
        ("Manually entered operating-expense fact, kept structurally separate from Shopify-sourced facts. "
         "Mirrors the input table on 10_Expenses — this is the Data Model-ready version of it."
         if manual else
         f"Fact table for the star schema — transaction-level grain, built from RAW_ staging data plus dimension keys."),
        "10_Expenses manual entry table." if manual else "RAW_ staging tables + DIM_ key lookups.",
        "Referenced by DAX measures across 08_Finance, 09_Profitability, 02/03 dashboards." if manual else "Referenced by DAX measures across all dashboards.",
        "Grain: one row per expense entry." if manual else "Many-to-one into each related DIM_ table.",
        "10_Expenses (already the source of truth — no external system)." if manual else "Built in Power Query from RAW_ + DIM_ — Phase 2/3.",
        last_col=len(s["headers"]) + 1,
    )
    add_table(ws, "tbl_" + s["code"], row, 2, s["headers"], s["category"])
    freeze_below_header(ws)
    protect_ws(ws)
    ws.sheet_properties.tabColor = TAB_COLOR["fact"]
    ws.sheet_state = "hidden"

LOG_SHEETS = [
    dict(code="LOG_RefreshHistory",
         headers=["RefreshID", "Timestamp", "Source", "RowsLoaded", "RowsUpdated", "Errors",
                   "DurationSeconds", "TriggeredBy"]),
    dict(code="LOG_DataQuality",
         headers=["CheckID", "Timestamp", "CheckName", "TableName", "Status", "Details"]),
]
for s in LOG_SHEETS:
    build_hidden_sheet(
        s["code"], "log",
        purpose=(
            "Append-only log of every workbook refresh: what ran, how many rows moved, and how long it took."
            if "Refresh" in s["code"] else
            "Append-only log of validation-rule results, one row per check per refresh."
        ),
        inputs="Written by the Power Query refresh process (Phase 2).",
        outputs="Displayed on 14_Data_Quality and summarized on 01_Home.",
        relationships="No Data Model relationship — a flat audit trail, queried directly by 14_Data_Quality.",
        future_source="Populated automatically on every Refresh All — Phase 2.",
        headers=s["headers"],
    )


# ============================================================================
# Tab order (creation order did not match required order — fix explicitly)
# ============================================================================
VISIBLE_ORDER = [
    "01_Home", "02_Partner_Dashboard", "03_CEO_Dashboard", "04_Sales", "05_Products",
    "06_Customers", "07_Inventory", "08_Finance", "09_Profitability", "10_Expenses",
    "11_Capital", "12_Suppliers", "13_Marketing", "14_Data_Quality", "15_Settings",
]
HIDDEN_ORDER = (
    [s["code"] for s in RAW_SHEETS] +
    [s["code"] for s in DIM_SHEETS] +
    [s["code"] for s in FACT_SHEETS] +
    [s["code"] for s in LOG_SHEETS]
)
FULL_ORDER = VISIBLE_ORDER + HIDDEN_ORDER
assert sorted(FULL_ORDER) == sorted(wb.sheetnames), (
    f"Order/sheet mismatch. Missing from order: {set(wb.sheetnames) - set(FULL_ORDER)}; "
    f"extra in order: {set(FULL_ORDER) - set(wb.sheetnames)}"
)
wb._sheets = [wb[name] for name in FULL_ORDER]
wb.active = 0

# ============================================================================
# Named ranges (workbook-scoped)
# ============================================================================
from openpyxl.workbook.defined_name import DefinedName

for name, sheet, cell in NAMED_RANGES:
    ref = f"'{sheet}'!{cell}"
    wb.defined_names[name] = DefinedName(name, attr_text=ref)

# ============================================================================
# Workbook-level structure protection
# ============================================================================
wb.security = WorkbookProtection(lockStructure=True, lockWindows=False, workbookPassword=PROTECT_PASSWORD)

# ============================================================================
# Save + manifest for documentation
# ============================================================================
import json, os

OUT_PATH = os.path.join(os.path.dirname(__file__), "..", "PASSRESS_MIS.xlsx")
wb.save(OUT_PATH)

manifest = {
    "visible_sheets": VISIBLE_ORDER,
    "hidden_sheets": HIDDEN_ORDER,
    "named_ranges": [{"name": n, "sheet": s, "cell": c} for n, s, c in NAMED_RANGES],
    "tables": [],
}
for sheet_name in wb.sheetnames:
    ws = wb[sheet_name]
    for tbl_name in ws.tables.keys():
        manifest["tables"].append({"table": tbl_name, "sheet": sheet_name, "ref": ws.tables[tbl_name].ref})

manifest_path = os.path.join(os.path.dirname(__file__), "..", "manifest.json")
with open(manifest_path, "w") as fh:
    json.dump(manifest, fh, indent=2)

print(f"Saved workbook: {OUT_PATH}")
print(f"Sheets: {len(wb.sheetnames)}  ({len(VISIBLE_ORDER)} visible, {len(HIDDEN_ORDER)} hidden)")
print(f"Tables: {len(manifest['tables'])}")
print(f"Named ranges: {len(NAMED_RANGES)}")
