import { prisma } from "../prisma";
import { DEFAULT_COMPANY_ID } from "../accounting/company";
import { fetchAllOrders } from "../shopify";
import { postQuickEntry } from "../accounting/quickEntry";
import { getAccountByCode } from "../accounting/ledger";

// Shared by the manual "Sync Shopify" button and the daily cron job --
// one code path so they can never drift out of sync with each other.
// Incremental: only asks Shopify for orders updated since the last
// successful run, so repeat syncs stay cheap regardless of how much
// order history the store has accumulated.
export async function syncShopifyOrders(companyId = DEFAULT_COMPANY_ID) {
  const company = await prisma.company.findUnique({ where: { id: companyId } });

  const orders = await fetchAllOrders({
    updatedAtMin: company?.lastShopifySyncAt ?? undefined,
  });

  const shopifySalesAccount = await getAccountByCode("4100", companyId);

  let created = 0;
  let updated = 0;

  for (const order of orders) {
    const reference = `shopify:${order.id}`;
    const existing = await prisma.journalEntry.findFirst({ where: { reference } });
    if (existing) {
      await prisma.journalEntry.delete({ where: { id: existing.id } });
    }

    await postQuickEntry({
      companyId,
      accountId: shopifySalesAccount.id,
      amount: Number(order.total_price),
      date: new Date(order.created_at),
      note: order.name,
      source: "SHOPIFY",
      reference,
    });

    if (existing) updated += 1;
    else created += 1;
  }

  await prisma.company.update({
    where: { id: companyId },
    data: { lastShopifySyncAt: new Date() },
  });

  return { created, updated, total: orders.length };
}
