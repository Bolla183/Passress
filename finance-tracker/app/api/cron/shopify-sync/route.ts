import { NextResponse } from "next/server";
import { syncShopifyOrders } from "@/lib/modules/shopifySync";

// Invoked by Vercel Cron (see vercel.json). Vercel automatically sends
// "Authorization: Bearer $CRON_SECRET" on cron-triggered requests -- this
// is the only thing that authorizes the request, since the route is listed
// as public in proxy.ts (Vercel's invocation carries no session cookie).
export async function GET(request: Request) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

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
