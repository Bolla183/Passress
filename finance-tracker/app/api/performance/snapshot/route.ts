import { NextResponse } from "next/server";
import { getProfitAndLoss } from "@/lib/accounting/reports";
import { startOfCairoDay, endOfCairoDay, startOfCairoMonth, endOfCairoMonth } from "@/lib/dates";

// A glanceable performance snapshot for the Add screen -- computed from the
// ledger directly (like the Performance dashboard), so it reflects every
// posting (quick-add, Bills, Invoices, Payroll, Loans, Inventory), not just
// plain cash entries.
export async function GET() {
  const now = new Date();

  const [today, month] = await Promise.all([
    getProfitAndLoss({ from: startOfCairoDay(now), to: endOfCairoDay(now) }),
    getProfitAndLoss({ from: startOfCairoMonth(now), to: endOfCairoMonth(now) }),
  ]);

  return NextResponse.json({
    today: { income: today.totalRevenue, expense: today.totalExpense, net: today.netProfit },
    month: { income: month.totalRevenue, expense: month.totalExpense, net: month.netProfit },
  });
}
