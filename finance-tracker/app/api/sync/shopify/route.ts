import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { fetchAllOrders } from "@/lib/shopify";
import { postQuickEntry } from "@/lib/accounting/quickEntry";
import { getAccountByCode } from "@/lib/accounting/ledger";

export async function POST() {
  let orders;
  try {
    orders = await fetchAllOrders();
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Sync failed" },
      { status: 400 }
    );
  }

  const shopifySalesAccount = await getAccountByCode("4100");

  let created = 0;
  let updated = 0;

  for (const order of orders) {
    const reference = `shopify:${order.id}`;
    const existing = await prisma.journalEntry.findFirst({ where: { reference } });
    if (existing) {
      await prisma.journalEntry.delete({ where: { id: existing.id } });
    }

    await postQuickEntry({
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

  return NextResponse.json({ ok: true, created, updated, total: orders.length });
}
