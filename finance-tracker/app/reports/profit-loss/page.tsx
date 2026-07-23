import Link from "next/link";
import { startOfCairoMonth, endOfCairoMonth, addMonths, monthLabel } from "@/lib/dates";
import { getProfitAndLoss } from "@/lib/accounting/reports";
import { formatEGP } from "@/lib/currency";
import Rows from "@/components/AccountRollupRows";

export const dynamic = "force-dynamic";

export default async function ProfitLossPage({
  searchParams,
}: {
  searchParams: Promise<{ month?: string }>;
}) {
  const { month } = await searchParams;
  const selected = month ? new Date(`${month}-01T00:00:00Z`) : new Date();
  const from = startOfCairoMonth(selected);
  const to = endOfCairoMonth(selected);

  const report = await getProfitAndLoss({ from, to });

  const dateParam = (d: Date) => `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
  const isCurrentMonth = to > new Date();

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

      <table className="w-full text-sm">
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
    </div>
  );
}
