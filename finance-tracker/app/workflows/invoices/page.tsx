import { prisma } from "@/lib/prisma";
import { DEFAULT_COMPANY_ID } from "@/lib/accounting/company";
import InvoicesScreen from "@/components/InvoicesScreen";

export const dynamic = "force-dynamic";

export default async function InvoicesPage() {
  const [customers, revenueAccounts, bankAccounts] = await Promise.all([
    prisma.customer.findMany({ where: { companyId: DEFAULT_COMPANY_ID, isActive: true }, orderBy: { name: "asc" } }),
    prisma.account.findMany({
      where: { companyId: DEFAULT_COMPANY_ID, isActive: true, type: "REVENUE" },
      orderBy: { name: "asc" },
    }),
    prisma.bankAccount.findMany({ where: { companyId: DEFAULT_COMPANY_ID, isActive: true }, orderBy: { name: "asc" } }),
  ]);

  return (
    <InvoicesScreen
      customers={customers.map((c) => ({ id: c.id, name: c.name }))}
      accounts={revenueAccounts.map((a) => ({ id: a.id, name: a.name }))}
      bankAccounts={bankAccounts.map((b) => ({ id: b.id, name: b.name }))}
    />
  );
}
