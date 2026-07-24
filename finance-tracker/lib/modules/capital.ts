import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID } from "../accounting/company";
import { postJournalEntry, getAccountByCode } from "../accounting/ledger";
import { getAccountBalance } from "../accounting/reports";
import { DEFAULT_CASH_ACCOUNT_CODE } from "../accounting/chartOfAccountsSeed";

const OWNERS_EQUITY_ACCOUNT_CODE = "3000";

// The only way money the owner puts in personally becomes visible to the
// ledger: Debit Cash / Credit Owner's Equity. Without this, "Capital
// Invested" and "Owner Equity" on the Dashboard have no way to move.
export async function recordCapitalContribution(input: {
  amount: number;
  date: Date;
  notes?: string;
  companyId?: string;
  createdBy?: string;
}) {
  const companyId = input.companyId ?? DEFAULT_COMPANY_ID;
  const [equityAccount, cash] = await Promise.all([
    getAccountByCode(OWNERS_EQUITY_ACCOUNT_CODE, companyId),
    getAccountByCode(DEFAULT_CASH_ACCOUNT_CODE, companyId),
  ]);

  return postJournalEntry({
    companyId,
    date: input.date,
    memo: input.notes ?? "Owner capital contribution",
    source: "MANUAL",
    lines: [
      { accountId: cash.id, debit: input.amount },
      { accountId: equityAccount.id, credit: input.amount },
    ],
  });
}

// Rolled-up balance of the Owner's Equity account as of today -- "Capital
// Invested" on the Dashboard is exactly this number, nothing more.
export async function getCapitalInvested(asOfDate: Date, companyId = DEFAULT_COMPANY_ID): Promise<number> {
  const equityAccount = await getAccountByCode(OWNERS_EQUITY_ACCOUNT_CODE, companyId);
  return getAccountBalance(equityAccount.id, asOfDate, companyId);
}

export async function listCapitalContributions(companyId = DEFAULT_COMPANY_ID) {
  const equityAccount = await getAccountByCode(OWNERS_EQUITY_ACCOUNT_CODE, companyId);
  const lines = await prisma.journalLine.findMany({
    where: { companyId, accountId: equityAccount.id, credit: { gt: 0 } },
    include: { journalEntry: true },
    orderBy: { journalEntry: { date: "desc" } },
  });
  return lines.map((l) => ({
    id: l.journalEntry.id,
    date: l.journalEntry.date,
    amount: Number(l.credit),
    notes: l.journalEntry.memo,
  }));
}
