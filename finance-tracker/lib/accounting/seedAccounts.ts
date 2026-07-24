import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID, ensureDefaultCompany } from "./company";
import { CHART_OF_ACCOUNTS, type AccountSeedNode } from "./chartOfAccountsSeed";

// Only creates missing accounts — never overwrites an existing row. The
// seed re-runs on every deploy (alongside the founder's own edits via the
// Chart of Accounts screen), so touching existing rows here would silently
// revert anything they've changed.
async function upsertAccountTree(
  node: AccountSeedNode,
  companyId: string,
  parentId: string | null
) {
  const existing = await prisma.account.findUnique({
    where: { companyId_code: { companyId, code: node.code } },
  });

  const account =
    existing ??
    (await prisma.account.create({
      data: {
        companyId,
        code: node.code,
        name: node.name,
        type: node.type,
        normalBalance: node.normalBalance,
        subtype: node.subtype,
        showInQuickAdd: node.showInQuickAdd ?? false,
        parentId,
      },
    }));

  for (const child of node.children ?? []) {
    await upsertAccountTree(child, companyId, account.id);
  }
}

function collectQuickAddCodes(nodes: AccountSeedNode[]): string[] {
  const codes: string[] = [];
  for (const node of nodes) {
    if (node.showInQuickAdd) codes.push(node.code);
    codes.push(...collectQuickAddCodes(node.children ?? []));
  }
  return codes;
}

// One-time backfill for the showInQuickAdd column added after accounts
// already existed in production. Only runs if no account has ever been
// flagged yet, so it can't clobber a founder's later edits via the Chart of
// Accounts screen — after the first run, this is permanently a no-op.
async function backfillQuickAddFlags(companyId: string) {
  const alreadyBackfilled = await prisma.account.findFirst({
    where: { companyId, showInQuickAdd: true },
  });
  if (alreadyBackfilled) return;

  const codes = collectQuickAddCodes(CHART_OF_ACCOUNTS);
  if (codes.length === 0) return;

  await prisma.account.updateMany({
    where: { companyId, code: { in: codes } },
    data: { showInQuickAdd: true },
  });
}

async function seedPaymentMethods(companyId: string) {
  const names = ["Cash", "Bank Transfer", "Credit Card", "Instapay", "Vodafone Cash"];
  for (const name of names) {
    const existing = await prisma.paymentMethod.findFirst({ where: { companyId, name } });
    if (!existing) {
      await prisma.paymentMethod.create({ data: { companyId, name } });
    }
  }
}

async function seedOrgDefaults(companyId: string) {
  const warehouse = await prisma.warehouse.findFirst({ where: { companyId, name: "Main Warehouse" } });
  if (!warehouse) {
    await prisma.warehouse.create({ data: { companyId, name: "Main Warehouse" } });
  }

  const location = await prisma.location.findFirst({ where: { companyId, name: "Cairo HQ" } });
  if (!location) {
    await prisma.location.create({ data: { companyId, name: "Cairo HQ" } });
  }

  const department = await prisma.department.findFirst({ where: { companyId, name: "Operations" } });
  if (!department) {
    await prisma.department.create({ data: { companyId, name: "Operations" } });
  }

  const costCenter = await prisma.costCenter.findFirst({ where: { companyId, name: "General" } });
  if (!costCenter) {
    await prisma.costCenter.create({ data: { companyId, name: "General" } });
  }

  const taxRates: Array<[string, number]> = [
    ["No Tax", 0],
    ["VAT 14%", 14],
  ];
  for (const [name, ratePercent] of taxRates) {
    const existing = await prisma.taxRate.findFirst({ where: { companyId, name } });
    if (!existing) {
      await prisma.taxRate.create({ data: { companyId, name, ratePercent } });
    }
  }
}

async function seedBankAccounts(companyId: string) {
  const mapping: Array<[string, string, string]> = [
    ["Cash", "CASH", "1000"],
    ["Bank - Current Account", "CURRENT_ACCOUNT", "1020"],
    ["Bank - Savings Account", "SAVINGS_ACCOUNT", "1030"],
  ];

  for (const [name, type, glCode] of mapping) {
    const existing = await prisma.bankAccount.findFirst({ where: { companyId, name } });
    if (existing) continue;

    const glAccount = await prisma.account.findUnique({
      where: { companyId_code: { companyId, code: glCode } },
    });
    if (!glAccount) continue;

    await prisma.bankAccount.create({
      data: {
        companyId,
        name,
        type: type as "CASH" | "CURRENT_ACCOUNT" | "SAVINGS_ACCOUNT",
        glAccountId: glAccount.id,
      },
    });
  }
}

// Placeholder garment products so COGS entries (Fabric, Production) can be
// tagged per-garment via JournalLine.productId -- the same dimension the
// Inventory module already uses, and the foundation a future per-product
// P&L/dashboard would read from. Real SKUs/cost/price can be edited anytime
// via More -> Master Data -> Products.
async function seedGarmentProducts(companyId: string) {
  const products: Array<[string, string]> = [
    ["Blazer", "BLZ-001"],
    ["Pants", "PNT-001"],
    ["Sleeves", "SLV-001"],
  ];

  for (const [name, sku] of products) {
    // Check both -- the DB's real uniqueness constraint is (companyId, sku),
    // but a name match also means "this garment already exists under some
    // other SKU" and shouldn't get a second, duplicate row either.
    const existing = await prisma.product.findFirst({
      where: { companyId, OR: [{ name }, { sku }] },
    });
    if (existing) continue;

    await prisma.product.create({
      data: { companyId, name, sku, type: "FINISHED_GOOD" },
    });
  }
}

export async function seedCompanyAndAccounts() {
  const company = await ensureDefaultCompany();

  // Must run before creating any new tree nodes below, so the "has this
  // ever run before" check only sees accounts that predate this feature.
  await backfillQuickAddFlags(company.id);

  for (const node of CHART_OF_ACCOUNTS) {
    await upsertAccountTree(node, company.id, null);
  }

  await seedPaymentMethods(company.id);
  await seedOrgDefaults(company.id);
  await seedBankAccounts(company.id);
  await seedGarmentProducts(company.id);

  return company;
}

if (require.main === module) {
  seedCompanyAndAccounts()
    .then(() => {
      console.log(`Chart of accounts seeded for company ${DEFAULT_COMPANY_ID}`);
      return prisma.$disconnect();
    })
    .catch(async (err) => {
      console.error(err);
      await prisma.$disconnect();
      process.exit(1);
    });
}
