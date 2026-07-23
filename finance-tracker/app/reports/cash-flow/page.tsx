import Link from "next/link";
import { startOfCairoMonth, endOfCairoMonth, addMonths, monthLabel } from "@/lib/dates";
import { getCashFlowStatement } from "@/lib/accounting/reports";
import { formatEGP } from "@/lib/currency";

export const dynamic = "force-dynamic";

export default async function CashFlowPage({
  searchParams,
}: {
  searchParams: Promise<{ month?: string }>;
}) {
  const { month } = await searchParams;
  const selected = month ? new Date(`${month}-01T00:00:00Z`) : new Date();
  const from = startOfCairoMonth(selected);
  const to = endOfCairoMonth(selected);

  const cashFlow = await getCashFlowStatement({ from, to });

  const dateParam = (d: Date) => `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
  const isCurrentMonth = to > new Date();

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <div className="mb-6 flex items-center justify-between">
        <Link href={`/reports/cash-flow?month=${dateParam(addMonths(selected, -1))}`} className="text-sm text-muted">
          ←
        </Link>
        <div className="text-center">
          <h1 className="text-lg tracking-widest uppercase">Cash Flow</h1>
          <p className="text-xs uppercase tracking-widest text-muted">{monthLabel(selected)}</p>
        </div>
        {isCurrentMonth ? (
          <span className="w-4" />
        ) : (
          <Link href={`/reports/cash-flow?month=${dateParam(addMonths(selected, 1))}`} className="text-sm text-muted">
            →
          </Link>
        )}
      </div>

      <table className="w-full text-sm">
        <tbody>
          <tr className="border-b border-hairline">
            <td className="py-2">Opening Cash</td>
            <td className="py-2 text-right">{formatEGP(cashFlow.openingCash)}</td>
          </tr>
          <tr className="border-b border-hairline">
            <td className="py-2">Operating Activities</td>
            <td className="py-2 text-right">{formatEGP(cashFlow.operating)}</td>
          </tr>
          <tr className="border-b border-hairline">
            <td className="py-2">Investing Activities</td>
            <td className="py-2 text-right">{formatEGP(cashFlow.investing)}</td>
          </tr>
          <tr className="border-b border-hairline">
            <td className="py-2">Financing Activities</td>
            <td className="py-2 text-right">{formatEGP(cashFlow.financing)}</td>
          </tr>
          <tr className="font-medium">
            <td className="py-2">Net Change in Cash</td>
            <td className="py-2 text-right">{formatEGP(cashFlow.netChange)}</td>
          </tr>
          <tr className="border-t border-ink font-medium">
            <td className="pt-3">Closing Cash</td>
            <td className="pt-3 text-right">{formatEGP(cashFlow.closingCash)}</td>
          </tr>
        </tbody>
      </table>
    </div>
  );
}
