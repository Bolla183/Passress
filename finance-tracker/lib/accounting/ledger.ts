import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID } from "./company";
import type { JournalSource } from "../../app/generated/prisma/enums";

export type JournalLineInput = {
  accountId: string;
  debit?: number;
  credit?: number;
  memo?: string;
  departmentId?: string;
  costCenterId?: string;
  employeeId?: string;
  supplierId?: string;
  customerId?: string;
  productId?: string;
  collectionId?: string;
  brandId?: string;
  campaignId?: string;
  projectId?: string;
  warehouseId?: string;
  locationId?: string;
};

export type PostJournalEntryInput = {
  date: Date;
  memo?: string;
  source?: JournalSource;
  reference?: string;
  paymentMethodId?: string;
  referenceNumber?: string;
  createdBy?: string;
  companyId?: string;
  lines: JournalLineInput[];
};

const ROUNDING_TOLERANCE = 0.005;

// The only function in this app allowed to write ledger data. Every module
// (quick-add, Shopify sync, bills, payroll, inventory) posts through this so
// a balanced double-entry ledger can never be bypassed by new code later.
export async function postJournalEntry(input: PostJournalEntryInput) {
  const companyId = input.companyId ?? DEFAULT_COMPANY_ID;

  if (input.lines.length < 2) {
    throw new Error("A journal entry needs at least two lines");
  }

  let totalDebit = 0;
  let totalCredit = 0;
  for (const line of input.lines) {
    const debit = line.debit ?? 0;
    const credit = line.credit ?? 0;
    if (debit < 0 || credit < 0) {
      throw new Error("Journal line amounts cannot be negative");
    }
    if (debit > 0 && credit > 0) {
      throw new Error("A journal line cannot have both a debit and a credit");
    }
    totalDebit += debit;
    totalCredit += credit;
  }

  if (Math.abs(totalDebit - totalCredit) > ROUNDING_TOLERANCE) {
    throw new Error(
      `Unbalanced journal entry: debits ${totalDebit.toFixed(2)} != credits ${totalCredit.toFixed(2)}`
    );
  }

  return prisma.journalEntry.create({
    data: {
      companyId,
      date: input.date,
      memo: input.memo,
      source: input.source ?? "MANUAL",
      reference: input.reference,
      paymentMethodId: input.paymentMethodId,
      referenceNumber: input.referenceNumber,
      createdBy: input.createdBy,
      lines: {
        create: input.lines.map((line) => ({
          companyId,
          accountId: line.accountId,
          debit: line.debit ?? 0,
          credit: line.credit ?? 0,
          memo: line.memo,
          departmentId: line.departmentId,
          costCenterId: line.costCenterId,
          employeeId: line.employeeId,
          supplierId: line.supplierId,
          customerId: line.customerId,
          productId: line.productId,
          collectionId: line.collectionId,
          brandId: line.brandId,
          campaignId: line.campaignId,
          projectId: line.projectId,
          warehouseId: line.warehouseId,
          locationId: line.locationId,
        })),
      },
    },
    include: { lines: true },
  });
}

export async function getAccountByCode(code: string, companyId = DEFAULT_COMPANY_ID) {
  const account = await prisma.account.findUnique({
    where: { companyId_code: { companyId, code } },
  });
  if (!account) throw new Error(`Account with code "${code}" not found`);
  return account;
}
