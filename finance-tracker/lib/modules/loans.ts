import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID } from "../accounting/company";
import { postJournalEntry, getAccountByCode, type JournalLineInput } from "../accounting/ledger";

const INTEREST_EXPENSE_CODE = "5620";

export async function recordLoanDisbursement(input: {
  loanId: string;
  bankAccountId: string;
  date: Date;
  companyId?: string;
}) {
  const companyId = input.companyId ?? DEFAULT_COMPANY_ID;
  const loan = await prisma.loan.findUnique({ where: { id: input.loanId } });
  if (!loan) throw new Error("Loan not found");
  if (loan.disbursementJournalEntryId) throw new Error("Loan already recorded as received");

  const bankAccount = await prisma.bankAccount.findUnique({ where: { id: input.bankAccountId } });
  if (!bankAccount) throw new Error("Bank account not found");

  const entry = await postJournalEntry({
    companyId,
    date: input.date,
    memo: `Loan received from ${loan.lender}`,
    source: "MANUAL",
    lines: [
      { accountId: bankAccount.glAccountId, debit: Number(loan.principal) },
      { accountId: loan.glAccountId, credit: Number(loan.principal) },
    ],
  });

  return prisma.loan.update({
    where: { id: input.loanId },
    data: {
      bankAccountId: input.bankAccountId,
      disbursementJournalEntryId: entry.id,
      remainingPrincipal: loan.principal,
    },
  });
}

export async function recordLoanRepayment(input: {
  loanId: string;
  principalAmount: number;
  interestAmount?: number;
  date: Date;
  bankAccountId: string;
  notes?: string;
  companyId?: string;
  createdBy?: string;
}) {
  const companyId = input.companyId ?? DEFAULT_COMPANY_ID;
  const loan = await prisma.loan.findUnique({ where: { id: input.loanId } });
  if (!loan) throw new Error("Loan not found");

  const remaining = Number(loan.remainingPrincipal ?? loan.principal);
  if (input.principalAmount > remaining + 0.005) {
    throw new Error(`Principal payment exceeds remaining balance of ${remaining.toFixed(2)}`);
  }

  const bankAccount = await prisma.bankAccount.findUnique({ where: { id: input.bankAccountId } });
  if (!bankAccount) throw new Error("Bank account not found");

  const interestAmount = input.interestAmount ?? 0;
  const lines: JournalLineInput[] = [{ accountId: loan.glAccountId, debit: input.principalAmount }];
  if (interestAmount > 0) {
    const interestAccount = await getAccountByCode(INTEREST_EXPENSE_CODE, companyId);
    lines.push({ accountId: interestAccount.id, debit: interestAmount });
  }
  lines.push({ accountId: bankAccount.glAccountId, credit: input.principalAmount + interestAmount });

  const entry = await postJournalEntry({
    companyId,
    date: input.date,
    memo: input.notes ?? `Loan repayment - ${loan.lender}`,
    source: "MANUAL",
    lines,
  });

  const payment = await prisma.loanPayment.create({
    data: {
      companyId,
      loanId: input.loanId,
      date: input.date,
      principalAmount: input.principalAmount,
      interestAmount,
      bankAccountId: input.bankAccountId,
      journalEntryId: entry.id,
      notes: input.notes,
      createdBy: input.createdBy,
    },
  });

  await prisma.loan.update({
    where: { id: input.loanId },
    data: { remainingPrincipal: remaining - input.principalAmount },
  });

  return payment;
}

export async function listLoans(companyId = DEFAULT_COMPANY_ID) {
  return prisma.loan.findMany({
    where: { companyId },
    include: { payments: true },
    orderBy: { startDate: "desc" },
  });
}
