import { prisma } from "@/lib/prisma";
import { startOfCairoDay, endOfCairoDay } from "@/lib/dates";
import SummaryCards from "@/components/SummaryCards";
import TransactionList from "@/components/TransactionList";
import SyncButton from "@/components/SyncButton";

export const dynamic = "force-dynamic";

export default async function DailyDashboard() {
  const now = new Date();
  const start = startOfCairoDay(now);
  const end = endOfCairoDay(now);

  const transactions = await prisma.transaction.findMany({
    where: { date: { gte: start, lt: end } },
    orderBy: { date: "desc" },
  });

  const income = transactions
    .filter((t) => t.type === "INCOME")
    .reduce((sum, t) => sum + Number(t.amount), 0);
  const expense = transactions
    .filter((t) => t.type === "EXPENSE")
    .reduce((sum, t) => sum + Number(t.amount), 0);

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-lg tracking-widest uppercase">Today</h1>
        <SyncButton />
      </div>

      <SummaryCards income={income} expense={expense} />

      <p className="mb-2 text-xs uppercase tracking-widest text-muted">Entries</p>
      <TransactionList
        transactions={transactions.map((t) => ({
          ...t,
          amount: Number(t.amount),
          date: t.date.toISOString(),
        }))}
      />
    </div>
  );
}
