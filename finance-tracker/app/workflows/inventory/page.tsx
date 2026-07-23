import { prisma } from "@/lib/prisma";
import { DEFAULT_COMPANY_ID } from "@/lib/accounting/company";
import InventoryScreen from "@/components/InventoryScreen";

export const dynamic = "force-dynamic";

export default async function InventoryPage() {
  const [products, warehouses, suppliers, customers, revenueAccounts, bankAccounts] = await Promise.all([
    prisma.product.findMany({ where: { companyId: DEFAULT_COMPANY_ID, isActive: true }, orderBy: { name: "asc" } }),
    prisma.warehouse.findMany({ where: { companyId: DEFAULT_COMPANY_ID, isActive: true }, orderBy: { name: "asc" } }),
    prisma.supplier.findMany({ where: { companyId: DEFAULT_COMPANY_ID, isActive: true }, orderBy: { name: "asc" } }),
    prisma.customer.findMany({ where: { companyId: DEFAULT_COMPANY_ID, isActive: true }, orderBy: { name: "asc" } }),
    prisma.account.findMany({
      where: { companyId: DEFAULT_COMPANY_ID, isActive: true, type: "REVENUE" },
      orderBy: { name: "asc" },
    }),
    prisma.bankAccount.findMany({ where: { companyId: DEFAULT_COMPANY_ID, isActive: true }, orderBy: { name: "asc" } }),
  ]);

  return (
    <InventoryScreen
      products={products.map((p) => ({ id: p.id, name: p.name, type: p.type, cost: Number(p.cost), price: Number(p.price) }))}
      warehouses={warehouses.map((w) => ({ id: w.id, name: w.name }))}
      suppliers={suppliers.map((s) => ({ id: s.id, name: s.name }))}
      customers={customers.map((c) => ({ id: c.id, name: c.name }))}
      revenueAccounts={revenueAccounts.map((a) => ({ id: a.id, name: a.name }))}
      bankAccounts={bankAccounts.map((b) => ({ id: b.id, name: b.name }))}
    />
  );
}
