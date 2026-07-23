import { prisma } from "@/lib/prisma";
import { DEFAULT_COMPANY_ID } from "@/lib/accounting/company";
import PayrollScreen from "@/components/PayrollScreen";

export const dynamic = "force-dynamic";

export default async function PayrollPage() {
  const employees = await prisma.employee.findMany({
    where: { companyId: DEFAULT_COMPANY_ID, isActive: true },
    orderBy: { name: "asc" },
    select: { name: true },
  });

  return <PayrollScreen employeeNames={employees.map((e) => e.name)} />;
}
