import { prisma } from "@/lib/prisma";
import { DEFAULT_COMPANY_ID } from "@/lib/accounting/company";
import MasterDataScreen from "@/components/MasterDataScreen";
import type { FieldConfig } from "@/components/MasterDataScreen";

export const dynamic = "force-dynamic";

const BANK_ACCOUNT_TYPES = [
  { value: "CASH", label: "Cash" },
  { value: "PETTY_CASH", label: "Petty Cash" },
  { value: "CURRENT_ACCOUNT", label: "Current Account" },
  { value: "SAVINGS_ACCOUNT", label: "Savings Account" },
  { value: "CREDIT_CARD", label: "Credit Card" },
  { value: "BUSINESS_LOAN", label: "Business Loan" },
];

export default async function BankAccountsPage() {
  const accounts = await prisma.account.findMany({
    where: { companyId: DEFAULT_COMPANY_ID, isActive: true },
    orderBy: { code: "asc" },
  });

  const fields: FieldConfig[] = [
    { name: "name", label: "Name", type: "text", required: true },
    { name: "type", label: "Type", type: "select", required: true, options: BANK_ACCOUNT_TYPES },
    { name: "accountNumber", label: "Account number", type: "text" },
    {
      name: "glAccountId",
      label: "Linked GL account",
      type: "select",
      required: true,
      options: accounts.map((a) => ({ value: a.id, label: `${a.code} · ${a.name}` })),
    },
    { name: "openingBalance", label: "Opening balance (EGP)", type: "number" },
    { name: "isActive", label: "Active", type: "checkbox" },
  ];

  return <MasterDataScreen entity="bank-accounts" title="Bank Accounts" fields={fields} />;
}
