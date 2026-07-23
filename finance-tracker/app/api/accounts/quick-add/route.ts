import { NextResponse } from "next/server";
import { getQuickAddAccounts } from "@/lib/accounting/quickEntry";

export async function GET() {
  const accounts = await getQuickAddAccounts();
  return NextResponse.json(accounts);
}
