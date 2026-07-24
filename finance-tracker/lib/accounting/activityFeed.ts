import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID } from "./company";

export type ActivityItem = {
  id: string;
  date: Date;
  label: string;
  sublabel: string | null;
  amount: number;
  direction: "in" | "out";
};

// A plain-language read of what a journal entry "was", for the Dashboard's
// recent-activity preview (and reused by the full Timeline in a later
// milestone). Reads JournalEntry directly rather than the quick-add
// "simple entries" reconstruction, so nothing posted through Bills,
// Invoices, Payroll, Inventory, or Shopify sync is invisible here.
export async function getRecentActivity(limit = 6, companyId = DEFAULT_COMPANY_ID): Promise<ActivityItem[]> {
  const entries = await prisma.journalEntry.findMany({
    where: { companyId },
    include: { lines: { include: { account: true, supplier: true, employee: true } } },
    orderBy: { date: "desc" },
    take: limit,
  });

  return entries.map((entry) => describeEntry(entry));
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

function describeEntry(entry: EntryWithLines): ActivityItem {
  const revenueLine = entry.lines.find((l) => l.account.type === "REVENUE");
  const expenseLine = entry.lines.find((l) => l.account.type === "EXPENSE");
  const equityLine = entry.lines.find((l) => l.account.code === "3000");

  if (revenueLine) {
    return {
      id: entry.id,
      date: entry.date,
      label: entry.source === "SHOPIFY" ? "Shopify Revenue" : revenueLine.account.name,
      sublabel: entry.memo,
      amount: Number(revenueLine.credit),
      direction: "in",
    };
  }

  if (expenseLine) {
    const supplierName = entry.lines.find((l) => l.supplier)?.supplier?.name;
    return {
      id: entry.id,
      date: entry.date,
      label: supplierName ? `Paid ${supplierName}` : expenseLine.account.name,
      sublabel: supplierName ? expenseLine.account.name : entry.memo,
      amount: Number(expenseLine.debit),
      direction: "out",
    };
  }

  if (equityLine && Number(equityLine.credit) > 0) {
    return {
      id: entry.id,
      date: entry.date,
      label: "Owner Capital",
      sublabel: entry.memo ?? "Contribution",
      amount: Number(equityLine.credit),
      direction: "in",
    };
  }

  const employeeName = entry.lines.find((l) => l.employee)?.employee?.name;
  if (employeeName) {
    const line = entry.lines.find((l) => Number(l.debit) > 0);
    return {
      id: entry.id,
      date: entry.date,
      label: `Paid ${employeeName}`,
      sublabel: "Payroll",
      amount: line ? Number(line.debit) : 0,
      direction: "out",
    };
  }

  const first = entry.lines[0];
  return {
    id: entry.id,
    date: entry.date,
    label: entry.memo ?? first?.account.name ?? "Entry",
    sublabel: null,
    amount: first ? Math.max(Number(first.debit), Number(first.credit)) : 0,
    direction: first && Number(first.debit) > Number(first.credit) ? "out" : "in",
  };
}
