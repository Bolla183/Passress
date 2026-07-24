import Link from "next/link";
import { startOfCairoMonth, endOfCairoMonth, addMonths, monthLabel } from "@/lib/dates";
import { getProfitAndLoss } from "@/lib/accounting/reports";
import { formatEGP } from "@/lib/currency";
import HeroMetric from "@/components/HeroMetric";
import KpiCards from "@/components/KpiCards";
import CategoryBarChart from "@/components/CategoryBarChart";
import Rows from "@/components/AccountRollupRows";

export const dynamic = "force-dynamic";

function pctChange(current: number, previous: number): number | null {
  if (previous === 0) return current === 0 ? 0 : null;
  return ((current - previous) / Math.abs(previous)) * 100;
}

export default async function ProfitLossPage({
  searchParams,
}: {
  searchParams: Promise<{ month?: string }>;
}) {
  const { month } = await searchParams;
  const selected = month ? new Date(`${month}-01T00:00:00Z`) : new Date();
  const from = startOfCairoMonth(selected);
  const to = endOfCairoMonth(selected);
  const lastMonthDate = addMonths(selected, -1);

  const [report, previous] = await Promise.all([
    getProfitAndLoss({ from, to }),
    getProfitAndLoss({ from: startOfCairoMonth(lastMonthDate), to: endOfCairoMonth(lastMonthDate) }),
  ]);

  const dateParam = (d: Date) => `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
  const isCurrentMonth = to > new Date();

  const topExpenses = report.expense
    .filter((r) => !r.code.endsWith("-GROUP") && r.depth === 1)
    .sort((a, b) => b.amount - a.amount)
    .slice(0, 6)
    .map((r) => ({ category: r.name, amount: r.amount }));

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <div className="mb-6 flex items-center justify-between">
        <Link href={`/reports/profit-loss?month=${dateParam(addMonths(selected, -1))}`} className="text-sm text-muted">
          ←
        </Link>
        <div className="text-center">
          <h1 className="text-lg tracking-widest uppercase">Profit &amp; Loss</h1>
          <p className="text-xs uppercase tracking-widest text-muted">{monthLabel(selected)}</p>
        </div>
        {isCurrentMonth ? (
          <span className="w-4" />
        ) : (
          <Link href={`/reports/profit-loss?month=${dateParam(addMonths(selected, 1))}`} className="text-sm text-muted">
            →
          </Link>
        )}
      </div>

      <HeroMetric
        label="Net Profit"
        value={report.netProfit}
        delta={pctChange(report.netProfit, previous.netProfit)}
        sublabel="vs last month"
      />

      <KpiCards
        columns={2}
        kpis={[
          { label: "Revenue", value: report.totalRevenue, tone: "income", delta: pctChange(report.totalRevenue, previous.totalRevenue) },
          { label: "Expenses", value: report.totalExpense, tone: "expense", delta: pctChange(report.totalExpense, previous.totalExpense) },
        ]}
      />

      <p className="mb-2 text-xs uppercase tracking-widest text-muted">Where the money went</p>
      <div className="mb-6 rounded-2xl border border-hairline p-3 shadow-sm">
        <CategoryBarChart data={topExpenses} />
      </div>

      <p className="mb-8 text-sm text-muted">
        You earned {formatEGP(report.totalRevenue)} and spent {formatEGP(report.totalExpense)}, {report.netProfit >= 0 ? "leaving a profit of" : "a loss of"}{" "}
        <span className={report.netProfit >= 0 ? "text-income" : "text-expense"}>{formatEGP(Math.abs(report.netProfit))}</span>.
      </p>

      <details className="mb-8">
        <summary className="cursor-pointer text-xs uppercase tracking-widest text-muted">Full breakdown</summary>
        <table className="mt-4 w-full text-sm">
          <tbody>
            <tr>
              <td className="pt-2 pb-1 text-xs uppercase tracking-widest text-muted">Revenue</td>
              <td></td>
            </tr>
            <Rows rows={report.revenue} />
            <tr className="font-medium">
              <td className="py-2">Total Revenue</td>
              <td className="py-2 text-right">{formatEGP(report.totalRevenue)}</td>
            </tr>

            <tr>
              <td className="pt-6 pb-1 text-xs uppercase tracking-widest text-muted">Expenses</td>
              <td></td>
            </tr>
            <Rows rows={report.expense} />
            <tr className="font-medium">
              <td className="py-2">Total Expenses</td>
              <td className="py-2 text-right">{formatEGP(report.totalExpense)}</td>
            </tr>

            <tr className="border-t border-ink font-medium">
              <td className="pt-3">Net Profit</td>
              <td className={`pt-3 text-right ${report.netProfit >= 0 ? "text-income" : "text-expense"}`}>
                {formatEGP(report.netProfit)}
              </td>
            </tr>
          </tbody>
        </table>
      </details>
    </div>
  );
}
