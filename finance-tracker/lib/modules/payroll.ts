import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID } from "../accounting/company";
import { postJournalEntry, getAccountByCode } from "../accounting/ledger";
import { DEFAULT_CASH_ACCOUNT_CODE } from "../accounting/chartOfAccountsSeed";

const SALARIES_EXPENSE_CODE = "5410"; // "Salaries" under Salaries & Contractors

// Cash-basis: paying salary directly debits the expense, no payable accrual
// step. Payroll is just a name and an amount — there's no separate
// "set up an employee first" step. The name resolves to an Employee record
// behind the scenes (matched case-insensitively, created if new) so
// per-employee reporting stays possible without adding friction up front.
async function findOrCreateEmployee(name: string, companyId: string) {
  const trimmed = name.trim();
  const existing = await prisma.employee.findFirst({
    where: { companyId, name: { equals: trimmed, mode: "insensitive" } },
  });
  if (existing) return existing;
  return prisma.employee.create({ data: { companyId, name: trimmed } });
}

function periodLabel(date: Date): string {
  return date.toLocaleDateString("en-US", { month: "short", year: "numeric", timeZone: "UTC" });
}

export async function recordSalaryPayment(input: {
  employeeName: string;
  amount: number;
  date: Date;
  notes?: string;
  companyId?: string;
  createdBy?: string;
}) {
  const companyId = input.companyId ?? DEFAULT_COMPANY_ID;
  const [employee, salariesAccount, cash] = await Promise.all([
    findOrCreateEmployee(input.employeeName, companyId),
    getAccountByCode(SALARIES_EXPENSE_CODE, companyId),
    getAccountByCode(DEFAULT_CASH_ACCOUNT_CODE, companyId),
  ]);

  const entry = await postJournalEntry({
    companyId,
    date: input.date,
    memo: input.notes ?? `Salary: ${employee.name}`,
    source: "MANUAL",
    lines: [
      { accountId: salariesAccount.id, debit: input.amount, employeeId: employee.id },
      { accountId: cash.id, credit: input.amount, employeeId: employee.id },
    ],
  });

  return prisma.salaryPayment.create({
    data: {
      companyId,
      employeeId: employee.id,
      period: periodLabel(input.date),
      amount: input.amount,
      date: input.date,
      journalEntryId: entry.id,
      notes: input.notes,
      createdBy: input.createdBy,
    },
    include: { employee: true },
  });
}

export async function listSalaryPayments(
  { from, to }: { from?: Date; to?: Date } = {},
  companyId = DEFAULT_COMPANY_ID
) {
  return prisma.salaryPayment.findMany({
    where: {
      companyId,
      date: { ...(from ? { gte: from } : {}), ...(to ? { lt: to } : {}) },
    },
    include: { employee: true },
    orderBy: { date: "desc" },
  });
}
