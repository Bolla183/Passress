import { startOfCairoMonth, endOfCairoMonth, addMonths, monthLabel } from "@/lib/dates";
import { listSimpleEntries } from "@/lib/accounting/quickEntry";
import TrendLineChart from "@/components/TrendLineChart";

export const dynamic = "force-dynamic";

const MONTHS_BACK = 11;

export default async function TrendsDashboard() {
  const now = new Date();
  const rangeStart = startOfCairoMonth(addMonths(now, -MONTHS_BACK));
  const rangeEnd = endOfCairoMonth(now);

  const transactions = await listSimpleEntries({ from: rangeStart, to: rangeEnd });

  const months: { start: Date; end: Date; label: string }[] = [];
  for (let i = MONTHS_BACK; i >= 0; i -= 1) {
    const d = addMonths(now, -i);
    months.push({
      start: startOfCairoMonth(d),
      end: endOfCairoMonth(d),
      label: monthLabel(d),
    });
  }

  const data = months.map(({ start, end, label }) => {
    const inRange = transactions.filter((t) => t.date >= start && t.date < end);
    const income = inRange
      .filter((t) => t.type === "INCOME")
      .reduce((s, t) => s + t.amount, 0);
    const expense = inRange
      .filter((t) => t.type === "EXPENSE")
      .reduce((s, t) => s + t.amount, 0);
    return { month: label, income, expense, net: income - expense };
  });

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-6 text-lg tracking-widest uppercase">Trends</h1>
      <p className="mb-4 text-xs uppercase tracking-widest text-muted">
        Last {MONTHS_BACK + 1} months
      </p>
      <TrendLineChart data={data} />
    </div>
  );
}
