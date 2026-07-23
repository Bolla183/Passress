import { prisma } from "../lib/prisma";
import { DEFAULT_COMPANY_ID } from "../lib/accounting/company";
import { getAccountByCode, postJournalEntry } from "../lib/accounting/ledger";
import {
  QUICK_ADD_INCOME_ACCOUNT_CODES,
  QUICK_ADD_EXPENSE_ACCOUNT_CODES,
  DEFAULT_CASH_ACCOUNT_CODE,
} from "../lib/accounting/chartOfAccountsSeed";

// Converts every existing flat Transaction row into an equivalent balanced
// JournalEntry against the new Chart of Accounts. Idempotent: each migrated
// entry is tagged with a reference back to the source row, so re-running
// this (e.g. on every Vercel build) is a safe no-op once already migrated.
export async function migrateLegacyTransactions() {
  const cash = await getAccountByCode(DEFAULT_CASH_ACCOUNT_CODE);
  const transactions = await prisma.transaction.findMany({ orderBy: { date: "asc" } });

  let migrated = 0;
  let skipped = 0;

  for (const transaction of transactions) {
    const reference = `legacy:${transaction.id}`;
    const existing = await prisma.journalEntry.findFirst({ where: { reference } });
    if (existing) {
      skipped += 1;
      continue;
    }

    const codeMap =
      transaction.type === "INCOME" ? QUICK_ADD_INCOME_ACCOUNT_CODES : QUICK_ADD_EXPENSE_ACCOUNT_CODES;
    const targetCode = codeMap[transaction.category];
    if (!targetCode) {
      console.warn(`Skipping transaction ${transaction.id}: unknown category "${transaction.category}"`);
      continue;
    }

    const targetAccount = await getAccountByCode(targetCode);
    const amount = Number(transaction.amount);

    await postJournalEntry({
      companyId: DEFAULT_COMPANY_ID,
      date: transaction.date,
      memo: transaction.note ?? undefined,
      source: "MIGRATION",
      reference,
      lines:
        transaction.type === "INCOME"
          ? [
              { accountId: cash.id, debit: amount },
              { accountId: targetAccount.id, credit: amount },
            ]
          : [
              { accountId: targetAccount.id, debit: amount },
              { accountId: cash.id, credit: amount },
            ],
    });

    migrated += 1;
  }

  return { migrated, skipped, total: transactions.length };
}

if (require.main === module) {
  migrateLegacyTransactions()
    .then((result) => {
      console.log(`Legacy transaction migration: ${JSON.stringify(result)}`);
      return prisma.$disconnect();
    })
    .catch(async (err) => {
      console.error(err);
      await prisma.$disconnect();
      process.exit(1);
    });
}
