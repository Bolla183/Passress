import { getBalanceSheet } from "@/lib/accounting/reports";
import { formatEGP } from "@/lib/currency";
import Rows from "@/components/AccountRollupRows";

export const dynamic = "force-dynamic";

export default async function BalanceSheetPage() {
  const sheet = await getBalanceSheet(new Date());
  const balances = sheet.totalAssets - (sheet.totalLiabilities + sheet.totalEquity);

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-1 text-lg tracking-widest uppercase">Balance Sheet</h1>
      <p className="mb-6 text-xs uppercase tracking-widest text-muted">As of today</p>

      <table className="w-full text-sm">
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

      {Math.abs(balances) > 0.5 && (
        <p className="mt-4 text-xs text-expense">
          Out of balance by {formatEGP(Math.abs(balances))} — check for entries outside the chart of accounts.
        </p>
      )}
    </div>
  );
}
