import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID } from "./company";
import { getAccountByCode, postJournalEntry } from "./ledger";
import { DEFAULT_CASH_ACCOUNT_CODE } from "./chartOfAccountsSeed";

// The mobile quick-add form and the daily/monthly/trends dashboards don't
// need to know about the ledger's debit/credit structure — this module is
// the simple "type + category + amount" view on top of the double-entry
// engine, reconstructed by finding the non-cash side of a two-line entry.
// Categories are just accounts flagged showInQuickAdd — adding a new one
// via the Chart of Accounts screen makes it show up here with no code
// change.

export type SimpleEntry = {
  id: string;
  date: Date;
  type: "INCOME" | "EXPENSE";
  category: string;
  amount: number;
  note: string | null;
  source: string;
};

// COGS accounts (children of "COGS / Inventory", 5000) are the ones a cost
// can actually be attributed to a specific garment -- Rent or Marketing
// can't, so only these surface the optional Product picker on the Add
// screen.
const COGS_PARENT_CODE = "5000";

export async function getQuickAddAccounts(companyId = DEFAULT_COMPANY_ID) {
  const [accounts, products] = await Promise.all([
    prisma.account.findMany({
      where: { companyId, showInQuickAdd: true, isActive: true },
      include: { parent: true },
      orderBy: { name: "asc" },
    }),
    prisma.product.findMany({
      where: { companyId, isActive: true },
      orderBy: { name: "asc" },
    }),
  ]);

  return {
    income: accounts
      .filter((a) => a.type === "REVENUE")
      .map((a) => ({ id: a.id, name: a.name })),
    expense: accounts
      .filter((a) => a.type === "EXPENSE")
      .map((a) => ({ id: a.id, name: a.name, needsProduct: a.parent?.code === COGS_PARENT_CODE })),
    products: products.map((p) => ({ id: p.id, name: p.name })),
  };
}

export async function postQuickEntry(input: {
  accountId: string;
  amount: number;
  date: Date;
  note?: string;
  source?: "MANUAL" | "SHOPIFY";
  reference?: string;
  companyId?: string;
  productId?: string;
}): Promise<SimpleEntry> {
  const companyId = input.companyId ?? DEFAULT_COMPANY_ID;

  const [cash, target, product] = await Promise.all([
    getAccountByCode(DEFAULT_CASH_ACCOUNT_CODE, companyId),
    prisma.account.findUnique({ where: { id: input.accountId } }),
    input.productId ? prisma.product.findUnique({ where: { id: input.productId } }) : null,
  ]);
  if (!target || target.companyId !== companyId) {
    throw new Error("Unknown account");
  }
  if (target.type !== "REVENUE" && target.type !== "EXPENSE") {
    throw new Error("Quick-add only supports income/expense accounts");
  }
  if (input.productId && (!product || product.companyId !== companyId)) {
    throw new Error("Unknown product");
  }

  const isIncome = target.type === "REVENUE";

  const entry = await postJournalEntry({
    companyId,
    date: input.date,
    memo: input.note,
    source: input.source ?? "MANUAL",
    reference: input.reference,
    lines: isIncome
      ? [
          { accountId: cash.id, debit: input.amount },
          { accountId: target.id, credit: input.amount, productId: product?.id },
        ]
      : [
          { accountId: target.id, debit: input.amount, productId: product?.id },
          { accountId: cash.id, credit: input.amount },
        ],
  });

  return {
    id: entry.id,
    date: entry.date,
    type: isIncome ? "INCOME" : "EXPENSE",
    category: target.name,
    amount: input.amount,
    note: entry.memo,
    source: entry.source,
  };
}

export async function deleteQuickEntry(journalEntryId: string) {
  await prisma.journalEntry.delete({ where: { id: journalEntryId } }).catch(() => null);
}

export async function listSimpleEntries(
  { from, to }: { from?: Date; to?: Date },
  companyId = DEFAULT_COMPANY_ID
): Promise<SimpleEntry[]> {
  const cash = await getAccountByCode(DEFAULT_CASH_ACCOUNT_CODE, companyId);

  const entries = await prisma.journalEntry.findMany({
    where: {
      companyId,
      date: { ...(from ? { gte: from } : {}), ...(to ? { lt: to } : {}) },
    },
    include: { lines: { include: { account: true } } },
    orderBy: { date: "desc" },
  });

  const result: SimpleEntry[] = [];
  for (const entry of entries) {
    if (entry.lines.length !== 2) continue;
    const cashLine = entry.lines.find((l) => l.accountId === cash.id);
    const otherLine = entry.lines.find((l) => l.accountId !== cash.id);
    if (!cashLine || !otherLine) continue;

    const isIncome = Number(cashLine.debit) > 0;
    result.push({
      id: entry.id,
      date: entry.date,
      type: isIncome ? "INCOME" : "EXPENSE",
      category: otherLine.account.name,
      amount: isIncome ? Number(cashLine.debit) : Number(cashLine.credit),
      note: entry.memo,
      source: entry.source,
    });
  }

  return result;
}
