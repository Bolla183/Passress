import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { fetchAllOrders } from "@/lib/shopify";

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

  let created = 0;
  let updated = 0;

  for (const order of orders) {
    const shopifyOrderId = String(order.id);
    const existing = await prisma.transaction.findUnique({
      where: { shopifyOrderId },
    });

    await prisma.transaction.upsert({
      where: { shopifyOrderId },
      create: {
        type: "INCOME",
        category: "Shopify Sales",
        amount: Number(order.total_price),
        date: new Date(order.created_at),
        note: order.name,
        source: "SHOPIFY",
        shopifyOrderId,
      },
      update: {
        amount: Number(order.total_price),
        date: new Date(order.created_at),
        note: order.name,
      },
    });

    if (existing) updated += 1;
    else created += 1;
  }

  return NextResponse.json({ ok: true, created, updated, total: orders.length });
}
