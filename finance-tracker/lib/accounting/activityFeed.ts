import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID } from "./company";

export type ActivityCategory = "expense" | "revenue" | "capital" | "payroll";

export type ActivityItem = {
  id: string;
  date: Date;
  label: string;
  sublabel: string | null;
  amount: number;
  direction: "in" | "out";
  category: ActivityCategory;
  emoji: string;
};

const EMOJI_KEYWORDS: [RegExp, string][] = [
  [/fabric|textile|material/, "🧵"],
  [/ship|courier|fulfillment|delivery/, "🚚"],
  [/photo|content|shoot/, "📸"],
  [/marketing|ads|campaign/, "📣"],
  [/software|subscription/, "💻"],
  [/rent|utilit|office/, "🏠"],
  [/bank|fee/, "🏦"],
  [/packag/, "📦"],
  [/shopify|sales|wholesale/, "🛍"],
];

function emojiFor(category: ActivityCategory, label: string, sublabel: string | null): string {
  if (category === "capital") return "💰";
  if (category === "payroll") return "👤";
  const haystack = `${label} ${sublabel ?? ""}`.toLowerCase();
  for (const [pattern, emoji] of EMOJI_KEYWORDS) {
    if (pattern.test(haystack)) return emoji;
  }
  return category === "revenue" ? "💵" : "💸";
}

// A plain-language read of what a journal entry "was" -- used by the
// Dashboard's recent-activity preview and the full Timeline screen. Reads
// JournalEntry directly rather than the quick-add "simple entries"
// reconstruction, so nothing posted through Bills, Invoices, Payroll,
// Inventory, or Shopify sync is invisible here.
export async function getRecentActivity(limit = 6, companyId = DEFAULT_COMPANY_ID): Promise<ActivityItem[]> {
  const entries = await prisma.journalEntry.findMany({
    where: { companyId },
    include: { lines: { include: { account: true, supplier: true, employee: true } } },
    orderBy: { date: "desc" },
    take: limit,
  });

  return entries.map((entry) => describeEntry(entry));
}

export async function getActivityDetail(id: string, companyId = DEFAULT_COMPANY_ID) {
  const entry = await prisma.journalEntry.findFirst({
    where: { id, companyId },
    include: { lines: { include: { account: true, supplier: true, employee: true, customer: true } } },
  });
  if (!entry) return null;

  const summary = describeEntry(entry);
  const supplier = entry.lines.find((l) => l.supplier)?.supplier?.name ?? null;
  const employee = entry.lines.find((l) => l.employee)?.employee?.name ?? null;
  const customer = entry.lines.find((l) => l.customer)?.customer?.name ?? null;
  // The real account name, independent of the summary label/sublabel (which
  // swap meaning depending on whether a supplier/employee is present) --
  // the detail page needs one unambiguous "category" field.
  const categoryName =
    entry.lines.find((l) => l.account.type === "REVENUE" || l.account.type === "EXPENSE")?.account.name ?? null;

  return { ...summary, memo: entry.memo, categoryName, supplier, employee, customer, source: entry.source };
}

type EntryWithLines = Awaited<ReturnType<typeof prisma.journalEntry.findMany>>[number] & {
  lines: Array<{
    account: { name: string; type: string; code: string };
    supplier: { name: string } | null;
    employee: { name: string } | null;
    debit: unknown;
    credit: unknown;
  }>;
};

// Several posting paths store memo as "" rather than omitting it (form
// fields default to empty strings, and `input.notes ?? fallback` only
// catches null/undefined, not ""). Treat blank memo as absent everywhere
// it's used as a fallback, so a label never renders as empty text.
function nonEmpty(value: string | null | undefined): string | null {
  return value && value.trim() ? value : null;
}

function describeEntry(entry: EntryWithLines): ActivityItem {
  const memo = nonEmpty(entry.memo);
  const equityLine = entry.lines.find((l) => l.account.code === "3000");
  const employeeName = entry.lines.find((l) => l.employee)?.employee?.name;
  const revenueLine = entry.lines.find((l) => l.account.type === "REVENUE");
  const expenseLine = entry.lines.find((l) => l.account.type === "EXPENSE");

  // Order matters: capital and payroll are more specific than "any expense
  // line", so they're checked first -- otherwise a payroll entry (which
  // debits an EXPENSE account) would just look like a generic expense.
  if (equityLine && Number(equityLine.credit) > 0) {
    const label = "Owner Capital";
    const sublabel = memo ?? "Contribution";
    return {
      id: entry.id,
      date: entry.date,
      label,
      sublabel,
      amount: Number(equityLine.credit),
      direction: "in",
      category: "capital",
      emoji: emojiFor("capital", label, sublabel),
    };
  }

  if (employeeName) {
    const line = entry.lines.find((l) => Number(l.debit) > 0);
    const label = `Paid ${employeeName}`;
    const sublabel = "Payroll";
    return {
      id: entry.id,
      date: entry.date,
      label,
      sublabel,
      amount: line ? Number(line.debit) : 0,
      direction: "out",
      category: "payroll",
      emoji: emojiFor("payroll", label, sublabel),
    };
  }

  if (revenueLine) {
    const label = entry.source === "SHOPIFY" ? "Shopify Revenue" : revenueLine.account.name;
    const sublabel = memo;
    return {
      id: entry.id,
      date: entry.date,
      label,
      sublabel,
      amount: Number(revenueLine.credit),
      direction: "in",
      category: "revenue",
      emoji: emojiFor("revenue", label, sublabel),
    };
  }

  if (expenseLine) {
    const supplierName = entry.lines.find((l) => l.supplier)?.supplier?.name;
    const label = supplierName ? `Paid ${supplierName}` : expenseLine.account.name;
    const sublabel = supplierName ? expenseLine.account.name : memo;
    return {
      id: entry.id,
      date: entry.date,
      label,
      sublabel,
      amount: Number(expenseLine.debit),
      direction: "out",
      category: "expense",
      emoji: emojiFor("expense", label, sublabel),
    };
  }

  const first = entry.lines[0];
  const direction: "in" | "out" = first && Number(first.debit) > Number(first.credit) ? "out" : "in";
  const label = memo ?? first?.account.name ?? "Entry";
  return {
    id: entry.id,
    date: entry.date,
    label,
    sublabel: null,
    amount: first ? Math.max(Number(first.debit), Number(first.credit)) : 0,
    direction,
    category: direction === "out" ? "expense" : "revenue",
    emoji: emojiFor(direction === "out" ? "expense" : "revenue", label, null),
  };
}
