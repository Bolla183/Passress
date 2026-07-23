import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID } from "./company";
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
