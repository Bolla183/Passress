import Link from "next/link";
import { prisma } from "@/lib/prisma";
import { DEFAULT_COMPANY_ID } from "@/lib/accounting/company";

export const dynamic = "force-dynamic";

export default async function GeneralLedgerIndex() {
  const accounts = await prisma.account.findMany({
    where: { companyId: DEFAULT_COMPANY_ID, isActive: true },
    orderBy: { code: "asc" },
  });

  return (
    <div className="mx-auto max-w-lg px-6 pt-10">
      <h1 className="mb-6 text-lg tracking-widest uppercase">General Ledger</h1>
      <p className="mb-4 text-xs uppercase tracking-widest text-muted">Choose an account</p>
      <ul>
        {accounts.map((account) => (
          <li key={account.id} className="border-b border-hairline">
            <Link
              href={`/reports/general-ledger/${account.id}`}
              className="flex items-center justify-between py-3 text-sm"
            >
              <span>
                <span className="text-muted">{account.code}</span> {account.name}
              </span>
              <span className="text-muted">→</span>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
