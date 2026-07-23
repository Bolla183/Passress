import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID, ensureDefaultCompany } from "./company";
import { CHART_OF_ACCOUNTS, type AccountSeedNode } from "./chartOfAccountsSeed";

async function upsertAccountTree(
  node: AccountSeedNode,
  companyId: string,
  parentId: string | null
) {
  const account = await prisma.account.upsert({
    where: { companyId_code: { companyId, code: node.code } },
    update: {
      name: node.name,
      type: node.type,
      normalBalance: node.normalBalance,
      subtype: node.subtype,
      parentId,
    },
    create: {
      companyId,
      code: node.code,
      name: node.name,
      type: node.type,
      normalBalance: node.normalBalance,
      subtype: node.subtype,
      parentId,
    },
  });

  for (const child of node.children ?? []) {
    await upsertAccountTree(child, companyId, account.id);
  }
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

export async function seedCompanyAndAccounts() {
  const company = await ensureDefaultCompany();

  for (const node of CHART_OF_ACCOUNTS) {
    await upsertAccountTree(node, company.id, null);
  }

  await seedPaymentMethods(company.id);
  await seedOrgDefaults(company.id);
  await seedBankAccounts(company.id);

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
