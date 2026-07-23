import { prisma } from "@/lib/prisma";
import { getGeneralLedger } from "@/lib/accounting/reports";
import { formatEGP } from "@/lib/currency";

export const dynamic = "force-dynamic";

export default async function GeneralLedgerAccountPage({
  params,
}: {
  params: Promise<{ accountId: string }>;
}) {
  const { accountId } = await params;
  const account = await prisma.account.findUnique({ where: { id: accountId } });
  if (!account) {
    return <div className="mx-auto max-w-lg px-6 pt-10 text-sm text-muted">Account not found.</div>;
  }

  const lines = await getGeneralLedger(accountId, { to: new Date() });

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-1 text-lg tracking-widest uppercase">{account.name}</h1>
      <p className="mb-6 text-xs uppercase tracking-widest text-muted">{account.code} · All time</p>

      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-hairline text-xs uppercase tracking-widest text-muted">
            <th className="py-2 text-left font-normal">Date</th>
            <th className="py-2 text-left font-normal">Memo</th>
            <th className="py-2 text-right font-normal">Debit</th>
            <th className="py-2 text-right font-normal">Credit</th>
            <th className="py-2 text-right font-normal">Balance</th>
          </tr>
        </thead>
        <tbody>
          {lines.map((line) => (
            <tr key={line.id} className="border-b border-hairline">
              <td className="py-2 whitespace-nowrap">
                {line.date.toLocaleDateString("en-GB", { timeZone: "UTC" })}
              </td>
              <td className="py-2 text-muted">{line.memo ?? ""}</td>
              <td className="py-2 text-right">{line.debit ? formatEGP(line.debit) : ""}</td>
              <td className="py-2 text-right">{line.credit ? formatEGP(line.credit) : ""}</td>
              <td className="py-2 text-right">{formatEGP(line.runningBalance)}</td>
            </tr>
          ))}
          {lines.length === 0 && (
            <tr>
              <td colSpan={5} className="py-6 text-center text-muted">
                No activity yet.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
