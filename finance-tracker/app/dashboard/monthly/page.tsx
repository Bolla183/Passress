import Link from "next/link";
import {
  startOfCairoMonth,
  endOfCairoMonth,
  addMonths,
  monthLabel,
} from "@/lib/dates";
import { listSimpleEntries } from "@/lib/accounting/quickEntry";
import SummaryCards from "@/components/SummaryCards";
import CategoryBarChart from "@/components/CategoryBarChart";
import { formatEGP } from "@/lib/currency";

export const dynamic = "force-dynamic";

function pctChange(current: number, previous: number): string {
  if (previous === 0) return current === 0 ? "0%" : "+100%";
  const change = ((current - previous) / previous) * 100;
  return `${change >= 0 ? "+" : ""}${change.toFixed(0)}%`;
}

export default async function MonthlyDashboard({
  searchParams,
}: {
  searchParams: Promise<{ month?: string }>;
}) {
  const { month } = await searchParams;
  const selected = month ? new Date(`${month}-01T00:00:00Z`) : new Date();

  const start = startOfCairoMonth(selected);
  const end = endOfCairoMonth(selected);
  const prevStart = startOfCairoMonth(addMonths(selected, -1));
  const prevEnd = endOfCairoMonth(addMonths(selected, -1));
  const nextMonthStart = addMonths(selected, 1);

  const [current, previous] = await Promise.all([
    listSimpleEntries({ from: start, to: end }),
    listSimpleEntries({ from: prevStart, to: prevEnd }),
  ]);

  const sumBy = (list: typeof current, type: "INCOME" | "EXPENSE") =>
    list.filter((t) => t.type === type).reduce((s, t) => s + t.amount, 0);

  const income = sumBy(current, "INCOME");
  const expense = sumBy(current, "EXPENSE");
  const prevIncome = sumBy(previous, "INCOME");
  const prevExpense = sumBy(previous, "EXPENSE");

  const categoryTotals = new Map<string, number>();
  current
    .filter((t) => t.type === "EXPENSE")
    .forEach((t) => {
      categoryTotals.set(t.category, (categoryTotals.get(t.category) ?? 0) + t.amount);
    });
  const categoryData = Array.from(categoryTotals, ([category, amount]) => ({
    category,
    amount,
  })).sort((a, b) => b.amount - a.amount);

  const prevMonthParam = dateParam(addMonths(selected, -1));
  const nextMonthParam = dateParam(nextMonthStart);
  const isCurrentMonth = end > new Date();

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <div className="mb-6 flex items-center justify-between">
        <Link href={`/dashboard/monthly?month=${prevMonthParam}`} className="text-sm text-muted">
          ←
        </Link>
        <h1 className="text-lg tracking-widest uppercase">{monthLabel(selected)}</h1>
        {isCurrentMonth ? (
          <span className="w-4" />
        ) : (
          <Link href={`/dashboard/monthly?month=${nextMonthParam}`} className="text-sm text-muted">
            →
          </Link>
        )}
      </div>

      <SummaryCards income={income} expense={expense} />

      <div className="mb-8 grid grid-cols-2 gap-4 text-sm">
        <div>
          <p className="text-xs uppercase tracking-widest text-muted">vs last month, income</p>
          <p>{pctChange(income, prevIncome)} <span className="text-muted">({formatEGP(prevIncome)} prior)</span></p>
        </div>
        <div>
          <p className="text-xs uppercase tracking-widest text-muted">vs last month, expense</p>
          <p>{pctChange(expense, prevExpense)} <span className="text-muted">({formatEGP(prevExpense)} prior)</span></p>
        </div>
      </div>

      <p className="mb-2 text-xs uppercase tracking-widest text-muted">Expenses by category</p>
      <CategoryBarChart data={categoryData} />
    </div>
  );
}

function dateParam(date: Date): string {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
}
