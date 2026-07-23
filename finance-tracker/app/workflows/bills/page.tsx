import { prisma } from "@/lib/prisma";
import { DEFAULT_COMPANY_ID } from "@/lib/accounting/company";
import BillsScreen from "@/components/BillsScreen";

export const dynamic = "force-dynamic";

export default async function BillsPage() {
  const [suppliers, expenseAccounts, bankAccounts] = await Promise.all([
    prisma.supplier.findMany({ where: { companyId: DEFAULT_COMPANY_ID, isActive: true }, orderBy: { name: "asc" } }),
    prisma.account.findMany({
      where: { companyId: DEFAULT_COMPANY_ID, isActive: true, type: "EXPENSE" },
      orderBy: { name: "asc" },
    }),
    prisma.bankAccount.findMany({ where: { companyId: DEFAULT_COMPANY_ID, isActive: true }, orderBy: { name: "asc" } }),
  ]);

  return (
    <BillsScreen
      suppliers={suppliers.map((s) => ({ id: s.id, name: s.name }))}
      accounts={expenseAccounts.map((a) => ({ id: a.id, name: a.name }))}
      bankAccounts={bankAccounts.map((b) => ({ id: b.id, name: b.name }))}
    />
  );
}
