import Link from "next/link";
import {
  startOfCairoMonth,
  endOfCairoMonth,
  startOfCairoQuarter,
  startOfCairoYear,
  addMonths,
  monthLabel,
  quarterLabel,
} from "@/lib/dates";
import { getExecutiveSummary, getMonthlyTrend } from "@/lib/accounting/reports";
import HeroMetric from "@/components/HeroMetric";
import KpiCards from "@/components/KpiCards";
import CategoryBarChart from "@/components/CategoryBarChart";
import PerformanceAreaChart from "@/components/PerformanceAreaChart";

export const dynamic = "force-dynamic";

const PERIODS = [
  { id: "this-month", label: "This Month" },
  { id: "last-month", label: "Last Month" },
  { id: "this-quarter", label: "This Quarter" },
  { id: "this-year", label: "This Year" },
] as const;

type PeriodId = (typeof PERIODS)[number]["id"];

function periodRange(period: PeriodId, now: Date): { from: Date; to: Date; label: string } {
  switch (period) {
    case "last-month": {
      const target = addMonths(now, -1);
      return { from: startOfCairoMonth(target), to: endOfCairoMonth(target), label: monthLabel(target) };
    }
    case "this-quarter": {
      const from = startOfCairoQuarter(now);
      return { from, to: addMonths(from, 3), label: quarterLabel(now) };
    }
    case "this-year": {
      const from = startOfCairoYear(now);
      return { from, to: addMonths(from, 12), label: String(now.getUTCFullYear()) };
    }
    case "this-month":
    default: {
      return { from: startOfCairoMonth(now), to: endOfCairoMonth(now), label: monthLabel(now) };
    }
  }
}

// The comparable period immediately before the selected one, for a
// period-over-period growth delta (e.g. "This Month" vs "Last Month").
function previousPeriodRange(period: PeriodId, now: Date): { from: Date; to: Date; label: string } {
  switch (period) {
    case "last-month": {
      const target = addMonths(now, -2);
      return { from: startOfCairoMonth(target), to: endOfCairoMonth(target), label: "the month before" };
    }
    case "this-quarter": {
      const from = addMonths(startOfCairoQuarter(now), -3);
      return { from, to: addMonths(from, 3), label: "last quarter" };
    }
    case "this-year": {
      const from = addMonths(startOfCairoYear(now), -12);
      return { from, to: addMonths(from, 12), label: "last year" };
    }
    case "this-month":
    default: {
      const target = addMonths(now, -1);
      return { from: startOfCairoMonth(target), to: endOfCairoMonth(target), label: "last month" };
    }
  }
}

function pctChange(current: number, previous: number): number | null {
  if (previous === 0) return current === 0 ? 0 : null;
  return ((current - previous) / Math.abs(previous)) * 100;
}

const TREND_MONTHS_BACK = 11;

export default async function PerformanceDashboard({
  searchParams,
}: {
  searchParams: Promise<{ period?: string }>;
}) {
  const { period: periodParam } = await searchParams;
  const period: PeriodId = PERIODS.some((p) => p.id === periodParam) ? (periodParam as PeriodId) : "this-month";

  const now = new Date();
  const { from, to, label } = periodRange(period, now);
  const previous = previousPeriodRange(period, now);

  const months: { start: Date; end: Date; label: string }[] = [];
  for (let i = TREND_MONTHS_BACK; i >= 0; i -= 1) {
    const d = addMonths(now, -i);
    months.push({ start: startOfCairoMonth(d), end: endOfCairoMonth(d), label: monthLabel(d) });
  }

  const [summary, previousSummary, trend] = await Promise.all([
    getExecutiveSummary({ from, to }),
    getExecutiveSummary({ from: previous.from, to: previous.to }),
    getMonthlyTrend(months),
  ]);

  const margin = summary.totalRevenue > 0 ? (summary.netProfit / summary.totalRevenue) * 100 : 0;
  const netProfitDelta = pctChange(summary.netProfit, previousSummary.netProfit);
  const revenueDelta = pctChange(summary.totalRevenue, previousSummary.totalRevenue);
  const expenseDelta = pctChange(summary.totalExpense, previousSummary.totalExpense);

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-6 text-lg tracking-widest uppercase">Performance</h1>

      <div className="mb-4 flex gap-4 overflow-x-auto text-xs uppercase tracking-widest">
        {PERIODS.map((p) => (
          <Link
            key={p.id}
            href={`/dashboard/performance?period=${p.id}`}
            className={`shrink-0 pb-1 ${p.id === period ? "border-b border-ink text-ink" : "text-muted"}`}
          >
            {p.label}
          </Link>
        ))}
      </div>
      <p className="mb-6 text-xs text-muted">{label}</p>

      <HeroMetric
        label="Net Profit"
        value={summary.netProfit}
        delta={netProfitDelta}
        sublabel={`vs ${previous.label}`}
      />

      <KpiCards
        kpis={[
          { label: "Revenue", value: summary.totalRevenue, tone: "income", delta: revenueDelta },
          { label: "Expenses", value: summary.totalExpense, tone: "expense", delta: expenseDelta },
          { label: "Margin", value: margin, tone: margin >= 0 ? "income" : "expense", format: "percent" },
        ]}
      />

      <p className="mb-2 text-xs uppercase tracking-widest text-muted">Revenue vs Expense, last 12 months</p>
      <div className="mb-8 rounded-2xl border border-hairline p-3 shadow-sm">
        <PerformanceAreaChart data={trend} />
      </div>

      <p className="mb-2 text-xs uppercase tracking-widest text-muted">Revenue by category ({label})</p>
      <div className="mb-8">
        {summary.revenueByCategory.length === 0 ? (
          <p className="py-6 text-sm text-muted">No revenue this period.</p>
        ) : (
          <CategoryBarChart data={summary.revenueByCategory} />
        )}
      </div>

      <p className="mb-2 text-xs uppercase tracking-widest text-muted">Expenses by category ({label})</p>
      <CategoryBarChart data={summary.expenseByCategory} />
    </div>
  );
}
