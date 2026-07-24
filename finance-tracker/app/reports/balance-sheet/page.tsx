import { getBalanceSheet } from "@/lib/accounting/reports";
import { formatEGP } from "@/lib/currency";
import HeroMetric from "@/components/HeroMetric";
import KpiCards from "@/components/KpiCards";
import CategoryBarChart from "@/components/CategoryBarChart";
import Rows from "@/components/AccountRollupRows";

export const dynamic = "force-dynamic";

export default async function BalanceSheetPage() {
  const sheet = await getBalanceSheet(new Date());
  const balances = sheet.totalAssets - (sheet.totalLiabilities + sheet.totalEquity);

  const composition = [
    { category: "Assets", amount: sheet.totalAssets },
    { category: "Liabilities", amount: sheet.totalLiabilities },
    { category: "Equity", amount: sheet.totalEquity },
  ];

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-1 text-lg tracking-widest uppercase">Balance Sheet</h1>
      <p className="mb-6 text-xs uppercase tracking-widest text-muted">As of today</p>

      <HeroMetric label="Owner Equity" value={sheet.totalEquity} sublabel="what the business is worth to you" />

      <KpiCards
        kpis={[
          { label: "Assets", value: sheet.totalAssets, tone: "income" },
          { label: "Liabilities", value: sheet.totalLiabilities, tone: "expense" },
          { label: "Equity", value: sheet.totalEquity },
        ]}
      />

      <p className="mb-2 text-xs uppercase tracking-widest text-muted">Assets vs liabilities vs equity</p>
      <div className="mb-6 rounded-2xl border border-hairline p-3 shadow-sm">
        <CategoryBarChart data={composition} />
      </div>

      <p className="mb-8 text-sm text-muted">
        You own {formatEGP(sheet.totalAssets)} and owe {formatEGP(sheet.totalLiabilities)}, leaving{" "}
        <span className={sheet.totalEquity >= 0 ? "text-income" : "text-expense"}>{formatEGP(sheet.totalEquity)}</span> in owner
        equity.
      </p>

      <details className="mb-8">
        <summary className="cursor-pointer text-xs uppercase tracking-widest text-muted">Full breakdown</summary>
        <table className="mt-4 w-full text-sm">
          <tbody>
            <tr>
              <td className="pb-1 text-xs uppercase tracking-widest text-muted">Assets</td>
              <td></td>
            </tr>
            <Rows rows={sheet.assets} />
            <tr className="font-medium">
              <td className="py-2">Total Assets</td>
              <td className="py-2 text-right">{formatEGP(sheet.totalAssets)}</td>
            </tr>

            <tr>
              <td className="pt-6 pb-1 text-xs uppercase tracking-widest text-muted">Liabilities</td>
              <td></td>
            </tr>
            <Rows rows={sheet.liabilities} />
            <tr className="font-medium">
              <td className="py-2">Total Liabilities</td>
              <td className="py-2 text-right">{formatEGP(sheet.totalLiabilities)}</td>
            </tr>

            <tr>
              <td className="pt-6 pb-1 text-xs uppercase tracking-widest text-muted">Equity</td>
              <td></td>
            </tr>
            <Rows rows={sheet.equity} />
            <tr>
              <td className="py-2 text-muted">Net Income (current)</td>
              <td className="py-2 text-right text-muted">{formatEGP(sheet.netIncome)}</td>
            </tr>
            <tr className="font-medium">
              <td className="py-2">Total Equity</td>
              <td className="py-2 text-right">{formatEGP(sheet.totalEquity)}</td>
            </tr>

            <tr className="border-t border-ink font-medium">
              <td className="pt-3">Liabilities + Equity</td>
              <td className="pt-3 text-right">{formatEGP(sheet.totalLiabilities + sheet.totalEquity)}</td>
            </tr>
          </tbody>
        </table>
      </details>

      {Math.abs(balances) > 0.5 && (
        <p className="mt-4 text-xs text-expense">
          Out of balance by {formatEGP(Math.abs(balances))} — check for entries outside the chart of accounts.
        </p>
      )}
    </div>
  );
}
