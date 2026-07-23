import { prisma } from "@/lib/prisma";
import { DEFAULT_COMPANY_ID } from "@/lib/accounting/company";
import PayrollScreen from "@/components/PayrollScreen";

export const dynamic = "force-dynamic";

export default async function PayrollPage() {
  const [employees, bankAccounts] = await Promise.all([
    prisma.employee.findMany({ where: { companyId: DEFAULT_COMPANY_ID, isActive: true }, orderBy: { name: "asc" } }),
    prisma.bankAccount.findMany({ where: { companyId: DEFAULT_COMPANY_ID, isActive: true }, orderBy: { name: "asc" } }),
  ]);

  return (
    <PayrollScreen
      employees={employees.map((e) => ({
        id: e.id,
        name: e.name,
        salaryAmount: e.salaryAmount ? Number(e.salaryAmount) : null,
      }))}
      bankAccounts={bankAccounts.map((b) => ({ id: b.id, name: b.name }))}
    />
  );
}
