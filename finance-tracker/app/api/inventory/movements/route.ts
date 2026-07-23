import { NextResponse } from "next/server";
import { listInventoryMovements } from "@/lib/modules/inventory";

export async function GET() {
  const movements = await listInventoryMovements();
  return NextResponse.json({ movements });
}
