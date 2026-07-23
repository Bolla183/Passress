import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID } from "../accounting/company";
import { postJournalEntry, getAccountByCode } from "../accounting/ledger";

const SALARIES_EXPENSE_CODE = "5410"; // "Salaries" under Salaries & Contractors

// Cash-basis: paying salary directly debits the expense, no payable accrual
// step. That matches how a small team is actually paid day to day.
export async function recordSalaryPayment(input: {
  employeeId: string;
  period: string;
  amount: number;
  date: Date;
  bankAccountId: string;
  notes?: string;
  companyId?: string;
  createdBy?: string;
}) {
  const companyId = input.companyId ?? DEFAULT_COMPANY_ID;
  const [salariesAccount, bankAccount] = await Promise.all([
    getAccountByCode(SALARIES_EXPENSE_CODE, companyId),
    prisma.bankAccount.findUnique({ where: { id: input.bankAccountId } }),
  ]);
  if (!bankAccount) throw new Error("Bank account not found");

  const entry = await postJournalEntry({
    companyId,
    date: input.date,
    memo: input.notes ?? `Salary for ${input.period}`,
    source: "MANUAL",
    lines: [
      { accountId: salariesAccount.id, debit: input.amount, employeeId: input.employeeId },
      { accountId: bankAccount.glAccountId, credit: input.amount, employeeId: input.employeeId },
    ],
  });

  return prisma.salaryPayment.create({
    data: {
      companyId,
      employeeId: input.employeeId,
      period: input.period,
      amount: input.amount,
      date: input.date,
      bankAccountId: input.bankAccountId,
      journalEntryId: entry.id,
      notes: input.notes,
      createdBy: input.createdBy,
    },
  });
}

export async function listSalaryPayments(companyId = DEFAULT_COMPANY_ID) {
  return prisma.salaryPayment.findMany({
    where: { companyId },
    include: { employee: true },
    orderBy: { date: "desc" },
  });
}
