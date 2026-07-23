import { NextResponse } from "next/server";
import { getStockLevels } from "@/lib/modules/inventory";

export async function GET() {
  const stock = await getStockLevels();
  return NextResponse.json({ stock });
}
