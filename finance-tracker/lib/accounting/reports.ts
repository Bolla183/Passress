import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID } from "./company";
import { getAccountByCode } from "./ledger";
import { dateInputValue, startOfCairoDay } from "../dates";
import type { Account } from "../../app/generated/prisma/client";

type Activity = { debit: number; credit: number };

async function getAllAccounts(companyId: string) {
  return prisma.account.findMany({ where: { companyId }, orderBy: { code: "asc" } });
}

// Own (non-rolled-up) debit/credit activity per account, for lines dated <= `to`
// and (if given) >= `from`. This is the primitive every report is built from.
async function getOwnActivity(
  companyId: string,
  to: Date,
  from?: Date
): Promise<Map<string, Activity>> {
  const lines = await prisma.journalLine.groupBy({
    by: ["accountId"],
    where: {
      companyId,
      journalEntry: {
        date: { lte: to, ...(from ? { gte: from } : {}) },
      },
    },
    _sum: { debit: true, credit: true },
  });

  const map = new Map<string, Activity>();
  for (const line of lines) {
    map.set(line.accountId, {
      debit: Number(line._sum.debit ?? 0),
      credit: Number(line._sum.credit ?? 0),
    });
  }
  return map;
}

function buildChildrenMap(accounts: Account[]): Map<string | null, Account[]> {
  const map = new Map<string | null, Account[]>();
  for (const account of accounts) {
    const key = account.parentId;
    if (!map.has(key)) map.set(key, []);
    map.get(key)!.push(account);
  }
  return map;
}

// Sums an account's own activity plus every descendant's, recursively —
// this is what makes the hierarchical Chart of Accounts actually roll up
// in reports instead of only being a display grouping.
function rollUp(
  accountId: string,
  ownActivity: Map<string, Activity>,
  childrenByParent: Map<string | null, Account[]>
): Activity {
  const own = ownActivity.get(accountId) ?? { debit: 0, credit: 0 };
  let debit = own.debit;
  let credit = own.credit;

  for (const child of childrenByParent.get(accountId) ?? []) {
    const childTotal = rollUp(child.id, ownActivity, childrenByParent);
    debit += childTotal.debit;
    credit += childTotal.credit;
  }

  return { debit, credit };
}

function netBalance(account: Account, activity: Activity): number {
  return account.normalBalance === "DEBIT"
    ? activity.debit - activity.credit
    : activity.credit - activity.debit;
}

export type TrialBalanceRow = {
  accountId: string;
  code: string;
  name: string;
  type: string;
  debitBalance: number;
  creditBalance: number;
};

export async function getTrialBalance(
  asOfDate: Date,
  companyId = DEFAULT_COMPANY_ID
): Promise<TrialBalanceRow[]> {
  const accounts = await getAllAccounts(companyId);
  const ownActivity = await getOwnActivity(companyId, asOfDate);

  const rows: TrialBalanceRow[] = [];
  for (const account of accounts) {
    const own = ownActivity.get(account.id);
    if (!own) continue;
    const net = netBalance(account, own);
    if (Math.abs(net) < 0.005) continue;
    rows.push({
      accountId: account.id,
      code: account.code,
      name: account.name,
      type: account.type,
      debitBalance: net > 0 && account.normalBalance === "DEBIT" ? net : net < 0 && account.normalBalance === "CREDIT" ? -net : 0,
      creditBalance: net > 0 && account.normalBalance === "CREDIT" ? net : net < 0 && account.normalBalance === "DEBIT" ? -net : 0,
    });
  }

  return rows.sort((a, b) => a.code.localeCompare(b.code));
}

export type GeneralLedgerLine = {
  id: string;
  date: Date;
  memo: string | null;
  source: string;
  debit: number;
  credit: number;
  runningBalance: number;
};

export async function getGeneralLedger(
  accountId: string,
  { from, to }: { from?: Date; to: Date },
  companyId = DEFAULT_COMPANY_ID
): Promise<GeneralLedgerLine[]> {
  const account = await prisma.account.findUnique({ where: { id: accountId } });
  if (!account) return [];

  const lines = await prisma.journalLine.findMany({
    where: {
      companyId,
      accountId,
      journalEntry: { date: { lte: to, ...(from ? { gte: from } : {}) } },
    },
    include: { journalEntry: true },
    orderBy: { journalEntry: { date: "asc" } },
  });

  let running = 0;
  return lines.map((line) => {
    const debit = Number(line.debit);
    const credit = Number(line.credit);
    running += account.normalBalance === "DEBIT" ? debit - credit : credit - debit;
    return {
      id: line.id,
      date: line.journalEntry.date,
      memo: line.memo ?? line.journalEntry.memo,
      source: line.journalEntry.source,
      debit,
      credit,
      runningBalance: running,
    };
  });
}

export type AccountRollupRow = {
  accountId: string;
  code: string;
  name: string;
  depth: number;
  amount: number;
};

async function rollUpByType(
  companyId: string,
  types: string[],
  to: Date,
  from?: Date
): Promise<{ rows: AccountRollupRow[]; total: number }> {
  const accounts = await getAllAccounts(companyId);
  const ownActivity = await getOwnActivity(companyId, to, from);
  const childrenByParent = buildChildrenMap(accounts);
  const byId = new Map(accounts.map((a) => [a.id, a]));

  const depthOf = (account: Account): number => {
    let depth = 0;
    let current = account;
    while (current.parentId) {
      const parent = byId.get(current.parentId);
      if (!parent) break;
      depth += 1;
      current = parent;
    }
    return depth;
  };

  const roots = accounts.filter((a) => !a.parentId && types.includes(a.type));
  const rows: AccountRollupRow[] = [];
  let total = 0;

  const visit = (account: Account) => {
    const rolled = rollUp(account.id, ownActivity, childrenByParent);
    const amount = netBalance(account, rolled);
    if (Math.abs(amount) >= 0.005) {
      rows.push({ accountId: account.id, code: account.code, name: account.name, depth: depthOf(account), amount });
    }
    for (const child of childrenByParent.get(account.id) ?? []) {
      visit(child);
    }
  };

  for (const root of roots) {
    visit(root);
    const rolled = rollUp(root.id, ownActivity, childrenByParent);
    total += netBalance(root, rolled);
  }

  return { rows, total };
}

export async function getProfitAndLoss(
  { from, to }: { from: Date; to: Date },
  companyId = DEFAULT_COMPANY_ID
) {
  const revenue = await rollUpByType(companyId, ["REVENUE"], to, from);
  const expense = await rollUpByType(companyId, ["EXPENSE"], to, from);
  return {
    revenue: revenue.rows,
    totalRevenue: revenue.total,
    expense: expense.rows,
    totalExpense: expense.total,
    netProfit: revenue.total - expense.total,
  };
}

export async function getBalanceSheet(asOfDate: Date, companyId = DEFAULT_COMPANY_ID) {
  const assets = await rollUpByType(companyId, ["ASSET"], asOfDate);
  const liabilities = await rollUpByType(companyId, ["LIABILITY"], asOfDate);
  const equity = await rollUpByType(companyId, ["EQUITY"], asOfDate);

  // No formal period-close entries yet, so current net income is folded
  // into equity here rather than requiring a manual closing journal entry.
  const revenue = await rollUpByType(companyId, ["REVENUE"], asOfDate);
  const expense = await rollUpByType(companyId, ["EXPENSE"], asOfDate);
  const netIncome = revenue.total - expense.total;

  return {
    assets: assets.rows,
    totalAssets: assets.total,
    liabilities: liabilities.rows,
    totalLiabilities: liabilities.total,
    equity: equity.rows,
    totalEquity: equity.total + netIncome,
    netIncome,
  };
}

// A single account's rolled-up balance as of a date — the same primitive
// the Balance Sheet uses per-row, exposed standalone for dashboards that
// only need one account (e.g. "cash on hand" or "AR outstanding").
export async function getAccountBalance(
  accountId: string,
  asOfDate: Date,
  companyId = DEFAULT_COMPANY_ID
): Promise<number> {
  const accounts = await getAllAccounts(companyId);
  const account = accounts.find((a) => a.id === accountId);
  if (!account) return 0;

  const ownActivity = await getOwnActivity(companyId, asOfDate);
  const childrenByParent = buildChildrenMap(accounts);
  const rolled = rollUp(accountId, ownActivity, childrenByParent);
  return netBalance(account, rolled);
}

export type ExecutiveSummary = {
  totalRevenue: number;
  totalExpense: number;
  netProfit: number;
  cashBalance: number;
  arOutstanding: number;
  apOutstanding: number;
  revenueByCategory: { category: string; amount: number }[];
  expenseByCategory: { category: string; amount: number }[];
};

// Everything an Executive Dashboard needs, computed only from the ledger
// (postJournalEntry / journal lines) — never from the quick-add "simple
// entries" view, which only reconstructs plain two-line cash transactions
// and would miss Bills, Invoices, Payroll, Loans, and Inventory postings.
export async function getExecutiveSummary(
  { from, to }: { from: Date; to: Date },
  companyId = DEFAULT_COMPANY_ID
): Promise<ExecutiveSummary> {
  const [pnl, bankAccounts, arAccount, apAccount] = await Promise.all([
    getProfitAndLoss({ from, to }, companyId),
    prisma.bankAccount.findMany({ where: { companyId }, select: { glAccountId: true } }),
    getAccountByCode("1100", companyId),
    getAccountByCode("2000", companyId),
  ]);

  const [cashBalances, arOutstanding, apOutstanding] = await Promise.all([
    Promise.all(bankAccounts.map((b) => getAccountBalance(b.glAccountId, to, companyId))),
    getAccountBalance(arAccount.id, to, companyId),
    getAccountBalance(apAccount.id, to, companyId),
  ]);

  // depth 0 is the synthetic "Revenue"/"Expenses" root the chart-of-accounts
  // seed wraps every category in (see the "-GROUP" codes) — depth 1 is the
  // actual category (Shopify Sales, Marketing & Ads, Payroll, ...), already
  // rolled up to include its own children (e.g. Meta Ads under Marketing).
  const topLevel = (rows: AccountRollupRow[]) =>
    rows
      .filter((r) => r.depth === 1)
      .map((r) => ({ category: r.name, amount: r.amount }))
      .sort((a, b) => b.amount - a.amount);

  return {
    totalRevenue: pnl.totalRevenue,
    totalExpense: pnl.totalExpense,
    netProfit: pnl.netProfit,
    cashBalance: cashBalances.reduce((s, v) => s + v, 0),
    arOutstanding,
    apOutstanding,
    revenueByCategory: topLevel(pnl.revenue),
    expenseByCategory: topLevel(pnl.expense),
  };
}

export type MonthlyTrendPoint = { month: string; income: number; expense: number; net: number };

// Ledger-accurate month-by-month revenue/expense, for the Executive
// Dashboard trend chart — reads P&L account activity directly rather than
// the quick-add "simple entries" reconstruction the older Trends page uses.
export async function getMonthlyTrend(
  months: { start: Date; end: Date; label: string }[],
  companyId = DEFAULT_COMPANY_ID
): Promise<MonthlyTrendPoint[]> {
  return Promise.all(
    months.map(async ({ start, end, label }) => {
      const pnl = await getProfitAndLoss({ from: start, to: end }, companyId);
      return {
        month: label,
        income: pnl.totalRevenue,
        expense: pnl.totalExpense,
        net: pnl.netProfit,
      };
    })
  );
}

export type DailyTrendPoint = { day: string; income: number; expense: number; net: number };

// Day-by-day revenue/expense within a single range (typically the current
// month, up to today) -- one query for every REVENUE/EXPENSE line in range,
// bucketed by Cairo day in application code, rather than one getProfitAndLoss
// call per day.
export async function getDailyTrend(
  { from, to }: { from: Date; to: Date },
  companyId = DEFAULT_COMPANY_ID
): Promise<DailyTrendPoint[]> {
  const lines = await prisma.journalLine.findMany({
    where: {
      companyId,
      account: { type: { in: ["REVENUE", "EXPENSE"] } },
      journalEntry: { date: { gte: from, lte: to } },
    },
    select: { debit: true, credit: true, account: { select: { type: true } }, journalEntry: { select: { date: true } } },
  });

  const buckets = new Map<string, { income: number; expense: number }>();
  for (const line of lines) {
    const key = dateInputValue(line.journalEntry.date);
    const bucket = buckets.get(key) ?? { income: 0, expense: 0 };
    if (line.account.type === "REVENUE") bucket.income += Number(line.credit);
    else bucket.expense += Number(line.debit);
    buckets.set(key, bucket);
  }

  const points: DailyTrendPoint[] = [];
  const lastDay = startOfCairoDay(to).getTime() < startOfCairoDay(new Date()).getTime() ? startOfCairoDay(to) : startOfCairoDay(new Date());
  for (let cursor = startOfCairoDay(from); cursor.getTime() <= lastDay.getTime(); cursor = new Date(cursor.getTime() + 24 * 60 * 60 * 1000)) {
    const key = dateInputValue(cursor);
    const bucket = buckets.get(key) ?? { income: 0, expense: 0 };
    points.push({ day: String(Number(key.slice(-2))), income: bucket.income, expense: bucket.expense, net: bucket.income - bucket.expense });
  }
  return points;
}

const INVESTING_SUBTYPES = new Set(["FIXED_ASSET", "FIXED_ASSET_CONTRA"]);

export async function getCashFlowStatement(
  { from, to }: { from: Date; to: Date },
  companyId = DEFAULT_COMPANY_ID
) {
  const bankAccounts = await prisma.bankAccount.findMany({ where: { companyId }, include: { glAccount: true } });
  const cashAccountIds = new Set(bankAccounts.map((b) => b.glAccountId));
  if (cashAccountIds.size === 0) {
    return { operating: 0, investing: 0, financing: 0, netChange: 0, openingCash: 0, closingCash: 0 };
  }

  const entries = await prisma.journalEntry.findMany({
    where: { companyId, date: { gte: from, lte: to } },
    include: { lines: { include: { account: true } } },
  });

  let operating = 0;
  let investing = 0;
  let financing = 0;

  for (const entry of entries) {
    const cashLines = entry.lines.filter((l) => cashAccountIds.has(l.accountId));
    const otherLines = entry.lines.filter((l) => !cashAccountIds.has(l.accountId));
    if (cashLines.length === 0 || otherLines.length === 0) continue;

    const cashDelta = cashLines.reduce((sum, l) => sum + Number(l.debit) - Number(l.credit), 0);

    const bucket = otherLines.some((l) => INVESTING_SUBTYPES.has(l.account.subtype ?? ""))
      ? "investing"
      : otherLines.some((l) => l.account.type === "LIABILITY" || l.account.type === "EQUITY")
        ? "financing"
        : "operating";

    if (bucket === "investing") investing += cashDelta;
    else if (bucket === "financing") financing += cashDelta;
    else operating += cashDelta;
  }

  const openingActivity = await getOwnActivity(companyId, new Date(from.getTime() - 1));
  let openingCash = 0;
  for (const account of await getAllAccounts(companyId)) {
    if (!cashAccountIds.has(account.id)) continue;
    const own = openingActivity.get(account.id);
    if (own) openingCash += netBalance(account, own);
  }

  const netChange = operating + investing + financing;
  return { operating, investing, financing, netChange, openingCash, closingCash: openingCash + netChange };
}
