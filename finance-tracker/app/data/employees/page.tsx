import { prisma } from "@/lib/prisma";
import { DEFAULT_COMPANY_ID } from "@/lib/accounting/company";
import MasterDataScreen from "@/components/MasterDataScreen";
import type { FieldConfig } from "@/components/MasterDataScreen";

export const dynamic = "force-dynamic";

export default async function EmployeesPage() {
  const departments = await prisma.department.findMany({
    where: { companyId: DEFAULT_COMPANY_ID, isActive: true },
    orderBy: { name: "asc" },
  });

  const fields: FieldConfig[] = [
    { name: "name", label: "Name", type: "text", required: true },
    { name: "email", label: "Email", type: "email" },
    { name: "phone", label: "Phone", type: "tel" },
    { name: "role", label: "Role", type: "text" },
    {
      name: "departmentId",
      label: "Department",
      type: "select",
      options: departments.map((d) => ({ value: d.id, label: d.name })),
    },
    { name: "salaryAmount", label: "Salary (EGP)", type: "number" },
    { name: "hireDate", label: "Hire date", type: "date" },
    { name: "isActive", label: "Active", type: "checkbox" },
  ];

  return <MasterDataScreen entity="employees" title="Employees" fields={fields} />;
}
