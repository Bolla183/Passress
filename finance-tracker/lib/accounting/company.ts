import { prisma } from "../prisma";

// Single-tenant today; every table already carries companyId so a real
// multi-company product surface (signup, switcher, billing) can be added
// later without touching the data model.
export const DEFAULT_COMPANY_ID = "passress";

export async function ensureDefaultCompany() {
  return prisma.company.upsert({
    where: { id: DEFAULT_COMPANY_ID },
    update: {},
    create: { id: DEFAULT_COMPANY_ID, name: "Passress" },
  });
}
