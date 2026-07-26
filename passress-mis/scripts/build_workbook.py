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
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.comments import Comment
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

NAMED_RANGES = []       # (name, sheet, cell) -> single-cell named ranges (e.g. Settings parameters)
NAMED_LIST_RANGES = []  # (name, table, column) -> table-column named ranges (e.g. dropdown list sources)

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


# --------------------------------------------------- Phase 3: master data --

def add_lookup_table(ws, table_name, top_row, top_col, header, values, list_name=None, width=18):
    """Small single-column configurable lookup table (orange = Settings) used
    as a dropdown source elsewhere. Registers a table-column named range
    (list_name) so Data Validation can reference it as '=ListName'.
    Returns next free row."""
    style = CATEGORY_STYLE["settings"]
    ws.column_dimensions[get_column_letter(top_col)].width = width
    hcell = ws.cell(row=top_row, column=top_col, value=header)
    hcell.font = f(size=9, bold=True, color=C["white"])
    hcell.fill = fill(style["header_fill"])
    hcell.border = BORDER_ALL
    ws.row_dimensions[top_row].height = 16

    for i, val in enumerate(values):
        r = top_row + 1 + i
        cell = ws.cell(row=r, column=top_col, value=val)
        cell.font = f(size=9, color=style["body_font"])
        cell.fill = fill(style["body_fill"])
        cell.border = BORDER_ALL
        cell.protection = Protection(locked=False)

    end_row = top_row + len(values)
    ref = f"{get_column_letter(top_col)}{top_row}:{get_column_letter(top_col)}{end_row}"
    tbl = Table(displayName=table_name, ref=ref)
    tbl.tableStyleInfo = TableStyleInfo(name="TableStyleLight1", showFirstColumn=False,
                                         showLastColumn=False, showRowStripes=False, showColumnStripes=False)
    ws.add_table(tbl)

    if list_name:
        NAMED_LIST_RANGES.append((list_name, table_name, header))
    return end_row + 2


def add_dropdown(ws, cell_range, list_name, title, prompt, error_title="Invalid entry", error_msg=None):
    """Attaches list-based Data Validation (dropdown + input prompt + stop-on-error
    message) to a column range, sourced from a named list range."""
    dv = DataValidation(
        type="list", formula1=f"={list_name}", allow_blank=True,
        showDropDown=False,  # False = show the in-cell dropdown arrow (openpyxl's flag is inverted)
        showInputMessage=True, showErrorMessage=True, errorStyle="stop",
    )
    dv.promptTitle = title[:32]
    dv.prompt = prompt[:255]
    dv.errorTitle = error_title[:32]
    dv.error = (error_msg or f"Please choose a value from the {title} list — free text isn't accepted here.")[:255]
    ws.add_data_validation(dv)
    dv.add(cell_range)
    return dv


def extend_validation_down(ws, dv, cell_range):
    """Adds an additional range to an existing DataValidation (e.g. future
    rows below the current placeholder data)."""
    dv.add(cell_range)


def make_calc_column(ws, row, col, formula, numfmt=None, italic=False):
    """Overwrites a cell inside an otherwise-green (input) table row with a
    locked, gray-styled formula — for identifier/total/flag columns that are
    computed, not typed, even though they live inside a manual-entry table."""
    style = CATEGORY_STYLE["calc"]
    cell = ws.cell(row=row, column=col, value=formula)
    cell.font = f(size=9, color=style["body_font"], italic=italic)
    cell.fill = fill(style["body_fill"])
    cell.border = BORDER_ALL
    cell.protection = Protection(locked=True)
    if numfmt:
        cell.number_format = numfmt
    return cell


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
        purpose="Product-level performance dashboard placeholders (Phase 4) PLUS, as of Phase 3, the Product Cost Master — the workbook's historical/versioned SKU costing table.",
        inputs="DIM_Product, FACT_OrderLines (Phase 4 dashboard). RAW_Variants, RAW_Collections (Phase 3 Product Cost Master dropdowns).",
        outputs="Product KPI row, Top Products table, Product Margin table, Variant Detail table (Phase 4). tbl_ProductCostMaster feeding DIM_ProductCostHistory (Phase 3, live now).",
        relationships="DIM_Product links to FACT_OrderLines on ProductKey (Phase 4). tbl_ProductCostMaster[SKU] links to RAW_Variants[SKU]; Phase 4's COGS calculation will further match SKU + order date against Effective From/To Date.",
        future_source="RAW_Products / RAW_Variants via Power Query — Phase 2 (dashboard). Product Cost Master is manual entry today — see PHASE3_DOCUMENTATION.md §1.",
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

DASHBOARD_END_ROW = {}
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
        row = add_placeholder_box(ws, chart_row, 2, 10, 8, ch, phase="Phase 4")
        chart_row = row
    row += 1
    ws.cell(row=row, column=2, value="DETAIL (PIVOTTABLES)").font = f(size=10, bold=True, color=C["text_gray"])
    row += 1
    piv_col = 2
    for pv in spec["pivots"]:
        row2 = add_placeholder_box(ws, row, piv_col, 5, 10, pv, phase="Phase 4")
        piv_col += 5
        if piv_col > 10:
            piv_col = 2
            row = row2
    row = max(row, row2) + 1
    freeze_below_header(ws)
    protect_ws(ws)
    ws.sheet_properties.tabColor = TAB_COLOR["dashboard"] if "Dashboard" in spec["title"] else TAB_COLOR["report"]
    DASHBOARD_END_ROW[spec["code"]] = row


# ============================================================================
# 05_Products — Phase 3 addition: Product Cost Master (historical costing)
# Appended below the Phase 1 dashboard placeholders (untouched — those are
# still Phase 4 work). This table is the only genuinely new master-data input
# added to an existing dashboard-template sheet in Phase 3.
# ============================================================================
ws = wb["05_Products"]
pcm_row = DASHBOARD_END_ROW["05_Products"] + 1
ws.cell(row=pcm_row, column=2, value="PRODUCT COST MASTER  (Phase 3 — green cells = type here; Cost ID, Total Landed Cost, "
        "Expected Gross Margin %, and the overlap warning are automatic)").font = f(size=12, bold=True, color=C["black"])
pcm_row += 1
ws.cell(row=pcm_row, column=2, value=(
    "Historical costing: never edit or delete a past row when a cost changes — add a NEW row for the "
    "new cost with its own Effective From Date, and set the OLD row's Effective To Date to the day "
    "before and its Active Flag to Inactive. Phase 4's COGS calculation will match each order line to "
    "the cost row whose SKU matches and whose Effective From/To range contains the order's date — so "
    "past orders keep using the cost that was actually active when they happened, even after costs change."
)).font = f(size=8, italic=True, color=C["text_gray"])
ws.row_dimensions[pcm_row].height = 24
pcm_row += 2

pcm_header_row = pcm_row
pcm_row = add_table(
    ws, "tbl_ProductCostMaster", pcm_row, 2,
    ["Cost ID", "SKU", "Product Name", "Variant", "Collection", "Fabric Cost", "Accessories Cost",
     "Manufacturing Cost", "Packaging Cost", "Shipping Cost", "Other Cost", "Total Landed Cost",
     "Selling Price", "Expected Gross Margin %", "Effective From Date", "Effective To Date",
     "Active Flag", "Overlap Warning"],
    "input",
    example_row=["", "", "EXAMPLE — Amara Wrap Dress", "Black / M", "", 180, 25, 90, 15, 20, 0,
                 "", 650, "", "2026-01-01", "", "Active", ""],
)
pcm_data_row = pcm_header_row + 1
make_calc_column(ws, pcm_data_row, 2, f'="COST-"&TEXT(ROW()-{pcm_header_row},"00000")')
make_calc_column(ws, pcm_data_row, 13,
    '=SUM([@[Fabric Cost]],[@[Accessories Cost]],[@[Manufacturing Cost]],[@[Packaging Cost]],[@[Shipping Cost]],[@[Other Cost]])',
    numfmt="#,##0.00")
make_calc_column(ws, pcm_data_row, 15,
    '=IF([@[Selling Price]]=0,"",([@[Selling Price]]-[@[Total Landed Cost]])/[@[Selling Price]])',
    numfmt="0.0%")
make_calc_column(ws, pcm_data_row, 19,
    '=IF(COUNTIFS(tbl_ProductCostMaster[SKU],[@SKU],tbl_ProductCostMaster[Active Flag],"Active")>1,'
    '"Multiple Active cost rows for this SKU — deactivate all but the current one","")')

add_dropdown(ws, f"C{pcm_data_row}:C501", "SKUList", "SKU",
             "Choose a live Shopify SKU.")
add_dropdown(ws, f"F{pcm_data_row}:F501", "CollectionTitleList", "Collection",
             "Choose a live Shopify collection.")
active_flag_dv = DataValidation(type="list", formula1='"Active,Inactive"', allow_blank=True,
                                 showDropDown=False, showInputMessage=True, showErrorMessage=True, errorStyle="stop")
active_flag_dv.promptTitle = "Active Flag"
active_flag_dv.prompt = "Only ONE row per SKU should be Active at a time — see the historical-costing note above."
active_flag_dv.errorTitle = "Invalid entry"
active_flag_dv.error = "Choose Active or Inactive."
ws.add_data_validation(active_flag_dv)
active_flag_dv.add(f"R{pcm_data_row}:R501")

freeze_below_header(ws)


# ============================================================================
# 10_Expenses  — manual-entry sheet (green) — Phase 3: complete module
# ============================================================================
ws = wb.create_sheet("10_Expenses")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3] + [13, 12, 16, 16, 16, 11, 10, 13, 15, 12, 12, 20, 14, 14, 16, 18, 15])
title_bar(ws, "Expenses", last_col=18)
row = doc_block(
    ws,
    "Complete operating-expense entry module — the manual-entry source for costs that do not come from Shopify (rent, salaries, ad spend, shipping, etc.), with category/subcategory lookups, optional SKU/Collection attribution, cost-center tagging, document references, and duplicate detection.",
    "15_Settings lookup tables (Expense Category, Expense Subcategory, Payment Method, Currency, Cost Center), tbl_SupplierMaster (12_Suppliers), RAW_Variants / RAW_Collections (live Shopify SKUs/collections).",
    "FACT_ManualExpenses (Data Model-ready hidden mirror).",
    "Feeds the Data Model as its own fact table, kept structurally separate from Shopify-sourced facts so system-of-record vs. hand-entered data is always distinguishable. Related SKU/Collection dropdowns pull from the live Shopify RAW_ tables, not a separate manual list, so an expense can be tied to real product/collection data. Category list is fully configurable on 15_Settings — nothing is hardcoded.",
    "This IS the source — no external system. Document Management: Invoice Number/File Name/File Path/Cloud Link are references only — see passress-mis/PHASE3_DOCUMENTATION.md; a future phase may connect Cloud Link directly to OneDrive/SharePoint.",
    last_col=18,
)
row, _ = add_kpi_row(ws, row, ["Expenses MTD", "Expenses YTD", "Largest Category", "Budget Variance"], col_start=2, card_width=2)
row += 1
ws.cell(row=row, column=2, value="MANUAL EXPENSE ENTRY  (green cells = type here — Expense ID and Possible Duplicate are automatic)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
expenses_header_row = row
row = add_table(
    ws, "tbl_ManualExpenses", row, 2,
    ["Expense ID", "Expense Date", "Expense Category", "Expense Subcategory", "Supplier", "Amount",
     "Currency", "Payment Method", "Related Collection", "Related SKU", "Cost Center", "Notes",
     "Invoice Number", "File Name", "File Path", "Cloud Link", "Possible Duplicate"],
    "input",
    example_row=["", "2026-01-15", "Rent", "Office", "", 15000, "EGP", "Bank Transfer", "", "",
                 "Head Office", "EXAMPLE — January office rent", "INV-2026-0001", "jan-rent.pdf",
                 "/Finance/2026/Rent/", "", ""],
)
exp_data_row = expenses_header_row + 1
make_calc_column(ws, exp_data_row, 2, f'="EXP-"&TEXT(ROW()-{expenses_header_row},"00000")')
make_calc_column(ws, exp_data_row, 18,
    '=IF(COUNTIFS(tbl_ManualExpenses[Expense Date],[@[Expense Date]],tbl_ManualExpenses[Supplier],[@Supplier],tbl_ManualExpenses[Amount],[@Amount])>1,"Possible Duplicate","")')

add_dropdown(ws, f"D{exp_data_row}:D501", "LookupExpenseCategory", "Expense Category",
             "Choose from the Expense Category list on 15_Settings.")
add_dropdown(ws, f"E{exp_data_row}:E501", "LookupExpenseSubcategory", "Expense Subcategory",
             "Choose from the Expense Subcategory list on 15_Settings.")
add_dropdown(ws, f"F{exp_data_row}:F501", "SupplierNameList", "Supplier",
             "Choose from Supplier Master (12_Suppliers). Leave blank if this expense has no supplier.")
add_dropdown(ws, f"H{exp_data_row}:H501", "LookupCurrency", "Currency",
             "Choose from the Currency list on 15_Settings.")
add_dropdown(ws, f"I{exp_data_row}:I501", "LookupPaymentMethod", "Payment Method",
             "Choose from the Payment Method list on 15_Settings.")
add_dropdown(ws, f"J{exp_data_row}:J501", "CollectionTitleList", "Related Collection (optional)",
             "Choose a live Shopify collection, or leave blank.")
add_dropdown(ws, f"K{exp_data_row}:K501", "SKUList", "Related SKU (optional)",
             "Choose a live Shopify SKU, or leave blank.")
add_dropdown(ws, f"L{exp_data_row}:L501", "LookupCostCenter", "Cost Center",
             "Choose from the Cost Center list on 15_Settings.")

freeze_below_header(ws)
protect_ws(ws)
ws.sheet_properties.tabColor = TAB_COLOR["input"]

# ============================================================================
# 11_Capital — manual-entry sheet (green) — Phase 3: Owner/Transaction Type lookups
# ============================================================================
ws = wb.create_sheet("11_Capital")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3, 14, 12, 14, 20, 14, 30, 14, 16])
title_bar(ws, "Capital", last_col=9)
row = doc_block(
    ws,
    "Tracks owner capital contributions and withdrawals, and the resulting owner-equity position.",
    "15_Settings lookup tables (Owner, Capital Transaction Type).",
    "FACT_CapitalTransactions (Data Model-ready hidden mirror).",
    "The only source that grows/shrinks Capital Invested and Owner Equity in future financial calculations. Owner and Transaction Type are both configurable lookups on 15_Settings, not hardcoded.",
    "This IS the source — no external system. Manual entry only.",
    last_col=9,
)
row, _ = add_kpi_row(ws, row, ["Capital Invested", "Owner Withdrawals", "Net Owner Equity", "YTD Movement"], col_start=2, card_width=2)
row += 1
ws.cell(row=row, column=2, value="CAPITAL TRANSACTIONS  (green cells = type here — Capital ID and Possible Duplicate are automatic)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
capital_header_row = row
row = add_table(
    ws, "tbl_CapitalTransactions", row, 2,
    ["Capital ID", "Date", "Owner", "Transaction Type", "Amount", "Notes", "Entered By", "Possible Duplicate"],
    "input",
    example_row=["", "2026-01-01", "Founder", "Capital Contribution", 50000,
                 "EXAMPLE — founder capital injection", "Founder", ""],
)
capital_data_row = capital_header_row + 1
make_calc_column(ws, capital_data_row, 2, f'="CAP-"&TEXT(ROW()-{capital_header_row},"00000")')
make_calc_column(ws, capital_data_row, 9,
    '=IF(COUNTIFS(tbl_CapitalTransactions[Date],[@Date],tbl_CapitalTransactions[Owner],[@Owner],tbl_CapitalTransactions[Amount],[@Amount])>1,"Possible Duplicate","")')

add_dropdown(ws, f"D{capital_data_row}:D501", "LookupOwner", "Owner",
             "Choose from the Owner list on 15_Settings.")
add_dropdown(ws, f"E{capital_data_row}:E501", "LookupCapitalTransactionType", "Transaction Type",
             "Capital Contribution or Capital Withdrawal — from the list on 15_Settings.")

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
    ["3.0", "2026-07-26", "Phase 3 — Business Master Data & Manual-Entry Engine",
     "Product Cost Master with historical/versioned costing (05_Products). Complete Manual Expenses module: category/subcategory lookups, duplicate-flag column, document references (10_Expenses). Capital module (11_Capital). Expanded Supplier Master + full Purchase Order engine — Header/Lines/Goods Receipt with a Draft-to-Closed status workflow (12_Suppliers). Every dropdown sourced from an editable lookup table on 15_Settings — no hardcoded values — with input prompts and stop-on-error messages. SKU/Collection dropdowns reference the live Shopify RAW_ tables, not a separate manual list. New hidden Data-Model-ready mirrors: DIM_Supplier, DIM_ProductCostHistory, FACT_CapitalTransactions, FACT_PurchaseOrderHeader, FACT_PurchaseOrderLines, FACT_GoodsReceipt. See /passress-mis/PHASE3_DOCUMENTATION.md. Still no dashboards, PivotTables, DAX, or financial statements."],
    ["4.0", "2026-07-26", "Phase 4 — Financial Calculation Engine (Data Model + DAX)",
     "Completed the RAW_/manual-table -> star-schema transformation layer Phase 1 sketched but Phase 2-3 left empty (power-query/star-schema/, 18 M files): DIM_Date (generated calendar, fiscal-year aware), DIM_Product/Customer/Location/Collection/Supplier/ProductCostHistory, and every FACT_ table, including historically-correct COGS resolved per order line via fn_GetEffectiveCost (SKU + order date -> the Product Cost Master row active on that date, never today's cost). Full DAX measure library (dax/MEASURES.md): P&L, Balance Sheet, Cash Flow, Product Profitability, Customer Metrics (incl. cohorts), Inventory Metrics, Executive KPIs, and a full time-intelligence layer (MTD/QTD/YTD/previous period/SPLY/rolling 30-90-365) applied to the headline measures with the reusable pattern documented for extending to any other. Built as composable base measures referenced by name from composite ones — no duplicated calculations. Reconciliation section validates Balance Sheet (Assets=Liabilities+Equity), Cash Position (direct vs. indirect), Net Sales (FACT vs. RAW Shopify totals), and refund/cost-coverage integrity. Accounts Payable is a documented proxy (no payment-status field exists yet — flagged, not silently assumed). See /passress-mis/dax/README.md and MEASURES.md. Still no dashboards, PivotTables, PivotCharts, or KPI cards."],
]
tbl_version_log_top_row = row
row = add_table(
    ws, "tbl_VersionLog", row, 2,
    ["Version", "Date", "Phase", "Summary"],
    "calc",
    data_rows=VERSION_LOG_ROWS,
)
row += 1

# --- Master data lookup tables (Phase 3) -----------------------------------
# Every dropdown elsewhere in the workbook sources its list from one of these
# tables via a named range — never a hardcoded Excel list. Add/remove rows
# here and every dropdown that uses it updates automatically.
ws.cell(row=row, column=2, value="MASTER DATA LOOKUP TABLES  (orange cells = configurable — edit freely, every dropdown in the workbook reads from here)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1

LOOKUPS = [
    ("tbl_LookupExpenseCategory", "Expense Category", "LookupExpenseCategory",
     ["Rent", "Utilities", "Salaries", "Marketing", "Shipping & Logistics", "Packaging",
      "Software & Subscriptions", "Professional Fees", "Bank Charges", "Other"]),
    ("tbl_LookupExpenseSubcategory", "Expense Subcategory", "LookupExpenseSubcategory",
     ["General", "Office", "Warehouse", "Online Ads", "Influencer", "Photography", "Courier",
      "Customs & Duties", "Software License", "Legal", "Accounting", "Other"]),
    ("tbl_LookupCostCenter", "Cost Center", "LookupCostCenter",
     ["Head Office", "Warehouse", "E-Commerce", "Marketing", "Production"]),
    ("tbl_LookupPaymentMethod", "Payment Method", "LookupPaymentMethod",
     ["Bank Transfer", "Cash", "Credit Card", "Instapay", "Cheque", "Other"]),
    ("tbl_LookupCurrency", "Currency", "LookupCurrency", ["EGP", "USD", "EUR", "GBP"]),
    ("tbl_LookupSupplierType", "Supplier Type", "LookupSupplierType",
     ["Fabric", "Accessories", "Manufacturing", "Packaging", "Logistics",
      "Marketing Agency", "Software Vendor", "Other"]),
    ("tbl_LookupSupplierStatus", "Supplier Status", "LookupSupplierStatus",
     ["Active", "Inactive", "On Hold"]),
    ("tbl_LookupCapitalTransactionType", "Capital Transaction Type", "LookupCapitalTransactionType",
     ["Capital Contribution", "Capital Withdrawal"]),
    ("tbl_LookupPOStatus", "PO Status", "LookupPOStatus",
     ["Draft", "Approved", "Sent", "Partially Received", "Received", "Closed", "Cancelled"]),
    ("tbl_LookupWarehouse", "Warehouse", "LookupWarehouse",
     ["Main Warehouse", "Retail Store", "Third-Party Logistics"]),
    ("tbl_LookupOwner", "Owner", "LookupOwner", ["Founder"]),
]
for table_name, header, list_name, values in LOOKUPS:
    row = add_lookup_table(ws, table_name, row, 2, header, values, list_name=list_name)

freeze_below_header(ws)
protect_ws(ws)
ws.sheet_properties.tabColor = TAB_COLOR["report"]


# ============================================================================
# 12_Suppliers — manual-entry sheet (green) — Phase 3: Supplier Master +
# complete Purchase Order engine (Header / Lines / Goods Receipt)
# ============================================================================
ws = wb.create_sheet("12_Suppliers")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3] + [14, 20, 14, 14, 22, 10, 16, 12, 26])
title_bar(ws, "Suppliers", last_col=10)
row = doc_block(
    ws,
    "Supplier master data and the complete purchasing engine: Purchase Order Header, Purchase Order Lines, and Goods Receipt, with a Draft-through-Closed status workflow.",
    "15_Settings lookup tables (Supplier Type, Supplier Status, Currency, PO Status, Warehouse), RAW_Variants (live Shopify SKUs).",
    "DIM_Supplier, FACT_PurchaseOrderHeader, FACT_PurchaseOrderLines, FACT_GoodsReceipt (Data Model-ready hidden mirrors).",
    "PO Lines and Goods Receipt both key on PO Number (from PO Header) and SKU (from the live Shopify variant list), not a separate manual product list. Goods Receipt's Remaining Quantity and Variance from PO are computed by looking up PO Lines for the same PO Number + SKU.",
    "This IS the source today. Candidate for supplier-portal or accounting-system integration later (see Future Integrations in the Phase 0 architecture).",
    last_col=10,
)
row, _ = add_kpi_row(ws, row, ["Active Suppliers", "Open POs", "Purchases YTD", "Outstanding Receipts"], col_start=2, card_width=2)
row += 1

# --- Supplier Master --------------------------------------------------------
ws.cell(row=row, column=2, value="SUPPLIER MASTER  (green cells = type here — Supplier ID is automatic)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
supplier_header_row = row
row = add_table(
    ws, "tbl_SupplierMaster", row, 2,
    ["Supplier ID", "Supplier Name", "Supplier Type", "Contact Person", "Phone", "Email",
     "Currency", "Payment Terms", "Status", "Notes"],
    "input",
    example_row=["", "EXAMPLE — ABC Textiles", "Fabric", "Mona Ahmed", "+20 100 000 0000",
                 "contact@example.com", "EGP", "Net 30", "Active", ""],
)
supplier_data_row = supplier_header_row + 1
make_calc_column(ws, supplier_data_row, 2, f'="SUP-"&TEXT(ROW()-{supplier_header_row},"00000")')
add_dropdown(ws, f"D{supplier_data_row}:D501", "LookupSupplierType", "Supplier Type",
             "Choose from the Supplier Type list on 15_Settings.")
add_dropdown(ws, f"H{supplier_data_row}:H501", "LookupCurrency", "Currency",
             "Choose from the Currency list on 15_Settings.")
add_dropdown(ws, f"J{supplier_data_row}:J501", "LookupSupplierStatus", "Status",
             "Choose from the Supplier Status list on 15_Settings.")
NAMED_LIST_RANGES.append(("SupplierNameList", "tbl_SupplierMaster", "Supplier Name"))
row += 1

# --- Purchase Order Header ---------------------------------------------------
ws.cell(row=row, column=2, value="PURCHASE ORDER HEADER  (green cells = type here — PO Number is automatic)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
poh_header_row = row
row = add_table(
    ws, "tbl_POHeader", row, 2,
    ["PO Number", "Supplier", "Order Date", "Expected Delivery Date", "Status", "Currency", "Notes"],
    "input",
    example_row=["", "EXAMPLE — ABC Textiles", "2026-01-10", "2026-01-24", "Draft", "EGP", ""],
)
poh_data_row = poh_header_row + 1
make_calc_column(ws, poh_data_row, 2, f'="PO-"&TEXT(ROW()-{poh_header_row},"00000")')
add_dropdown(ws, f"C{poh_data_row}:C501", "SupplierNameList", "Supplier",
             "Choose from Supplier Master (this sheet, above).")
add_dropdown(ws, f"F{poh_data_row}:F501", "LookupPOStatus", "Status",
             "Draft → Approved → Sent → Partially Received → Received → Closed, or Cancelled at any point.")
add_dropdown(ws, f"G{poh_data_row}:G501", "LookupCurrency", "Currency",
             "Choose from the Currency list on 15_Settings.")
NAMED_LIST_RANGES.append(("POHeaderList", "tbl_POHeader", "PO Number"))
row += 1

# --- Purchase Order Lines ----------------------------------------------------
ws.cell(row=row, column=2, value="PURCHASE ORDER LINES  (green cells = type here — Total Cost is automatic)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
pol_header_row = row
row = add_table(
    ws, "tbl_POLines", row, 2,
    ["PO Number", "SKU", "Quantity Ordered", "Unit Cost", "Total Cost"],
    "input",
    example_row=["", "", 50, 120, ""],
)
pol_data_row = pol_header_row + 1
make_calc_column(ws, pol_data_row, 6, '=[@[Quantity Ordered]]*[@[Unit Cost]]')
add_dropdown(ws, f"B{pol_data_row}:B501", "POHeaderList", "PO Number",
             "Choose an existing PO Number from Purchase Order Header, above.")
add_dropdown(ws, f"C{pol_data_row}:C501", "SKUList", "SKU",
             "Choose a live Shopify SKU.")
row += 1

# --- Goods Receipt ------------------------------------------------------------
ws.cell(row=row, column=2, value="GOODS RECEIPT  (green cells = type here — Remaining Quantity and Variance from PO are automatic)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
gr_header_row = row
row = add_table(
    ws, "tbl_GoodsReceipt", row, 2,
    ["PO Number", "SKU", "Goods Received Date", "Quantity Received", "Remaining Quantity",
     "Actual Unit Cost", "Variance from PO", "Warehouse", "Receiver"],
    "input",
    example_row=["", "", "2026-01-20", 30, "", 122, "", "Main Warehouse", ""],
)
gr_data_row = gr_header_row + 1
make_calc_column(ws, gr_data_row, 6,
    '=SUMIFS(tbl_POLines[Quantity Ordered],tbl_POLines[PO Number],[@[PO Number]],tbl_POLines[SKU],[@SKU])'
    '-SUMIFS(tbl_GoodsReceipt[Quantity Received],tbl_GoodsReceipt[PO Number],[@[PO Number]],tbl_GoodsReceipt[SKU],[@SKU])')
make_calc_column(ws, gr_data_row, 8,
    '=[@[Actual Unit Cost]]-SUMIFS(tbl_POLines[Unit Cost],tbl_POLines[PO Number],[@[PO Number]],tbl_POLines[SKU],[@SKU])')
add_dropdown(ws, f"B{gr_data_row}:B501", "POHeaderList", "PO Number",
             "Choose an existing PO Number from Purchase Order Header, above.")
add_dropdown(ws, f"C{gr_data_row}:C501", "SKUList", "SKU",
             "Choose a live Shopify SKU.")
add_dropdown(ws, f"I{gr_data_row}:I501", "LookupWarehouse", "Warehouse",
             "Choose from the Warehouse list on 15_Settings.")

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

# Phase 3 dropdowns (10_Expenses Related SKU/Collection, 05_Products Product
# Cost Master, 12_Suppliers PO Lines/Goods Receipt) source their lists
# directly from the live Shopify staging tables, not a separate manual list —
# this is what keeps master data integrated with the Shopify Data Model.
NAMED_LIST_RANGES.append(("SKUList", "tbl_RAW_Variants", "SKU"))
NAMED_LIST_RANGES.append(("CollectionTitleList", "tbl_RAW_Collections", "Title"))

DIM_SHEETS = [
    dict(code="DIM_Date", pq="star-schema/DIM_Date.pq",
         headers=["DateKey", "Date", "Year", "FiscalYear", "Quarter", "Month", "MonthName",
                   "Week", "Day", "DayName", "IsWeekend"]),
    dict(code="DIM_Product", pq="star-schema/DIM_Product.pq",
         headers=["ProductKey", "ProductID", "SKU", "Title", "ProductType", "Vendor",
                   "Collection", "UnitCost", "Status"]),
    dict(code="DIM_Customer", pq="star-schema/DIM_Customer.pq",
         headers=["CustomerKey", "CustomerID", "Name", "Email", "Country",
                   "FirstOrderDate", "CustomerSegment"]),
    dict(code="DIM_Location", pq="star-schema/DIM_Location.pq",
         headers=["LocationKey", "LocationID", "LocationName", "City", "Country"]),
    dict(code="DIM_Collection", pq="star-schema/DIM_Collection.pq",
         headers=["CollectionKey", "CollectionID", "Title", "Handle"]),
    dict(code="DIM_Parameters", headers=["ParameterName", "ParameterValue"]),
    # --- Phase 3 additions: mirrors of new manual master-data sheets ---
    dict(code="DIM_Supplier", mirror_of="12_Suppliers (Supplier Master table)", pq="star-schema/DIM_Supplier.pq",
         headers=["SupplierKey", "SupplierID", "SupplierName", "SupplierType", "Currency", "Status"]),
    dict(code="DIM_ProductCostHistory", mirror_of="05_Products (Product Cost Master table)", pq="star-schema/DIM_ProductCostHistory.pq",
         headers=["CostKey", "SKU", "Collection", "TotalLandedCost", "SellingPrice", "ExpectedGrossMarginPct",
                   "EffectiveFromDate", "EffectiveToDate", "ActiveFlag"]),
]
for s in DIM_SHEETS:
    is_params = s["code"] == "DIM_Parameters"
    mirror_of = s.get("mirror_of")
    pq = s.get("pq")
    build_hidden_sheet(
        s["code"], "dim",
        purpose=(
            "Disconnected mirror of 15_Settings, used so DAX measures can reference configurable "
            "constants without creating a relationship into the star schema."
            if is_params else
            f"Data Model-ready mirror of {mirror_of}, time-variant (Effective From/To + Active Flag preserved) "
            "so Phase 4 can join each order line to the cost that was active on the order's date."
            if mirror_of == "05_Products (Product Cost Master table)" else
            f"Data Model-ready mirror of {mirror_of}."
            if mirror_of else
            f"Dimension table for the star schema — describes the '{s['code'].replace('DIM_', '')}' entity that FACT_ tables relate to."
        ),
        inputs=(
            "15_Settings (linked manually / via Power Query, Phase 2)." if is_params else
            f"{mirror_of.split(' (')[0]}'s master-data table." if mirror_of else
            "RAW_ staging table(s) built in Phase 2."
        ),
        outputs="Referenced by DAX measures across all dashboards." if is_params else "Related to FACT_ tables in the Data Model (one-to-many).",
        relationships=(
            "N/A — disconnected table by design." if is_params else
            "SKU relates to FACT_OrderLines; EffectiveFromDate/EffectiveToDate bound which cost row applies to a given order date via fn_GetEffectiveCost (Power Query), not a Data Model relationship — see dax/README.md."
            if s["code"] == "DIM_ProductCostHistory" else
            "SupplierID relates to FACT_ManualExpenses/FACT_PurchaseOrderHeader; PrimarySupplierID on DIM_Product relates back here (one-to-many)." if s["code"] == "DIM_Supplier" else
            "One-to-many into the relevant FACT_ table(s) on this dimension's key column — see dax/README.md for the full relationship list."
        ),
        future_source=(
            "Manual link to 15_Settings — Phase 3." if is_params else
            f"Live now: paste passress-mis/power-query/{pq} — see passress-mis/dax/README.md for setup order." if pq else
            "Built from RAW_ staging data in Power Query — Phase 2/3."
        ),
        headers=s["headers"],
    )

FACT_SHEETS = [
    dict(code="FACT_OrderLines", category="calc", pq="star-schema/FACT_OrderLines.pq",
         headers=["OrderLineKey", "OrderID", "DateKey", "ProductKey", "CustomerKey", "LocationKey",
                   "Quantity", "UnitPrice", "GrossAmount", "DiscountAmount", "TaxAmount", "NetAmount",
                   "UnitCost", "COGS", "MissingCostFlag"]),
    dict(code="FACT_Refunds", category="calc", pq="star-schema/FACT_Refunds.pq",
         headers=["RefundKey", "OrderLineKey", "DateKey", "Quantity", "RefundAmount"]),
    dict(code="FACT_InventoryMovements", category="calc", pq="star-schema/FACT_InventoryMovements.pq",
         headers=["MovementKey", "DateKey", "ProductKey", "LocationKey", "MovementType", "QuantityChange",
                   "ResultingOnHand"]),
    dict(code="FACT_Payments", category="calc", pq="star-schema/FACT_Payments.pq",
         headers=["PaymentKey", "OrderID", "DateKey", "PaymentMethod", "Currency", "Amount",
                   "PresentmentAmount"]),
    dict(code="FACT_ManualExpenses", category="input", mirror_of="10_Expenses", pq="star-schema/FACT_ManualExpenses.pq",
         headers=["ExpenseKey", "DateKey", "ExpenseDate", "ExpenseCategory", "ExpenseSubcategory", "SupplierID",
                   "Amount", "Currency", "PaymentMethod", "RelatedCollection", "RelatedSKU", "CostCenter",
                   "InvoiceNumber"]),
    # --- Phase 3 additions: mirrors of new manual master-data sheets ---
    dict(code="FACT_CapitalTransactions", category="input", mirror_of="11_Capital", pq="star-schema/FACT_CapitalTransactions.pq",
         headers=["CapitalKey", "DateKey", "Date", "Owner", "TransactionType", "Amount"]),
    dict(code="FACT_PurchaseOrderHeader", category="input", mirror_of="12_Suppliers (PO Header table)", pq="star-schema/FACT_PurchaseOrderHeader.pq",
         headers=["PONumber", "DateKey", "SupplierID", "OrderDate", "ExpectedDeliveryDate", "Status", "Currency"]),
    dict(code="FACT_PurchaseOrderLines", category="input", mirror_of="12_Suppliers (PO Lines table)", pq="star-schema/FACT_PurchaseOrderLines.pq",
         headers=["PONumber", "SKU", "QuantityOrdered", "UnitCost", "TotalCost"]),
    dict(code="FACT_GoodsReceipt", category="input", mirror_of="12_Suppliers (Goods Receipt table)", pq="star-schema/FACT_GoodsReceipt.pq",
         headers=["PONumber", "DateKey", "SKU", "GoodsReceivedDate", "QuantityReceived", "RemainingQuantity",
                   "ActualUnitCost", "VarianceFromPO", "Warehouse"]),
]
for s in FACT_SHEETS:
    manual = s["category"] == "input"
    mirror_of = s.get("mirror_of", "10_Expenses")
    pq = s.get("pq")
    ws = wb.create_sheet(s["code"])
    ws.sheet_view.showGridLines = False
    set_col_widths(ws, [3] + [16] * len(s["headers"]))
    title_bar(ws, s["code"], last_col=len(s["headers"]) + 1)
    row = doc_block(
        ws,
        (f"Manually entered fact, kept structurally separate from Shopify-sourced facts. Mirrors the input "
         f"table(s) on {mirror_of} — this is the Data Model-ready version of it."
         if manual else
         f"Fact table for the star schema — transaction-level grain, built from RAW_ staging data plus dimension keys via Power Query (not re-fetched from Shopify)."),
        f"{mirror_of} manual entry table(s)." if manual else "RAW_ staging tables + DIM_ key lookups.",
        "Referenced by DAX measures — see passress-mis/dax/MEASURES.md.",
        "Grain matches its source table on the visible sheet, one-for-one." if manual else "Many-to-one into each related DIM_ table — see dax/README.md for the full relationship list.",
        f"Live now: paste passress-mis/power-query/{pq} — see passress-mis/dax/README.md for setup order." if pq else "Built in Power Query from RAW_ + DIM_ — Phase 2/3.",
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

for name, table, column in NAMED_LIST_RANGES:
    wb.defined_names[name] = DefinedName(name, attr_text=f"={table}[{column}]")

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
    "named_list_ranges": [{"name": n, "table": t, "column": c} for n, t, c in NAMED_LIST_RANGES],
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
print(f"Named ranges: {len(NAMED_RANGES)} single-cell + {len(NAMED_LIST_RANGES)} list/table")
