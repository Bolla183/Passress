import type { AccountRollupRow } from "@/lib/accounting/reports";
import { formatEGP } from "@/lib/currency";

export default function AccountRollupRows({ rows }: { rows: AccountRollupRow[] }) {
  return (
    <>
      {rows.map((row) => (
        <tr key={row.accountId} className="border-b border-hairline">
          <td className="py-2" style={{ paddingLeft: `${row.depth * 16}px` }}>
            {!row.code.endsWith("-GROUP") && <span className="text-muted">{row.code}</span>} {row.name}
          </td>
          <td className="py-2 text-right">{formatEGP(row.amount)}</td>
        </tr>
      ))}
    </>
  );
}
