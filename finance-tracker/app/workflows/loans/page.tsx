import { prisma } from "@/lib/prisma";
import { DEFAULT_COMPANY_ID } from "@/lib/accounting/company";
import LoansScreen from "@/components/LoansScreen";

export const dynamic = "force-dynamic";

export default async function LoansPage() {
  const [liabilityAccounts, bankAccounts] = await Promise.all([
    prisma.account.findMany({
      where: { companyId: DEFAULT_COMPANY_ID, isActive: true, type: "LIABILITY" },
      orderBy: { name: "asc" },
    }),
    prisma.bankAccount.findMany({ where: { companyId: DEFAULT_COMPANY_ID, isActive: true }, orderBy: { name: "asc" } }),
  ]);

  return (
    <LoansScreen
      liabilityAccounts={liabilityAccounts.map((a) => ({ id: a.id, name: a.name }))}
      bankAccounts={bankAccounts.map((b) => ({ id: b.id, name: b.name }))}
    />
  );
}
