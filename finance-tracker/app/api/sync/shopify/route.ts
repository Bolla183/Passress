import { NextResponse } from "next/server";
import { syncShopifyOrders } from "@/lib/modules/shopifySync";
import { prisma } from "@/lib/prisma";
import { DEFAULT_COMPANY_ID } from "@/lib/accounting/company";

export async function GET() {
  const company = await prisma.company.findUnique({ where: { id: DEFAULT_COMPANY_ID } });
  return NextResponse.json({ lastSyncedAt: company?.lastShopifySyncAt ?? null });
}

export async function POST() {
  try {
    const result = await syncShopifyOrders();
    return NextResponse.json({ ok: true, ...result });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Sync failed" },
      { status: 400 }
    );
  }
}
