import { NextResponse } from "next/server";
import { recordBillPayment } from "@/lib/modules/bills";

export async function POST(
  request: Request,
  ctx: { params: Promise<{ id: string }> }
) {
  const { id } = await ctx.params;
  const body = await request.json();
  const { amount, date, bankAccountId } = body ?? {};

  const numericAmount = Number(amount);
  if (!Number.isFinite(numericAmount) || numericAmount <= 0) {
    return NextResponse.json({ error: "Invalid amount" }, { status: 400 });
  }
  if (typeof date !== "string" || !date) {
    return NextResponse.json({ error: "Invalid date" }, { status: 400 });
  }
  if (typeof bankAccountId !== "string" || !bankAccountId) {
    return NextResponse.json({ error: "Choose a bank account" }, { status: 400 });
  }

  try {
    const payment = await recordBillPayment({
      billId: id,
      amount: numericAmount,
      date: new Date(`${date}T00:00:00Z`),
      bankAccountId,
    });
    return NextResponse.json({ payment }, { status: 201 });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Could not record payment" },
      { status: 400 }
    );
  }
}
