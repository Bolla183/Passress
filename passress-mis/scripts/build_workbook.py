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
from openpyxl.chart import LineChart, BarChart, Reference
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
    "marketing": "8064A2",  # Phase 5: purple, distinguishes "not connected yet" placeholders from live RAW_ (blue)
    "bi": "31859B",         # Phase 5: teal, system-generated BI outputs (Insights/Alerts/Forecast)
    "future": "BFBFBF",     # Phase 5: light gray, reserved/unimplemented
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


def title_bar(ws, text, last_col=10, is_home=False):
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=last_col)
    c = ws.cell(row=1, column=1, value=text)
    c.font = f(size=18, bold=True, color=C["white"])
    c.fill = fill(C["black"])
    c.alignment = Alignment(vertical="center", horizontal="left", indent=1)
    ws.row_dimensions[1].height = 34

    # Breadcrumb doubles as "Back to Home" (Phase 5, item 7) — clicking
    # anywhere on this row jumps to 01_Home, except on Home itself.
    ws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=last_col)
    b = ws.cell(row=2, column=1, value=("PASSRESS MIS   |   Home ▸ " + text) if not is_home else "PASSRESS MIS   |   Home")
    b.font = f(size=9, italic=True, color=C["text_gray"] if not is_home else C["white"])
    b.fill = fill(C["light_gray"] if not is_home else C["dark_gray"])
    b.alignment = Alignment(vertical="center", horizontal="left", indent=1)
    if not is_home:
        b.hyperlink = "#'01_Home'!A1"
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


# --------------------------------------------- Phase 5: BI application layer --
# CUBEVALUE/CUBESET/CUBERANKEDMEMBER read the Data Model directly into plain
# cells — no PivotTable/PivotCache required, so these are real openpyxl-
# writable formulas (unlike Slicers, which need a PivotTable to attach to and
# have no reliable openpyxl write support). They only RESOLVE once the Data
# Model + DAX measures from dax/README.md are wired up in Excel — until then
# they display 0/blank, which is expected, not an error.
CUBE_CONN = "ThisWorkbookDataModel"


def cube_measure(measure_name):
    """CUBEVALUE formula pulling one DAX measure, unfiltered (grand total)."""
    return f'=CUBEVALUE("{CUBE_CONN}","[Measures].[{measure_name}]")'


def add_cube_kpi_row(ws, row, labels_measures, col_start=2, card_width=2, numfmt="#,##0", height_rows=3):
    """Dark-gray KPI cards wired to real CUBEVALUE formulas (Phase 5) instead
    of Phase 1-3's static '—' placeholders. labels_measures: list of
    (label, measure_name) or (label, measure_name, numfmt_override) tuples —
    the 3rd element is optional, falling back to the row-level numfmt.
    Returns (next_free_row, next_free_col)."""
    col = col_start
    top = row
    bottom = row + height_rows - 1
    for item in labels_measures:
        label, measure_name = item[0], item[1]
        card_numfmt = item[2] if len(item) > 2 else numfmt
        left, right = col, col + card_width - 1
        ws.merge_cells(start_row=top, start_column=left, end_row=top, end_column=right)
        lab = ws.cell(row=top, column=left, value=label.upper())
        lab.font = f(size=8, bold=True, color=C["med_gray"])
        lab.alignment = Alignment(vertical="bottom", horizontal="left", indent=1)

        ws.merge_cells(start_row=top + 1, start_column=left, end_row=bottom, end_column=right)
        val = ws.cell(row=top + 1, column=left, value=cube_measure(measure_name))
        val.font = f(size=20, bold=True, color=C["white"])
        val.alignment = Alignment(vertical="center", horizontal="left", indent=1)
        val.number_format = card_numfmt
        val.protection = Protection(locked=True)

        for rr in range(top, bottom + 1):
            for cc in range(left, right + 1):
                ws.cell(row=rr, column=cc).fill = fill(C["kpi_fill"])
        ws.row_dimensions[top].height = 15
        col += card_width
    for rr in range(top + 1, bottom + 1):
        ws.row_dimensions[rr].height = 22
    return bottom + 2, col


def add_cube_trend_table(ws, top_row, top_col, measure_name, n_months=12, label="Trend"):
    """Builds a hidden-ish helper table (Month label row + CUBEVALUE row) that
    a native openpyxl chart can reference. DIM_Date must be marked as the
    Data Model's date table (dax/README.md, Step 3) for the month math here
    to line up with what the measure actually returns.
    Returns (table_top_row, table_bottom_row, first_col, last_col)."""
    ws.cell(row=top_row, column=top_col, value=label).font = f(size=8, bold=True, color=C["text_gray"])
    month_row, value_row = top_row + 1, top_row + 2
    for i in range(n_months):
        col = top_col + 1 + i
        # Month label, oldest to newest, computed from TODAY() so the table
        # stays current on every open — matches Rolling 12 Months' window.
        label_formula = f'=TEXT(EDATE(TODAY(),{-(n_months - 1 - i)}),"mmm-yy")'
        lc = ws.cell(row=month_row, column=col, value=label_formula)
        lc.font = f(size=8, color=C["text_gray"])
        lc.number_format = "@"
        vc = ws.cell(row=value_row, column=col, value=(
            f'=CUBEVALUE("{CUBE_CONN}","[Measures].[{measure_name}]",'
            f'"[DIM_Date].[Year].&["&YEAR(EDATE(TODAY(),{-(n_months - 1 - i)}))&"]",'
            f'"[DIM_Date].[Month].&["&MONTH(EDATE(TODAY(),{-(n_months - 1 - i)}))&"]")'
        ))
        vc.font = f(size=8, color=C["calc_body"])
        vc.number_format = "#,##0"
    return top_row, value_row, top_col + 1, top_col + n_months


def add_drill_link(ws, row, col, label, target_sheet):
    """Phase 6, item 7: Drill-through Experience. A real hyperlink from a
    KPI/section to the existing sheet that shows its supporting detail — the
    documented path is Revenue Card -> Monthly Sales (04_Sales) -> Order
    Details -> Order Lines -> Customer -> Product; true interactive
    OLAP-style drill-through (right-click a PivotTable cell > Show Details)
    needs real PivotTables, which don't exist yet (a Phase 7+ capability
    once Phase 6's Data Model is used to build them). This link-based
    version is the honest, buildable version of that same navigation intent
    today, and costs nothing to upgrade later — the target sheets don't
    change, only how you reach them does."""
    cell = ws.cell(row=row, column=col, value=f"↓ Drill into {target_sheet.split('_', 1)[1].replace('_', ' ')}")
    cell.font = f(size=8, italic=True, color=C["text_gray"])
    cell.hyperlink = f"#'{target_sheet}'!A1"
    return row + 1


def set_print_friendly(ws, last_col=12, last_row=90):
    """Phase 5, item 11: 'printable to PDF without breaking' — landscape,
    fit-to-width, a defined print area so PDF export doesn't spill columns
    across extra pages or cut off mid-KPI-card."""
    ws.page_setup.orientation = "landscape"
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0
    ws.sheet_properties.pageSetUpPr = PageSetupProperties(fitToPage=True)
    ws.print_area = f"A1:{get_column_letter(last_col)}{last_row}"
    ws.page_margins.left = ws.page_margins.right = 0.3
    ws.page_margins.top = ws.page_margins.bottom = 0.4


def add_native_line_chart(ws, anchor_cell, title, cats_ref, data_ref, height_cm=6, width_cm=16):
    chart = LineChart()
    chart.title = title
    chart.style = 2
    chart.y_axis.majorGridlines = None
    chart.height = height_cm
    chart.width = width_cm
    chart.add_data(data_ref, titles_from_data=False)
    chart.set_categories(cats_ref)
    if chart.series:
        chart.series[0].graphicalProperties.line.solidFill = C["black"]
        chart.series[0].graphicalProperties.line.width = 20000
        chart.series[0].smooth = False
    chart.legend = None
    ws.add_chart(chart, anchor_cell)
    return chart


def add_native_multiseries_line_chart(ws, anchor_cell, title, cats_ref, data_ref, series_names, height_cm=7, width_cm=17):
    """Same mechanism as add_native_line_chart, generalized to N series in
    one chart (e.g. P&L Trend: Net Sales / Operating Expenses / Net Profit
    together) — data_ref must span one row per series, from_rows=True tells
    openpyxl to read it that way rather than one series per column."""
    chart = LineChart()
    chart.title = title
    chart.style = 2
    chart.y_axis.majorGridlines = None
    chart.height = height_cm
    chart.width = width_cm
    chart.add_data(data_ref, titles_from_data=False, from_rows=True)
    chart.set_categories(cats_ref)
    line_colors = [C["black"], C["shopify_body"], C["input_body"]]
    for i, s in enumerate(chart.series):
        s.graphicalProperties.line.solidFill = line_colors[i % len(line_colors)]
        s.graphicalProperties.line.width = 18000
        s.smooth = False
    from openpyxl.chart.series import SeriesLabel
    for i, name in enumerate(series_names):
        if i < len(chart.series):
            chart.series[i].tx = SeriesLabel(v=name)
    chart.legend.position = "b"
    ws.add_chart(chart, anchor_cell)
    return chart


def add_native_bar_chart(ws, anchor_cell, title, cats_ref, data_ref, height_cm=7, width_cm=17):
    """Same mechanism as add_native_line_chart with openpyxl's BarChart
    instead of LineChart — a ranked list (e.g. Top 10 Products) reads
    better as bars than as a line, and BarChart is just as natively
    writable by openpyxl as LineChart already was."""
    chart = BarChart()
    chart.type = "col"
    chart.title = title
    chart.style = 10
    chart.y_axis.majorGridlines = None
    chart.height = height_cm
    chart.width = width_cm
    chart.add_data(data_ref, titles_from_data=False)
    chart.set_categories(cats_ref)
    if chart.series:
        chart.series[0].graphicalProperties.solidFill = C["dark_gray"]
    chart.legend = None
    ws.add_chart(chart, anchor_cell)
    return chart


def add_cube_top_n(ws, top_row, top_col, title, dim_table, dim_attribute, measure_name, n=5, ascending=False):
    """CUBESET + CUBERANKEDMEMBER + CUBEVALUE: a live 'Top N by measure' list
    with no PivotTable — e.g. Top 5 best-selling products. ascending=True for
    a 'bottom N' / declining list instead."""
    ws.cell(row=top_row, column=top_col, value=title).font = f(size=10, bold=True, color=C["text_gray"])
    order = "BASC" if ascending else "BDESC"
    set_formula = (
        f'=CUBESET("{CUBE_CONN}","{{[{dim_table}].[{dim_attribute}].Children}}","{title}",'
        f'"{order}","[Measures].[{measure_name}]")'
    )
    set_cell = ws.cell(row=top_row, column=top_col + 4, value=set_formula)
    set_cell.font = f(size=7, color=C["med_gray"])
    set_ref = f"${get_column_letter(top_col + 4)}${top_row}"
    for i in range(n):
        r = top_row + 1 + i
        name_formula = f'=CUBERANKEDMEMBER("{CUBE_CONN}",{set_ref},{i + 1})'
        val_formula = f'=CUBEVALUE("{CUBE_CONN}","[Measures].[{measure_name}]",CUBERANKEDMEMBER("{CUBE_CONN}",{set_ref},{i + 1}))'
        nc = ws.cell(row=r, column=top_col, value=name_formula)
        nc.font = f(size=9, color=style_calc_font())
        vc = ws.cell(row=r, column=top_col + 2, value=val_formula)
        vc.font = f(size=9, color=style_calc_font())
        vc.number_format = "#,##0"
    return top_row + n + 1


def style_calc_font():
    return CATEGORY_STYLE["calc"]["body_font"]


# ============================================================================
# Phase 8: completing 04/05/06/07/08/09/13's placeholder KPI cards, charts,
# and "PivotTable" detail sections using ONLY existing DAX measures and the
# existing CUBEVALUE/CUBESET/CUBERANKEDMEMBER mechanism Phase 5 established
# (no PivotTables were ever writable via openpyxl — that hasn't changed).
# Three small additions to that same mechanism, not a new architecture:
# ============================================================================

def add_cube_rank1_name(ws, helper_row, helper_col, dim_table, dim_attribute, measure_name, ascending=False, label="Set"):
    """Writes a CUBESET helper cell (ordered by an existing measure) and
    returns a CUBERANKEDMEMBER formula string for its rank-1 member — e.g.
    'Best Seller' as a single name, not a ranked list. Same fix pattern as
    BI_Insights' INS-06/07 (Phase 7): CUBERANKEDMEMBER against a raw
    unordered set has no defined rank-1 member, so the CUBESET helper cell
    (which DOES support ordering) is required, not optional."""
    order = "BASC" if ascending else "BDESC"
    set_formula = (
        f'=CUBESET("{CUBE_CONN}","{{[{dim_table}].[{dim_attribute}].Children}}","{label}",'
        f'"{order}","[Measures].[{measure_name}]")'
    )
    cell = ws.cell(row=helper_row, column=helper_col, value=set_formula)
    cell.font = f(size=7, color=C["med_gray"])
    set_ref = f"${get_column_letter(helper_col)}${helper_row}"
    return f'=CUBERANKEDMEMBER("{CUBE_CONN}",{set_ref},1)'


def add_cube_breakdown_table(ws, top_row, top_col, title, dim_table, dim_attribute, measures, n=8, ascending=False, order_measure=None):
    """Generalizes add_cube_top_n to more than one measure column — the
    'PivotTable' substitute for a dimension-by-measure(s) breakdown (Sales
    by Product, Margin by Collection, Stock by Location, etc.). Same three
    CUBE functions, same single-shared-CUBESET-per-table pattern, just N
    value columns instead of 1. measures: list of (label, measure_name,
    numfmt) — numfmt optional, defaults to '#,##0'. order_measure defaults
    to the first measure in the list. Returns next free row."""
    ws.cell(row=top_row, column=top_col, value=title).font = f(size=10, bold=True, color=C["text_gray"])
    header_row = top_row + 1
    dim_header = ws.cell(row=header_row, column=top_col, value=dim_attribute)
    dim_header.font = f(size=8, bold=True, color=C["white"])
    dim_header.fill = fill(CATEGORY_STYLE["calc"]["header_fill"])
    for j, m in enumerate(measures):
        mlabel = m[0]
        hc = ws.cell(row=header_row, column=top_col + 1 + j, value=mlabel)
        hc.font = f(size=8, bold=True, color=C["white"])
        hc.fill = fill(CATEGORY_STYLE["calc"]["header_fill"])

    order_by = order_measure or measures[0][1]
    order = "BASC" if ascending else "BDESC"
    helper_col = top_col + 1 + len(measures) + 2
    set_formula = (
        f'=CUBESET("{CUBE_CONN}","{{[{dim_table}].[{dim_attribute}].Children}}","{title}",'
        f'"{order}","[Measures].[{order_by}]")'
    )
    set_cell = ws.cell(row=top_row, column=helper_col, value=set_formula)
    set_cell.font = f(size=7, color=C["med_gray"])
    set_ref = f"${get_column_letter(helper_col)}${top_row}"

    for i in range(n):
        r = header_row + 1 + i
        member_ref = f'CUBERANKEDMEMBER("{CUBE_CONN}",{set_ref},{i + 1})'
        nc = ws.cell(row=r, column=top_col, value=f"={member_ref}")
        nc.font = f(size=9, color=style_calc_font())
        for j, m in enumerate(measures):
            _, measure_name, *rest = m
            numfmt = rest[0] if rest else "#,##0"
            vc = ws.cell(row=r, column=top_col + 1 + j,
                         value=f'=CUBEVALUE("{CUBE_CONN}","[Measures].[{measure_name}]",{member_ref})')
            vc.font = f(size=9, color=style_calc_font())
            vc.number_format = numfmt
    return header_row + n + 2


def add_statement_table(ws, top_row, top_col, title, rows):
    """P&L Statement / Cash Flow Statement 'PivotTable' substitute: every
    line is already a named, existing measure (dax/MEASURES.md §1 and §3
    literally are this table, as prose) — this just turns that documented
    map into working CUBEVALUE formulas, one per line, unfiltered
    (grand-total / all-time). rows: list of (label, measure_name, numfmt)."""
    ws.cell(row=top_row, column=top_col, value=title).font = f(size=10, bold=True, color=C["text_gray"])
    r = top_row + 1
    for label, measure_name, numfmt in rows:
        lc = ws.cell(row=r, column=top_col, value=label)
        lc.font = f(size=9, color=style_calc_font())
        vc = ws.cell(row=r, column=top_col + 2, value=cube_measure(measure_name))
        vc.font = f(size=9, bold=True, color=style_calc_font())
        vc.number_format = numfmt
        r += 1
    return r + 1


def add_gap_box(ws, row, col, width, height, item_label, reason):
    """The honest alternative to add_placeholder_box for an item that
    genuinely cannot be built from what already exists — states which
    PivotTable/chart/KPI this was meant to be AND the specific technical
    reason (missing measure, missing dimension, or a CUBE-function/MDX
    pattern that can't safely represent a 2D matrix), instead of a generic
    'not yet built.'"""
    r2, c2 = row + height - 1, col + width - 1
    ws.merge_cells(start_row=row, start_column=col, end_row=r2, end_column=c2)
    cell = ws.cell(row=row, column=col, value=f"[ {item_label} — Not implementable: {reason} ]")
    cell.font = f(size=8, italic=True, color=C["text_gray"])
    cell.fill = fill(C["light_gray"])
    cell.alignment = Alignment(vertical="center", horizontal="center", wrap_text=True)
    dashed = Side(style="dashed", color=C["border_gray"])
    box_border = Border(left=dashed, right=dashed, top=dashed, bottom=dashed)
    for rr in range(row, r2 + 1):
        for cc in range(col, c2 + 1):
            ws.cell(row=rr, column=cc).border = box_border
            if ws.cell(row=rr, column=cc).fill.fgColor.rgb in (None, "00000000"):
                ws.cell(row=rr, column=cc).fill = fill(C["light_gray"])
    return r2 + 2


def add_kpi_row_v2(ws, row, cards, col_start=2, card_width=2, height_rows=3):
    """Like add_cube_kpi_row, but each card is a dict so a card can be a
    live CUBEVALUE measure, a rank-1-name formula (add_cube_rank1_name),
    OR a genuine gap ('N/A', reason recorded for the sheet's Known Gaps
    note rather than silently blank). cards: list of dicts with keys
    label, formula (a full '=...' string, or None for a gap), numfmt
    (optional), reason (required when formula is None).
    Returns (next_free_row, next_free_col, gaps) where gaps is a list of
    (label, reason) for every card that couldn't be wired."""
    col = col_start
    top = row
    bottom = row + height_rows - 1
    gaps = []
    for card in cards:
        label = card["label"]
        formula = card.get("formula")
        numfmt = card.get("numfmt", "#,##0")
        left, right = col, col + card_width - 1
        ws.merge_cells(start_row=top, start_column=left, end_row=top, end_column=right)
        lab = ws.cell(row=top, column=left, value=label.upper())
        lab.font = f(size=8, bold=True, color=C["med_gray"])
        lab.alignment = Alignment(vertical="bottom", horizontal="left", indent=1)

        ws.merge_cells(start_row=top + 1, start_column=left, end_row=bottom, end_column=right)
        if formula is not None:
            val = ws.cell(row=top + 1, column=left, value=formula)
            val.number_format = numfmt
        else:
            val = ws.cell(row=top + 1, column=left, value="N/A")
            gaps.append((label, card["reason"]))
        val.font = f(size=20 if formula is None or numfmt != "@" else 13, bold=True, color=C["white"])
        val.alignment = Alignment(vertical="center", horizontal="left", indent=1)
        val.protection = Protection(locked=True)

        for rr in range(top, bottom + 1):
            for cc in range(left, right + 1):
                ws.cell(row=rr, column=cc).fill = fill(C["kpi_fill"])
        ws.row_dimensions[top].height = 15
        col += card_width
    for rr in range(top + 1, bottom + 1):
        ws.row_dimensions[rr].height = 22
    return bottom + 2, col, gaps


def add_known_gaps_note(ws, row, col, gaps, last_col=12):
    """Renders every KPI-card gap collected by add_kpi_row_v2 as visible
    text (not just a hover comment) — required reading item 3 of your
    instruction: every unimplemented placeholder must be documented with
    the exact technical reason, in the workbook itself, not only in a
    Python comment nobody using Excel will ever see."""
    if not gaps:
        return row
    ws.cell(row=row, column=col, value="KNOWN GAPS ON THIS SHEET  (documented, not silently missing)").font = f(size=9, bold=True, color=C["text_gray"])
    row += 1
    for label, reason in gaps:
        c = ws.cell(row=row, column=col, value=f"{label}: {reason}")
        c.font = f(size=8, italic=True, color=C["text_gray"])
        c.alignment = Alignment(wrap_text=True, vertical="top")
        ws.merge_cells(start_row=row, start_column=col, end_row=row, end_column=last_col)
        ws.row_dimensions[row].height = 24
        row += 1
    return row + 1


# ============================================================================
# 01_Home
# ============================================================================
ws = wb.create_sheet("01_Home")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3] + [14] * 11)
title_bar(ws, "PASSRESS MIS — Home", last_col=12, is_home=True)
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

# "Last Refresh" / "Data Quality" were left as static Phase 1 "—" placeholders
# through Phases 2-6 even though this sheet's own doc_block always promised
# they read LOG_RefreshHistory / LOG_DataQuality — found and wired in the
# Phase 7 production-readiness review. Both use the same LOG_RefreshHistory
# post-wiring table name convention already established for SKUList/etc.
# (see the NAMED_LIST_RANGES comment near RAW_Variants below), and
# OverallDataQualityPct is the same named range 14_Data_Quality/BI_HealthScore
# already read — reused, not recomputed.
last_refresh_cell = ws.cell(row=home_kpi_top + 1, column=2, value='=IFERROR(TEXT(MAX(LOG_RefreshHistory[Timestamp]),"dd-mmm hh:mm"),"—")')
last_refresh_cell.font = f(size=13, bold=True, color=C["white"])
last_refresh_cell.fill = fill(C["kpi_fill"])
last_refresh_cell.alignment = Alignment(vertical="center", horizontal="left", indent=1)
last_refresh_cell.protection = Protection(locked=True)

data_quality_cell = ws.cell(row=home_kpi_top + 1, column=4, value='=IFERROR(TEXT(OverallDataQualityPct,"0.0%"),"—")')
data_quality_cell.font = f(size=20, bold=True, color=C["white"])
data_quality_cell.fill = fill(C["kpi_fill"])
data_quality_cell.alignment = Alignment(vertical="center", horizontal="left", indent=1)
data_quality_cell.protection = Protection(locked=True)

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
row = start_row + ((len(nav) - 1) // per_row + 1) * 3 + 2

# --- Global Filters (Phase 5, item 8) ---------------------------------------
# Real Excel Slicers need a PivotTable/PivotCache to attach to — none exist
# yet (that's Phase 6). These filter cells are the prepared alternative:
# named ranges any CUBEVALUE formula on any dashboard can reference to build
# a filtered member expression (e.g. "[DIM_Collection].[Title].["&FilterCollection&"]"),
# so filtering stays centralized here rather than duplicated per dashboard.
# The Partner/CEO dashboards built in Phase 5 intentionally do NOT wire their
# KPI cards to these yet (unfiltered CUBEVALUE is the safer, verified-correct
# baseline) — see dax/README.md's note on why filtered CUBEVALUE needs
# spot-checking before being load-bearing. Once real PivotTables exist in
# Phase 6, native Slicers bound to these same dimensions are a straight
# upgrade path, not a redesign.
ws.cell(row=row, column=2, value="GLOBAL FILTERS  (orange cells = type or choose 'All')").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
GLOBAL_FILTERS = [
    ("Date From", "FilterDateFrom", None, "2026-01-01"),
    ("Date To", "FilterDateTo", None, "2026-12-31"),
    ("Collection", "FilterCollection", "CollectionTitleList", "All"),
    ("SKU", "FilterSKU", "SKUList", "All"),
    ("Supplier", "FilterSupplier", "SupplierNameList", "All"),
    ("Location", "FilterLocation", None, "All"),
    ("Campaign", "FilterCampaign", None, "All (reserved — see Marketing-Ready Layer, not connected yet)"),
]
filt_col = 2
for label, rng_name, list_name, default in GLOBAL_FILTERS:
    lab = ws.cell(row=row, column=filt_col, value=label)
    lab.font = f(size=8, bold=True, color=C["text_gray"])
    vc = ws.cell(row=row + 1, column=filt_col, value=default)
    vc.font = f(size=9, bold=True, color=C["settings_body"])
    vc.fill = fill(C["settings_fill"])
    vc.border = BORDER_ALL
    vc.protection = Protection(locked=False)
    NAMED_RANGES.append((rng_name, "01_Home", f"${get_column_letter(filt_col)}${row + 1}"))
    if list_name:
        add_dropdown(ws, f"{get_column_letter(filt_col)}{row + 1}", list_name, label, f"Choose a {label}, or 'All'.")
    filt_col += 2
ws.row_dimensions[row].height = 14
ws.row_dimensions[row + 1].height = 18
row += 3

# --- Reports & Tools (Phase 6) -----------------------------------------------
# RPT_ExecutiveBrief and RPT_Workflow are hidden (per Phase 6's chosen
# placement — see PHASE6_DOCUMENTATION.md), reached from here two ways:
# the hyperlink below, or manually via right-click any sheet tab > Unhide.
# Internal hyperlinks to hidden sheets are reasonably well supported in
# current Excel but weren't testable in this environment — the Unhide path
# is the guaranteed fallback if a link doesn't navigate as expected.
ws.cell(row=row, column=2, value="REPORTS & TOOLS  (hidden sheets — click to open, or right-click any tab → Unhide)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
for label, sheet_code in [("Daily Executive Brief", "RPT_ExecutiveBrief"), ("Workflow Dashboard", "RPT_Workflow")]:
    cell = ws.cell(row=row, column=2, value=f"→  {label}")
    cell.font = f(size=10, color=C["text_gray"])
    cell.hyperlink = f"#'{sheet_code}'!A1"
    ws.merge_cells(start_row=row, start_column=2, end_row=row, end_column=5)
    row += 1
row += 1

ws.cell(row=row, column=2, value=(
    "Phase 6 build. See 15_Settings' Version Log for the full phase history and roadmap. "
    "Data shown on dashboards resolves once the Data Model is wired — see power-query/README.md and dax/README.md."
)).font = f(size=9, italic=True, color=C["text_gray"])
freeze_below_header(ws)
protect_ws(ws)
ws.sheet_properties.tabColor = TAB_COLOR["nav"]


# ============================================================================
# 04/05/06/07/08/09/13 — Phase 8: completing the placeholder KPI cards,
# charts, and "PivotTable" detail sections these sheets shipped with since
# Phase 1, using only dax/MEASURES.md's existing measures and the same
# CUBEVALUE/CUBESET/CUBERANKEDMEMBER mechanism established in Phase 5.
# Explicit scope per your instruction: no new measures, no new KPIs, no
# architecture changes. Every item below is either (a) wired to an existing
# measure, (b) a CUBE-function breakdown table standing in for a real
# PivotTable (openpyxl still can't write one — that hasn't changed since
# Phase 1), or (c) left as an add_gap_box with the specific technical reason
# it can't be built from what already exists. 02_Partner_Dashboard and
# 03_CEO_Dashboard remain Phase 5's bespoke builds, below, unchanged.
# ============================================================================
DASHBOARD_END_ROW = {}

# ---------------------------------------------------------------- 04_Sales --
ws = wb.create_sheet("04_Sales")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3] + [13] * 11)
title_bar(ws, "Sales", last_col=12)
row = doc_block(
    ws,
    "Sales performance detail — orders, revenue, discounts, and returns by period, product, and channel.",
    "FACT_OrderLines, FACT_Refunds, DIM_Date, DIM_Product, DIM_Collection.",
    "Sales KPI row, Sales Trend chart (doubles as Sales by Date), Sales by Product / Sales by Collection breakdown tables (CUBE-function substitutes for a PivotTable — see dax/README.md), a link to the full Order List.",
    "FACT_OrderLines links to DIM_Date/DIM_Product/DIM_Collection; FACT_Refunds links to FACT_OrderLines.",
    "Live now: every card/table below reads dax/MEASURES.md's Gross Sales/Discounts/Returns/Net Sales measures (§0/§1) directly.",
    last_col=12,
)
row, _ = add_cube_kpi_row(ws, row, [
    ("Gross Sales", "Gross Sales"), ("Discounts", "Discounts"),
    ("Returns", "Returns"), ("Net Sales", "Net Sales"),
], col_start=2, card_width=2)
row += 1

ws.cell(row=row, column=2, value="SALES TREND / SALES BY DATE  (same Net Sales-by-month data — chart and table, not recomputed twice)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
trend_top = row
_, trend_value_row, trend_first_col, trend_last_col = add_cube_trend_table(ws, trend_top, 2, "Net Sales", n_months=12, label="Net Sales — trailing 12 months")
cats_ref = Reference(ws, min_col=trend_first_col, max_col=trend_last_col, min_row=trend_top + 1, max_row=trend_top + 1)
data_ref = Reference(ws, min_col=trend_first_col, max_col=trend_last_col, min_row=trend_value_row, max_row=trend_value_row)
add_native_line_chart(ws, f"B{trend_top + 4}", "Net Sales — Trailing 12 Months", cats_ref, data_ref, height_cm=7, width_cm=17)
row = trend_top + 20

ws.cell(row=row, column=2, value="SALES BY PRODUCT").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_cube_breakdown_table(ws, row, 2, "Sales by Product (Top 8 by Net Sales)", "DIM_Product", "Title", [("Net Sales", "Net Sales")], n=8)
row += 1

ws.cell(row=row, column=2, value="SALES BY COLLECTION").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_cube_breakdown_table(ws, row, 2, "Sales by Collection (Top 8 by Net Sales)", "DIM_Collection", "Title", [("Net Sales", "Net Sales")], n=8)
row += 1

ws.cell(row=row, column=2, value="ORDER LIST").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_gap_box(ws, row, 2, 10, 3, "Order List (Table)",
    "No Order-level dimension exists in the Data Model — CUBE functions browse dimension members (Product/Collection/Customer/Location/Date), not individual fact rows, so a row-level order list can't be built this way without adding a new Data Model object, which is out of scope (architecture frozen). The full, live order list is RAW_Orders itself, already wired once Power Query is set up.")
row = add_drill_link(ws, row, 2, "Order List", "RAW_Orders")
row += 1

freeze_below_header(ws)
protect_ws(ws)
ws.sheet_properties.tabColor = TAB_COLOR["report"]
DASHBOARD_END_ROW["04_Sales"] = row

# ------------------------------------------------------------- 05_Products --
ws = wb.create_sheet("05_Products")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3] + [13] * 11)
title_bar(ws, "Products", last_col=12)
row = doc_block(
    ws,
    "Product-level performance dashboard PLUS, as of Phase 3, the Product Cost Master — the workbook's historical/versioned SKU costing table.",
    "DIM_Product, FACT_OrderLines (dashboard). RAW_Variants, RAW_Collections (Product Cost Master dropdowns).",
    "Product KPI row, Top 10 Products chart, Product Margin breakdown table (CUBE-function substitute for a PivotTable). tbl_ProductCostMaster feeding DIM_ProductCostHistory.",
    "DIM_Product links to FACT_OrderLines on ProductKey. tbl_ProductCostMaster[SKU] links to RAW_Variants[SKU]; COGS is matched via fn_GetEffectiveCost (SKU + order date against Effective From/To Date).",
    "Live now: dashboard reads dax/MEASURES.md measures directly. Product Cost Master is manual entry — see PHASE3_DOCUMENTATION.md §1.",
    last_col=12,
)
prod_kpi_top = row
bestseller_formula = add_cube_rank1_name(ws, prod_kpi_top, 14, "DIM_Product", "Title", "Net Sales", ascending=False, label="BestSellerProduct")
row, _, gaps05 = add_kpi_row_v2(ws, row, [
    dict(label="Active SKUs", formula=None, reason="No DAX measure counts total/active SKUs — dax/MEASURES.md's Product Profitability section (§4) covers profit PER SKU via PivotTable row context, not a SKU-count aggregate. A DISTINCTCOUNT(DIM_Product[SKU]) measure doesn't exist in the library; adding one is out of this phase's reuse-only scope."),
    dict(label="Best Seller", formula=bestseller_formula, numfmt="@"),
    dict(label="Avg Margin %", formula=cube_measure("Gross Margin %"), numfmt="0.0%"),
    dict(label="Slow Movers", formula=cube_measure("Slow Moving SKU Count"), numfmt="#,##0"),
], col_start=2, card_width=2)
row += 1

ws.cell(row=row, column=2, value="TOP 10 PRODUCTS  (by Net Sales)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
top10_row = row
top10_helper_col = 14
top10_set_formula = f'=CUBESET("{CUBE_CONN}","{{[DIM_Product].[Title].Children}}","Top10Products","BDESC","[Measures].[Net Sales]")'
top10_sc = ws.cell(row=top10_row, column=top10_helper_col, value=top10_set_formula)
top10_sc.font = f(size=7, color=C["med_gray"])
top10_set_ref = f"${get_column_letter(top10_helper_col)}${top10_row}"
for i in range(10):
    r = top10_row + 1 + i
    ws.cell(row=r, column=2, value=f'=CUBERANKEDMEMBER("{CUBE_CONN}",{top10_set_ref},{i + 1})').font = f(size=9, color=style_calc_font())
    vc = ws.cell(row=r, column=4, value=f'=CUBEVALUE("{CUBE_CONN}","[Measures].[Net Sales]",CUBERANKEDMEMBER("{CUBE_CONN}",{top10_set_ref},{i + 1}))')
    vc.font = f(size=9, color=style_calc_font())
    vc.number_format = "#,##0"
top10_cats = Reference(ws, min_col=2, max_col=2, min_row=top10_row + 1, max_row=top10_row + 10)
top10_data = Reference(ws, min_col=4, max_col=4, min_row=top10_row + 1, max_row=top10_row + 10)
add_native_bar_chart(ws, f"F{top10_row}", "Top 10 Products — Net Sales", top10_cats, top10_data, height_cm=8, width_cm=15)
row = top10_row + 12

ws.cell(row=row, column=2, value="PRODUCT MARGIN").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_cube_breakdown_table(ws, row, 2, "Product Margin (Top 8 by Gross Profit)", "DIM_Product", "Title",
    [("Net Sales", "Net Sales"), ("Gross Profit", "Gross Profit"), ("Gross Margin %", "Gross Margin %", "0.0%")],
    n=8, order_measure="Gross Profit")
row += 1

ws.cell(row=row, column=2, value="VARIANT DETAIL").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_gap_box(ws, row, 2, 10, 3, "Variant Detail (PivotTable)",
    "SKU/variant attributes (Price, Compare-at Price, current Unit Cost, Status) are row-level dimension data, not aggregate measures — CUBE functions can rank/aggregate a dimension's members by a measure (used above), but can't display raw per-row attribute columns the way a real PivotTable's row area can. Full variant detail is on DIM_Product / RAW_Variants directly.")
row = add_drill_link(ws, row, 2, "Variant Detail", "DIM_Product")
row += 1
row = add_known_gaps_note(ws, row, 2, gaps05, last_col=12)

freeze_below_header(ws)
protect_ws(ws)
ws.sheet_properties.tabColor = TAB_COLOR["report"]
DASHBOARD_END_ROW["05_Products"] = row

# ------------------------------------------------------------ 06_Customers --
ws = wb.create_sheet("06_Customers")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3] + [13] * 11)
title_bar(ws, "Customers", last_col=12)
row = doc_block(
    ws,
    "Customer analytics — lifetime value, repeat-purchase rate, and geography.",
    "DIM_Customer, FACT_OrderLines.",
    "Customer KPI row, Top Customers / Geography breakdown tables (CUBE-function substitutes for a PivotTable).",
    "DIM_Customer links to FACT_OrderLines on CustomerKey.",
    "Live now: reads dax/MEASURES.md's Customer Metrics measures (§5) directly.",
    last_col=12,
)
row, _, gaps06 = add_kpi_row_v2(ws, row, [
    dict(label="Total Customers", formula=None, reason="No DAX measure counts the full customer roster — dax/MEASURES.md defines [Customers Active (Current Period)] (period-filtered) and [New Customers] (first-order-in-period), but no all-time DISTINCTCOUNT(DIM_Customer[CustomerKey]) measure exists. Mapping this card to either existing measure would misrepresent what it actually counts, so it's left undocumented rather than mislabeled."),
    dict(label="New Customers", formula=cube_measure("New Customers"), numfmt="#,##0"),
    dict(label="Repeat Rate %", formula=cube_measure("Repeat Customer % Actual"), numfmt="0.0%"),
    dict(label="Avg LTV", formula=cube_measure("Customer Lifetime Value (Historical)"), numfmt="#,##0"),
], col_start=2, card_width=2)
row += 1

ws.cell(row=row, column=2, value="COHORT TREND / COHORT TABLE").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
COHORT_GAP_REASON = ("dax/MEASURES.md §5 documents Customer Cohorts as a PivotTable LAYOUT (DIM_Customer[CohortMonth] "
    "on rows, DIM_Date[MonthName]/[Year] on columns), not a single measure — it is inherently a 2-dimensional "
    "matrix. CUBE functions here rank a single dimension by a single measure (used everywhere else on this "
    "sheet); reproducing a true cohort matrix would need nested CUBESET/CUBEVALUE expressions per cohort-month "
    "x calendar-month intersection — the same class of advanced, execution-untestable MDX pattern already "
    "flagged as a confidence risk in dax/README.md and the Phase 5/6 documentation. Not attempted rather than "
    "shipped unverified.")
row = add_gap_box(ws, row, 2, 10, 4, "Cohort Trend (Chart) / Cohort Table (PivotTable)", COHORT_GAP_REASON)
row += 1

ws.cell(row=row, column=2, value="TOP CUSTOMERS").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_cube_breakdown_table(ws, row, 2, "Top Customers (Top 8 by Net Sales)", "DIM_Customer", "Name",
    [("Net Sales", "Net Sales"), ("CLV (Historical)", "Customer Lifetime Value (Historical)")], n=8)
row += 1

ws.cell(row=row, column=2, value="GEOGRAPHY").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_cube_breakdown_table(ws, row, 2, "Geography (Net Sales by Country)", "DIM_Customer", "Country", [("Net Sales", "Net Sales")], n=10)
row += 1
row = add_known_gaps_note(ws, row, 2, gaps06, last_col=12)

freeze_below_header(ws)
protect_ws(ws)
ws.sheet_properties.tabColor = TAB_COLOR["report"]
DASHBOARD_END_ROW["06_Customers"] = row

# ------------------------------------------------------------- 07_Inventory --
ws = wb.create_sheet("07_Inventory")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3] + [13] * 11)
title_bar(ws, "Inventory", last_col=12)
row = doc_block(
    ws,
    "Stock levels, valuation, and turnover.",
    "FACT_InventoryMovements, DIM_Product, DIM_Location.",
    "Inventory KPI row, Stock Trend chart, Stock by Location / Low Stock / Inventory Valuation breakdown tables (CUBE-function substitutes for a PivotTable).",
    "FACT_InventoryMovements links to DIM_Product and DIM_Location.",
    "Live now: reads dax/MEASURES.md's Inventory Metrics measures (§6) directly.",
    last_col=12,
)
row, _, gaps07 = add_kpi_row_v2(ws, row, [
    dict(label="Inventory Value", formula=cube_measure("Inventory Value"), numfmt="#,##0"),
    dict(label="Units on Hand", formula=None, reason="No DAX measure sums on-hand units across products — dax/MEASURES.md's Inventory Metrics (§6) are all VALUE-based ([Inventory Value], [Average Inventory Value]) or RATIO-based (Turnover, Days of Inventory, Stock Coverage), never a plain unit-count aggregate of FACT_InventoryMovements[ResultingOnHand]. Adding one would be a new measure outside this phase's reuse-only scope."),
    dict(label="Inventory Turns", formula=cube_measure("Inventory Turnover"), numfmt="0.00"),
    dict(label="Stockout Risk", formula=None, reason="No DAX measure or defined threshold exists for stockout risk — dax/MEASURES.md defines Slow Moving / Dead Stock SKU Count (low or zero sales while holding stock) but nothing for the opposite risk (high sales velocity vs. low remaining stock). Building one would require inventing a new business rule (a velocity-vs-stock threshold), which this phase's 'no new KPIs' scope rules out."),
], col_start=2, card_width=2)
row += 1

ws.cell(row=row, column=2, value="STOCK TREND").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
ws.cell(row=row, column=2, value=(
    "Uses [Average Inventory Value], not [Inventory Value]: dax/MEASURES.md §6 documents that [Inventory Value] "
    "always returns the MOST RECENT snapshot regardless of any date filter — charting it by month would repeat "
    "the same 'today' figure 12 times, not show a real trend. [Average Inventory Value] is the measure "
    "specifically documented as date-filter-aware, so it's the one that actually plots a trend."
)).font = f(size=8, italic=True, color=C["text_gray"])
ws.row_dimensions[row].height = 24
row += 1
trend_top = row
_, trend_value_row, trend_first_col, trend_last_col = add_cube_trend_table(ws, trend_top, 2, "Average Inventory Value", n_months=12, label="Average Inventory Value — trailing 12 months")
cats_ref = Reference(ws, min_col=trend_first_col, max_col=trend_last_col, min_row=trend_top + 1, max_row=trend_top + 1)
data_ref = Reference(ws, min_col=trend_first_col, max_col=trend_last_col, min_row=trend_value_row, max_row=trend_value_row)
add_native_line_chart(ws, f"B{trend_top + 4}", "Average Inventory Value — Trailing 12 Months", cats_ref, data_ref, height_cm=7, width_cm=17)
row = trend_top + 20

ws.cell(row=row, column=2, value="STOCK BY LOCATION").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_cube_breakdown_table(ws, row, 2, "Stock by Location (Inventory Value)", "DIM_Location", "LocationName", [("Inventory Value", "Inventory Value")], n=10)
row += 1

ws.cell(row=row, column=2, value="LOW STOCK LIST").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
ws.cell(row=row, column=2, value="Ranked by Inventory Value, ascending — a unit-count 'low stock' measure doesn't exist (see Units on Hand, above); Inventory Value ascending is the closest existing-measure proxy for 'what's running low.'").font = f(size=8, italic=True, color=C["text_gray"])
ws.row_dimensions[row].height = 24
row += 1
row = add_cube_breakdown_table(ws, row, 2, "Low Stock List (Bottom 8 by Inventory Value)", "DIM_Product", "Title", [("Inventory Value", "Inventory Value")], n=8, ascending=True)
row += 1

ws.cell(row=row, column=2, value="INVENTORY VALUATION").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_cube_breakdown_table(ws, row, 2, "Inventory Valuation (Top 8 Products by Inventory Value)", "DIM_Product", "Title", [("Inventory Value", "Inventory Value")], n=8)
row += 1
row = add_known_gaps_note(ws, row, 2, gaps07, last_col=12)

freeze_below_header(ws)
protect_ws(ws)
ws.sheet_properties.tabColor = TAB_COLOR["report"]
DASHBOARD_END_ROW["07_Inventory"] = row

# --------------------------------------------------------------- 08_Finance --
ws = wb.create_sheet("08_Finance")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3] + [13] * 11)
title_bar(ws, "Finance", last_col=12)
row = doc_block(
    ws,
    "Core management-basis financial statements — Profit & Loss and Cash Flow summary (not audited books).",
    "FACT_OrderLines, FACT_ManualExpenses, FACT_Payments, Chart of Accounts mapping (15_Settings).",
    "Finance KPI row, P&L Trend chart, P&L Statement and Cash Flow Statement (CUBE-function substitutes for a PivotTable, transcribing dax/MEASURES.md §1/§3's own documented measure maps into working formulas).",
    "Combines Shopify-sourced facts with manually entered FACT_ManualExpenses, categorized via the Chart of Accounts mapping table.",
    "Live now: every line reads an existing dax/MEASURES.md measure directly.",
    last_col=12,
)
row, _ = add_cube_kpi_row(ws, row, [
    ("Net Sales", "Net Sales"), ("Total Expenses", "Operating Expenses"),
    ("Net Profit", "Net Profit"), ("Cash Balance", "Cash Position (Direct, Cumulative)"),
], col_start=2, card_width=2)
row += 1

ws.cell(row=row, column=2, value="P&L TREND  (Net Sales / Operating Expenses / Net Profit)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
pnl_month_row = row + 1
PNL_SERIES = [("Net Sales", "Net Sales"), ("Operating Expenses", "Operating Expenses"), ("Net Profit", "Net Profit")]
pnl_n_months = 12
for i in range(pnl_n_months):
    col = 3 + i
    lc = ws.cell(row=pnl_month_row, column=col, value=f'=TEXT(EDATE(TODAY(),{-(pnl_n_months - 1 - i)}),"mmm-yy")')
    lc.font = f(size=8, color=C["text_gray"])
    lc.number_format = "@"
for s_idx, (s_label, s_measure) in enumerate(PNL_SERIES):
    vrow = pnl_month_row + 1 + s_idx
    ws.cell(row=vrow, column=2, value=s_label).font = f(size=8, color=C["text_gray"])
    for i in range(pnl_n_months):
        col = 3 + i
        vc = ws.cell(row=vrow, column=col, value=(
            f'=CUBEVALUE("{CUBE_CONN}","[Measures].[{s_measure}]",'
            f'"[DIM_Date].[Year].&["&YEAR(EDATE(TODAY(),{-(pnl_n_months - 1 - i)}))&"]",'
            f'"[DIM_Date].[Month].&["&MONTH(EDATE(TODAY(),{-(pnl_n_months - 1 - i)}))&"]")'
        ))
        vc.font = f(size=8, color=C["calc_body"])
        vc.number_format = "#,##0"
pnl_cats_ref = Reference(ws, min_col=3, max_col=2 + pnl_n_months, min_row=pnl_month_row, max_row=pnl_month_row)
pnl_data_ref = Reference(ws, min_col=3, max_col=2 + pnl_n_months, min_row=pnl_month_row + 1, max_row=pnl_month_row + len(PNL_SERIES))
add_native_multiseries_line_chart(ws, f"B{pnl_month_row + len(PNL_SERIES) + 2}", "P&L Trend — Trailing 12 Months", pnl_cats_ref, pnl_data_ref, [s[0] for s in PNL_SERIES], height_cm=8, width_cm=17)
row = pnl_month_row + len(PNL_SERIES) + 20

ws.cell(row=row, column=2, value="P&L STATEMENT").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_statement_table(ws, row, 2, "P&L Statement (dax/MEASURES.md §1)", [
    ("Gross Sales", "Gross Sales", "#,##0"),
    ("Discounts", "Discounts", "#,##0"),
    ("Returns", "Returns", "#,##0"),
    ("Net Sales", "Net Sales", "#,##0"),
    ("COGS", "COGS", "#,##0"),
    ("Gross Profit", "Gross Profit", "#,##0"),
    ("Gross Margin %", "Gross Margin %", "0.0%"),
    ("Operating Expenses", "Operating Expenses", "#,##0"),
    ("EBITDA", "EBITDA", "#,##0"),
    ("Net Profit", "Net Profit", "#,##0"),
])
row += 1

ws.cell(row=row, column=2, value="CASH FLOW STATEMENT").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_statement_table(ws, row, 2, "Cash Flow Statement (dax/MEASURES.md §3)", [
    ("Cash Flow from Operating Activities", "Cash Flow from Operating Activities", "#,##0"),
    ("Cash Flow from Investing Activities", "Cash Flow from Investing Activities", "#,##0"),
    ("Cash Flow from Financing Activities", "Cash Flow from Financing Activities", "#,##0"),
    ("Net Cash Flow", "Net Cash Flow", "#,##0"),
    ("Cash Position (Direct, Cumulative)", "Cash Position (Direct, Cumulative)", "#,##0"),
])
row += 1

freeze_below_header(ws)
protect_ws(ws)
ws.sheet_properties.tabColor = TAB_COLOR["report"]
DASHBOARD_END_ROW["08_Finance"] = row

# --------------------------------------------------------- 09_Profitability --
ws = wb.create_sheet("09_Profitability")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3] + [13] * 11)
title_bar(ws, "Profitability", last_col=12)
row = doc_block(
    ws,
    "Margin analysis — gross margin and profitability by product and collection.",
    "FACT_OrderLines, DIM_Product, DIM_Collection.",
    "Profitability KPI row, Margin Trend chart, Margin by Product / Margin by Collection breakdown tables (CUBE-function substitutes for a PivotTable).",
    "FACT_OrderLines carries both revenue and COGS at line grain, enabling margin by any dimension.",
    "Live now: reads dax/MEASURES.md's Gross Margin %/Gross Profit measures directly.",
    last_col=12,
)
prof_kpi_top = row
best_margin_formula = add_cube_rank1_name(ws, prof_kpi_top, 14, "DIM_Product", "ProductType", "Gross Margin %", ascending=False, label="BestMarginCategory")
worst_margin_formula = add_cube_rank1_name(ws, prof_kpi_top + 1, 14, "DIM_Product", "ProductType", "Gross Margin %", ascending=True, label="WorstMarginCategory")
row, _, gaps09 = add_kpi_row_v2(ws, row, [
    dict(label="Gross Margin %", formula=cube_measure("Gross Margin %"), numfmt="0.0%"),
    dict(label="Contribution Margin %", formula=None, reason="dax/MEASURES.md doesn't define a Contribution Margin % measure — [Gross Margin %] (Net Sales less COGS) is a different, already-defined concept from Contribution Margin (Net Sales less variable costs only, excluding fixed costs), and Operating Expenses aren't split into fixed/variable in this model. Mapping this card to Gross Margin % would mislabel an existing measure as something it isn't, so it's left undocumented instead."),
    dict(label="Best Margin Category", formula=best_margin_formula, numfmt="@"),
    dict(label="Worst Margin Category", formula=worst_margin_formula, numfmt="@"),
], col_start=2, card_width=2)
row += 1
ws.cell(row=row, column=2, value="\"Category\" = Shopify's ProductType field (DIM_Product[ProductType]) — the workbook has no separate Category dimension. Same ranking caveat as BI_Insights' Best/Weakest Seller: a low-volume ProductType can rank first/last on a thin sample.").font = f(size=8, italic=True, color=C["text_gray"])
ws.row_dimensions[row].height = 24
row += 1

ws.cell(row=row, column=2, value="MARGIN TREND").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
trend_top = row
_, trend_value_row, trend_first_col, trend_last_col = add_cube_trend_table(ws, trend_top, 2, "Gross Margin %", n_months=12, label="Gross Margin % — trailing 12 months")
for c in range(trend_first_col, trend_last_col + 1):
    ws.cell(row=trend_value_row, column=c).number_format = "0.0%"
cats_ref = Reference(ws, min_col=trend_first_col, max_col=trend_last_col, min_row=trend_top + 1, max_row=trend_top + 1)
data_ref = Reference(ws, min_col=trend_first_col, max_col=trend_last_col, min_row=trend_value_row, max_row=trend_value_row)
add_native_line_chart(ws, f"B{trend_top + 4}", "Gross Margin % — Trailing 12 Months", cats_ref, data_ref, height_cm=7, width_cm=17)
row = trend_top + 20

ws.cell(row=row, column=2, value="MARGIN BY PRODUCT").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_cube_breakdown_table(ws, row, 2, "Margin by Product (Top 8 by Gross Profit)", "DIM_Product", "Title",
    [("Gross Profit", "Gross Profit"), ("Gross Margin %", "Gross Margin %", "0.0%")], n=8, order_measure="Gross Profit")
row += 1

ws.cell(row=row, column=2, value="MARGIN BY COLLECTION").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_cube_breakdown_table(ws, row, 2, "Margin by Collection (Top 8 by Gross Profit)", "DIM_Collection", "Title",
    [("Gross Profit", "Gross Profit"), ("Gross Margin %", "Gross Margin %", "0.0%")], n=8, order_measure="Gross Profit")
row += 1
row = add_known_gaps_note(ws, row, 2, gaps09, last_col=12)

freeze_below_header(ws)
protect_ws(ws)
ws.sheet_properties.tabColor = TAB_COLOR["report"]
DASHBOARD_END_ROW["09_Profitability"] = row

# -------------------------------------------------------------- 13_Marketing --
ws = wb.create_sheet("13_Marketing")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3] + [13] * 11)
title_bar(ws, "Marketing", last_col=12)
row = doc_block(
    ws,
    "Campaign and discount-code performance tracking; future home for ad-spend ROAS once integrated.",
    "DIM_Collection, FACT_OrderLines (discount amounts). Future: FACT_MarketingSpend.",
    "Marketing KPI row, Discount Trend chart. Campaign Performance / Discount Code Usage remain undocumented gaps (no Campaign dimension in the Data Model).",
    "FACT_OrderLines[DiscountAmount] rolls up via the existing [Discounts] measure.",
    "Live now: Total Discount Given / Discount Trend read dax/MEASURES.md's [Discounts] directly. Meta/TikTok Ads API — future integration, still not connected (Marketing-Ready Layer, Phase 5).",
    last_col=12,
)
row, _, gaps13 = add_kpi_row_v2(ws, row, [
    dict(label="Total Discount Given", formula=cube_measure("Discounts"), numfmt="#,##0"),
    dict(label="Active Campaigns", formula=None, reason="No Campaign dimension exists in the Data Model — the Marketing-Ready Layer (RAW_MetaAds/RAW_GoogleAds/etc., FACT_MarketingSpend) is reserved but deliberately not connected (no API wired, per Phase 5's explicit scope), so there's no campaign data to count."),
    dict(label="Discount Rate %", formula=None, reason="No DAX measure defines a discount-rate ratio — [Discounts] and [Gross Sales] both exist individually, but DIVIDE([Discounts],[Gross Sales]) as a named, reusable measure isn't in dax/MEASURES.md or its addenda. Adding one would be a new measure outside this phase's reuse-only scope, even though both inputs it would combine already exist."),
    dict(label="ROAS (future)", formula=None, reason="Documented as a future metric since this card's own label was written (Phase 1) — ROAS needs ad spend data from the unconnected Marketing-Ready Layer, same root cause as Active Campaigns above. dax/PHASE5_MEASURES_ADDENDUM.md's KPI Targets section states this explicitly: the target is ready and editable, there's no Actual to compare it against yet."),
], col_start=2, card_width=2)
row += 1

ws.cell(row=row, column=2, value="DISCOUNT TREND").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
trend_top = row
_, trend_value_row, trend_first_col, trend_last_col = add_cube_trend_table(ws, trend_top, 2, "Discounts", n_months=12, label="Discounts — trailing 12 months")
cats_ref = Reference(ws, min_col=trend_first_col, max_col=trend_last_col, min_row=trend_top + 1, max_row=trend_top + 1)
data_ref = Reference(ws, min_col=trend_first_col, max_col=trend_last_col, min_row=trend_value_row, max_row=trend_value_row)
add_native_line_chart(ws, f"B{trend_top + 4}", "Discounts — Trailing 12 Months", cats_ref, data_ref, height_cm=7, width_cm=17)
row = trend_top + 20

ws.cell(row=row, column=2, value="CAMPAIGN PERFORMANCE / DISCOUNT CODE USAGE").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
MARKETING_GAP_REASON = ("No Campaign dimension exists (Active Campaigns' reason above applies identically). "
    "Discount Code Usage specifically: RAW_Discounts (Power Query staging) holds discount-code data, but it was "
    "never built into the star schema in Phase 4 — no DIM_/FACT_ table, no Data Model relationship, no DAX "
    "measure reads it. It's real, wired data (once Power Query is set up) but not reachable from the Data Model "
    "this sheet's other cards depend on.")
row = add_gap_box(ws, row, 2, 10, 4, "Campaign Performance (PivotTable) / Discount Code Usage (PivotTable)", MARKETING_GAP_REASON)
row = add_drill_link(ws, row, 2, "Discount Code Data", "RAW_Discounts")
row += 1
row = add_known_gaps_note(ws, row, 2, gaps13, last_col=12)

freeze_below_header(ws)
protect_ws(ws)
ws.sheet_properties.tabColor = TAB_COLOR["report"]
DASHBOARD_END_ROW["13_Marketing"] = row


# ============================================================================
# 02_Partner_Dashboard — Phase 5 bespoke build: "simple, beautiful, minimal,
# no operational details" per the brief. Exactly 5 KPI cards, one trend
# chart, a live Top-5 list, and Key Insights pulled from BI_Insights — no
# more. Row/column math for the BI_Insights references below mirrors that
# sheet's own construction order (documented there); if BI_Insights' layout
# ever changes, these references need updating too.
# ============================================================================
ws = wb.create_sheet("02_Partner_Dashboard")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3] + [13] * 11)
title_bar(ws, "Partner Dashboard", last_col=12)
row = doc_block(
    ws,
    "Executive view for business partners — the headline numbers only, no operational drill-down. Simple, beautiful, minimal by design.",
    "The Data Model (dax/MEASURES.md, dax/PHASE5_MEASURES_ADDENDUM.md) via CUBEVALUE/CUBESET — no PivotTable required.",
    "5 KPI cards, one 12-month trend chart, a live Top 5 Products list, Key Insights (from BI_Insights).",
    "Reads the Data Model directly; BI_Insights supplies the insight text shown here.",
    "Already live: every number resolves once the Data Model + measures are wired — see power-query/README.md and dax/README.md. Until then, cards show 0 and the chart is flat — expected, not an error.",
    last_col=12,
)
row, _ = add_cube_kpi_row(ws, row, [
    ("Revenue", "Net Sales"), ("Net Profit", "Net Profit"), ("Margin %", "Gross Margin %", "0.0%"),
    ("Cash Position", "Cash Position (Direct, Cumulative)"), ("Orders", "Order Count"),
], col_start=2, card_width=2)
row = add_drill_link(ws, row, 2, "Revenue", "04_Sales")
row += 1

ws.cell(row=row, column=2, value="MONTHLY TREND — NET SALES").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
trend_top = row
_, trend_value_row, trend_first_col, trend_last_col = add_cube_trend_table(ws, trend_top, 2, "Net Sales", n_months=12, label="Net Sales — trailing 12 months")
cats_ref_p = Reference(ws, min_col=trend_first_col, max_col=trend_last_col, min_row=trend_top + 1, max_row=trend_top + 1)
data_ref_p = Reference(ws, min_col=trend_first_col, max_col=trend_last_col, min_row=trend_value_row, max_row=trend_value_row)
add_native_line_chart(ws, f"B{trend_top + 4}", "Net Sales — Trailing 12 Months", cats_ref_p, data_ref_p, height_cm=7, width_cm=17)
row = trend_top + 20

ws.cell(row=row, column=2, value="TOP 5 PRODUCTS  (by Net Sales)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_cube_top_n(ws, row, 2, "Top 5 Products", "DIM_Product", "Title", "Net Sales", n=5, ascending=False)
row += 1

ws.cell(row=row, column=2, value="KEY INSIGHTS").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
# Curated subset (Sales, Margin, Cash, best-seller) — not all 8 BI_Insights
# rows, per "no operational details." References BI_Insights' own layout:
# InsightText lives in column D, rows 15-22 for INS-01..INS-08 (see that
# sheet's build code for the row-math derivation).
KEY_INSIGHT_ROWS = [15, 16, 19, 20]  # INS-01 Sales, INS-02 Margin, INS-05 Cash, INS-06 Best seller
for i, src_row in enumerate(KEY_INSIGHT_ROWS):
    r = row + i
    bullet = ws.cell(row=r, column=2, value=f"=\"•  \"&IFERROR('BI_Insights'!D{src_row},\"(resolves once Data Model is wired)\")")
    bullet.font = f(size=9, color=C["text_gray"])
    bullet.alignment = Alignment(wrap_text=True, vertical="top")
    ws.merge_cells(start_row=r, start_column=2, end_row=r, end_column=11)
    ws.row_dimensions[r].height = 16
row += len(KEY_INSIGHT_ROWS) + 1

freeze_below_header(ws)
protect_ws(ws)
set_print_friendly(ws, last_col=12, last_row=140)
ws.sheet_properties.tabColor = TAB_COLOR["dashboard"]


# ============================================================================
# 03_CEO_Dashboard — Phase 5 bespoke build: the richer management view.
# Section headers group Financial / Customer / Inventory / Sales /
# Profitability / Expense / Budget / Forecast / Alerts / Insights, each its
# own KPI-card row or small reference table — nothing crammed onto one row.
# BI_Alerts/BI_Forecast row references mirror those sheets' own construction
# order (documented there) the same way 02_Partner_Dashboard's does.
# ============================================================================
ws = wb.create_sheet("03_CEO_Dashboard")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3] + [13] * 11)
title_bar(ws, "CEO Dashboard", last_col=12)
row = doc_block(
    ws,
    "Management view: every KPI category, Budget/Forecast/Alerts summaries, and Business Insights — the full operational picture, unlike Partner Dashboard's deliberately minimal set.",
    "The Data Model (dax/MEASURES.md, dax/PHASE5_MEASURES_ADDENDUM.md) via CUBEVALUE; BI_Alerts, BI_Forecast, BI_Insights for their respective sections.",
    "9 KPI-card sections + Budget/Forecast/Alerts/Insights reference tables.",
    "Reads the Data Model directly for KPI cards; reads BI_Alerts/BI_Forecast/BI_Insights directly (simple cell references, not re-derived CUBE formulas) for those three sections.",
    "Already live: every number resolves once the Data Model + measures are wired — see power-query/README.md and dax/README.md.",
    last_col=12,
)

CEO_SECTIONS = [
    ("FINANCIAL KPIs", [("Net Sales", "Net Sales"), ("Gross Profit", "Gross Profit"), ("Net Profit", "Net Profit"), ("Cash Position", "Cash Position (Direct, Cumulative)")]),
    ("SALES KPIs", [("Order Count", "Order Count"), ("Average Order Value", "Average Order Value", "#,##0"), ("Units Sold", "Units Sold"), ("Revenue Growth % YoY", "Revenue Growth % (YoY)", "0.0%")]),
    ("CUSTOMER KPIs", [("New Customers", "New Customers"), ("Returning Customers", "Returning Customers"), ("CLV (Historical)", "Customer Lifetime Value (Historical)"), ("Retention Rate (MoM)", "Customer Retention Rate (MoM)", "0.0%")]),
    ("INVENTORY KPIs", [("Inventory Value", "Inventory Value"), ("Inventory Turnover", "Inventory Turnover", "0.00"), ("Days of Inventory", "Days of Inventory", "0"), ("Slow Moving SKUs", "Slow Moving SKU Count", "0")]),
    ("PROFITABILITY", [("Gross Margin %", "Gross Margin %", "0.0%"), ("Net Profit Margin %", "Net Profit Margin %", "0.0%"), ("Break-Even Net Sales", "Break-Even Net Sales")]),
    ("EXPENSE ANALYSIS", [("Operating Expenses", "Operating Expenses"), ("Expense Ratio %", "Operating Expense Ratio %", "0.0%"), ("Expense Actual vs Budget", "Expense Actual vs Budget")]),
]
CEO_SECTION_DRILL_TARGETS = {
    "SALES KPIs": "04_Sales", "CUSTOMER KPIs": "06_Customers",
    "INVENTORY KPIs": "07_Inventory", "PROFITABILITY": "09_Profitability",
    "EXPENSE ANALYSIS": "10_Expenses",
}
for title, cards in CEO_SECTIONS:
    ws.cell(row=row, column=2, value=title).font = f(size=10, bold=True, color=C["text_gray"])
    row += 1
    row, _ = add_cube_kpi_row(ws, row, cards, col_start=2, card_width=2)
    if title in CEO_SECTION_DRILL_TARGETS:
        row = add_drill_link(ws, row, 2, title, CEO_SECTION_DRILL_TARGETS[title])
    row += 1

# --- Budget summary (reads DAX Actual-vs-Budget measures directly) --------
ws.cell(row=row, column=2, value="BUDGET  (Actual vs Budget, current period)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
budget_summary_row = row
BUDGET_ROWS = [
    ("Revenue", "Net Sales", "Revenue Budget (Period)", "Revenue Actual vs Budget"),
    ("Expense", "Operating Expenses", "Expense Budget (Period)", "Expense Actual vs Budget"),
    ("Purchasing", "Cash Paid for Purchases", "Purchasing Budget (Period)", "Purchasing Actual vs Budget"),
    ("Profit", "Net Profit", "Profit Budget (Period)", "Profit Actual vs Budget"),
]
for i, h in enumerate(["Category", "Actual", "Budget", "Variance"]):
    c = ws.cell(row=budget_summary_row, column=2 + i, value=h)
    c.font = f(size=9, bold=True, color=C["white"])
    c.fill = fill(CATEGORY_STYLE["calc"]["header_fill"])
    c.border = BORDER_ALL
for i, (cat, actual_m, budget_m, var_m) in enumerate(BUDGET_ROWS):
    r = budget_summary_row + 1 + i
    vals = [cat, cube_measure(actual_m), cube_measure(budget_m), cube_measure(var_m)]
    for j, v in enumerate(vals):
        cell = ws.cell(row=r, column=2 + j, value=v)
        cell.font = f(size=9, color=CATEGORY_STYLE["calc"]["body_font"])
        cell.fill = fill(CATEGORY_STYLE["calc"]["body_fill"])
        cell.border = BORDER_ALL
        if j > 0:
            cell.number_format = "#,##0"
row = budget_summary_row + len(BUDGET_ROWS) + 2

# --- Forecast summary (direct cell references into BI_Forecast) -----------
ws.cell(row=row, column=2, value="FORECAST  (next period, rolling linear trend — see BI_Forecast)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
forecast_summary_row = row
for i, h in enumerate(["Metric", "Forecast (Next Month)"]):
    c = ws.cell(row=forecast_summary_row, column=2 + i, value=h)
    c.font = f(size=9, bold=True, color=C["white"])
    c.fill = fill(CATEGORY_STYLE["calc"]["header_fill"])
    c.border = BORDER_ALL
# BI_Forecast!E37..E41 = Sales/Expenses/Profit/Inventory/Cash — see that
# sheet's build code for the row-math derivation.
for i, (metric, src_row) in enumerate([("Sales", 37), ("Expenses", 38), ("Profit", 39), ("Inventory", 40), ("Cash", 41)]):
    r = forecast_summary_row + 1 + i
    ws.cell(row=r, column=2, value=metric).font = f(size=9, color=CATEGORY_STYLE["calc"]["body_font"])
    vc = ws.cell(row=r, column=3, value=f"='BI_Forecast'!E{src_row}")
    vc.font = f(size=9, color=CATEGORY_STYLE["calc"]["body_font"])
    vc.number_format = "#,##0"
row = forecast_summary_row + 7

# --- Alerts summary (direct cell references into BI_Alerts) ---------------
ws.cell(row=row, column=2, value="ALERTS  (see 14_Data_Quality and BI_Alerts for full detail)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
alerts_summary_row = row
for i, h in enumerate(["Alert", "Status", "Severity"]):
    c = ws.cell(row=alerts_summary_row, column=2 + i, value=h)
    c.font = f(size=9, bold=True, color=C["white"])
    c.fill = fill(CATEGORY_STYLE["calc"]["header_fill"])
    c.border = BORDER_ALL
# BI_Alerts!B15..B26 = AlertName, E15..E26 = Status(live formula), F15..F26
# = Severity — see that sheet's build code for the row-math derivation.
for i in range(12):
    r = alerts_summary_row + 1 + i
    src = 15 + i
    ws.cell(row=r, column=2, value=f"='BI_Alerts'!B{src}").font = f(size=9, color=CATEGORY_STYLE["calc"]["body_font"])
    ws.cell(row=r, column=3, value=f"='BI_Alerts'!E{src}").font = f(size=9, color=CATEGORY_STYLE["calc"]["body_font"])
    ws.cell(row=r, column=4, value=f"='BI_Alerts'!F{src}").font = f(size=9, color=CATEGORY_STYLE["calc"]["body_font"])
row = alerts_summary_row + 14

# --- Business Insights (all 8, unlike Partner Dashboard's curated 4) ------
ws.cell(row=row, column=2, value="BUSINESS INSIGHTS").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
# BI_Insights!D15..D22 = InsightText for INS-01..INS-08 — see that sheet's
# build code for the row-math derivation.
for i in range(8):
    r = row + i
    src = 15 + i
    bullet = ws.cell(row=r, column=2, value=f"=\"•  \"&IFERROR('BI_Insights'!D{src},\"(resolves once Data Model is wired)\")")
    bullet.font = f(size=9, color=C["text_gray"])
    bullet.alignment = Alignment(wrap_text=True, vertical="top")
    ws.merge_cells(start_row=r, start_column=2, end_row=r, end_column=11)
    ws.row_dimensions[r].height = 16
row += 9

freeze_below_header(ws)
protect_ws(ws)
set_print_friendly(ws, last_col=12, last_row=140)
ws.sheet_properties.tabColor = TAB_COLOR["dashboard"]


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
# 08_Finance — Phase 5 addition: Budget Module (yearly & monthly)
# Appended below 08_Finance's Phase 1 dashboard placeholders, same pattern as
# 05_Products' Product Cost Master (Phase 3).
# ============================================================================
ws = wb["08_Finance"]
budget_row = DASHBOARD_END_ROW["08_Finance"] + 1
ws.cell(row=budget_row, column=2, value="BUDGET  (Phase 5 — green cells = type here; Budget ID is automatic)").font = f(size=12, bold=True, color=C["black"])
budget_row += 1
ws.cell(row=budget_row, column=2, value=(
    "Leave Month blank for a YEARLY budget line (the whole year's target for that Year+Category); fill in "
    "Month for a MONTHLY line. dax/MEASURES_PHASE5.md's [Budget Variance] / [Forecast vs Budget] measures "
    "match Actuals to whichever grain a report is built at."
)).font = f(size=8, italic=True, color=C["text_gray"])
ws.row_dimensions[budget_row].height = 20
budget_row += 2

budget_header_row = budget_row
budget_row = add_table(
    ws, "tbl_Budget", budget_row, 2,
    ["Budget ID", "Year", "Month", "Category", "Budget Amount", "Notes"],
    "input",
    example_row=["", 2026, "", "Revenue", 500000, "EXAMPLE — 2026 annual revenue budget"],
)
budget_data_row = budget_header_row + 1
make_calc_column(ws, budget_data_row, 2, f'="BUD-"&TEXT(ROW()-{budget_header_row},"00000")')
add_dropdown(ws, f"E{budget_data_row}:E501", "LookupBudgetCategory", "Category",
             "Revenue, Expense, Marketing, Purchasing, or Profit — from the list on 15_Settings.")

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
row, _, gaps_exp = add_kpi_row_v2(ws, row, [
    dict(label="Expenses MTD", formula=None, reason="dax/MEASURES.md's time-intelligence pattern (§8: MTD/QTD/YTD/Previous Period/SPLY/Rolling) was only instantiated for Net Sales, Gross Profit, Net Profit, and Order Count — an 'Operating Expenses MTD' measure was never written out, though the pattern to add one is documented. Adding it is a new measure, outside this phase's reuse-only scope."),
    dict(label="Expenses YTD", formula=None, reason="Same root cause as Expenses MTD above — no YTD variant of [Operating Expenses] exists in dax/MEASURES.md or its addenda."),
    dict(label="Largest Category", formula=None, reason="Expense Category is a plain text column on FACT_ManualExpenses, not a Data Model dimension (DIM_Product/DIM_Collection/DIM_Customer/DIM_Location are — Expense Category isn't among them, per dax/README.md's relationship list) — CUBESET/CUBERANKEDMEMBER, the mechanism used everywhere else on this sheet, can only rank members of an actual dimension hierarchy."),
    dict(label="Budget Variance", formula=cube_measure("Expense Actual vs Budget"), numfmt="#,##0"),
], col_start=2, card_width=2)
row += 1
row = add_known_gaps_note(ws, row, 2, gaps_exp, last_col=18)
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
row, _, gaps_cap = add_kpi_row_v2(ws, row, [
    dict(label="Capital Invested", formula=cube_measure("Capital Invested (Cumulative)"), numfmt="#,##0"),
    dict(label="Owner Withdrawals", formula=cube_measure("Capital Withdrawals (Period)"), numfmt="#,##0"),
    dict(label="Net Owner Equity", formula=cube_measure("Equity"), numfmt="#,##0"),
    dict(label="YTD Movement", formula=None, reason="dax/MEASURES.md defines [Net Capital (Period)] and [Capital Invested (Cumulative)] (all-time, since inception) but no YTD-specific variant — the §8 time-intelligence pattern (TOTALYTD, etc.) was only instantiated for Net Sales/Gross Profit/Net Profit/Order Count, not Net Capital. Adding a 'Net Capital YTD' measure is outside this phase's reuse-only scope."),
], col_start=2, card_width=2)
row += 1
row = add_known_gaps_note(ws, row, 2, gaps_cap, last_col=9)
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
dq_kpi_top = row
row, _ = add_kpi_row(ws, row, ["Last Refresh", "Rows Loaded", "Errors Found", "Data Freshness"], col_start=2, card_width=2)

# Wired to LOG_RefreshHistory/LOG_DataQuality — left as static "—"
# placeholders through Phases 2-6 despite this sheet existing specifically
# to surface refresh health; found and wired in the Phase 7 production-
# readiness review. "Errors Found" reuses the same WARNING-status check
# already used by BI_Alerts (ALT-11) and the Refresh Failures row in
# tbl_DataQualityChecks above — not recomputed differently here.
dq_last_refresh = ws.cell(row=dq_kpi_top + 1, column=2, value='=IFERROR(TEXT(MAX(LOG_RefreshHistory[Timestamp]),"dd-mmm hh:mm"),"—")')
dq_last_refresh.font = f(size=13, bold=True, color=C["white"])
dq_last_refresh.fill = fill(C["kpi_fill"])
dq_last_refresh.alignment = Alignment(vertical="center", horizontal="left", indent=1)
dq_last_refresh.protection = Protection(locked=True)

dq_rows_loaded = ws.cell(row=dq_kpi_top + 1, column=4, value='=IFERROR(SUM(LOG_RefreshHistory[RowsLoaded]),"—")')
dq_rows_loaded.font = f(size=20, bold=True, color=C["white"])
dq_rows_loaded.fill = fill(C["kpi_fill"])
dq_rows_loaded.alignment = Alignment(vertical="center", horizontal="left", indent=1)
dq_rows_loaded.protection = Protection(locked=True)

dq_errors_found = ws.cell(row=dq_kpi_top + 1, column=6, value='=IFERROR(COUNTIF(LOG_DataQuality[Status],"WARNING*"),"—")')
dq_errors_found.font = f(size=20, bold=True, color=C["white"])
dq_errors_found.fill = fill(C["kpi_fill"])
dq_errors_found.alignment = Alignment(vertical="center", horizontal="left", indent=1)
dq_errors_found.protection = Protection(locked=True)

dq_freshness = ws.cell(row=dq_kpi_top + 1, column=8, value='=IFERROR(TODAY()-INT(MAX(LOG_RefreshHistory[Timestamp])),"—")')
dq_freshness.font = f(size=20, bold=True, color=C["white"])
dq_freshness.fill = fill(C["kpi_fill"])
dq_freshness.alignment = Alignment(vertical="center", horizontal="left", indent=1)
dq_freshness.number_format = '0" days"'
dq_freshness.protection = Protection(locked=True)
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
row += 1

# --- Data Quality Dashboard (Phase 6) ---------------------------------------
# Expands this sheet rather than replacing anything above — same
# append-below-existing-content pattern as every prior phase's additions.
# Prefers plain worksheet formulas (COUNTIFS/SUMPRODUCT against the live
# RAW_/DIM_/FACT_ tables) over CUBEVALUE wherever possible: data-quality
# checks should work as soon as Power Query is refreshed, without requiring
# the full Data Model + DAX layer to exist yet — checking your data before
# you build reports on it is the right order of operations.
set_col_widths(ws, [3, 30, 30, 16, 30, 30])
ws.cell(row=row, column=2, value="DATA QUALITY CHECKS").font = f(size=12, bold=True, color=C["black"])
row += 1
dq_header_row = row
row = add_table(
    ws, "tbl_DataQualityChecks", row, 2,
    ["Check Name", "Metric", "Result", "Status", "Notes"],
    "calc",
)
dq_data_row = dq_header_row + 1
DATA_QUALITY_CHECKS = [
    ("Missing SKU", "RAW_Variants rows with a blank SKU",
     '=COUNTIFS(RAW_Variants[SKU],"")',
     "Reused from Alerts (ALT-04) — same check, not recomputed differently here."),
    ("Missing Cost", "Order lines with no matching Product Cost Master row",
     '=CUBEVALUE("ThisWorkbookDataModel","[Measures].[Lines Missing Cost]")',
     "Reused from dax/MEASURES.md's [Lines Missing Cost] — same measure Alerts (ALT-03) reads."),
    ("Missing Supplier", "SKUs with no PrimarySupplierID (DIM_Product)",
     '=COUNTIFS(DIM_Product[PrimarySupplierID],"")',
     "PrimarySupplierID is best-effort (most recent Goods Receipt per SKU) — see DIM_Product.pq. A count here is expected for never-received SKUs, not necessarily an error."),
    ("Duplicate Orders", "OrderIDs appearing more than once in RAW_Orders",
     '=SUMPRODUCT((COUNTIF(RAW_Orders[OrderID],RAW_Orders[OrderID])>1)*1)',
     "Should always be 0 — Shopify order IDs are unique. A nonzero count means the Power Query refresh appended duplicate rows; check RAW_Orders.pq's incremental-window logic first."),
    ("Duplicate Expenses", "Manual Expenses flagged Possible Duplicate",
     '=COUNTIF(tbl_ManualExpenses[Possible Duplicate],"Possible Duplicate")',
     "Reused from Alerts (ALT-06) and Phase 3's own duplicate-flag column — not recomputed."),
    ("Products without Collection", "RAW_Products rows with blank CollectionIDs",
     '=COUNTIFS(RAW_Products[CollectionIDs],"")',
     None),
    ("Products without Images", "N/A — not computable with current data",
     '="N/A"',
     "RAW_Products.pq never fetched image data (not in Phase 2's original scope, and Phase 6 must not modify Phase 2's files) — adding an `images` field to that GraphQL query is a clean, isolated future addition, not a Phase 6 change."),
    ("Negative Inventory", "RAW_InventoryLevels rows with Available < 0",
     '=COUNTIFS(RAW_InventoryLevels[Available],"<0")',
     "Should always be 0 — a negative available count usually signals an oversell or an inventory-sync issue in Shopify itself, not a workbook bug."),
    ("Missing Customer", "RAW_Orders rows with a blank CustomerID",
     '=COUNTIFS(RAW_Orders[CustomerID],"")',
     "Expected to be nonzero for legitimate guest checkouts — a HIGH count relative to total orders is the actual signal worth investigating, not any nonzero count."),
    ("Missing Payment", "Orders in RAW_Orders with no matching transaction in RAW_Transactions",
     '=SUMPRODUCT((COUNTIF(RAW_Transactions[OrderID],RAW_Orders[OrderID])=0)*1)',
     "An anti-join count — orders that exist but have zero associated payment transactions. Should be near 0 for a store where checkout = payment."),
    ("Refresh Failures", "Refreshes with an error condition (from LOG_DataQuality)",
     '=COUNTIF(LOG_DataQuality[Status],"WARNING*")',
     "Reused from Alerts (ALT-11) — same LOG_DataQuality check, not recomputed."),
]
for i, (name, metric, formula, notes) in enumerate(DATA_QUALITY_CHECKS):
    r = dq_data_row + i
    ws.cell(row=r, column=2, value=name).font = f(size=9, color=C["calc_body"])
    ws.cell(row=r, column=3, value=metric).font = f(size=8, italic=True, color=C["text_gray"])
    rc = ws.cell(row=r, column=4, value=formula)
    rc.font = f(size=9, bold=True, color=C["calc_body"])
    is_na = "N/A" in metric
    status_formula = '="N/A"' if is_na else f'=IF(D{r}=0,"PASS","REVIEW")'
    ws.cell(row=r, column=5, value=status_formula).font = f(size=9, color=C["calc_body"])
    ws.cell(row=r, column=6, value=notes or "").font = f(size=8, italic=True, color=C["text_gray"])
    ws.row_dimensions[r].height = 26

row = dq_data_row + len(DATA_QUALITY_CHECKS) + 1

# Overall Data Quality % — share of the quantifiable checks (excludes the
# one N/A row) currently passing. Named so BI_HealthScore's Data Quality
# component can reference it without re-deriving the logic.
ws.cell(row=row, column=2, value="Overall Data Quality %").font = f(size=10, bold=True, color=C["text_gray"])
dq_pct_cell_row = row
overall_dq_formula = (
    f'=COUNTIF(E{dq_data_row}:E{dq_data_row + len(DATA_QUALITY_CHECKS) - 1},"PASS")'
    f'/(COUNTA(E{dq_data_row}:E{dq_data_row + len(DATA_QUALITY_CHECKS) - 1})-COUNTIF(E{dq_data_row}:E{dq_data_row + len(DATA_QUALITY_CHECKS) - 1},"N/A"))'
)
dq_pct_cell = ws.cell(row=row, column=3, value=overall_dq_formula)
dq_pct_cell.font = f(size=14, bold=True, color=C["calc_body"])
dq_pct_cell.number_format = "0.0%"
NAMED_RANGES.append(("OverallDataQualityPct", "14_Data_Quality", f"$C${dq_pct_cell_row}"))
row += 2

# Historical Refresh Trend — native chart against LOG_RefreshHistory's own
# growing log (Phase 2). LOG_RefreshHistory doesn't exist yet at this point
# in the script (built later, with the other LOG_/RAW_/DIM_/FACT_ sheets) —
# the chart itself is added after that, anchored back to DQ_CHART_ANCHOR_ROW.
ws.cell(row=row, column=2, value="HISTORICAL REFRESH TREND  (Rows Loaded per refresh, from LOG_RefreshHistory)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
DQ_CHART_ANCHOR_ROW = row
row += 13

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
    ["5.0", "2026-07-26", "Phase 5 — BI Application Layer (Dashboards, Insights, Alerts, Budget, Forecast)",
     "02_Partner_Dashboard and 03_CEO_Dashboard rebuilt with real content: live KPI cards, a 12-month trend chart, and a Top-5-products list, all built with CUBEVALUE/CUBESET/CUBERANKEDMEMBER formulas reading the Data Model directly — no PivotTable required, so these resolve for real once the Data Model is wired, not just placeholders. BI_Insights and BI_Alerts (new hidden BI_ sheets): CUBEVALUE-driven auto-generated business insights and operational alerts, reusing Phase 2-4's own data-quality/reconciliation logic rather than duplicating it. BI_Forecast: rolling linear-trend forecasts (Excel's native FORECAST.LINEAR) for Sales/Expenses/Profit/Inventory/Cash, with an explicit Method column so a future AI forecasting layer is a swap-in, not a redesign. KPI Targets (15_Settings) and a yearly/monthly Budget module (08_Finance) with Actual-vs-Target and Actual/Forecast-vs-Budget DAX measures (dax/PHASE5_MEASURES_ADDENDUM.md, additive to Phase 4's MEASURES.md). Marketing-Ready Layer: 6 reserved, unconnected RAW_ tables (Meta/Google Analytics/Google Ads/TikTok/Email/Influencer) plus FACT_MarketingSpend, matching Phase 1's original placeholder pattern. FUTURE_AI_Insights: a reserved, unimplemented inventory of future AI features. Every dashboard now has a clickable breadcrumb back to 01_Home (title_bar's Home link). Global Filters panel (01_Home) prepares named filter cells for future slicer-equivalent filtering; native Excel Slicers still need real PivotTables (Phase 6) to attach to. Dashboards are landscape, fit-to-width, print-area-scoped for clean PDF export. See /passress-mis/PHASE5_DOCUMENTATION.md."],
    ["6.0", "2026-07-26", "Phase 6 — Operational Excellence, Automation, Auditability, Production Readiness",
     "RPT_ExecutiveBrief (new hidden sheet, linked from 01_Home): one-page A4-printable daily brief — today's Revenue/Orders/Gross Profit/Margin, Cash Position, Inventory Value, Revenue vs Yesterday, Top 5 Products/Collections, Critical Alerts, Business Health Score, Executive Commentary — also serves as the Automated Daily Report (print-ready from the start, no separate duplicate sheet). BI_HealthScore: the master 0-100 Business Health Score, 10 weighted components (weights editable on 15_Settings' new tbl_HealthScoreWeights), Red/Amber/Green status. 14_Data_Quality expanded with 11 checks (Missing SKU/Cost/Supplier, Duplicate Orders/Expenses, Products without Collection/Images, Negative Inventory, Missing Customer/Payment, Refresh Failures — Products without Images marked N/A, honestly, since RAW_Products.pq was never extended to fetch image data and Phase 6 must not modify Phase 2), an Overall Data Quality % (named range, reused by the Health Score), and a Historical Refresh Trend chart. RPT_Workflow (new hidden sheet): Purchase Orders/Open Orders/Pending Receipts/Inventory to Receive/Supplier Status/Capital Remaining/Outstanding Expenses/Monthly Purchasing — reuses existing measures under workflow-specific labels rather than inventing new ones. DIM_Date.pq extended (additively — every existing column unchanged) with IsWorkingDay/IsHoliday/HolidayName, reading a new empty-by-default Holidays table (15_Settings) — MTD/QTD/YTD/Rolling 12/Previous Year/SPLY needed no new columns, already fully covered by Phase 4's time intelligence. Drill-through hyperlinks added from Partner/CEO Dashboard KPI sections to their detail sheets (04_Sales/06_Customers/07_Inventory/09_Profitability/10_Expenses) — link-based navigation, not true OLAP drill-through, which needs real PivotTables (Phase 7+). PRODUCTION READINESS REVIEW found and fixed 5 real bugs: SKUList/CollectionTitleList named ranges and 3 Phase 5 Alert formulas referenced Phase 1's placeholder table names (tbl_RAW_Variants, tbl_LOG_RefreshHistory, tbl_LOG_DataQuality) instead of the permanent post-Power-Query-wiring names (RAW_Variants, LOG_RefreshHistory, LOG_DataQuality) — every DAX measure already used the correct convention; only these 5 worksheet-formula references were wrong, now fixed. Full findings in /passress-mis/PHASE6_PRODUCTION_READINESS_REVIEW.md; what's new in /passress-mis/PHASE6_DOCUMENTATION.md."],
    ["7.0", "2026-07-26", "Phase 7 — Production Readiness Certification",
     "Full line-by-line review of build_workbook.py, every Power Query shared function, a representative cross-section of staging/star-schema queries, and the complete DAX measure library, against explicit correctness/performance/security criteria. Found and fixed 5 real defects: BI_Alerts ALT-10's stray placeholder-token formula (simplified, no functional change but removed a maintenance trap); 14_Data_Quality's Historical Refresh Trend chart was off-by-one, silently dropping the first logged refresh; BI_Insights' INS-06/INS-07 (Best/Weakest seller) called CUBERANKEDMEMBER against an unordered, unranked MDX set, so both insights always showed the identical arbitrary product instead of true sales-ranked results — fixed with proper CUBESET-backed ranking (BDESC/BASC by Net Sales), the same pattern used everywhere else in the workbook; 01_Home's and 14_Data_Quality's Last Refresh/Data Quality/Rows Loaded/Errors Found KPI cards were left as static Phase 1 placeholders despite their own doc_block promising live LOG_ data — wired to existing LOG_RefreshHistory/LOG_DataQuality/OverallDataQualityPct sources, no new measures. Also corrected the now-inaccurate 'Placeholder, built in Phase 4' label on 04_Sales/06_Customers/07_Inventory/09_Profitability/13_Marketing/05_Products/08_Finance's still-unbuilt generic dashboard chart/PivotTable placeholders — deliberately left unbuilt (never commissioned by any phase's brief, and wiring their KPI cards would require inventing new DAX measures outside this phase's 'no new features' scope) but the stale phase-attribution text was actively misleading and is now accurate. Four new documentation deliverables: DEPLOYMENT_GUIDE.md, OPERATIONS_MANUAL.md, TECHNICAL_DOCUMENTATION.md, and PHASE7_FINAL_ARCHITECTURE_REVIEW.md (technical debt, performance/security review, SQL Server + Power BI migration path). No architecture changes, no new dashboards or modules — additive fixes and documentation only, per this phase's explicit scope."],
    ["8.0", "2026-07-26", "Phase 8 — Placeholder Completion (Reuse-Only)",
     "Completed every remaining placeholder KPI card, chart, and 'PivotTable' substitute that could be built from the existing Power Query layer, Data Model, and DAX measure library — architecture frozen, no new measures, no new KPIs, no new dashboards, per this phase's explicit scope. 04_Sales/05_Products/06_Customers/07_Inventory/08_Finance/09_Profitability/13_Marketing rebuilt: 20 of 28 KPI cards wired to existing measures, 6 new native charts (Sales/Stock/Margin/Discount trends, a 3-series P&L Trend, a Top-10-Products bar chart), 12 CUBE-function breakdown tables standing in for a PivotTable (Sales/Margin by Product/Collection, Stock by Location, Top Customers, Geography, etc. — a new add_cube_breakdown_table helper generalizing Phase 5's add_cube_top_n to multiple measure columns, same underlying mechanism), P&L Statement and Cash Flow Statement built directly from dax/MEASURES.md §1/§3's own documented measure maps. 10_Expenses/11_Capital/12_Suppliers' own unwired KPI cards (missed by Phase 7's sweep, caught in this phase's fuller scan) also completed — 6 of 12 wired, 3 of them reusing RPT_Workflow's own existing formulas verbatim. Order List and Variant Detail (row-level detail no CUBE function can produce) linked directly to RAW_Orders/DIM_Product instead of left blank. Every remaining gap (13 KPI cards, 4 chart/pivot items) is left as a visible, specific 'Not implementable: <reason>' note in the workbook itself, not just in documentation — no existing measure covers the concept, no Data Model dimension exists for the breakdown, the data is row-level and can't be produced by a CUBE function, or (Customer Cohorts alone) the underlying data exists but a true 2D matrix needs an execution-untestable nested-MDX pattern. Full inventory in /passress-mis/PHASE8_DOCUMENTATION.md. Second full scan after all fixes: 0 static placeholder cells, 0 generic placeholder boxes remaining, all structural validation clean."],
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
    # --- Phase 5 additions ---
    ("tbl_LookupBudgetPeriod", "Budget Period", "LookupBudgetPeriod", ["Monthly", "Yearly"]),
    ("tbl_LookupBudgetCategory", "Budget Category", "LookupBudgetCategory",
     ["Revenue", "Expense", "Marketing", "Purchasing", "Profit"]),
    ("tbl_LookupAlertSeverity", "Alert Severity", "LookupAlertSeverity", ["Info", "Warning", "Critical"]),
]
for table_name, header, list_name, values in LOOKUPS:
    row = add_lookup_table(ws, table_name, row, 2, header, values, list_name=list_name)

row += 1
# --- KPI Targets (Phase 5) --------------------------------------------------
# Every dashboard's Actual-vs-Target cards read this table via
# dax/MEASURES_PHASE5.md's [<KPI> Variance] / [<KPI> Attainment %] measures
# (LOOKUPVALUE against KPIName) — edit a target here and every dashboard
# using it updates on next refresh, nothing hardcoded per-dashboard.
ws.cell(row=row, column=2, value="KPI TARGETS  (green Target Value cells = type here)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
kpi_targets_header_row = row
row = add_table(
    ws, "tbl_KPITargets", row, 2,
    ["KPI Name", "Target Value", "Unit", "Period", "Notes"],
    "input",
    data_rows=[
        ["Sales Target", 500000, "EGP", "Monthly", "Net Sales target"],
        ["Margin Target", 0.55, "%", "Monthly", "Gross Margin % target"],
        ["Orders Target", 400, "Count", "Monthly", "Order Count target"],
        ["Inventory Target", 300000, "EGP", "Monthly", "Inventory Value ceiling (avoid overstock)"],
        ["AOV Target", 1200, "EGP", "Monthly", "Average Order Value target"],
        ["CAC Target", 150, "EGP", "Monthly", "Customer Acquisition Cost ceiling — needs Marketing-Ready spend data (Phase 6+) to compute Actual"],
        ["ROAS Target", 4, "Ratio", "Monthly", "Return on Ad Spend target — needs Marketing-Ready spend data (Phase 6+) to compute Actual"],
        ["Repeat Customer % Target", 0.30, "%", "Monthly", "Returning Customers / Customers Active target"],
        ["Conversion Rate Target", 0.02, "%", "Monthly", "Needs Shopify session/traffic data (not fetched — Admin API has no storefront analytics) to compute Actual"],
        ["Inventory Turnover Target", 6, "Ratio", "Yearly", "COGS / Average Inventory Value target"],
    ],
)
kpi_targets_data_row = kpi_targets_header_row + 1
# KPI Name/Unit/Period/Notes are reference columns (not meant for free
# retyping) — restyle as calc/gray while keeping Target Value (col C) the
# only green/editable one.
KPI_TARGET_ROWS = 10
for r_off in range(KPI_TARGET_ROWS):
    rr = kpi_targets_data_row + r_off
    for cc in (2, 4, 6):
        cell = ws.cell(row=rr, column=cc)
        cell.font = f(size=9, color=CATEGORY_STYLE["calc"]["body_font"])
        cell.fill = fill(CATEGORY_STYLE["calc"]["body_fill"])
        cell.protection = Protection(locked=True)
add_dropdown(ws, f"E{kpi_targets_data_row}:E{kpi_targets_data_row + KPI_TARGET_ROWS - 1}", "LookupBudgetPeriod", "Period",
             "Monthly or Yearly.")
row += 1

# --- Business Health Score weights (Phase 6) --------------------------------
# BI_HealthScore reads these 10 weights to compute the weighted composite
# score — change a weight here (they don't need to sum to exactly 100; the
# formula divides by their actual sum) rather than editing the formula.
ws.cell(row=row, column=2, value="BUSINESS HEALTH SCORE WEIGHTS  (green cells = type here — must be numeric, any scale)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
health_weights_header_row = row
row = add_table(
    ws, "tbl_HealthScoreWeights", row, 2,
    ["Component", "Weight"],
    "input",
    data_rows=[
        ["Revenue Growth", 15], ["Gross Margin", 15], ["Cash Position", 15],
        ["Inventory Health", 10], ["Customer Growth", 10], ["Repeat Customers", 10],
        ["Return Rate", 10], ["Budget Performance", 5], ["Data Quality", 5], ["Alerts", 5],
    ],
)
health_weights_data_row = health_weights_header_row + 1
for r_off in range(10):
    cell = ws.cell(row=health_weights_data_row + r_off, column=2)
    cell.font = f(size=9, color=CATEGORY_STYLE["calc"]["body_font"])
    cell.fill = fill(CATEGORY_STYLE["calc"]["body_fill"])
    cell.protection = Protection(locked=True)
row += 1

# --- Holidays (Phase 6, Financial Calendar) ---------------------------------
# Empty by default — DIM_Date.pq's IsHoliday/HolidayName columns read this
# table. No holidays are assumed or fabricated; populate with the business's
# actual closure dates.
ws.cell(row=row, column=2, value="HOLIDAYS  (green cells = type here — optional, empty by default)").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
row = add_table(
    ws, "tbl_Holidays", row, 2,
    ["Date", "Holiday Name"],
    "input",
    example_row=["", "EXAMPLE — delete or overwrite this row; leave the table empty if no holidays apply"],
)

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
row, _, gaps_sup = add_kpi_row_v2(ws, row, [
    # Active Suppliers / Outstanding Receipts reuse the EXACT same formulas
    # RPT_Workflow already writes against these same tables (Phase 6) — not
    # recomputed differently here, just the same plain worksheet formula
    # shown on a second sheet. Open POs reuses the same "not Closed, not
    # Cancelled" filter dax/MEASURES.md's [Accounts Payable (Proxy)] already
    # defines for "committed, unsettled" POs, applied as a worksheet
    # COUNTIFS against the same tbl_POHeader table sitting right below.
    dict(label="Active Suppliers", formula='=COUNTIFS(tbl_SupplierMaster[Status],"Active")', numfmt="#,##0"),
    dict(label="Open POs", formula='=COUNTIFS(tbl_POHeader[Status],"<>Closed",tbl_POHeader[Status],"<>Cancelled")', numfmt="#,##0"),
    dict(label="Purchases YTD", formula=None, reason="dax/MEASURES.md defines [Cash Paid for Purchases] (period-aggregate, driven by whatever filter context a report provides) but no YTD-specific variant — the §8 time-intelligence pattern was only instantiated for Net Sales/Gross Profit/Net Profit/Order Count. A worksheet SUMIFS reimplementing a Jan-1-to-today window against tbl_GoodsReceipt directly would be new logic, not a reuse of an existing formula or measure, so it wasn't added."),
    dict(label="Outstanding Receipts", formula='=SUM(tbl_GoodsReceipt[Remaining Quantity])', numfmt="#,##0"),
], col_start=2, card_width=2)
row += 1
row = add_known_gaps_note(ws, row, 2, gaps_sup, last_col=10)

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
    table_category = {"raw": "shopify", "dim": "calc", "fact": "calc", "log": "calc",
                       "marketing": "shopify", "bi": "calc", "future": "calc"}[category]
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
#
# Deliberately "RAW_Variants"/"RAW_Collections", NOT "tbl_RAW_Variants"/
# "tbl_RAW_Collections" (the Phase 1 placeholder table names still on these
# sheets today): per power-query/README.md's setup steps, the placeholder
# table gets DELETED and Power Query's "Load To Existing Worksheet" creates
# a new table named after the QUERY (e.g. "RAW_Variants") once wired — so
# this points at the table's PERMANENT post-wiring name. Every DAX measure
# already assumes this same no-tbl_-prefix convention (dax/MEASURES.md).
# Until Phase 2 is wired, these two named ranges (and everything that reads
# them — Phase 3's SKU/Collection dropdowns, Phase 6's data-quality checks)
# will show a broken reference — expected, same as every other "resolves
# once wired" caveat in this workbook; wire Phase 2 before relying on them.
NAMED_LIST_RANGES.append(("SKUList", "RAW_Variants", "SKU"))
NAMED_LIST_RANGES.append(("CollectionTitleList", "RAW_Collections", "Title"))

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

# 14_Data_Quality's Historical Refresh Trend chart — deferred to here since
# LOG_RefreshHistory (referenced below) only now exists. Over-provisioned to
# row 500 since the log is append-only; Excel charts skip blank cells.
# min_row=12, not 13: LOG_RefreshHistory's table header is on row 11 (every
# hidden sheet's doc_block reserves rows 1-10), so its first data/log row is
# 12 — starting the chart at 13 silently dropped the very first refresh
# entry (found in the Phase 7 production-readiness review).
_dq_ws = wb["14_Data_Quality"]
_lrh_ws = wb["LOG_RefreshHistory"]
_cats_ref_dq = Reference(_lrh_ws, min_col=3, max_col=3, min_row=12, max_row=500)  # Timestamp (C)
_data_ref_dq = Reference(_lrh_ws, min_col=5, max_col=5, min_row=12, max_row=500)  # RowsLoaded (E)
add_native_line_chart(_dq_ws, f"B{DQ_CHART_ANCHOR_ROW}", "Rows Loaded per Refresh", _cats_ref_dq, _data_ref_dq, height_cm=6, width_cm=15)


# ============================================================================
# Phase 5, item 6: Marketing-Ready Layer — empty tables + relationships for
# future ad-platform APIs. NOT connected (no API calls, no tokens, no
# scheduled refresh) — purely reserved structure, same spirit as Phase 1's
# original RAW_ placeholders before Phase 2 connected them for real.
# ============================================================================
MARKETING_SHEETS = [
    dict(code="RAW_MetaAds", channel="Meta Ads (Facebook/Instagram)"),
    dict(code="RAW_GoogleAnalytics", channel="Google Analytics"),
    dict(code="RAW_GoogleAds", channel="Google Ads"),
    dict(code="RAW_TikTokAds", channel="TikTok Ads"),
    dict(code="RAW_EmailMarketing", channel="Email Marketing (e.g. Klaviyo/Mailchimp)"),
    dict(code="RAW_InfluencerCampaigns", channel="Influencer Campaigns"),
]
for s in MARKETING_SHEETS:
    build_hidden_sheet(
        s["code"], "marketing",
        purpose=f"RESERVED, NOT CONNECTED — placeholder for future {s['channel']} API ingestion. No API calls, no credentials, no scheduled refresh exist for this yet.",
        inputs=f"None yet. Future: {s['channel']}'s own API/export.",
        outputs="Will feed FACT_MarketingSpend once connected.",
        relationships="DateKey -> DIM_Date; Campaign -> a future DIM_Campaign (not yet built — see FACT_MarketingSpend's notes).",
        future_source=f"{s['channel']} API — a future phase (6+), following the exact Power Query pattern power-query/README.md established for Shopify (auth via Extension.CurrentCredential, paginated fetch, incremental refresh).",
        headers=["DateKey", "CampaignID", "CampaignName", "Spend", "Impressions", "Clicks", "Conversions", "Currency"],
    )

build_hidden_sheet(
    "FACT_MarketingSpend", "marketing",
    purpose="RESERVED, NOT CONNECTED — the unified cross-channel spend fact every RAW_<Channel>Ads table above would roll into, so DAX (CAC, ROAS) can query one table instead of six. Channel-specific fields (e.g. TikTok's video view counts) stay on each RAW_ table; only the common shape (spend, date, campaign, conversions) is unified here.",
    inputs="Will be built from every RAW_MetaAds/RAW_GoogleAds/RAW_TikTokAds/etc. table above, once connected.",
    outputs="dax/MEASURES.md's [CAC] and [ROAS] (currently unbuildable — see KPI Targets' notes on those two rows) will read from here.",
    relationships="DateKey -> DIM_Date; ChannelName is a plain attribute (not worth its own dimension at this scale); CampaignID -> a future DIM_Campaign.",
    future_source="Union of the RAW_<Channel>Ads tables above, in Power Query — a future phase (6+).",
    headers=["DateKey", "ChannelName", "CampaignID", "CampaignName", "Spend", "Conversions", "Currency"],
)


# ============================================================================
# Phase 5, item 12: AI-Ready Architecture — reserved structure only, per the
# brief's explicit "No implementation yet." This is intentionally the
# thinnest table in the workbook: a checklist of what a future AI layer would
# populate, not a working feature.
# ============================================================================
build_hidden_sheet(
    "FUTURE_AI_Insights", "future",
    purpose="RESERVED, NOT IMPLEMENTED — placeholder inventory of AI-generated features a future phase could add (Executive Summary, Daily/Weekly/Monthly Summary, Recommendations, Anomaly Detection, Natural Language Q&A). No AI model is called anywhere in this workbook today.",
    inputs="None yet. Future: the Data Model (dax/MEASURES.md) + BI_Insights/BI_Alerts (Phase 5's own rule-based versions of Summary/Anomaly-Detection, which an AI layer would eventually supersede or enrich, not duplicate).",
    outputs="None yet.",
    relationships="None yet.",
    future_source="A future phase's AI integration (e.g. an LLM API call summarizing the Data Model's current state) — not scoped or estimated here.",
    headers=["FeatureName", "Status", "Description", "WouldReplaceOrEnrich"],
    example_row=["Executive Summary", "Not Implemented", "One-paragraph AI-written summary of the period's performance", "Enriches BI_Insights (adds narrative synthesis on top of the rule-based bullet points)"],
)


# ============================================================================
# Phase 5, items 1 & 3: Executive Commentary Engine + Alerts Engine.
# CUBEVALUE-driven — real formulas, not static text — so these actually
# update as the Data Model's numbers change. Both stay hidden; dashboards
# (Partner/CEO) surface a curated subset, not the raw tables.
# ============================================================================
ws = build_hidden_sheet(
    "BI_Insights", "bi",
    purpose="Auto-generated business insights, one row per insight, built from CUBEVALUE formulas reading dax/MEASURES.md's measures directly (no PivotTable needed). Recalculates on every workbook open/refresh — nothing here is typed by hand.",
    inputs="The Data Model (dax/MEASURES.md) via CUBEVALUE/CUBESET/CUBERANKEDMEMBER.",
    outputs="02_Partner_Dashboard and 03_CEO_Dashboard both surface a subset of these rows under 'Key Insights'.",
    relationships="No Data Model relationship — reads the model via CUBE functions, same mechanism the dashboards themselves use.",
    future_source="Already live: resolves for real once the Data Model + measures are wired per dax/README.md. Until then shows blank/0 — expected, not an error.",
    headers=["InsightID", "Category", "InsightText", "Severity"],
)
insight_row = ws.max_row + 2
ws.cell(row=insight_row, column=2, value="INSIGHT FORMULAS  (CUBEVALUE-driven — see dax/PHASE5_MEASURES_ADDENDUM.md for the exact measures each one reads)").font = f(size=9, bold=True, color=C["text_gray"])
insight_row += 1

# INS-06/07 (Best/Weakest seller) need a CUBESET-backed CUBERANKEDMEMBER, not
# a raw MDX set expression — "{[DIM_Product].[Title].Children}" alone is
# UNORDERED, so rank 1 of it has no defined meaning and is not sorted by
# sales; the original formula also called that same unordered expression for
# both "best" and "weakest," so the two insights always displayed the exact
# same (arbitrary) product. Fixed the way add_cube_top_n() already does it
# everywhere else in the workbook: a CUBESET helper cell defines the ranked
# set (BDESC/BASC by Net Sales), CUBERANKEDMEMBER pulls rank 1 from it.
# Found in the Phase 7 production-readiness review.
bestseller_row = insight_row + 5
weakest_row = insight_row + 6
bestseller_set_cell = ws.cell(row=bestseller_row, column=8, value=(
    '=CUBESET("ThisWorkbookDataModel","{[DIM_Product].[Title].Children}","BestSeller","BDESC","[Measures].[Net Sales]")'
))
bestseller_set_cell.font = f(size=7, color=C["med_gray"])
weakest_set_cell = ws.cell(row=weakest_row, column=8, value=(
    '=CUBESET("ThisWorkbookDataModel","{[DIM_Product].[Title].Children}","WeakestSeller","BASC","[Measures].[Net Sales]")'
))
weakest_set_cell.font = f(size=7, color=C["med_gray"])

INSIGHTS = [
    ("INS-01", "Sales", '="Net Sales "&TEXT(ABS(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Revenue Growth % (YoY)]")),"0.0%")&IF(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Revenue Growth % (YoY)]")>=0," higher"," lower")&" than the same period last year."'),
    ("INS-02", "Margin", '="Gross Margin is "&TEXT(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Gross Margin %]"),"0.0%")&", vs. a target of "&TEXT(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Margin Target]"),"0.0%")&"."'),
    ("INS-03", "Customers", '="Customer Retention (month-over-month) is "&TEXT(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Customer Retention Rate (MoM)]"),"0.0%")&"."'),
    ("INS-04", "Inventory", '=IF(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Inventory Turnover]")<CUBEVALUE("ThisWorkbookDataModel","[Measures].[Inventory Turnover Target]"),"Inventory turnover is below target — stock may be moving slower than planned.","Inventory turnover is at or above target.")'),
    ("INS-05", "Cash", '=IF(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Cash Position (Direct, Cumulative)]")>0,"Cash position is healthy (positive).","Cash position is negative — review Reconciliation: Cash Variance before acting on this.")'),
    ("INS-06", "Products", f'="Best seller: "&CUBERANKEDMEMBER("ThisWorkbookDataModel",$H${bestseller_row},1)&"."'),
    ("INS-07", "Products", f'="Weakest seller (with any sales): "&CUBERANKEDMEMBER("ThisWorkbookDataModel",$H${weakest_row},1)&" — see 05_Products for the full ranked list rather than relying on one row here."'),
    ("INS-08", "Orders", '="Average Order Value is "&TEXT(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Average Order Value]"),"#,##0")&" EGP, vs. a target of "&TEXT(CUBEVALUE("ThisWorkbookDataModel","[Measures].[AOV Target]"),"#,##0")&" EGP."'),
]
for i, (iid, cat, formula) in enumerate(INSIGHTS):
    r = insight_row + i
    ws.cell(row=r, column=2, value=iid).font = f(size=9, color=C["calc_body"])
    ws.cell(row=r, column=3, value=cat).font = f(size=9, color=C["calc_body"])
    tc = ws.cell(row=r, column=4, value=formula)
    tc.font = f(size=9, color=C["calc_body"])
    tc.alignment = Alignment(wrap_text=True)
    ws.cell(row=r, column=5, value="Info").font = f(size=9, color=C["calc_body"])

ws = build_hidden_sheet(
    "BI_Alerts", "bi",
    purpose="Auto-generated operational alerts, one row per alert type, built from CUBEVALUE formulas plus a few direct structural checks already computed elsewhere (Product Cost Master's Overlap Warning, Manual Expenses' Possible Duplicate) rather than re-deriving them — reuses, doesn't duplicate, Phase 2-4's own data-quality logic.",
    inputs="The Data Model (dax/MEASURES.md) via CUBEVALUE; LOG_DataQuality; tbl_ProductCostMaster/tbl_ManualExpenses' existing flag columns.",
    outputs="14_Data_Quality and 03_CEO_Dashboard both surface these under 'Alerts'.",
    relationships="No Data Model relationship — reads via CUBE functions and direct cell/table references.",
    future_source="Already live: resolves for real once the Data Model + measures are wired per dax/README.md.",
    headers=["AlertID", "AlertName", "Condition", "Status", "Severity"],
)
alert_row = ws.max_row + 2
ws.cell(row=alert_row, column=2, value="ALERT FORMULAS").font = f(size=9, bold=True, color=C["text_gray"])
alert_row += 1
ALERTS = [
    ("ALT-01", "Low Inventory", "Inventory Value below target", '=IF(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Inventory Value]")<CUBEVALUE("ThisWorkbookDataModel","[Measures].[Inventory Target]")*0.5,"TRIGGERED","OK")', "Warning"),
    ("ALT-02", "Negative Margin", "Gross Margin % below 0", '=IF(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Gross Margin %]")<0,"TRIGGERED","OK")', "Critical"),
    ("ALT-03", "Products without Cost", "Order lines with no matching Product Cost Master row", '=IF(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Lines Missing Cost]")>0,"TRIGGERED ("&CUBEVALUE("ThisWorkbookDataModel","[Measures].[Lines Missing Cost]")&" lines)","OK")', "Warning"),
    ("ALT-04", "Products without SKU", "RAW_Variants rows with a blank SKU", '=IF(COUNTIFS(RAW_Variants[SKU],"")>0,"TRIGGERED","OK")', "Warning"),
    ("ALT-05", "Expenses without Category", "Manual Expenses rows with a blank Expense Category", '=IF(COUNTIFS(tbl_ManualExpenses[Expense Category],"")>0,"TRIGGERED","OK")', "Warning"),
    ("ALT-06", "Duplicate Expenses", "Manual Expenses flagged Possible Duplicate", '=IF(COUNTIF(tbl_ManualExpenses[Possible Duplicate],"Possible Duplicate")>0,"TRIGGERED ("&COUNTIF(tbl_ManualExpenses[Possible Duplicate],"Possible Duplicate")&")","OK")', "Info"),
    ("ALT-07", "Inactive Products", "Product Cost Master rows marked Inactive with no Active replacement", '=IF(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Lines Missing Cost]")>0,"REVIEW — see Products without Cost above (same root cause)","OK")', "Info"),
    ("ALT-08", "Slow Moving Inventory", "SKUs below the Slow Moving threshold (dax/MEASURES.md)", '=IF(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Slow Moving SKU Count]")>0,"TRIGGERED ("&CUBEVALUE("ThisWorkbookDataModel","[Measures].[Slow Moving SKU Count]")&" SKUs)","OK")', "Info"),
    ("ALT-09", "Dead Stock", "SKUs with zero sales in 180 days while still holding stock", '=IF(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Dead Stock SKU Count]")>0,"TRIGGERED ("&CUBEVALUE("ThisWorkbookDataModel","[Measures].[Dead Stock SKU Count]")&" SKUs)","OK")', "Warning"),
    ("ALT-10", "Missing Shopify Sync", "No successful refresh recorded in the last 2 days", '=IF(COUNTIFS(LOG_RefreshHistory[Timestamp],">="&TODAY()-2)=0,"TRIGGERED","OK")', "Critical"),
    ("ALT-11", "Refresh Errors", "LOG_DataQuality rows with a WARNING status this refresh", '=IF(COUNTIF(LOG_DataQuality[Status],"WARNING*")>0,"TRIGGERED","OK")', "Warning"),
    ("ALT-12", "Over Budget Expenses", "Operating Expenses exceed the Budget for the current period", '=IF(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Operating Expenses]")>CUBEVALUE("ThisWorkbookDataModel","[Measures].[Expense Budget (Period)]"),"TRIGGERED","OK")', "Warning"),
]
for i, (aid, name, cond, formula, sev) in enumerate(ALERTS):
    r = alert_row + i
    ws.cell(row=r, column=2, value=aid).font = f(size=9, color=C["calc_body"])
    ws.cell(row=r, column=3, value=name).font = f(size=9, color=C["calc_body"])
    ws.cell(row=r, column=4, value=cond).font = f(size=8, italic=True, color=C["text_gray"])
    ws.cell(row=r, column=5, value=formula).font = f(size=9, color=C["calc_body"])
    ws.cell(row=r, column=6, value=sev).font = f(size=9, color=C["calc_body"])


# ============================================================================
# Phase 5, item 5: Forecast Module — rolling-trend forecasts using Excel's
# native FORECAST.LINEAR against a CUBEVALUE-pulled trailing-12-month
# actuals series, per metric. "Allow future replacement with AI forecasting"
# means: Method is its own labeled column, so a future phase can swap the
# formula in that one column without touching anything else here.
# ============================================================================
ws = build_hidden_sheet(
    "BI_Forecast", "bi",
    purpose="Rolling-trend forecast for Sales, Expenses, Profit, Inventory, and Cash — Excel's native FORECAST.LINEAR projecting one period ahead from each metric's trailing 12-month actuals (pulled via CUBEVALUE). Deliberately simple (linear trend, not seasonality-aware) so it's easy to audit and easy to replace.",
    inputs="The Data Model (dax/MEASURES.md) via CUBEVALUE, trailing 12 months.",
    outputs="03_CEO_Dashboard's Forecast section.",
    relationships="No Data Model relationship.",
    future_source="AI forecasting — replace this table's Method/Formula columns with a call to an external forecasting service once one exists; every other column (Metric, ForecastPeriod, ForecastValue) stays the same shape so downstream references don't break.",
    headers=["Metric", "Method", "ForecastPeriod", "ForecastValue"],
)
forecast_row = ws.max_row + 2
ws.cell(row=forecast_row, column=2, value="TRAILING 12-MONTH ACTUALS (feeds the forecasts below)").font = f(size=9, bold=True, color=C["text_gray"])
forecast_row += 1
FORECAST_METRICS = [("Sales", "Net Sales"), ("Expenses", "Operating Expenses"), ("Profit", "Net Profit"),
                     ("Inventory", "Inventory Value"), ("Cash", "Cash Position (Direct, Cumulative)")]
trend_tops = {}
for i, (label, measure) in enumerate(FORECAST_METRICS):
    r = forecast_row + i * 4
    trend_tops[label] = add_cube_trend_table(ws, r, 2, measure, n_months=12, label=f"{label} — trailing 12 months")
forecast_calc_row = forecast_row + len(FORECAST_METRICS) * 4 + 1
ws.cell(row=forecast_calc_row, column=2, value="FORECAST (next period, linear trend)").font = f(size=9, bold=True, color=C["text_gray"])
forecast_calc_row += 1
X_CONSTANT = "{1,2,3,4,5,6,7,8,9,10,11,12}"  # known_x's for FORECAST.LINEAR — an
# inline array constant rather than a helper row, so nothing here risks
# writing into row 1 (reserved by every sheet's title bar merge).
for i, (label, measure) in enumerate(FORECAST_METRICS):
    r = forecast_calc_row + i
    _, value_row, first_col, last_col = trend_tops[label]
    values_range = f"{get_column_letter(first_col)}{value_row}:{get_column_letter(last_col)}{value_row}"
    ws.cell(row=r, column=2, value=label).font = f(size=9, color=C["calc_body"])
    ws.cell(row=r, column=3, value="Linear Trend (FORECAST.LINEAR)").font = f(size=9, color=C["calc_body"])
    ws.cell(row=r, column=4, value="Next Month").font = f(size=9, color=C["calc_body"])
    fc = ws.cell(row=r, column=5, value=f'=_xlfn.FORECAST.LINEAR(13,{values_range},{X_CONSTANT})')
    fc.font = f(size=9, bold=True, color=C["calc_body"])
    fc.number_format = "#,##0"


# ============================================================================
# Phase 6, item 3: Business Health Score — one master 0-100 KPI, weighted
# from 10 components. Weights live on 15_Settings (tbl_HealthScoreWeights,
# editable) so the business can rebalance without touching a formula. Two
# components (Data Quality, Alerts) intentionally read worksheet tables
# directly rather than CUBEVALUE — see dax/PHASE6_MEASURES_ADDENDUM.md for
# why a pure-DAX measure couldn't reach them cleanly.
# ============================================================================
ws = build_hidden_sheet(
    "BI_HealthScore", "bi",
    purpose="The single master KPI (0-100, Red/Amber/Green) combining 10 weighted components across growth, profitability, cash, inventory, customers, budget, data quality, and alerts — the one number an executive glances at first.",
    inputs="The Data Model (dax/MEASURES.md, PHASE5/6 addenda) via CUBEVALUE; 14_Data_Quality's Overall Data Quality %; BI_Alerts' Status column; tbl_HealthScoreWeights (15_Settings).",
    outputs="02_Partner_Dashboard, 03_CEO_Dashboard, and RPT_ExecutiveBrief all reference this sheet's Total Score cell directly.",
    relationships="No Data Model relationship — reads via CUBE functions and direct cell/table references, same mechanism as BI_Insights/BI_Alerts.",
    future_source="Already live: resolves for real once the Data Model + measures are wired.",
    headers=["Component", "Score (0-100)", "Weight", "Weighted Contribution"],
)
hs_row = ws.max_row + 2
ws.cell(row=hs_row, column=2, value="COMPONENT SCORES  (formulas — do not edit; change weights on 15_Settings instead)").font = f(size=9, bold=True, color=C["text_gray"])
hs_row += 1
hs_data_row = hs_row
HEALTH_COMPONENTS = [
    ("Revenue Growth", 'MIN(100,MAX(0,50+CUBEVALUE("ThisWorkbookDataModel","[Measures].[Revenue Growth % (YoY)]")*250))'),
    ("Gross Margin", 'MIN(100,MAX(0,IFERROR(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Gross Margin %]")/CUBEVALUE("ThisWorkbookDataModel","[Measures].[Margin Target]")*100,0)))'),
    ("Cash Position", 'MIN(100,MAX(0,IFERROR(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Cash Position (Direct, Cumulative)]")/CUBEVALUE("ThisWorkbookDataModel","[Measures].[Expense Budget (Period)]")*100,0)))'),
    ("Inventory Health", 'MIN(100,MAX(0,IFERROR(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Inventory Turnover]")/CUBEVALUE("ThisWorkbookDataModel","[Measures].[Inventory Turnover Target]")*100,0)))'),
    ("Customer Growth", 'MIN(100,MAX(0,50+CUBEVALUE("ThisWorkbookDataModel","[Measures].[Customer Growth % (YoY)]")*250))'),
    ("Repeat Customers", 'MIN(100,MAX(0,IFERROR(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Repeat Customer % Actual]")/CUBEVALUE("ThisWorkbookDataModel","[Measures].[Repeat Customer % Target]")*100,0)))'),
    ("Return Rate", 'MIN(100,MAX(0,100-CUBEVALUE("ThisWorkbookDataModel","[Measures].[Return Rate %]")*1000))'),
    ("Budget Performance", 'MIN(100,MAX(0,100-ABS(IFERROR(CUBEVALUE("ThisWorkbookDataModel","[Measures].[Expense Actual vs Budget]")/CUBEVALUE("ThisWorkbookDataModel","[Measures].[Expense Budget (Period)]"),0))*100))'),
    ("Data Quality", "MIN(100,MAX(0,OverallDataQualityPct*100))"),
    ("Alerts", '=MIN(100,MAX(0,100-COUNTIF(\'BI_Alerts\'!E15:E26,"TRIGGERED*")*(100/12)))'),
]
for i, (comp, formula) in enumerate(HEALTH_COMPONENTS):
    r = hs_data_row + i
    ws.cell(row=r, column=2, value=comp).font = f(size=9, color=C["calc_body"])
    score_formula = formula if formula.startswith("=") else f"={formula}"
    sc = ws.cell(row=r, column=3, value=score_formula)
    sc.font = f(size=9, bold=True, color=C["calc_body"])
    sc.number_format = "0.0"
    # Weight: pulled from tbl_HealthScoreWeights by matching Component name —
    # plain worksheet formula (INDEX/MATCH, not DAX LOOKUPVALUE, since this
    # is a worksheet, not a measure).
    ws.cell(row=r, column=4, value=f'=INDEX(tbl_HealthScoreWeights[Weight],MATCH(B{r},tbl_HealthScoreWeights[Component],0))').font = f(size=9, color=C["calc_body"])
    wcc = ws.cell(row=r, column=5, value=f'=C{r}*D{r}')
    wcc.font = f(size=9, color=C["calc_body"])
    wcc.number_format = "0.0"
hs_end_row = hs_data_row + len(HEALTH_COMPONENTS) - 1
row_total = hs_end_row + 2
ws.cell(row=row_total, column=2, value="TOTAL BUSINESS HEALTH SCORE").font = f(size=12, bold=True, color=C["black"])
total_formula = f'=SUM(E{hs_data_row}:E{hs_end_row})/SUM(D{hs_data_row}:D{hs_end_row})'
total_cell = ws.cell(row=row_total, column=3, value=total_formula)
total_cell.font = f(size=20, bold=True, color=C["black"])
total_cell.number_format = "0.0"
NAMED_RANGES.append(("BusinessHealthScore", "BI_HealthScore", f"$C${row_total}"))
row_status = row_total + 1
ws.cell(row=row_status, column=2, value="Status (Red < 50, Amber 50-75, Green > 75)").font = f(size=9, italic=True, color=C["text_gray"])
status_formula = f'=IF(C{row_total}>75,"GREEN",IF(C{row_total}>=50,"AMBER","RED"))'
status_cell = ws.cell(row=row_status, column=3, value=status_formula)
status_cell.font = f(size=11, bold=True, color=C["calc_body"])
NAMED_RANGES.append(("BusinessHealthStatus", "BI_HealthScore", f"$C${row_status}"))


# ============================================================================
# Phase 6, items 1-2: Daily Executive Brief + Automated Daily Report.
# One sheet serves both — RPT_ExecutiveBrief is built print-ready (A4,
# portrait, no dropdowns/interactive elements in the printable region) from
# the start, rather than duplicating the same 13 metrics onto a second
# sheet. See PHASE6_DOCUMENTATION.md for why. Hidden (per your placement
# choice) — right-click any sheet tab > Unhide > RPT_ExecutiveBrief to view
# or print; 01_Home also links to it directly.
# "Biggest Increase/Decrease": scoped to overall Revenue vs Yesterday (a
# single, reliable day-over-day delta) rather than a per-product "biggest
# mover" ranking — CUBESET can't cleanly cross a date filter with a ranking
# measure without an MDX pattern too advanced to verify in this environment.
# "Top 5 Products/Collections": the SAME CUBESET/CUBERANKEDMEMBER measure
# 02_Partner_Dashboard already uses, called again here — reusing the
# measure, not re-deriving the logic, the same way the same KPI naturally
# appears on more than one dashboard.
# ============================================================================
ws = wb.create_sheet("RPT_ExecutiveBrief")
ws.sheet_view.showGridLines = False
set_col_widths(ws, [3] + [13] * 9)
title_bar(ws, "Daily Executive Brief", last_col=10)
row = doc_block(
    ws,
    "One-page, auto-summarized snapshot of today's business — printable as-is, no editing or slicers, suitable to hand a partner without walking them through the workbook.",
    "The Data Model via CUBEVALUE/CUBESET; BI_HealthScore; BI_Alerts; BI_Insights.",
    "A single printable A4 page.",
    "Reads the Data Model and the BI_ sheets directly — this page computes nothing new itself.",
    "Already live: resolves for real once the Data Model + measures are wired.",
    last_col=10,
)
TODAY_YMD = 'CUBEVALUE("ThisWorkbookDataModel","[Measures].[{m}]","[DIM_Date].[Year].&["&YEAR(TODAY())&"]","[DIM_Date].[Month].&["&MONTH(TODAY())&"]","[DIM_Date].[Day].&["&DAY(TODAY())&"]")'
YEST_YMD = 'CUBEVALUE("ThisWorkbookDataModel","[Measures].[{m}]","[DIM_Date].[Year].&["&YEAR(TODAY()-1)&"]","[DIM_Date].[Month].&["&MONTH(TODAY()-1)&"]","[DIM_Date].[Day].&["&DAY(TODAY()-1)&"]")'
TODAY_CARDS = [
    ("Revenue Today", TODAY_YMD.format(m="Net Sales"), "#,##0"),
    ("Orders Today", TODAY_YMD.format(m="Order Count"), "#,##0"),
    ("Gross Profit", TODAY_YMD.format(m="Gross Profit"), "#,##0"),
    ("Margin %", TODAY_YMD.format(m="Gross Margin %"), "0.0%"),
    ("Cash Position", 'CUBEVALUE("ThisWorkbookDataModel","[Measures].[Cash Position (Direct, Cumulative)]")', "#,##0"),
    ("Inventory Value", 'CUBEVALUE("ThisWorkbookDataModel","[Measures].[Inventory Value]")', "#,##0"),
]
brief_kpi_top = row
for i, (label, formula, numfmt) in enumerate(TODAY_CARDS):
    col = 2 + i
    lab = ws.cell(row=brief_kpi_top, column=col, value=label.upper())
    lab.font = f(size=8, bold=True, color=C["med_gray"])
    lab.alignment = Alignment(vertical="bottom", horizontal="left", indent=1)

    ws.merge_cells(start_row=brief_kpi_top + 1, start_column=col, end_row=brief_kpi_top + 2, end_column=col)
    val = ws.cell(row=brief_kpi_top + 1, column=col, value=f"={formula}")
    val.font = f(size=14, bold=True, color=C["white"])
    val.number_format = numfmt
    val.alignment = Alignment(vertical="center", horizontal="left", indent=1)

    for rr in (brief_kpi_top, brief_kpi_top + 1, brief_kpi_top + 2):
        ws.cell(row=rr, column=col).fill = fill(C["kpi_fill"])
row = brief_kpi_top + 4

ws.cell(row=row, column=2, value="Revenue vs Yesterday").font = f(size=9, bold=True, color=C["text_gray"])
row += 1
vy_cell = ws.cell(row=row, column=2, value=f'=IFERROR({TODAY_YMD.format(m="Net Sales")}-{YEST_YMD.format(m="Net Sales")},0)')
vy_cell.font = f(size=14, bold=True, color=C["calc_body"])
vy_cell.number_format = "+#,##0;-#,##0;0"
ws.cell(row=row, column=3, value='=IF(B' + str(row) + '>=0,"▲ Increase","▼ Decrease")').font = f(size=10, color=C["calc_body"])
row += 2

ws.cell(row=row, column=2, value="TOP 5 PRODUCTS").font = f(size=10, bold=True, color=C["text_gray"])
ws.cell(row=row, column=7, value="TOP 5 COLLECTIONS").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
top_row_start = row
row = add_cube_top_n(ws, top_row_start, 2, "Top 5 Products (Brief)", "DIM_Product", "Title", "Net Sales", n=5, ascending=False)
add_cube_top_n(ws, top_row_start, 7, "Top 5 Collections (Brief)", "DIM_Collection", "Title", "Net Sales", n=5, ascending=False)
row += 1

ws.cell(row=row, column=2, value="CRITICAL ALERTS").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
# ALT-02 (Negative Margin) and ALT-10 (Missing Shopify Sync) are the only
# two Severity="Critical" rows in BI_Alerts (rows 15-26) — referenced
# directly rather than re-scanning the whole table on this page.
for label, src in [("Negative Margin", 16), ("Missing Shopify Sync", 24)]:
    ws.cell(row=row, column=2, value=label).font = f(size=9, color=C["text_gray"])
    ws.cell(row=row, column=4, value=f"='BI_Alerts'!E{src}").font = f(size=9, bold=True, color=C["calc_body"])
    row += 1
row += 1

ws.cell(row=row, column=2, value="BUSINESS HEALTH SCORE").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
hcell = ws.cell(row=row, column=2, value="=BusinessHealthScore")
hcell.font = f(size=24, bold=True, color=C["black"])
hcell.number_format = "0.0"
ws.cell(row=row, column=4, value="=BusinessHealthStatus").font = f(size=14, bold=True, color=C["calc_body"])
row += 2

ws.cell(row=row, column=2, value="EXECUTIVE COMMENTARY").font = f(size=10, bold=True, color=C["text_gray"])
row += 1
for i, src_row in enumerate([15, 16, 19, 20]):  # same curated 4 as 02_Partner_Dashboard
    r = row + i
    bullet = ws.cell(row=r, column=2, value=f"=\"•  \"&IFERROR('BI_Insights'!D{src_row},\"(resolves once Data Model is wired)\")")
    bullet.font = f(size=9, color=C["text_gray"])
    bullet.alignment = Alignment(wrap_text=True, vertical="top")
    ws.merge_cells(start_row=r, start_column=2, end_row=r, end_column=10)
    ws.row_dimensions[r].height = 16
row += 6

freeze_below_header(ws)
protect_ws(ws)
ws.page_setup.orientation = "portrait"
ws.page_setup.fitToWidth = 1
ws.page_setup.fitToHeight = 1
ws.sheet_properties.pageSetUpPr = PageSetupProperties(fitToPage=True)
ws.page_setup.paperSize = 9  # ECMA-376 paper-size code for A4 (openpyxl has no named constant for this)
ws.print_area = f"A1:J{row}"
ws.page_margins.left = ws.page_margins.right = 0.3
ws.page_margins.top = ws.page_margins.bottom = 0.4
ws.sheet_properties.tabColor = TAB_COLOR["bi"]
ws.sheet_state = "hidden"


# ============================================================================
# Phase 6, item 5: Workflow Dashboard — one operational view spanning
# Purchasing (12_Suppliers), Capital (11_Capital), and Expenses (10_Expenses)
# territory, which is why it's its own sheet rather than appended to any one
# of those (see PHASE6_DOCUMENTATION.md for the placement reasoning). Prefers
# plain worksheet formulas against the Phase 3 manual tables (tbl_POHeader
# etc. — these never get replaced by Power Query, unlike RAW_/LOG_, so the
# tbl_ prefix is permanently correct here) and reuses existing DAX measures
# via CUBEVALUE rather than inventing new "Capital Remaining"/"Outstanding
# Expenses" concepts — both are just [Cash Position] and [Accounts Payable
# (Proxy)] under a workflow-specific label.
# ============================================================================
ws = build_hidden_sheet(
    "RPT_Workflow", "bi",
    purpose="Operational workflow view: purchasing pipeline, order fulfillment status, supplier standing, and cash/expense runway — the day-to-day ops picture, distinct from the financial-statement framing of 08_Finance or the executive framing of the CEO Dashboard.",
    inputs="tbl_POHeader/tbl_POLines/tbl_GoodsReceipt (12_Suppliers), tbl_SupplierMaster, RAW_Orders, the Data Model via CUBEVALUE.",
    outputs="A single operational dashboard page.",
    relationships="No new relationships — reads existing Phase 3 tables and Phase 4/5 measures directly.",
    future_source="Already live: resolves for real once Power Query (Phase 2) and the Data Model (Phase 4) are wired.",
    headers=["Metric", "Value", "Notes"],
)
wf_row = ws.max_row + 2
ws.cell(row=wf_row, column=2, value="PURCHASING & RECEIVING").font = f(size=10, bold=True, color=C["text_gray"])
wf_row += 1
WORKFLOW_METRICS_1 = [
    ("Purchase Orders (Total)", '=COUNTA(tbl_POHeader[PO Number])', "All POs ever entered, any status."),
    ("Open Orders", '=COUNTIFS(RAW_Orders[FulfillmentStatus],"<>FULFILLED")', "Shopify orders not yet fully fulfilled."),
    ("Pending Receipts", '=COUNTIFS(tbl_POHeader[Status],"Approved")+COUNTIFS(tbl_POHeader[Status],"Sent")+COUNTIFS(tbl_POHeader[Status],"Partially Received")', "POs Approved, Sent, or Partially Received — not yet fully in hand."),
    ("Inventory to Receive (units)", '=SUM(tbl_GoodsReceipt[Remaining Quantity])', "Reuses Phase 3's own Remaining Quantity column (12_Suppliers) — not recomputed here."),
    ("Monthly Purchasing (this month)", 'CUBEVALUE("ThisWorkbookDataModel","[Measures].[Cash Paid for Purchases]")', "Current-period Cash Paid for Purchases (dax/MEASURES.md)."),
]
for i, (label, formula, note) in enumerate(WORKFLOW_METRICS_1):
    r = wf_row + i
    ws.cell(row=r, column=2, value=label).font = f(size=9, color=C["calc_body"])
    vf = formula if formula.startswith("=") else f"={formula}"
    ws.cell(row=r, column=3, value=vf).font = f(size=9, bold=True, color=C["calc_body"])
    ws.cell(row=r, column=4, value=note).font = f(size=8, italic=True, color=C["text_gray"])
wf_row += len(WORKFLOW_METRICS_1) + 2

ws.cell(row=wf_row, column=2, value="SUPPLIER STATUS").font = f(size=10, bold=True, color=C["text_gray"])
wf_row += 1
for i, status in enumerate(["Active", "Inactive", "On Hold"]):
    r = wf_row + i
    ws.cell(row=r, column=2, value=status).font = f(size=9, color=C["calc_body"])
    ws.cell(row=r, column=3, value=f'=COUNTIFS(tbl_SupplierMaster[Status],"{status}")').font = f(size=9, bold=True, color=C["calc_body"])
wf_row += 5

ws.cell(row=wf_row, column=2, value="CASH & EXPENSES").font = f(size=10, bold=True, color=C["text_gray"])
wf_row += 1
WORKFLOW_METRICS_2 = [
    ("Capital Remaining", 'CUBEVALUE("ThisWorkbookDataModel","[Measures].[Cash Position (Direct, Cumulative)]")', "Same figure as Cash Position elsewhere — \"remaining\" is a workflow-page label, not a different calculation."),
    ("Outstanding Expenses", 'CUBEVALUE("ThisWorkbookDataModel","[Measures].[Accounts Payable (Proxy)]")', "Reuses the Balance Sheet's Accounts Payable proxy (dax/MEASURES.md §2) — same documented limitation applies (no payment-status field exists)."),
]
for i, (label, formula, note) in enumerate(WORKFLOW_METRICS_2):
    r = wf_row + i
    ws.cell(row=r, column=2, value=label).font = f(size=9, color=C["calc_body"])
    vf = formula if formula.startswith("=") else f"={formula}"
    ws.cell(row=r, column=3, value=vf).font = f(size=9, bold=True, color=C["calc_body"])
    ws.cell(row=r, column=4, value=note).font = f(size=8, italic=True, color=C["text_gray"])
wf_row += len(WORKFLOW_METRICS_2) + 2

ws.cell(row=wf_row, column=2, value="MONTHLY PURCHASING — TRAILING 12 MONTHS").font = f(size=10, bold=True, color=C["text_gray"])
wf_row += 1
_, wf_value_row, wf_first_col, wf_last_col = add_cube_trend_table(ws, wf_row, 2, "Cash Paid for Purchases", n_months=12, label="Monthly Purchasing")
wf_cats_ref = Reference(ws, min_col=wf_first_col, max_col=wf_last_col, min_row=wf_row + 1, max_row=wf_row + 1)
wf_data_ref = Reference(ws, min_col=wf_first_col, max_col=wf_last_col, min_row=wf_value_row, max_row=wf_value_row)
add_native_line_chart(ws, f"B{wf_row + 4}", "Monthly Purchasing — Trailing 12 Months", wf_cats_ref, wf_data_ref, height_cm=6, width_cm=15)

# build_hidden_sheet() already froze panes, protected, colored the tab, and
# hid this sheet — only print setup is new here.
set_print_friendly(ws, last_col=15, last_row=80)


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
    [s["code"] for s in LOG_SHEETS] +
    [s["code"] for s in MARKETING_SHEETS] + ["FACT_MarketingSpend"] +
    ["FUTURE_AI_Insights", "BI_Insights", "BI_Alerts", "BI_Forecast",
     "BI_HealthScore", "RPT_ExecutiveBrief", "RPT_Workflow"]
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
