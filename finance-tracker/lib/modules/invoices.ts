import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID } from "../accounting/company";
import { postJournalEntry, getAccountByCode } from "../accounting/ledger";

const ACCOUNTS_RECEIVABLE_CODE = "1100";

export async function recordInvoice(input: {
  customerId: string;
  accountId: string;
  amount: number;
  invoiceDate: Date;
  dueDate?: Date;
  invoiceNumber?: string;
  notes?: string;
  companyId?: string;
  createdBy?: string;
}) {
  const companyId = input.companyId ?? DEFAULT_COMPANY_ID;
  const ar = await getAccountByCode(ACCOUNTS_RECEIVABLE_CODE, companyId);

  const entry = await postJournalEntry({
    companyId,
    date: input.invoiceDate,
    memo: input.notes ?? input.invoiceNumber,
    source: "MANUAL",
    lines: [
      { accountId: ar.id, debit: input.amount, customerId: input.customerId },
      { accountId: input.accountId, credit: input.amount, customerId: input.customerId },
    ],
  });

  return prisma.invoice.create({
    data: {
      companyId,
      customerId: input.customerId,
      accountId: input.accountId,
      amount: input.amount,
      invoiceDate: input.invoiceDate,
      dueDate: input.dueDate,
      invoiceNumber: input.invoiceNumber,
      notes: input.notes,
      journalEntryId: entry.id,
      createdBy: input.createdBy,
    },
  });
}

export async function recordInvoicePayment(input: {
  invoiceId: string;
  amount: number;
  date: Date;
  bankAccountId: string;
  companyId?: string;
  createdBy?: string;
}) {
  const companyId = input.companyId ?? DEFAULT_COMPANY_ID;
  const invoice = await prisma.invoice.findUnique({ where: { id: input.invoiceId } });
  if (!invoice) throw new Error("Invoice not found");

  const remaining = Number(invoice.amount) - Number(invoice.amountPaid);
  if (input.amount > remaining + 0.005) {
    throw new Error(`Payment exceeds remaining balance of ${remaining.toFixed(2)}`);
  }

  const bankAccount = await prisma.bankAccount.findUnique({ where: { id: input.bankAccountId } });
  if (!bankAccount) throw new Error("Bank account not found");

  const ar = await getAccountByCode(ACCOUNTS_RECEIVABLE_CODE, companyId);

  const entry = await postJournalEntry({
    companyId,
    date: input.date,
    memo: `Collection for invoice ${invoice.invoiceNumber ?? invoice.id}`,
    source: "MANUAL",
    lines: [
      { accountId: bankAccount.glAccountId, debit: input.amount, customerId: invoice.customerId },
      { accountId: ar.id, credit: input.amount, customerId: invoice.customerId },
    ],
  });

  const payment = await prisma.invoicePayment.create({
    data: {
      companyId,
      invoiceId: input.invoiceId,
      date: input.date,
      amount: input.amount,
      bankAccountId: input.bankAccountId,
      journalEntryId: entry.id,
      createdBy: input.createdBy,
    },
  });

  const newAmountPaid = Number(invoice.amountPaid) + input.amount;
  await prisma.invoice.update({
    where: { id: input.invoiceId },
    data: {
      amountPaid: newAmountPaid,
      status: newAmountPaid >= Number(invoice.amount) - 0.005 ? "PAID" : "PARTIALLY_PAID",
    },
  });

  return payment;
}

export async function listInvoices(companyId = DEFAULT_COMPANY_ID) {
  return prisma.invoice.findMany({
    where: { companyId },
    include: { customer: true, account: true, payments: true },
    orderBy: { invoiceDate: "desc" },
  });
}
