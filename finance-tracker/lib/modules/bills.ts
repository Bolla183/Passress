import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID } from "../accounting/company";
import { postJournalEntry, getAccountByCode } from "../accounting/ledger";

const ACCOUNTS_PAYABLE_CODE = "2000";

export async function recordBill(input: {
  supplierId: string;
  accountId: string;
  amount: number;
  billDate: Date;
  dueDate?: Date;
  billNumber?: string;
  notes?: string;
  companyId?: string;
  createdBy?: string;
}) {
  const companyId = input.companyId ?? DEFAULT_COMPANY_ID;
  const ap = await getAccountByCode(ACCOUNTS_PAYABLE_CODE, companyId);

  const entry = await postJournalEntry({
    companyId,
    date: input.billDate,
    memo: input.notes ?? input.billNumber,
    source: "MANUAL",
    lines: [
      { accountId: input.accountId, debit: input.amount, supplierId: input.supplierId },
      { accountId: ap.id, credit: input.amount, supplierId: input.supplierId },
    ],
  });

  return prisma.bill.create({
    data: {
      companyId,
      supplierId: input.supplierId,
      accountId: input.accountId,
      amount: input.amount,
      billDate: input.billDate,
      dueDate: input.dueDate,
      billNumber: input.billNumber,
      notes: input.notes,
      journalEntryId: entry.id,
      createdBy: input.createdBy,
    },
  });
}

export async function recordBillPayment(input: {
  billId: string;
  amount: number;
  date: Date;
  bankAccountId: string;
  companyId?: string;
  createdBy?: string;
}) {
  const companyId = input.companyId ?? DEFAULT_COMPANY_ID;
  const bill = await prisma.bill.findUnique({ where: { id: input.billId } });
  if (!bill) throw new Error("Bill not found");

  const remaining = Number(bill.amount) - Number(bill.amountPaid);
  if (input.amount > remaining + 0.005) {
    throw new Error(`Payment exceeds remaining balance of ${remaining.toFixed(2)}`);
  }

  const bankAccount = await prisma.bankAccount.findUnique({ where: { id: input.bankAccountId } });
  if (!bankAccount) throw new Error("Bank account not found");

  const ap = await getAccountByCode(ACCOUNTS_PAYABLE_CODE, companyId);

  const entry = await postJournalEntry({
    companyId,
    date: input.date,
    memo: `Payment for bill ${bill.billNumber ?? bill.id}`,
    source: "MANUAL",
    lines: [
      { accountId: ap.id, debit: input.amount, supplierId: bill.supplierId },
      { accountId: bankAccount.glAccountId, credit: input.amount, supplierId: bill.supplierId },
    ],
  });

  const payment = await prisma.billPayment.create({
    data: {
      companyId,
      billId: input.billId,
      date: input.date,
      amount: input.amount,
      bankAccountId: input.bankAccountId,
      journalEntryId: entry.id,
      createdBy: input.createdBy,
    },
  });

  const newAmountPaid = Number(bill.amountPaid) + input.amount;
  await prisma.bill.update({
    where: { id: input.billId },
    data: {
      amountPaid: newAmountPaid,
      status: newAmountPaid >= Number(bill.amount) - 0.005 ? "PAID" : "PARTIALLY_PAID",
    },
  });

  return payment;
}

export async function listBills(companyId = DEFAULT_COMPANY_ID) {
  return prisma.bill.findMany({
    where: { companyId },
    include: { supplier: true, account: true, payments: true },
    orderBy: { billDate: "desc" },
  });
}
