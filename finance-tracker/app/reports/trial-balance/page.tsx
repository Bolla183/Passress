import { getTrialBalance } from "@/lib/accounting/reports";
import { formatEGP } from "@/lib/currency";

export const dynamic = "force-dynamic";

export default async function TrialBalancePage() {
  const rows = await getTrialBalance(new Date());
  const totalDebit = rows.reduce((s, r) => s + r.debitBalance, 0);
  const totalCredit = rows.reduce((s, r) => s + r.creditBalance, 0);

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-1 text-lg tracking-widest uppercase">Trial Balance</h1>
      <p className="mb-6 text-xs uppercase tracking-widest text-muted">As of today</p>

      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-hairline text-xs uppercase tracking-widest text-muted">
            <th className="py-2 text-left font-normal">Account</th>
            <th className="py-2 text-right font-normal">Debit</th>
            <th className="py-2 text-right font-normal">Credit</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.accountId} className="border-b border-hairline">
              <td className="py-2">
                <span className="text-muted">{row.code}</span> {row.name}
              </td>
              <td className="py-2 text-right">{row.debitBalance ? formatEGP(row.debitBalance) : ""}</td>
              <td className="py-2 text-right">{row.creditBalance ? formatEGP(row.creditBalance) : ""}</td>
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr className="font-medium">
            <td className="pt-3">Total</td>
            <td className="pt-3 text-right">{formatEGP(totalDebit)}</td>
            <td className="pt-3 text-right">{formatEGP(totalCredit)}</td>
          </tr>
        </tfoot>
      </table>
    </div>
  );
}
