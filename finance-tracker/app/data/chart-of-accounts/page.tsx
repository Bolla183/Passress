import { prisma } from "@/lib/prisma";
import { DEFAULT_COMPANY_ID } from "@/lib/accounting/company";
import MasterDataScreen from "@/components/MasterDataScreen";
import type { FieldConfig } from "@/components/MasterDataScreen";

export const dynamic = "force-dynamic";

const ACCOUNT_TYPES = [
  { value: "ASSET", label: "Asset" },
  { value: "LIABILITY", label: "Liability" },
  { value: "EQUITY", label: "Equity" },
  { value: "REVENUE", label: "Revenue" },
  { value: "EXPENSE", label: "Expense" },
];

const NORMAL_BALANCES = [
  { value: "DEBIT", label: "Debit" },
  { value: "CREDIT", label: "Credit" },
];

export default async function ChartOfAccountsPage() {
  const accounts = await prisma.account.findMany({
    where: { companyId: DEFAULT_COMPANY_ID },
    orderBy: { code: "asc" },
  });

  const fields: FieldConfig[] = [
    { name: "name", label: "Name", type: "text", required: true },
    { name: "code", label: "Code", type: "text", required: true },
    { name: "type", label: "Type", type: "select", required: true, options: ACCOUNT_TYPES },
    {
      name: "normalBalance",
      label: "Normal balance",
      type: "select",
      required: true,
      options: NORMAL_BALANCES,
    },
    {
      name: "parentId",
      label: "Parent account",
      type: "select",
      options: accounts.map((a) => ({ value: a.id, label: `${a.code} · ${a.name}` })),
    },
    {
      name: "showInQuickAdd",
      label: "Show as a quick-add category",
      type: "checkbox",
    },
    { name: "isActive", label: "Active", type: "checkbox" },
  ];

  return <MasterDataScreen entity="accounts" title="Chart of Accounts" fields={fields} />;
}
