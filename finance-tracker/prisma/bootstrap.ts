import "dotenv/config";
import { prisma } from "../lib/prisma";
import { seedCompanyAndAccounts } from "../lib/accounting/seedAccounts";
import { migrateLegacyTransactions } from "./migrate-legacy-transactions";

async function main() {
  await seedCompanyAndAccounts();
  const result = await migrateLegacyTransactions();
  console.log(`Bootstrap complete. Legacy migration: ${JSON.stringify(result)}`);
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (err) => {
    console.error(err);
    await prisma.$disconnect();
    process.exit(1);
  });
